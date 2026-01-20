repo/

├─ services/hos/                               # H‑OS = LEGAL TRUTH (kanonik hukuk, Tier‑0)
│  ├─ api/
│  │   ├─ OIDC/Identity                        # /authorize /token /userinfo /jwks.json + discovery
│  │   │    - token claims: hos_user_id (identity only; NO decision/proof in token)
│  │   │
│  │   ├─ Membership (canonical)               # user↔tenant↔role truth + membership_version (monotonic)
│  │   │    - Emergency Revocation (kill-switch)
│  │   │      * scope-limited: {user_id OR session_id OR permit_id} only
│  │   │      * every revoke writes proof/audit_event (who/why/when)
│  │   │
│  │   ├─ Policy+Contract = PERMIT issuance    # single legal decision point
│  │   │    POST /v1/permits
│  │   │      input : { actor(hos_user_id), tenant_id,
│  │   │                subject_ref{world_id,tenant_id,type,id},
│  │   │                from, to, expected_version,
│  │   │                command_key, ctx }
│  │   │      rules:
│  │   │        - input.tenant_id MUST == subject_ref.tenant_id (else 422)
│  │   │        - issuance-idempotency: UNIQUE(actor_id, tenant_id, command_key)
│  │   │        - same (actor,tenant,command_key) + different snapshot_hash => 409
│  │   │      output: { permit_id, permit_sig, snapshot, snapshot_hash, expires_at }
│  │   │      rollout rule: permits issued under old policy/contract_version remain confirmable until TTL
│  │   │
│  │   ├─ Confirm = PROOF finalize (idempotent, time-safe, canonical errors)
│  │   │    POST /v1/permits/{permit_id}/confirm
│  │   │      input : { world_id, world_mutation_id(UUIDv7), new_version,
│  │   │                snapshot_hash, mutation_hash, confirmed_at }
│  │   │      rules:
│  │   │        - confirm.world_id MUST == snapshot.subject_ref.world_id (else 422/409)
│  │   │        - snapshot_hash MUST match permit.snapshot_hash (else 409 BINDING_MISMATCH)
│  │   │        - permit_id ↔ world_mutation_id is 1:1 (second different => 409)
│  │   │        - expires checked by H‑OS server time only
│  │   │        - UNIQUE(permit_id): duplicate confirm returns SAME proof_id
│  │   │      canonical response contract:
│  │   │        - always returns: { http_status, error_code, error_subcode, next_action, guard_state }
│  │   │        - 409 subcodes are explicit:
│  │   │            * STALE_VERSION      -> next_action=REISSUE_PERMIT
│  │   │            * BINDING_MISMATCH   -> next_action=MARK_ILLEGAL
│  │   │        - NOTE (canonical): "POLICY_CHANGED" is NOT a normal confirm-path subcode.
│  │   │          It is reserved for ops/resolve-driven cases (admin intervention).
│  │   │        - NOTE (canonical): guard_state in H‑OS response is a LABEL only;
│  │   │          the canonical persisted guard_state is in WORLD guard_ledger.
│  │   │
│  │   ├─ Ops Resolve (Phase‑2 optional, canonical + audited)
│  │   │    POST /v1/permits/{permit_id}/resolve
│  │   │      output: { resolution_id, resolution_sig, world_actions[] }
│  │   │
│  │   ├─ Proof query (ops/audit)
│  │   │    GET /v1/proof?tenant_id=&world_id=&subject_type=&subject_id=&limit=&cursor=
│  │   │
│  │   └─ Ops/GC/Reconcile
│  │
│  └─ db/
│
├─ packages/platform/                           # ORTAK (world-agnostic, tekrar yok)
│  ├─ hos-client/
│  ├─ hos-gate/
│  ├─ mutation-kernel/
│  │    - buildCommandKey()
│  │      canonical rule: command_key is created once at UI-action start, carried in request body,
│  │      and persisted in WORLD guard_ledger on first mutation attempt; retries MUST reuse it.
│  │      canonical rule: intent is ACTOR-BOUND. If actor changes (proxy/impersonation/devralma),
│  │      a NEW command_key MUST be generated (new legal intent).
│  │    - requestPermit() (guarded transitions ALWAYS)
│  │    - applyCAS()
│  │    - recordGuardLedgerIntent()
│  │    - enqueueConfirm()
│  ├─ outbox/confirm-queue/
│  │    - STALE_VERSION handling (canonical):
│  │      * re-read entity
│  │      * re-validate the UI action is still meaningful (server-side truth)
│  │      * only then request new permit (otherwise stop / show no-op)
│  ├─ ddl-standards/
│  │    - guard_ledger uniques include actor_id (intent is actor-bound)
│  └─ ci-guards/
│
└─ apps/*                                       # WORLDS = DOMAIN TRUTH (iş verisi + commit)
   ├─ commerce/
   ├─ rentals/
   ├─ food/
   ├─ services/
   ├─ real_estate/
   └─ vehicles/
      ├─ domain/
      ├─ ui/
      ├─ services/Mutations/
      └─ db/
         - entities: status + entity_version
         - guard_ledger: canonical persisted guard_state (H‑OS label is advisory only)
         - MVP without /resolve (manual compensate minimum audit standard):
           * compensation_note fields (CANONICAL):
             { permit_id, command_key, actor_id, tenant_id, subject_ref,
               who(hos_user_id), why(text), when(timestamp), linked_refs(optional) }
           * stored as append-only audit log row in world DB (and later can be forwarded to H‑OS proof)

=============================
REGISTER (CANONICAL) — v1.2
=============================

Purpose:
- This section is the ONLY canonical “Register is Done” definition. Do not duplicate it in other docs.

Single source:
- Canonical world_id list lives in repo root `WORLD_REGISTRY.md`.
- `docs/FOUNDING_SPEC.md` describes the rules; it MUST NOT become a second registry list.

Definition:
Register is considered DONE if and only if the following rules hold in BOTH systems (Pazar + H‑OS):

1) World list consistency (no drift)
- `WORLD_REGISTRY.md` defines the canonical set:
  { commerce, rentals, food, services, real_estate, vehicles }  (world_id are English)
- Pazar MUST use exactly the same keys in `config/worlds.php` (case-sensitive).
- Any mismatch is drift and is not allowed.

2) Closed-world law (H‑OS hard stop)
- If a world is closed/disabled, H‑OS MUST NOT issue permits for it.
- If `ctx.world` is closed, H‑OS MUST return:
  HTTP 410 with error_subcode = WORLD_CLOSED.

3) Legal continuity
- Removing or disabling a world_id NEVER invalidates existing proof/audit history.
- It ONLY forbids issuing NEW permits for that world going forward.

4) No default world (anti-drift)
- H‑OS MUST NOT have a default/fallback world.
- `ctx.world` is mandatory and singular on every policy/contract/proof call.
- Missing/empty `ctx.world` MUST be rejected (HTTP 400).

5) Done proofs (smoke)
- Pazar: `/up` and `/ui/login` respond successfully.
- H‑OS: `ctx.world` missing => 400, `ctx.world` closed => 410 WORLD_CLOSED.


========================
APPENDIX (MVP CANONICAL)
========================

1) command_key persistence (idempotency MUST)

- command_key is created ONCE at UI-action start.
- The client MUST send the same command_key on every retry (double-click / refresh / network retry).
- The world MUST persist the intent on first mutation attempt in guard_ledger (so server-side retries can reuse it).
- If command_key is regenerated per retry, idempotency is LOST (this is a bug).

2) actor-bound intent (proxy/impersonation/devralma)

- Canonical rule: intent is ACTOR-BOUND.
- If the effective actor identity changes (proxy/impersonation/devralma), a NEW command_key MUST be generated.
- Expected behavior: idempotency applies per actor; a proxied action will not reuse the original actor’s command_key.

3) STALE_VERSION handling (canonical retry flow)

When H‑OS confirm returns:
  error_subcode="STALE_VERSION" and next_action="REISSUE_PERMIT"

World MUST:
- Re-read the entity (current status + entity_version).
- Re-validate the action is still meaningful server-side (not only UI hint).
  Examples:
  - if status already changed and action is no longer applicable => stop (no-op) and inform user.
  - else => request a NEW permit with updated {from, expected_version} and proceed.
- Never “blindly reissue permit” without re-validation.

4) guard_state authority (no drift)

- H‑OS response guard_state is a LABEL only (advisory).
- Canonical persisted guard_state lives in WORLD guard_ledger.
- World behavior MUST be driven by H‑OS {error_subcode, next_action} + its own persisted guard_ledger state.

5) Confirm error interpretation (no guessing)

- World MUST NOT interpret raw HTTP status alone.
- World MUST follow H‑OS response contract fields:
  { error_subcode, next_action, guard_state }.
- 409 MUST be disambiguated by error_subcode:
  - STALE_VERSION => retry flow
  - BINDING_MISMATCH => illegal/terminal

6) Manual compensate (MVP only) — canonical audit + linkage

- Manual compensate is allowed in MVP even without /resolve, but MUST be audited.

Table (append-only):
  world_compensation_audits(
    audit_id,
    created_at,
    permit_id,
    command_key,
    actor_id,
    tenant_id,
    subject_ref_world_id,
    subject_ref_type,
    subject_ref_id,
    who_hos_user_id,
    why_text,
    when_ts,
    linked_refs_json_optional
  )

Entity linkage (so ops can navigate from entity -> audit):
- Each guarded entity table MUST include:
  last_compensation_audit_id NULLABLE
  compensated_at NULLABLE

Canonical rule:
- Compensation writes a NEW audit row (never update old audit rows).
- Entity updates last_compensation_audit_id + compensated_at in SAME world DB transaction.

Scope note (avoid MVP scope creep):
- “Forward world audit log to H‑OS proof” is Phase‑2 optional.
- MVP does NOT implement any audit→H‑OS pipeline.

7) needs_ops behavior (canonical)

If guard_state = needs_ops:
- Allowed reads:
  - view entity
  - view timeline / guard_ledger / proof status
  - view payment status
- Allowed writes (non-guarded only):
  - add internal note
  - open support ticket
  - send message
- Forbidden:
  - any guarded transition listed in GUARDED ENTITY REGISTRY
- Closing path:
  - MVP: replay confirm + manual compensate (audited)
  - Phase‑2: H‑OS /resolve emits world_actions; world applies them idempotently

8) World Actions idempotency (Phase‑2)

When /resolve exists:
- World MUST have an action_ledger to apply world_actions idempotently:

  world_action_ledger(
    action_id,
    resolution_id,
    command_key,
    applied_at,
    result_json
  )

Constraints:
- UNIQUE(resolution_id, command_key)
- Applying the same action twice MUST be safe (no double-compensate).

9) Guarded entity registry (avoid arguments)

- There MUST be a canonical GUARDED ENTITY REGISTRY (manifest) per world:
  - which entities are guarded
  - which transitions are guarded
  - what “from/to” pairs require permits
- Teams MUST NOT decide ad-hoc; changes to registry require review.

10) DB hard guards are REQUIRED (CI is not enough)

- Direct UPDATE of guarded status/version columns MUST be forbidden for app DB user.
- Guarded mutations MUST go through stored-procedure template which enforces:
  - CAS: WHERE status=from AND entity_version=expected_version
  - guard_ledger update in SAME TX
- Any ORM migration that bypasses this is a Sev-0 issue.

11) Permit TTL + clock (canonical)

- expires_at default: 3 minutes (2–5 min range).
- Only H‑OS server time decides expiry.
- If expired => next_action=NEEDS_OPS (do not retry forever).

12) Ops replay safety

- Replay/DLQ tooling MUST be:
  - audited
  - rate-limited
  - exponential backoff
  - scope-limited to “resend confirm only” (no direct mutation, no bypass)

===========================
APPENDIX ADDENDUM (CANONICAL)
===========================

13) Permit issuance idempotency ↔ guard_ledger intent persistence (failure semantics)

Canonical rule:
- command_key is always supplied by the client/request (UI-created, retry-reused).
- guard_ledger is the server-side source-of-truth for “intent persisted”.

If the first attempt fails before committing the world DB TX (rollback happens):
- guard_ledger row does NOT exist (by definition).
- The client MUST retry with the SAME command_key.
- The world MUST simply re-run the same mutation flow using the command_key from the request.
- There is NO server-side “lookup” needed; the request carries the key, and guard_ledger will be written
  on the first successful commit.
- Runbook note: “Missing guard_ledger row after a failed attempt is normal; keep retrying with same command_key.”

14) Phase‑2 /resolve world_actions apply spec (canonical minimal effects)

World MUST apply each world_action idempotently using world_action_ledger (UNIQUE(resolution_id, command_key)).

Apply rules (minimum canonical):
- COMPENSATE:
  - write a new world_compensation_audits row (append-only)
  - set entity.last_compensation_audit_id + entity.compensated_at (same TX)
  - set guard_ledger.guard_state = needs_ops OR finalized depending on compensation policy
    (canonical default: keep needs_ops until a human confirms closure; do not auto-finalize silently)

- REISSUE_PERMIT:
  - does NOT mutate the entity directly
  - creates a new “permit request task” referencing (subject_ref, actor_id, new command_key)
  - then normal permit→commit→confirm pipeline runs

- MARK_ILLEGAL:
  - set guard_ledger.guard_state = illegal (terminal)
  - entity status is NOT rolled back (domain truth stays), but guarded transitions remain blocked
  - append an audit row linking permit_id + resolution_id + reason

15) Proof query consistency SLO (ops expectation)

- Proof query is best-effort read-after-write, but we commit to an SLO:
  - p95 proof visibility delay < 10 seconds (from confirm success to appearing in GET /v1/proof)
- Ops UI behavior:
  - if proof not visible yet, show “pending propagation” instead of “missing”
  - only alert if delay > SLO window (not instantly)