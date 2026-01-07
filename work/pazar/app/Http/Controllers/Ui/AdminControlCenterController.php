<?php

namespace App\Http\Controllers\Ui;

use App\Http\Controllers\Controller;
use App\Hos\Remote\RemoteHosService;
use App\Models\HosOutboxEvent;
use App\Worlds\WorldRegistry;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\Process\Process;

final class AdminControlCenterController extends Controller
{
    private const CACHE_KEY_HOS_MEASURE = 'control_center:measure:hos';
    private const CACHE_KEY_OUTBOX_AUDIT = 'control_center:measure:outbox_audit';

    public function index(Request $request, RemoteHosService $remote, WorldRegistry $worlds)
    {
        $measuredAt = now();

        $timing = [
            'measured_at' => $measuredAt->toDateTimeString(),
        ];

        $db = [
            'ok' => false,
            'connection' => (string) config('database.default', ''),
            'driver' => '',
            'database' => '',
            'error' => null,
            'checked_at' => $measuredAt->toDateTimeString(),
            'duration_ms' => null,
        ];

        try {
            $conn = (string) config('database.default', '');
            $db['driver'] = (string) config("database.connections.{$conn}.driver", '');
            $db['database'] = (string) config("database.connections.{$conn}.database", '');
            $t0 = microtime(true);
            DB::select('select 1');
            $db['ok'] = true;
            $db['duration_ms'] = (int) round((microtime(true) - $t0) * 1000);
        } catch (\Throwable $e) {
            $db['error'] = $e->getMessage();
        }

        // Lightweight DB snapshot (counts + last activity) to avoid boolean-only "DB OK".
        $dbSnapshot = [
            'ok' => false,
            'duration_ms' => null,
            'migrations' => [
                'table' => false,
                'count' => null,
            ],
            'counts' => [],
            'latest_activity_at' => null,
            'error' => null,
        ];
        try {
            $t0 = microtime(true);
            $tables = [
                'users' => 'users',
                'tenants' => 'tenants',
                'orders' => 'orders',
                'reservations' => 'reservations',
                'payments' => 'payments',
            ];
            $latest = null;
            foreach ($tables as $key => $table) {
                if (! Schema::hasTable($table)) {
                    $dbSnapshot['counts'][$key] = ['table' => false, 'count' => null, 'latest' => null];
                    continue;
                }
                $count = (int) DB::table($table)->count();
                $latestRow = DB::table($table)->select(['created_at', 'updated_at'])->orderByDesc('id')->limit(1)->first();
                $latestAt = null;
                if ($latestRow) {
                    $cand = $latestRow->updated_at ?? $latestRow->created_at ?? null;
                    if ($cand) {
                        $latestAt = (string) $cand;
                    }
                }
                $dbSnapshot['counts'][$key] = ['table' => true, 'count' => $count, 'latest' => $latestAt];
                if (is_string($latestAt) && $latestAt !== '') {
                    $latest = $latest === null ? $latestAt : max($latest, $latestAt);
                }
            }
            $dbSnapshot['migrations']['table'] = Schema::hasTable('migrations');
            if ($dbSnapshot['migrations']['table']) {
                $dbSnapshot['migrations']['count'] = (int) DB::table('migrations')->count();
            }
            $dbSnapshot['latest_activity_at'] = $latest;
            $dbSnapshot['ok'] = true;
            $dbSnapshot['duration_ms'] = (int) round((microtime(true) - $t0) * 1000);
        } catch (\Throwable $e) {
            $dbSnapshot['error'] = $e->getMessage();
        }

        $outboxError = null;
        $outboxCounts = [];
        $oldestPending = null;
        $lastFailed = null;
        $outboxMeasuredAt = $measuredAt->toDateTimeString();
        $oldestPendingAgeSeconds = null;
        $outboxLastSentAt = null;
        $outboxLastEnqueuedAt = null;
        $outboxLastFailedAt = null;

        try {
            $outboxCounts = HosOutboxEvent::query()
                ->selectRaw('status, COUNT(*) as c')
                ->groupBy('status')
                ->orderBy('status')
                ->get()
                ->mapWithKeys(fn ($row) => [(string) $row->status => (int) $row->c])
                ->all();

            $oldestPending = HosOutboxEvent::query()
                ->where('status', 'pending')
                ->orderBy('id')
                ->first();

            $lastFailed = HosOutboxEvent::query()
                ->where('status', 'failed')
                ->orderByDesc('id')
                ->first();

            if ($oldestPending && $oldestPending->created_at) {
                $oldestPendingAgeSeconds = max(0, $measuredAt->diffInSeconds($oldestPending->created_at));
            }

            $outboxLastSentAt = HosOutboxEvent::query()->whereNotNull('sent_at')->max('sent_at');
            $outboxLastEnqueuedAt = HosOutboxEvent::query()->max('created_at');
            $outboxLastFailedAt = HosOutboxEvent::query()->where('status', 'failed')->max('updated_at');
        } catch (QueryException $e) {
            // Local dev often starts without migrations; do not break admin UI.
            $outboxError = $e->getMessage();
        }

        // H-OS measurements are on-demand. We show last measured values (or "not measured").
        $hosMeasure = Cache::get(self::CACHE_KEY_HOS_MEASURE);
        $remoteHealth = is_array($hosMeasure) && is_array(($hosMeasure['remoteHealth'] ?? null))
            ? (array) $hosMeasure['remoteHealth']
            : [
            'ok' => false,
                'data' => ['ok' => false, 'reason' => 'not_measured'],
            'error' => null,
                'checked_at' => null,
                'duration_ms' => null,
            ];

        $computedCallback = $request->getSchemeAndHttpHost().$request->getBaseUrl().'/ui/oidc/callback';
        $configuredRedirect = (string) config('oidc.redirect_uri', '');
        $effectiveRedirect = $configuredRedirect !== '' ? $configuredRedirect : $computedCallback;

        // Link convenience: H-OS Admin (web) is typically :3002 when API is :3000.
        $hosApiBase = (string) config('hos.remote.base_url', '');
        $hosAdminUrl = '';
        if ($hosApiBase !== '') {
            $hosAdminUrl = str_replace(':3000', ':3002', $hosApiBase);
        }

        $drift = [
            'ok' => false,
            'file' => null,
            'file_mtime' => null,
            'lines' => [],
        ];
        try {
            $path = storage_path('logs/laravel.log');
            $drift['file'] = $path;
            if (is_readable($path)) {
                $drift['file_mtime'] = @filemtime($path) ?: null;
                $all = @file($path, FILE_IGNORE_NEW_LINES);
                if (is_array($all) && count($all) > 0) {
                    // Take last N lines, then filter for drift/shadow ops.
                    $tail = array_slice($all, -400);
                    $filtered = array_values(array_filter($tail, function (string $line): bool {
                        return str_contains($line, 'hos.remote.shadow')
                            || str_contains($line, 'hos.policy.shadow_denied')
                            || str_contains($line, 'hos.policy.denied');
                    }));
                    $drift['lines'] = array_slice($filtered, -40);
                }
                $drift['ok'] = true;
            }
        } catch (\Throwable $e) {
            // ignore; keep drift ok=false
        }

        $notes = $this->loadNotes();

        // Runbook snapshot (progress is test-driven; keep it visible to humans).
        $runbookCurrentPath = base_path('docs/runbooks/CURRENT.md');
        $runbookWorklogPath = base_path('docs/runbooks/_worklog.md');
        $runbookCurrentText = $this->safeReadFile($runbookCurrentPath, 12000);
        // Worklog can grow large; show tail only in UI to keep it readable.
        $runbookWorklogText = $this->safeReadFile($runbookWorklogPath, 6000);
        $runbookWorklogEvents = $this->extractWorklogEventLines($runbookWorklogText, 10);
        // But evidence checks should not depend on the tail; scan a larger window.
        $runbookWorklogScan = $this->safeReadFile($runbookWorklogPath, 50000);

        // ===== Spine locks (live + evidence) =====
        $locks = [];

        // Lock 1: World registry drift (live, deterministic).
        $worldDrift = [
            'ok' => false,
            'expected' => [],
            'config_keys' => [],
            'error' => null,
        ];
        try {
            $registryPath = base_path('WORLD_REGISTRY.md');
            $raw = @file_get_contents($registryPath);
            $ids = [];
            if (is_string($raw)) {
                preg_match_all('/\\*\\*world_id\\*\\*:\\s*`([a-z0-9_]+)`/i', $raw, $m);
                $ids = array_values(array_unique($m[1] ?? []));
            }
            sort($ids);
            $cfg = array_keys((array) config('worlds.worlds', []));
            sort($cfg);
            $worldDrift = [
                'ok' => $ids === $cfg && count($ids) > 0,
                'expected' => $ids,
                'config_keys' => $cfg,
                'error' => null,
            ];
        } catch (\Throwable $e) {
            $worldDrift['error'] = $e->getMessage();
        }
        $locks[] = [
            'key' => 'world_registry_drift',
            'label' => 'World registry drift lock',
            'source' => 'Pazar runtime (WORLD_REGISTRY.md + config/worlds.php)',
            'type' => 'deterministic check',
            'trust' => 'canonical registry vs config',
            'ok' => (bool) ($worldDrift['ok'] ?? false),
            'detail' => (bool) ($worldDrift['ok'] ?? false)
                ? 'PASS'
                : 'FAIL: registry != config (drift)',
        ];

        $registerSmoke = is_array($hosMeasure) && is_array(($hosMeasure['registerSmoke'] ?? null))
            ? (array) $hosMeasure['registerSmoke']
            : [
                'ok' => null,
                'missing_world' => null,
                'invalid_world' => null,
                'world_closed' => null,
                'closed_world' => null,
                'world_closed_status' => null,
                'world_closed_subcode' => null,
                'world_closed_error' => null,
                'error' => 'not_measured',
                'duration_ms' => null,
                'checked_at' => null,
            ];
        $locks[] = [
            'key' => 'register_smoke',
            'label' => 'REGISTER smoke (ctx.world mandatory + canonical worlds)',
            'source' => 'H-OS Remote (read-only HTTP)',
            'type' => 'probe',
            'trust' => 'observation',
            'ok' => $registerSmoke['ok'] === true,
            'detail' => ($registerSmoke['error'] ?? null) === 'not_measured'
                ? 'CHECK: not measured yet (run Measure → H‑OS probes)'
                : ($registerSmoke['ok'] === true
                    ? 'PASS'
                    : ('FAIL'.($registerSmoke['error'] ? ': '.$registerSmoke['error'] : '')
                        .(is_string($registerSmoke['closed_world'] ?? null) ? ' (closed_world='.$registerSmoke['closed_world'].')' : '')
                        .(isset($registerSmoke['world_closed_status']) ? ' got='.$registerSmoke['world_closed_status'].' sub='.(string) ($registerSmoke['world_closed_subcode'] ?? '—') : ''))),
        ];

        // Lock 3: ctx.world enqueue locks (evidence-based; tests are the source of truth).
        $hasEvidence = is_string($runbookWorklogScan) && str_contains($runbookWorklogScan, 'Spine lock: ctx.world must be canonical');
        $locks[] = [
            'key' => 'ctx_world_enqueue',
            'label' => 'Outbox ctx.world enqueue lock (Order/Reservation/Payment)',
            'source' => 'Test suite evidence (docs/runbooks/_worklog.md)',
            'type' => 'evidence',
            'trust' => 'tests',
            'ok' => $hasEvidence,
            'detail' => $hasEvidence ? 'PASS (evidence recorded)' : 'UNKNOWN (no worklog evidence found)',
        ];

        $runbook = [
            'current_path' => $runbookCurrentPath,
            'current_text' => $runbookCurrentText,
            'current_mtime' => is_string($runbookCurrentPath) && $runbookCurrentPath !== '' && @is_file($runbookCurrentPath)
                ? date('Y-m-d H:i:s', (int) @filemtime($runbookCurrentPath))
                : null,
            'worklog_path' => $runbookWorklogPath,
            'worklog_text' => $runbookWorklogText,
            'worklog_events' => $runbookWorklogEvents,
            'worklog_is_tail' => true,
            'worklog_mtime' => is_string($runbookWorklogPath) && $runbookWorklogPath !== '' && @is_file($runbookWorklogPath)
                ? date('Y-m-d H:i:s', (int) @filemtime($runbookWorklogPath))
                : null,
        ];

        $outboxAudit = Cache::get(self::CACHE_KEY_OUTBOX_AUDIT);

        return view('ui.admin.control_center', [
            'timing' => $timing,
            'app' => [
                'env' => (string) config('app.env', ''),
                'debug' => (bool) config('app.debug', false),
                'url' => (string) config('app.url', ''),
            ],
            'legend' => (array) config('control_center.legend', []),
            'hos' => [
                'mode' => (string) config('hos.mode', 'embedded'),
                'policy_mode' => (string) config('hos.policy.mode', 'enforce'),
                'policy_version' => (string) config('hos.policy.version', ''),
                'contract_version' => (string) config('hos.contract.version', ''),
                'remote_base_url' => (string) config('hos.remote.base_url', ''),
                'api_key_present' => ((string) config('hos.remote.api_key', '')) !== '',
                'admin_url' => $hosAdminUrl,
                'remote_failover_read' => (string) config('hos.remote.failover.read_only', 'degrade'),
                'remote_failover_critical' => (string) config('hos.remote.failover.critical_mutation', 'fail_closed'),
            ],
            'db' => $db,
            'dbSnapshot' => $dbSnapshot,
            'queue' => [
                'default' => (string) config('queue.default', ''),
            ],
            'worlds' => [
                'default' => $worlds->defaultKey(),
                'items' => collect($worlds->all())->map(function (array $w, string $key) {
                    return [
                        'key' => $key,
                        'label' => (string) ($w['label'] ?? ''),
                        'enabled' => (bool) ($w['enabled'] ?? false),
                        // Use router-generated URL so subdirectory installs (e.g. /pazar/index.php) work.
                        'entry' => route('worlds.world.entry', ['world' => $key]),
                    ];
                })->values()->all(),
            ],
            'outbox' => [
                'counts' => $outboxCounts,
                'oldest_pending' => $oldestPending,
                'oldest_pending_age_seconds' => $oldestPendingAgeSeconds,
                'last_failed' => $lastFailed,
                'last_sent_at' => $outboxLastSentAt ? (string) $outboxLastSentAt : null,
                'last_enqueued_at' => $outboxLastEnqueuedAt ? (string) $outboxLastEnqueuedAt : null,
                'last_failed_at' => $outboxLastFailedAt ? (string) $outboxLastFailedAt : null,
                'error' => $outboxError,
                'measured_at' => $outboxMeasuredAt,
            ],
            'remoteHealth' => $remoteHealth,
            'oidc' => [
                'enabled' => (bool) config('oidc.enabled', false),
                'issuer' => (string) config('oidc.issuer', ''),
                'client_id' => (string) config('oidc.client_id', ''),
                'world' => (string) config('oidc.world', 'commerce'),
                'scopes' => (string) config('oidc.scopes', 'openid profile email'),
                'redirect_uri_configured' => $configuredRedirect,
                'redirect_uri_computed' => $computedCallback,
                'redirect_uri_effective' => $effectiveRedirect,
            ],
            'drift' => $drift,
            'notes' => $notes,
            'runbook' => $runbook,
            'locks' => $locks,
            'registerSmoke' => $registerSmoke,
            'outboxAudit' => is_array($outboxAudit) ? $outboxAudit : null,
        ]);
    }

