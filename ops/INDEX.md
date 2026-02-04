# ops/ (catalog)

This folder is intentionally large because it contains both:

- **CI gates** (called directly by GitHub workflows)
- **Local entrypoints** and **diagnostic helpers** (developer convenience)

If you only want “the one thing to run”, use:

- `.\ops\ops.ps1 full` (recommended)
- `.\ops\full_gates.ps1` (direct)

---

## Golden commands (human entrypoints)

- `.\ops\ops.ps1` - dispatcher (`full|status|run|...`)
- `.\ops\full_gates.ps1` - single local FULL_GATES pack (fastest high-signal)
- `.\ops\ops_status.ps1` - status/audit dashboard (wide, informative)
- `.\ops\ops_run.ps1` - daily pack runner (`-Profile Prototype|Full`)
- `.\ops\ship_main.ps1` - publish to main (runs gates + push flow)
- `.\ops\frontend_refresh.ps1` - restart/rebuild frontend

---

## CI gates (called directly by workflows)

These scripts are referenced from `.github/workflows/*.yml`. Deleting/renaming them will break CI.

- `ops/auth_security_check.ps1`
- `ops/baseline_status.ps1`
- `ops/catalog_contract_check.ps1`
- `ops/ci_guard.ps1`
- `ops/conformance.ps1`
- `ops/doctor.ps1`
- `ops/env_contract.ps1`
- `ops/graveyard_check.ps1`
- `ops/incident_bundle.ps1`
- `ops/listing_contract_check.ps1`
- `ops/openapi_contract.ps1`
- `ops/ops_drift_guard.ps1`
- `ops/pazar_spine_check.ps1`
- `ops/pazar_ui_smoke.ps1`
- `ops/product_api_crud_e2e.ps1`
- `ops/product_contract.ps1`
- `ops/product_contract_check.ps1`
- `ops/product_e2e.ps1`
- `ops/product_spine_e2e_check.ps1`
- `ops/rc0_check.ps1`
- `ops/rc0_gate.ps1`
- `ops/release_bundle.ps1`
- `ops/release_check.ps1`
- `ops/repo_integrity.ps1`
- `ops/reservation_contract_check.ps1`
- `ops/routes_snapshot.ps1`
- `ops/run_ops_status.ps1`
- `ops/schema_snapshot.ps1`
- `ops/security_audit.ps1`
- `ops/session_posture_check.ps1`
- `ops/smoke_surface.ps1`
- `ops/tenant_boundary_check.ps1`
- `ops/update_code_index.ps1`
- `ops/verify.ps1`
- `ops/world_spine_check.ps1`
- `ops/world_status_check.ps1`

---

## ops/_extras/

Non-core / one-off scripts are grouped under `ops/_extras/` to reduce root noise:

- `ops/_extras/proofs/` - evidence/demo scripts
- `ops/_extras/prototype/` - prototype/demo helpers (seed, readiness)
- `ops/_extras/tools/` - interactive tools/menus
- `ops/_extras/maintenance/` - one-time maintenance/freeze scripts
- `ops/_extras/packs/` - local packs (dev convenience)

