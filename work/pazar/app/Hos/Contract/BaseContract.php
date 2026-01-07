<?php

namespace App\Hos\Contract;

use App\Hos\Remote\RemoteHosService;
use App\Hos\Proof\ProofRecorder;
use App\Models\GuardLedger;
use App\Models\HosOutboxEvent;
use App\Worlds\WorldRegistry;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ServiceUnavailableHttpException;

/**
 * Minimal contract/FSM base.
 *
 * Goal: keep status transition rules in one canonical place and automatically record proof.
 */
abstract class BaseContract
{
    protected Model $subject;

    protected ProofRecorder $proof;

    public function __construct(Model $subject, ProofRecorder $proof)
    {
        $this->subject = $subject;
        $this->proof = $proof;
    }

    /**
     * @return array<string, array<int, string>> map: fromStatus => [toStatus...]
     */
    abstract protected function allowedTransitions(): array;

    /**
     * @return array<int, string>
     */
    protected function terminalStatuses(): array
    {
        return [];
    }

    public function isTerminal(string $status): bool
    {
        return in_array($status, $this->terminalStatuses(), true);
    }

    public function canTransition(string $toStatus): bool
    {
        $fromStatus = (string) ($this->subject->getAttribute('status') ?? '');

        if ($fromStatus === $toStatus) {
            return true;
        }

        if ($this->isTerminal($fromStatus)) {
            return false;
        }

        $allowed = $this->allowedTransitions();

        return in_array($toStatus, $allowed[$fromStatus] ?? [], true);
    }

    public function assertCanTransition(string $toStatus, string $message = 'Invalid status transition.'): void
    {
        $hosMode = (string) config('hos.mode', 'embedded');
        $world = app(WorldRegistry::class)->inferKeyForSubject($this->subject);

        // Remote/Hybrid contract can-transition gate.
        if (in_array($hosMode, ['hybrid', 'remote'], true)) {
            $subjectRef = [
                'type' => class_basename($this->subject::class),
                'class' => $this->subject::class,
                'id' => (int) ($this->subject->getAttribute('id') ?? 0),
                'tenant_id' => (int) ($this->subject->getAttribute('tenant_id') ?? 0),
                'status' => (string) ($this->subject->getAttribute('status') ?? ''),
            ];

            try {
                /** @var array<string,mixed> $resp */
                $resp = app(RemoteHosService::class)->contractCanTransition([
                    'subject_ref' => $subjectRef,
                    'to' => $toStatus,
                    'ctx' => [
                        'world' => $world,
                    ],
                ]);

                $remoteAllowed = (bool) ($resp['allowed'] ?? false);
                $remoteReason = (string) ($resp['reason'] ?? '');

                if ($hosMode === 'hybrid') {
                    $localAllowed = $this->canTransition($toStatus);
                    if ($remoteAllowed !== $localAllowed) {
                        Log::warning('hos.remote.shadow.contract_drift', [
                            'subject' => $this->subject::class,
                            'subject_id' => (int) ($this->subject->getAttribute('id') ?? 0),
                            'from' => (string) ($this->subject->getAttribute('status') ?? ''),
                            'to' => $toStatus,
                            'remote_allowed' => $remoteAllowed,
                            'local_allowed' => $localAllowed,
                            'remote_reason' => $remoteReason,
                            'contract_version' => (string) ($resp['contract_version'] ?? ''),
                        ]);
                    }
                    // Hybrid is shadow-only: embedded remains authoritative.
                } else {
                    // Remote is authoritative for can-transition gate.
                    if (! $remoteAllowed) {
                        throw ValidationException::withMessages([
                            'status' => [$remoteReason !== '' ? $remoteReason : $message],
                        ]);
                    }

                    // Allowed by remote -> continue (transition() still runs locally in this phase).
                    return;
                }
            } catch (ServiceUnavailableHttpException $e) {
                if ($hosMode === 'remote') {
                    // Canon: fail-closed for critical mutation when remote is required.
                    throw $e;
                }
                // Hybrid shadow: ignore.
            } catch (\Throwable $e) {
                if ($hosMode === 'remote') {
                    throw new ServiceUnavailableHttpException(null, 'H-OS remote unavailable for contract enforcement.', $e);
                }
                // Hybrid shadow: ignore.
            }
        }

        if (! $this->canTransition($toStatus)) {
            throw ValidationException::withMessages([
                'status' => [$message],
            ]);
        }
    }