    public function measureHos(Request $request, RemoteHosService $remote): \Illuminate\Http\RedirectResponse
    {
        $t0 = microtime(true);

        $remoteHealth = [
            'ok' => false,
            'data' => null,
            'error' => null,
            'checked_at' => now()->toDateTimeString(),
            'duration_ms' => null,
        ];
        try {
            $t = microtime(true);
            $remoteHealth['data'] = $remote->health();
            $remoteHealth['ok'] = (bool) ($remoteHealth['data']['ok'] ?? false);
            $remoteHealth['duration_ms'] = (int) round((microtime(true) - $t) * 1000);
        } catch (\Throwable $e) {
            $remoteHealth['error'] = $e->getMessage();
        }

        $registerSmoke = $this->runRegisterSmoke();

        $payload = [
            'measured_at' => now()->toDateTimeString(),
            'duration_ms' => (int) round((microtime(true) - $t0) * 1000),
            'remoteHealth' => $remoteHealth,
            'registerSmoke' => $registerSmoke,
        ];
        Cache::put(self::CACHE_KEY_HOS_MEASURE, $payload, now()->addHours(24));

        $msg = sprintf(
            'Measure: H-OS probes run (remote_ok=%s, register_ok=%s, duration_ms=%d)',
            $remoteHealth['ok'] ? 'true' : 'false',
            ($registerSmoke['ok'] ?? false) ? 'true' : 'false',
            (int) ($payload['duration_ms'] ?? 0)
        );
        $this->appendWorklogEntry($msg, $request);

        return back()->with('status', 'Measure: H‑OS probes completed.');
    }

