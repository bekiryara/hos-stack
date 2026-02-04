# OPS Entrypoints (Index)

**Purpose:** Short index for “what to run”. Keep this file **minimal** to avoid drift.

**Canonical runbook:** `docs/runbooks/OPS_ENTRYPOINTS.md`

---

## Golden 4 Commands (Run These)

These are the only scripts you should run directly in normal workflows:

1. `.\ops\ops.ps1` - **Dispatcher** (recommended human entrypoint; `full|status|run|...`)
2. `.\ops\full_gates.ps1` - Single local FULL_GATES pack (verify + openapi + conformance + pazar spine + messaging)
3. `.\ops\ops_status.ps1` - Status / audit dashboard (default: baseline checks; use `-Ci` to enable optional deep checks)
4. `.\ops\ship_main.ps1` - Publish to main (gates + push)
5. `.\ops\frontend_refresh.ps1` (restart) / `.\ops\frontend_refresh.ps1 -Build` (rebuild)

---

## Daily Entrypoint

- `.\ops\ops_run.ps1` - Daily baseline gates (Prototype profile by default)
- `.\ops\ops_run.ps1 -Profile Full` - Before release (includes `ops_status.ps1`)

---

## See Also

- `docs/runbooks/OPS_ENTRYPOINTS.md` - **Canonical details**

