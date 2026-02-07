# OPS System Audit (What is real, what is leftover)

This file exists because `ops/` grew organically and became hard to reason about.
Goal: clearly separate **real gates**, **human entrypoints**, **diagnostics**, and **dev leftovers**.

## How this audit is computed (deterministic)

This audit is kept simple:

- **Canonical entrypoint**: `.\ops\ops.ps1 help` (what humans should run)
- **CI truth**: `.github/workflows/*.yml` (what automation will execute)
- **Leaf scripts**: `ops/_checks/` and `ops/_tools/` (implementation details)

---

## 1) The only “human entrypoints” that matter

If you’re developing locally and want *real signal*, use:

- **Dispatcher**: `.\ops\ops.ps1`
  - `.\ops\ops.ps1 full` (FULL_GATES)
  - `.\ops\ops.ps1 run -Profile Prototype|Full` (daily packs)
  - `.\ops\ops.ps1 status` (dashboard)
- **Direct**: `.\ops\ops.ps1 full` (same pack)

These are “stable UX”: we keep them simple, predictable, and documented.

---

## 2) “Real gates” (CI-coupled, do NOT delete)

Anything referenced by workflows is a **CI gate**. Deleting/renaming breaks CI.

Audit rule: if a script path appears in `.github/workflows/*.yml`, it is a gate.

Examples of what they measure:

- **`.\ops\ops.ps1 openapi`** (script: `ops/_checks/openapi_contract.ps1`): OpenAPI spec exists + drift guard + endpoint probe
- **`.\ops\ops.ps1 conformance`** (script: `ops/_checks/conformance.ps1`): architecture rules (world ownership lock, forbidden artifacts, secrets guard, docs drift)
- **`.\ops\ops.ps1 pazar-spine`** (script: `ops/_checks/pazar_spine_check.ps1`): marketplace spine chain (world status, catalog, integrity, listing, reservation)
- **`.\ops\ops.ps1 verify`** (script: `ops/_checks/verify.ps1`): stack health (containers + /health + /up + FS posture)
- **snapshots**: `.\ops\ops.ps1 schema-snapshot`, `.\ops\ops.ps1 routes-snapshot`
- **security posture**: `.\ops\ops.ps1 session-posture`, `.\ops\ops.ps1 security-audit`, `.\ops\ops.ps1 tenant-boundary`

If a script is CI-referenced but looks “legacy”, it must be refactored *behind* a stable wrapper, not deleted.

---

## 3) Diagnostics / maintenance (useful, but not gates)

These are for investigations and local ops work. Many are leaf scripts (nobody calls them), which is OK.

Examples:

- **DB ops (legacy pack)**: `ops/_legacy/legacy.ps1 hos-db-reset`, `ops/_legacy/legacy.ps1 hos-db-recovery`, `ops/_legacy/legacy.ps1 hos-db-verify`
- **triage**: `.\ops\ops.ps1 triage`, `.\ops\ops.ps1 doctor`
- **frontend**: `frontend_smoke.ps1` (does real `npm ci` + `npm run build`)
- **release helpers**: `ops/_legacy/legacy.ps1 release-note`, `.\ops\ops.ps1 release`

Rule of thumb:

- If it changes state (reset/recovery/seed), keep it out of “daily packs”.
- Keep them reachable via `ops.ps1` commands (or documented in `ops/INDEX.md`).

---

## 4) Dev leftovers / archived scripts (high suspicion)

These are **not CI-referenced** and usually tagged `DEV`/`LEGACY`, or live under archive folders.

Examples:

- `ops/stack_up.ps1`, `ops/stack_down.ps1` (legacy wrappers; prefer `.\ops\ops.ps1 up/down`. Don’t move without updating any external scripts/proofs.)

Policy recommendation:

- If it is not CI-referenced and not used by humans, delete it.
- Keep **no wrappers** unless there is a real consumer (script-to-script call or docs command).

---

## 5) Concrete next cleanup (safe, low-risk)

Target scripts that satisfy ALL:

- `ci_ref=false` (not used by workflows)
- `called_by=0` (no other script calls it)
- not an “entrypoint”

Action:

- Delete them (or move under `ops/_legacy/` only if truly needed and explicitly documented)
- Add/adjust a dispatcher command in `ops/ops.ps1` if they are still useful
- Update docs (INDEX + README)

This reduces root noise **without breaking CI**.