    public function measureOutboxAudit(Request $request): \Illuminate\Http\RedirectResponse
    {
        $data = $request->validate([
            'limit' => ['nullable', 'integer', 'min:10', 'max:300'],
        ]);
        $limit = (int) ($data['limit'] ?? 50);
        $t0 = microtime(true);

        $worldKeys = array_keys((array) config('worlds.worlds', []));
        $worldSet = array_fill_keys($worldKeys, true);

        $rows = HosOutboxEvent::query()
            ->orderByDesc('id')
            ->limit($limit)
            ->get(['id', 'status', 'event_type', 'payload', 'created_at']);

        $bad = [
            'missing_ctx' => 0,
            'missing_world' => 0,
            'invalid_world' => 0,
            'missing_from' => 0,
        ];
        $samples = [];

        foreach ($rows as $e) {
            $payload = is_string($e->payload) ? json_decode($e->payload, true) : null;
            $ctx = is_array($payload) ? ($payload['ctx'] ?? null) : null;
            if (! is_array($ctx)) {
                $bad['missing_ctx']++;
                if (count($samples) < 5) {
                    $samples[] = ['id' => $e->id, 'status' => $e->status, 'event_type' => $e->event_type, 'issue' => 'missing_ctx'];
                }
                continue;
            }
            $w = (string) ($ctx['world'] ?? '');
            $from = (string) ($ctx['from'] ?? '');
            if ($w === '') {
                $bad['missing_world']++;
                if (count($samples) < 5) {
                    $samples[] = ['id' => $e->id, 'status' => $e->status, 'event_type' => $e->event_type, 'issue' => 'missing_world', 'ctx' => $ctx];
                }
            } elseif (! isset($worldSet[$w])) {
                $bad['invalid_world']++;
                if (count($samples) < 5) {
                    $samples[] = ['id' => $e->id, 'status' => $e->status, 'event_type' => $e->event_type, 'issue' => 'invalid_world', 'ctx' => $ctx];
                }
            }
            if ($from === '') {
                $bad['missing_from']++;
                if (count($samples) < 5) {
                    $samples[] = ['id' => $e->id, 'status' => $e->status, 'event_type' => $e->event_type, 'issue' => 'missing_from', 'ctx' => $ctx];
                }
            }
        }

        $ok = array_sum($bad) === 0;
        $result = [
            'measured_at' => now()->toDateTimeString(),
            'duration_ms' => (int) round((microtime(true) - $t0) * 1000),
            'limit' => $limit,
            'inspected' => (int) $rows->count(),
            'ok' => $ok,
            'bad' => $bad,
            'samples' => $samples,
        ];
        Cache::put(self::CACHE_KEY_OUTBOX_AUDIT, $result, now()->addHours(24));

        $this->appendWorklogEntry(sprintf('Measure: Outbox ctx audit (limit=%d, ok=%s)', $limit, $ok ? 'true' : 'false'), $request);

        return back()->with('status', 'Measure: Outbox audit completed.');
    }

