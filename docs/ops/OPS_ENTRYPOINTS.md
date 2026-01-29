# OPS Entrypoints (Index)

**Purpose:** Short index for “what to run”. Keep this file **minimal** to avoid drift.

**Canonical runbook:** `docs/runbooks/OPS_ENTRYPOINTS.md`

---

## Golden 4 Commands (Run These)

These are the only scripts you should run directly in normal workflows:

1. `.\ops\prototype_v1.ps1` - Prototype/demo verification
2. `.\ops\ops_status.ps1` - Status / audit dashboard (default: baseline checks; use `-Ci` to enable optional deep checks)
3. `.\ops\ship_main.ps1` - Publish to main (gates + push)
4. `.\ops\frontend_refresh.ps1` (restart) / `.\ops\frontend_refresh.ps1 -Build` (rebuild)

---

## Daily Entrypoint

- `.\ops\ops_run.ps1` - Daily baseline gates (Prototype profile by default)
- `.\ops\ops_run.ps1 -Profile Full` - Before release (includes `ops_status.ps1`)

---

## See Also

- `docs/runbooks/OPS_ENTRYPOINTS.md` - **Canonical details**

