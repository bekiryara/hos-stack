# OPS Entrypoints (Index)

**Purpose:** Short index for “what to run”. Keep this file **minimal** to avoid drift.

**Canonical runbook:** `docs/runbooks/OPS_ENTRYPOINTS.md`

---

## Golden 4 Commands (Run These)

These are the only scripts you should run directly in normal workflows:

1. `.\ops\ops.ps1` - **Dispatcher** (recommended human entrypoint; `full|status|run|...`)
2. `.\ops\ops.ps1 full` - Single local FULL GATES pack (verify + openapi + conformance + v2_gate + pazar spine + messaging)
3. `.\ops\ops_status.ps1` - Status / audit dashboard (default: baseline checks; use `-Ci` to enable optional deep checks)
4. `.\ops\ops.ps1 ship` - Publish to main (gates + push)
5. `.\ops\frontend_refresh.ps1` (restart) / `.\ops\frontend_refresh.ps1 -Build` (rebuild)

---

## Daily Entrypoint

- `.\ops\ops_run.ps1` - Daily baseline gates (Prototype profile by default)
- `.\ops\ops_run.ps1 -Profile Full` - Before release (includes `ops_status.ps1`)

---

## See Also

- `docs/runbooks/OPS_ENTRYPOINTS.md` - **Canonical details**