    /**
     * Run REGISTER invariants against H-OS (read-only HTTP probe).
     *
     * @return array<string,mixed>
     */
    private function runRegisterSmoke(): array
    {
        $measuredAt = now()->toDateTimeString();
        $registerSmoke = [
            'ok' => null,
            'missing_world' => null,
            'invalid_world' => null,
            'world_closed' => null,
            'closed_world' => null,
            'world_closed_status' => null,
            'world_closed_subcode' => null,
            'world_closed_error' => null,
            'error' => null,
            'duration_ms' => null,
            'checked_at' => $measuredAt,
        ];
        try {
            $baseUrl = rtrim((string) config('hos.remote.base_url', ''), '/');
            $apiKey = (string) config('hos.remote.api_key', '');
            if ($baseUrl === '') {
                $registerSmoke['error'] = 'H-OS remote base_url not configured.';
                return $registerSmoke;
            }

            $t0 = microtime(true);
            $headers = $apiKey !== '' ? ['X-HOS-API-KEY' => $apiKey] : [];
            
            // Propagate request ID to H-OS
            $request = request();
            if ($request->hasHeader('X-Request-Id')) {
                $headers['X-Request-Id'] = $request->header('X-Request-Id');
            } elseif ($request->attributes->has('request_id')) {
                $headers['X-Request-Id'] = $request->attributes->get('request_id');
            }
            
            $post = function (array $payload) use ($baseUrl, $headers) {
                return Http::baseUrl($baseUrl)
                    ->acceptJson()
                    ->asJson()
                    ->timeout(3)
                    ->withHeaders($headers)
                    ->post('/v1/contract/can-transition', $payload);
            };

            $subjectRef = ['type' => 'order', 'id' => 1, 'tenant_id' => '00000000-0000-0000-0000-000000000001'];

            $r1 = $post(['subject_ref' => $subjectRef, 'to' => 'cancelled', 'ctx' => []]);
            $j1 = $r1->json();
            $mwOk = $r1->status() === 400 && is_array($j1) && (string) ($j1['error'] ?? '') === 'missing_world';

            $r2 = $post(['subject_ref' => $subjectRef, 'to' => 'cancelled', 'ctx' => ['world' => 'pazar']]);
            $j2 = $r2->json();
            $iwOk = $r2->status() === 400 && is_array($j2) && (string) ($j2['error'] ?? '') === 'invalid_world';

            // Closed-world law: if a world is closed, H-OS MUST return 410 WORLD_CLOSED.
            $closedWorldKey = null;
            foreach ((array) config('worlds.worlds', []) as $key => $w) {
                if (! (bool) ($w['enabled'] ?? false)) {
                    $closedWorldKey = (string) $key;
                    break;
                }
            }
            $wcOk = null;
            if (is_string($closedWorldKey) && $closedWorldKey !== '') {
                $r3 = $post(['subject_ref' => $subjectRef, 'to' => 'cancelled', 'ctx' => ['world' => $closedWorldKey]]);
                $j3 = $r3->json();
                $sub = is_array($j3) ? (string) (($j3['error_subcode'] ?? '') ?: ($j3['subcode'] ?? '')) : '';
                $err = is_array($j3) ? (string) ($j3['error'] ?? '') : '';
                $wcOk = $r3->status() === 410 && (strtoupper($sub) === 'WORLD_CLOSED' || strtoupper($err) === 'WORLD_CLOSED' || $err === 'world_closed');
                $registerSmoke['world_closed_status'] = $r3->status();
                $registerSmoke['world_closed_subcode'] = $sub !== '' ? $sub : null;
                $registerSmoke['world_closed_error'] = $err !== '' ? $err : null;
            }

            $registerSmoke['missing_world'] = $mwOk;
            $registerSmoke['invalid_world'] = $iwOk;
            $registerSmoke['closed_world'] = $closedWorldKey;
            $registerSmoke['world_closed'] = $wcOk;
            $registerSmoke['ok'] = $mwOk && $iwOk && (($closedWorldKey === null) ? true : ($wcOk === true));
            $registerSmoke['duration_ms'] = (int) round((microtime(true) - $t0) * 1000);
        } catch (\Throwable $e) {
            $registerSmoke['error'] = $e->getMessage();
        }

        return $registerSmoke;
    }

    public function storeQuestion(Request $request)
    {
        if (! (bool) config('ops_notes.enabled', false)) {
            abort(404);
        }

        $data = $request->validate([
            'question' => ['required', 'string', 'min:3', 'max:400'],
            'topic' => ['nullable', 'string', 'max:40'],
        ]);

        $question = trim((string) $data['question']);
        $topic = $this->normalizeTopic((string) ($data['topic'] ?? ''));
        $path = (string) config('ops_notes.questions_file', '');
        if ($path === '') {
            return back()->withErrors(['question' => 'Questions file is not configured.'])->withInput();
        }

        $maxBytes = (int) config('ops_notes.max_bytes', 200000);
        $content = $this->safeReadFile($path, $maxBytes);
        if ($content === null) {
            return back()->withErrors(['question' => 'Questions file is not readable: '.$path])->withInput();
        }

        $updated = $this->insertQuestionIntoInbox($content, $question);
        if ($updated === null) {
            return back()->withErrors(['question' => 'Önce mevcut sorunun cevabını yazalım (INBOX dolu).'])->withInput();
        }

        // Stamp topic + origin metadata so "draft + evidence" can be deterministic and auditable.
        $updated = $this->updateInboxBlock($updated, [
            'TOPIC' => $topic,
            'FROM' => 'manual',
        ]) ?? $updated;

        $this->backupFileBestEffort($path);

        // Best-effort write (local only).
        $ok = @file_put_contents($path, $updated, LOCK_EX);
        if ($ok === false) {
            return back()->withErrors(['question' => 'Questions file is not writable: '.$path])->withInput();
        }

        // Append-only worklog entry so Q/A activity isn't lost in chat/terminal scrollback.
        $this->appendWorklogEntry(sprintf('INBOX question saved (topic=%s): "%s"', $topic, $question), $request);

        return back()->with('status', 'Soru kaydedildi (INBOX).');
    }