    /**
     * Transition subject status and record proof in one place.
     *
     * @param array{tenant_id:int, user_id?:int|null, source?:string, note?:string|null} $meta
     * @param array<string,mixed> $attributes Additional attributes to update together with status.
     */
    public function transition(string $toStatus, array $meta, array $attributes = []): Model
    {
        /** @var Model $fresh */
        $fresh = DB::transaction(function () use ($toStatus, $meta, $attributes) {
            $id = (int) ($this->subject->getAttribute('id') ?? 0);

            /** @var Model|null $locked */
            $locked = $this->subject::query()
                ->where('id', $id)
                ->lockForUpdate()
                ->first();

            if (! $locked) {
                return $this->subject;
            }

            $fromStatus = (string) ($locked->getAttribute('status') ?? '');
            if ($fromStatus === $toStatus) {
                return $locked;
            }

            // Ensure canTransition/assert checks read the locked row state.
            $this->subject = $locked;
            $this->assertCanTransition($toStatus);

            $fromVersion = (int) ($locked->getAttribute('entity_version') ?? 0);
            $toVersion = $fromVersion + 1;

            $update = array_merge($attributes, [
                'status' => $toStatus,
                'entity_version' => $toVersion,
            ]);
            $locked->update($update);

            $proof = $this->proof->statusChange(
                $meta['tenant_id'],
                $meta['user_id'] ?? null,
                $meta['source'] ?? 'system',
                $locked::class,
                (int) $locked->getAttribute('id'),
                $fromStatus,
                $toStatus,
                $meta['note'] ?? null
            );

            // MVP: persist intent + before/after state in a canonical local ledger.
            $commandKey = (string) ($meta['command_key'] ?? '');
            if ($commandKey === '') {
                $commandKey = 'pazar:auto:proof:'.$proof->id.':'.Str::uuid()->toString();
            }

            $world = (string) ($meta['world'] ?? app(WorldRegistry::class)->inferKeyForSubject($locked));

            GuardLedger::query()->create([
                'tenant_id' => (int) ($meta['tenant_id'] ?? ($locked->getAttribute('tenant_id') ?? 0)),
                'user_id' => $meta['user_id'] ?? null,
                'world' => $world !== '' ? $world : null,
                'subject_type' => $locked::class,
                'subject_id' => (int) ($locked->getAttribute('id') ?? 0),
                'command_key' => $commandKey,
                'from_status' => $fromStatus !== '' ? $fromStatus : null,
                'to_status' => $toStatus,
                'from_version' => $fromVersion,
                'to_version' => $toVersion,
                'created_at' => now(),
            ]);

            // Hybrid: shadow-send transition to remote H-OS for drift measurement / migration rehearsal.
            // Canon: remote failure must NOT break embedded (best-effort).
            $hosMode = (string) config('hos.mode', 'embedded');
            if ($hosMode === 'hybrid') {
                $subjectRef = [
                    'type' => class_basename($locked::class),
                    'class' => $locked::class,
                    'id' => (int) ($locked->getAttribute('id') ?? 0),
                    'tenant_id' => (int) ($meta['tenant_id'] ?? ($locked->getAttribute('tenant_id') ?? 0)),
                    'status' => $toStatus,
                ];

                // Add request_id to outbox event payload (non-breaking)
                $payload = [
                    'subject_ref' => $subjectRef,
                    'to' => $toStatus,
                    'meta' => $meta,
                    // Remote schema expects JSON object for attrs; ensure {} for empty payload.
                    'attrs' => empty($attributes) ? (object) [] : $attributes,
                    // Prefer command_key as idempotency key (actor-bound intent) when present.
                    'idempotency_key' => $commandKey,
                    'ctx' => [
                        'from' => $fromStatus,
                        'world' => $world,
                    ],
                ];
                
                // Add request_id to payload if available (non-breaking, optional field)
                $request = request();
                if ($request && ($request->hasHeader('X-Request-Id') || $request->attributes->has('request_id'))) {
                    $payload['request_id'] = $request->hasHeader('X-Request-Id') 
                        ? $request->header('X-Request-Id') 
                        : $request->attributes->get('request_id');
                }
                
                HosOutboxEvent::enqueue((int) ($meta['tenant_id'] ?? null), 'contract.transition', $payload);
            }

            return $locked->fresh();
        });

        return $fresh;
    }
}









