# OPS System Audit (What is real, what is leftover)

This file exists because `ops/` grew organically and became hard to reason about.
Goal: clearly separate **real gates**, **human entrypoints**, **diagnostics**, and **dev leftovers**.

## How this audit is computed (deterministic)

Run:

```powershell
.\ops\_extras\tools\ops_inventory.ps1
```

It extracts:

- **CI references**: any `ops/*.ps1` referenced by `.github/workflows/*.yml`
- **Script-to-script calls**: patterns like `.\ops\foo.ps1` inside scripts (dependency graph)
- **Header tags**: `WP-*`, `DEPRECATED/HISTORICAL/WRAPPER`, `PROTOTYPE/PROOF/EXPERIMENT`

This is the canonical source for “is it used / who calls it / is it CI”.

---

## 1) The only “human entrypoints” that matter

If you’re developing locally and want *real signal*, use:

- **Dispatcher**: `.\ops\ops.ps1`
  - `.\ops\ops.ps1 full` (FULL_GATES)
  - `.\ops\ops.ps1 run -Profile Prototype|Full` (daily packs)
  - `.\ops\ops.ps1 status` (dashboard)
- **Direct**: `.\ops\full_gates.ps1` (same pack, no indirection)

These are “stable UX”: we keep them simple, predictable, and documented.

---

## 2) “Real gates” (CI-coupled, do NOT delete)

Anything referenced by workflows is a **CI gate**. Deleting/renaming breaks CI.

Audit rule: `ci_ref=true` in `ops_inventory`.

Examples of what they measure:

- **`ops/openapi_contract.ps1`**: OpenAPI spec exists + drift guard + endpoint probe
- **`ops/conformance.ps1`**: architecture rules (world ownership lock, forbidden artifacts, secrets guard, docs drift)
- **`ops/pazar_spine_check.ps1`**: marketplace spine chain (world status, catalog, integrity, listing, reservation)
- **`ops/verify.ps1`**: stack health (containers + /health + /up + FS posture)
- **snapshots**: `schema_snapshot.ps1`, `routes_snapshot.ps1`
- **security posture**: `session_posture_check.ps1`, `security_audit.ps1`, `tenant_boundary_check.ps1`

If a script is CI-referenced but looks “legacy”, it must be refactored *behind* a stable wrapper, not deleted.

---

## 3) Diagnostics / maintenance (useful, but not gates)

These are for investigations and local ops work. Many are leaf scripts (nobody calls them), which is OK.

Examples:

- **DB ops**: `hos_db_reset_safe.ps1`, `hos_db_recovery.ps1`, `hos_db_verify.ps1`
- **triage**: `triage.ps1`, `doctor.ps1`
- **frontend**: `frontend_smoke.ps1` (does real `npm ci` + `npm run build`)
- **release helpers**: `release_note.ps1`, `rc0_release_bundle.ps1`

Rule of thumb:

- If it changes state (reset/recovery/seed), keep it out of “daily packs”.
- Keep them reachable via `ops.ps1` commands (or documented in `ops/INDEX.md`).

---

## 4) Dev leftovers / archived scripts (high suspicion)

These are **not CI-referenced** and usually tagged `DEV`/`LEGACY`, or live under archive folders.

Examples currently in tree:

- `ops/_archive/demo_seed*.ps1` (demo seed scripts; should not be “day to day”)
- `ops/verify/run.ps1` (old verification entrypoint; still **docs-referenced**. Keep until docs are migrated to `ops.ps1`.)
- `ops/stack_up.ps1`, `ops/stack_down.ps1` (legacy wrappers; still **docs-referenced**. Don’t move without updating runbooks/proofs.)

Policy recommendation:

- Move to `ops/_extras/legacy/` or `ops/_extras/archive/`
- Keep **no wrappers** unless there is a real consumer (script-to-script call or docs command).

---

## 5) Concrete next cleanup (safe, low-risk)

Using `ops_inventory` output, target scripts that satisfy ALL:

- `ci_ref=false` (not used by workflows)
- `called_by=0` (no other script calls it)
- not an “entrypoint”

Action:

- Move them under `ops/_extras/<category>/`
- Add/adjust a dispatcher command in `ops/ops.ps1` if they are still useful
- Update docs (INDEX + README)

This reduces root noise **without breaking CI**.