    public function storeChatNote(Request $request)
    {
        if (! (bool) config('ops_notes.enabled', false)) {
            abort(404);
        }

        $data = $request->validate([
            'note' => ['required', 'string', 'min:1', 'max:800'],
        ]);

        $note = trim((string) $data['note']);
        $when = now()->toDateTimeString();

        $body = "## {$when} — Chat note (Control Center)\n\n".
            "- actor: ".($request->user() ? 'session_user' : 'unknown')."\n\n".
            "```text\n{$note}\n```";

        $this->appendWorklogEntry('Chat note saved', $request, $body);

        return back()->with('status', 'Sohbet notu kaydedildi (Worklog).');
    }

    public function collectEvidence(Request $request)
    {
        if (! (bool) config('ops_notes.enabled', false)) {
            abort(404);
        }

        $data = $request->validate([
            'topic' => ['nullable', 'string', 'max:40'],
            'label' => ['nullable', 'string', 'max:120'],
        ]);

        $topic = $this->normalizeTopic((string) ($data['topic'] ?? 'general'));
        $label = trim((string) ($data['label'] ?? ''));
        $when = now()->toDateTimeString();

        $evidence = [];
        foreach ($this->evidenceSetForTopic($topic) as $spec) {
            $cmd = (string) ($spec['cmd'] ?? '');
            $timeout = (int) ($spec['timeout'] ?? 15);
            if ($cmd === '') {
                continue;
            }
            $evidence[] = $this->runArtisanEvidence($cmd, $timeout);
        }

        $title = $label !== '' ? $label : "topic={$topic}";
        $body = "## {$when} — Evidence (Control Center)\n\n".
            "- topic: {$topic}\n".
            ($label !== '' ? "- label: {$label}\n" : '').
            "- actor: system (automation)\n\n".
            "### Evidence\n\n".
            implode("\n\n", array_filter($evidence));

        $this->appendWorklogEntry("Evidence collected ({$title})", $request, $body);

        return back()->with('status', 'Kanıt toplandı (Worklog).');
    }

    public function generateDraft(Request $request)
    {
        if (! (bool) config('ops_notes.enabled', false)) {
            abort(404);
        }

        $questionsPath = (string) config('ops_notes.questions_file', '');
        if ($questionsPath === '') {
            return back()->withErrors(['question' => 'Questions file is not configured.']);
        }

        $maxBytes = (int) config('ops_notes.max_bytes', 200000);
        $content = $this->safeReadFile($questionsPath, $maxBytes);
        if ($content === null) {
            return back()->withErrors(['question' => 'Questions file is not readable: '.$questionsPath]);
        }

        $meta = $this->extractInboxMeta($content);
        if ($meta === null || trim((string) ($meta['s'] ?? '')) === '') {
            return back()->withErrors(['question' => 'INBOX boş. Önce bir soru yaz.']);
        }

        $question = trim((string) $meta['s']);
        $topic = $this->normalizeTopic((string) ($meta['topic'] ?? ''));
        $when = now()->toDateTimeString();

        // Run a small evidence set (best-effort). Keep timeouts short; choose by TOPIC.
        $evidence = [];
        foreach ($this->evidenceSetForTopic($topic) as $spec) {
            $cmd = (string) ($spec['cmd'] ?? '');
            $timeout = (int) ($spec['timeout'] ?? 15);
            if ($cmd === '') {
                continue;
            }
            $evidence[] = $this->runArtisanEvidence($cmd, $timeout);
        }

        $worklogMsg = "Evidence collected for INBOX (topic={$topic}): \"{$question}\"";
        $worklogBody = "## {$when} — Automation evidence (Control Center)\n\n".
            "- topic: {$topic}\n".
            "- question: {$question}\n".
            "- actor: system (automation)\n\n".
            "### Evidence\n\n".
            implode("\n\n", array_filter($evidence));

        $this->appendWorklogEntry($worklogMsg, $request, $worklogBody);

        // IMPORTANT: Automation does NOT fill C/K. Humans decide and close.
        $draftKanit = "Worklog entry: {$when} — Automation evidence (Control Center)";

        $updated = $this->updateInboxBlock($content, [
            'KANIT' => $draftKanit,
            'TOPIC' => $topic,
            'FROM' => "automation=control_center_evidence_v1; measured_at={$when}",
        ]);
        if ($updated === null) {
            return back()->withErrors(['question' => 'INBOX bloğu güncellenemedi (format beklenmeyen).']);
        }

        $this->backupFileBestEffort($questionsPath);
        $ok = @file_put_contents($questionsPath, $updated, LOCK_EX);
        if ($ok === false) {
            return back()->withErrors(['question' => 'Questions file is not writable: '.$questionsPath]);
        }

        return back()->with('status', 'Kanıt toplandı (Worklog).');
    }

    public function closeInbox(Request $request)
    {
        if (! (bool) config('ops_notes.enabled', false)) {
            abort(404);
        }

        $questionsPath = (string) config('ops_notes.questions_file', '');
        if ($questionsPath === '') {
            return back()->withErrors(['question' => 'Questions file is not configured.']);
        }

        $maxBytes = (int) config('ops_notes.max_bytes', 200000);
        $content = $this->safeReadFile($questionsPath, $maxBytes);
        if ($content === null) {
            return back()->withErrors(['question' => 'Questions file is not readable: '.$questionsPath]);
        }

        $meta = $this->extractInboxMeta($content);
        if ($meta === null || trim((string) ($meta['s'] ?? '')) === '') {
            return back()->withErrors(['question' => 'INBOX zaten boş.']);
        }
        if (trim((string) ($meta['c'] ?? '')) === '' || trim((string) ($meta['k'] ?? '')) === '') {
            return back()->withErrors(['question' => 'Kapatmak için önce C ve K dolu olmalı.']);
        }

        $updated = $this->appendNewInboxBlock($content);
        $this->backupFileBestEffort($questionsPath);
        $ok = @file_put_contents($questionsPath, $updated, LOCK_EX);
        if ($ok === false) {
            return back()->withErrors(['question' => 'Questions file is not writable: '.$questionsPath]);
        }

        $this->appendWorklogEntry('INBOX closed (new empty block appended)', $request);

        return back()->with('status', 'INBOX kapandı (yeni soru açıldı).');
    }

    /**
     * @return array<string,mixed>
     */
    private function loadNotes(): array
    {
        if (! (bool) config('ops_notes.enabled', false)) {
            return [
                'enabled' => false,
            ];
        }

        $maxBytes = (int) config('ops_notes.max_bytes', 200000);
        $statusPath = (string) config('ops_notes.status_file', '');
        $questionsPath = (string) config('ops_notes.questions_file', '');

        $statusText = $statusPath !== '' ? $this->safeReadFile($statusPath, $maxBytes) : null;
        $questionsText = $questionsPath !== '' ? $this->safeReadFile($questionsPath, $maxBytes) : null;

        $questionsInboxBlock = null;
        $questionsArchiveTail = null;
        $questionsRecordTail = null;
        if (is_string($questionsText)) {
            // Inbox block (canonical or legacy) for concise display.
            $questionsInboxBlock = str_contains($questionsText, '## INBOX')
                ? $this->extractCanonicalInboxBlock($questionsText)
                : $this->extractLastInboxBlock($questionsText);

            // Archive tail (canonical) or generic tail (legacy).
            if (str_contains($questionsText, '## ARCHIVE')) {
                if (preg_match('/^##\\s*ARCHIVE\\b[\\s\\S]*$/mi', $questionsText, $m)) {
                    $questionsArchiveTail = $this->tailText((string) $m[0], 6000);
                }
            }
            $questionsRecordTail = $this->tailText($questionsText, 6000);
        }

        return [
            'enabled' => true,
            'status' => [
                'path' => $statusPath,
                'text' => $statusText,
            ],
            'questions' => [
                'path' => $questionsPath,
                // Keep raw text available for debugging, but UI should prefer inbox_block/archive_tail.
                'text' => $questionsText,
                'inbox_block' => $questionsInboxBlock,
                'archive_tail' => $questionsArchiveTail,
                'record_tail' => $questionsRecordTail,
                'inbox' => $questionsText !== null ? $this->extractInboxQuestion($questionsText) : null,
                'inbox_meta' => $questionsText !== null ? $this->extractInboxMeta($questionsText) : null,
            ],
        ];
    }

    private function tailText(string $content, int $maxChars): string
    {
        $maxChars = max(0, $maxChars);
        if ($maxChars === 0) {
            return '';
        }
        if (strlen($content) <= $maxChars) {
            return $content;
        }
        return substr($content, -$maxChars);
    }

    private function safeReadFile(string $path, int $maxBytes): ?string
    {
        try {
            if (! is_readable($path)) {
                return null;
            }
            $raw = @file_get_contents($path);
            if (! is_string($raw)) {
                return null;
            }
            if ($maxBytes > 0 && strlen($raw) > $maxBytes) {
                // Keep last chunk to show most recent content.
                $raw = substr($raw, -$maxBytes);
            }
            return $raw;
        } catch (\Throwable $e) {
            return null;
        }
    }

    /**
     * Returns null if inbox is not found; returns empty string if found but empty.
     */
    private function extractInboxQuestion(string $content): ?string
    {
        // Canonical format first.
        $meta = $this->extractInboxMetaCanonical($content);
        if (is_array($meta)) {
            return trim((string) ($meta['s'] ?? ''));
        }

        // Legacy fallback: last "YENİ SORU" block.
        $pattern = '/^YEN[İI]\\s+SORU.*\\R^S:(.*)$/mi';
        if (! preg_match_all($pattern, $content, $m) || empty($m[1])) {
            return null;
        }
        $last = (string) end($m[1]);
        return trim($last);
    }

    /**
     * @return array{block:string,s:string,c:string,k:string,kanit:string,from:string,topic:string}|null
     */
    private function extractInboxMeta(string $content): ?array
    {
        // Canonical format first.
        $meta = $this->extractInboxMetaCanonical($content);
        if (is_array($meta)) {
            return $meta;
        }

        // Legacy fallback.
        $block = $this->extractLastInboxBlock($content);
        if ($block === null) {
            return null;
        }

        $get = function (string $key) use ($block): string {
            if (! preg_match('/^'.preg_quote($key, '/').'\\s*:(.*)$/mi', $block, $m)) {
                return '';
            }
            return trim((string) ($m[1] ?? ''));
        };

        return [
            'block' => $block,
            's' => $get('S'),
            'c' => $get('C'),
            'k' => $get('K'),
            'kanit' => $get('KANIT'),
            'from' => $get('FROM'),
            'topic' => $get('TOPIC'),
        ];
    }

    /**
     * Canonical format:
     *   ## INBOX (single active)
     *   S:
     *   C:
     *   K:
     *   KANIT:
     *   FROM:
     *   TOPIC:
     *
     * @return array{block:string,s:string,c:string,k:string,kanit:string,from:string,topic:string}|null
     */
    private function extractInboxMetaCanonical(string $content): ?array
    {
        $block = $this->extractCanonicalInboxBlock($content);
        if ($block === null) {
            return null;
        }

        $get = function (string $key) use ($block): string {
            if (! preg_match('/^'.preg_quote($key, '/').'[ \\t\\x{00A0}]*:(.*)$/miu', $block, $m)) {
                return '';
            }
            return $this->cleanFieldValue((string) ($m[1] ?? ''));
        };

        return [
            'block' => $block,
            's' => $get('S'),
            'c' => $get('C'),
            'k' => $get('K'),
            'kanit' => $get('KANIT'),
            'from' => $get('FROM'),
            'topic' => $get('TOPIC'),
        ];
    }

    private function extractCanonicalInboxBlock(string $content): ?string
    {
        // Capture from "## INBOX" until next "## " heading or end of file.
        if (! preg_match('/^##\\s*INBOX\\b[\\s\\S]*?(?=^##\\s|\\z)/mi', $content, $m)) {
            return null;
        }
        return (string) $m[0];
    }

    private function extractLastInboxBlock(string $content): ?string
    {
        $pattern = '/^YEN[İI]\\s+SORU\\s*\\R(?:(?!^YEN[İI]\\s+SORU).*(?:\\R|$))*/mi';
        if (! preg_match_all($pattern, $content, $m)) {
            return null;
        }
        $blocks = $m[0] ?? [];
        if (! is_array($blocks) || count($blocks) < 1) {
            return null;
        }
        return (string) end($blocks);
    }

    /**
     * Insert question into the last YENİ SORU block. Returns null if inbox already has a question or block missing.
     */
    private function insertQuestionIntoInbox(string $content, string $question): ?string
    {
        if (str_contains($content, "## INBOX")) {
            return $this->insertQuestionIntoInboxCanonical($content, $question);
        }

        $eol = str_contains($content, "\r\n") ? "\r\n" : "\n";

        // Robust: find the last legacy "YENİ/YENI SORU" block by regex, not by substring offsets.
        $last = $this->findLastLegacyInboxBlock($content);
        if ($last === null) {
            return null;
        }

        $block = $last['block'];
        if (! preg_match('/^S:(.*)$/m', $block, $m)) {
            return null;
        }
        $existing = trim((string) ($m[1] ?? ''));
        if ($existing !== '') {
            return null; // inbox already filled
        }

        $updatedBlock = preg_replace('/^S:\\s*$/m', 'S: '.$question, $block, 1);
        if (! is_string($updatedBlock)) {
            return null;
        }

        $out = substr($content, 0, $last['offset']).$updatedBlock.substr($content, $last['offset'] + $last['length']);
        if (! str_ends_with($out, $eol)) {
            $out .= $eol;
        }
        return $out;
    }

    /**
     * @return array{offset:int,length:int,block:string}|null
     */
    private function findLastLegacyInboxBlock(string $content): ?array
    {
        // Match each "YENİ SORU" (or "YENI SORU") block up to the next block or EOF.
        $pattern = '/^YEN[İI]\\s+SORU\\b[\\s\\S]*?(?=^YEN[İI]\\s+SORU\\b|\\z)/mi';
        if (! preg_match_all($pattern, $content, $m, PREG_OFFSET_CAPTURE)) {
            return null;
        }
        $matches = $m[0] ?? [];
        if (! is_array($matches) || count($matches) < 1) {
            return null;
        }
        $last = end($matches);
        if (! is_array($last) || count($last) < 2) {
            return null;
        }
        $block = (string) $last[0];
        $offset = (int) $last[1];
        return [
            'offset' => $offset,
            'length' => strlen($block),
            'block' => $block,
        ];
    }

    private function insertQuestionIntoInboxCanonical(string $content, string $question): ?string
    {
        $block = $this->extractCanonicalInboxBlock($content);
        if ($block === null) {
            return null;
        }
        // Read existing S line (tolerate NBSP and odd whitespace).
        if (! preg_match('/^S[ \\t\\x{00A0}]*:(.*)$/miu', $block, $m)) {
            return null;
        }
        $existing = $this->cleanFieldValue((string) ($m[1] ?? ''));
        if ($existing !== '') {
            return null; // inbox already filled
        }

        // Replace the first S line regardless of trailing whitespace.
        $updatedBlock = preg_replace('/^S[ \\t\\x{00A0}]*:.*$/miu', 'S: '.$question, $block, 1);
        if (! is_string($updatedBlock) || $updatedBlock === '') {
            return null;
        }
        return str_replace($block, $updatedBlock, $content);
    }

    private function updateInboxBlock(string $content, array $fields): ?string
    {
        if (str_contains($content, "## INBOX")) {
            return $this->updateInboxBlockCanonical($content, $fields);
        }

        $eol = str_contains($content, "\r\n") ? "\r\n" : "\n";

        // Find start of last block.
        $pos = strripos($content, 'YENİ SORU');
        if ($pos === false) {
            $pos = strripos($content, 'YENI SORU');
        }
        if ($pos === false) {
            return null;
        }

        $before = substr($content, 0, $pos);
        $block = substr($content, $pos);

        // Only operate on the last block slice (up to next block if somehow present).
        if (preg_match('/^YEN[İI]\\s+SORU\\b/mi', $block, $mm, PREG_OFFSET_CAPTURE) && isset($mm[0][1]) && (int) $mm[0][1] !== 0) {
            // shouldn't happen; keep safe
            return null;
        }

        foreach ($fields as $k => $v) {
            $key = strtoupper((string) $k);
            $val = trim((string) $v);
            $pattern = '/^'.preg_quote($key, '/').'\\s*:.*$/mi';
            if (preg_match($pattern, $block)) {
                $block = (string) preg_replace($pattern, $key.': '.$val, $block, 1);
            } else {
                // Append missing field at end of block.
                if (! str_ends_with($block, $eol)) {
                    $block .= $eol;
                }
                $block .= $key.': '.$val.$eol;
            }
        }

        $out = $before.$block;
        if (! str_ends_with($out, $eol)) {
            $out .= $eol;
        }
        return $out;
    }

    private function updateInboxBlockCanonical(string $content, array $fields): ?string
    {
        $block = $this->extractCanonicalInboxBlock($content);
        if ($block === null) {
            return null;
        }

        $updated = $block;
        foreach ($fields as $k => $v) {
            $key = strtoupper((string) $k);
            $val = trim((string) $v);
            $pattern = '/^'.preg_quote($key, '/').'[ \\t\\x{00A0}]*:.*$/miu';
            if (preg_match($pattern, $updated)) {
                $updated = (string) preg_replace($pattern, $key.': '.$val, $updated, 1);
            } else {
                $updated = rtrim($updated)."\n".$key.': '.$val."\n";
            }
        }

        return str_replace($block, $updated, $content);
    }

    private function appendNewInboxBlock(string $content): string
    {
        if (str_contains($content, "## INBOX")) {
            return $this->closeCanonicalInboxToArchive($content);
        }

        $eol = str_contains($content, "\r\n") ? "\r\n" : "\n";
        $block = $eol.
            "YENİ SORU{$eol}".
            "S:{$eol}".
            "C:{$eol}".
            "K:{$eol}".
            "KANIT:{$eol}".
            "FROM:{$eol}".
            "TOPIC: general{$eol}";
        $out = $content;
        if (! str_ends_with($out, $eol)) {
            $out .= $eol;
        }
        return $out.$block;
    }

    private function closeCanonicalInboxToArchive(string $content): string
    {
        $eol = str_contains($content, "\r\n") ? "\r\n" : "\n";
        $meta = $this->extractInboxMetaCanonical($content);
        if (! is_array($meta)) {
            return $content;
        }

        $s = $this->cleanFieldValue((string) ($meta['s'] ?? ''));
        $c = $this->cleanFieldValue((string) ($meta['c'] ?? ''));
        $k = $this->cleanFieldValue((string) ($meta['k'] ?? ''));
        $kanit = $this->cleanFieldValue((string) ($meta['kanit'] ?? ''));
        $from = $this->cleanFieldValue((string) ($meta['from'] ?? ''));
        $topic = $this->normalizeTopic((string) ($meta['topic'] ?? ''));
        $when = now()->toDateTimeString();

        // Clear INBOX fields.
        $content = $this->updateInboxBlockCanonical($content, [
            'S' => '',
            'C' => '',
            'K' => '',
            'KANIT' => '',
            'FROM' => '',
            'TOPIC' => 'general',
        ]) ?? $content;

        // Append to ARCHIVE section (create if missing).
        if (! str_contains($content, "## ARCHIVE")) {
            $content = rtrim($content).$eol.$eol."## ARCHIVE".$eol;
        }
        $archiveEntry =
            $eol."---".$eol.
            "### {$when}".$eol.
            "S: {$s}{$eol}".
            "C: {$c}{$eol}".
            "K: {$k}{$eol}".
            "KANIT: {$kanit}{$eol}".
            "FROM: {$from}{$eol}".
            "TOPIC: {$topic}{$eol}";

        return rtrim($content).$archiveEntry.$eol;
    }

    private function runArtisanEvidence(string $args, int $timeoutSeconds): string
    {
        try {
            $cmd = 'php artisan '.$args;
            $p = Process::fromShellCommandline($cmd, base_path());
            $p->setTimeout(max(1, $timeoutSeconds));
            $p->run();

            $out = trim($p->getOutput()."\n".$p->getErrorOutput());
            $code = $p->getExitCode();
            $status = $p->isSuccessful() ? 'PASS' : 'FAIL';

            return "- `{$cmd}` ({$status}, exit={$code})\n\n```text\n".($out !== '' ? $out : '(no output)')."\n```";
        } catch (\Throwable $e) {
            return "- `php artisan {$args}` (ERROR)\n\n```text\n".$e->getMessage()."\n```";
        }
    }

    private function appendWorklogEntry(string $message, Request $request, ?string $bodyMarkdown = null): void
    {
        try {
            $worklogPath = base_path('docs/runbooks/_worklog.md');
            $when = now()->toDateTimeString();
            $user = $request->user();
            $who = $user ? (trim(($user->name ?? '').' '.($user->email ?? '')) ?: ('user#'.($user->id ?? '?'))) : 'unknown';

            // De-dupe noisy automation: prevent the same entry from being appended repeatedly
            // within a short window (double-click / refresh).
            $dedupe = str_starts_with($message, 'Evidence')
                || str_starts_with($message, 'Measure')
                || str_contains($message, 'INBOX')
                || str_contains($message, 'Draft')
                || str_contains($message, 'Automation');
            if ($dedupe) {
                // Use message-only signature; body includes timestamps and would defeat de-dupe.
                $sig = sha1($message);
                $key = 'control_center:worklog_dedupe:'.$sig;
                if (Cache::has($key)) {
                    return;
                }
                Cache::put($key, 1, now()->addSeconds(60));
            }

            $entry = "\n---\n".
                "## {$when} — Ops Notes\n\n".
                "- actor: {$who}\n".
                "- event: {$message}\n";
            if (is_string($bodyMarkdown) && trim($bodyMarkdown) !== '') {
                $entry .= "\n".$bodyMarkdown."\n";
            }

            @file_put_contents($worklogPath, $entry, FILE_APPEND | LOCK_EX);
        } catch (\Throwable $e) {
            // best-effort; ignore
        }
    }

    /**
     * @return array<int,string>
     */
    private function extractWorklogEventLines(?string $worklogTail, int $limit): array
    {
        if (! is_string($worklogTail) || trim($worklogTail) === '') {
            return [];
        }
        $limit = max(0, $limit);
        if ($limit === 0) {
            return [];
        }
        if (! preg_match_all('/^-\\s*event:\\s*(.+)$/m', $worklogTail, $m)) {
            return [];
        }
        $lines = array_values(array_filter(array_map('trim', (array) ($m[1] ?? []))));
        // Compress consecutive duplicates to avoid "double click" noise in the UI summary.
        $compressed = [];
        $last = null;
        foreach ($lines as $line) {
            if ($last !== null && $line === $last) {
                continue;
            }
            $compressed[] = $line;
            $last = $line;
        }
        $lines = $compressed;
        if (count($lines) <= $limit) {
            return $lines;
        }
        return array_slice($lines, -$limit);
    }

    private function normalizeTopic(string $topic): string
    {
        $topic = strtolower(trim($topic));
        if ($topic === '') {
            return 'general';
        }

        $allowed = [
            'general',
            'hos',
            'outbox',
            'db',
            'ui',
        ];

        return in_array($topic, $allowed, true) ? $topic : 'general';
    }

    /**
     * @return array<int,array{cmd:string,timeout:int}>
     */
    private function evidenceSetForTopic(string $topic): array
    {
        $topic = $this->normalizeTopic($topic);

        if ($topic === 'hos') {
            return [
                ['cmd' => 'hos:register-smoke', 'timeout' => 20],
            ];
        }

        if ($topic === 'outbox') {
            return [
                ['cmd' => 'hos:outbox-report --limit=15 --pending-sample=300', 'timeout' => 25],
            ];
        }

        if ($topic === 'db') {
            return [
                ['cmd' => 'pazar:db-snapshot', 'timeout' => 15],
            ];
        }

        if ($topic === 'ui') {
            return [
                ['cmd' => 'test --filter=AdminControlCenterRendersTest', 'timeout' => 60],
            ];
        }

        return [
            ['cmd' => 'hos:register-smoke', 'timeout' => 20],
            ['cmd' => 'hos:outbox-report --limit=5 --pending-sample=50', 'timeout' => 25],
        ];
    }

    private function cleanFieldValue(string $value): string
    {
        // Normalize non-breaking space and common invisible separators to regular spaces, then trim.
        $value = preg_replace('/\\x{00A0}/u', ' ', $value) ?? $value;
        $value = preg_replace('/\\x{200B}|\\x{200C}|\\x{200D}|\\x{FEFF}/u', '', $value) ?? $value;
        return trim($value);
    }

    private function backupFileBestEffort(string $path): void
    {
        try {
            if (! is_file($path) || ! is_readable($path)) {
                return;
            }
            $dir = dirname($path);
            if (! is_dir($dir) || ! is_writable($dir)) {
                return;
            }
            $stamp = now()->format('Ymd-His');
            $base = basename($path);
            $backup = $dir.DIRECTORY_SEPARATOR.$base.'.bak-'.$stamp;
            @copy($path, $backup);
        } catch (\Throwable $e) {
            // best-effort; ignore
        }
    }
}


