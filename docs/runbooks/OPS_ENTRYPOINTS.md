# OPS Entrypoints Runbook (WP-68C)

**Purpose:** Define a single, professional entrypoint discipline for repository operations.

**Principle:** A developer can run the repo using ONLY 4 commands, and knows exactly when to use which.

---

## A) Golden 4 Commands

### (1) Prototype / Demo Verification
```powershell
.\ops\prototype_v1.ps1
```

**When to use:**
- After setting up the development environment
- Before demonstrating the prototype to stakeholders
- To verify that demo environment is ready

**Expected output:**
- `PASS`: Frontend smoke test and world status checks pass
- `FAIL`: One or more checks fail (review output for details)

**Troubleshooting:**
- If frontend smoke fails: Check that `hos-web` and `marketplace-web` containers are running
- If world status fails: Verify that `hos-api` and `pazar-api` services are accessible

---

### (2) Status / Audit
```powershell
.\ops\ops_status.ps1
```

**When to use:**
- To get a comprehensive overview of system health
- Before making significant changes
- To verify all gates and checks
- When troubleshooting issues

**Expected output:**
- Unified dashboard showing:
  - Core availability (H-OS + hos-db)
  - Service status
  - Gate results
  - Audit information

**Troubleshooting:**
- If gates fail: Review the FAIL section in output
- If services unavailable: Check Docker containers are running (`docker compose ps`)
- For detailed diagnostics: Run individual contract checks (see Leaf Scripts below)

---

### (3) Publish
```powershell
.\ops\ship_main.ps1
```

**When to use:**
- When ready to publish changes to main branch
- After all local tests pass
- Before creating a release

**Expected output:**
- Runs all gates and smoke tests
- Pushes to main if all checks pass
- `PASS`: Changes published successfully
- `FAIL`: One or more gates failed (changes not published)

**Troubleshooting:**
- If gates fail: Fix issues and re-run
- If git push fails: Check branch protection rules and permissions
- Review output for specific failure reasons

---

### (4) Frontend Apply
```powershell
.\ops\frontend_refresh.ps1          # Restart (default)
.\ops\frontend_refresh.ps1 -Build   # Rebuild
```

**When to use:**
- After making UI/text/layout changes (use default restart)
- After updating dependencies or build assets (use `-Build`)
- When browser cache prevents seeing changes

**Expected output:**
- `PASS`: Services restarted/rebuilt successfully
- Instructions for next steps (browser hard refresh)

**Troubleshooting:**
- If restart fails: Check Docker containers exist (`docker compose ps`)
- If rebuild fails: Check Docker build logs
- If changes still not visible: Perform hard refresh (Ctrl+F5) in browser

---

## B) Decision Table

| Scenario | Command | Notes |
|----------|---------|-------|
| UI change not showing | `.\ops\frontend_refresh.ps1` + Ctrl+F5 | Default restart is usually sufficient |
| New dependencies or build assets | `.\ops\frontend_refresh.ps1 -Build` | Full rebuild required |
| Gate fails | `.\ops\ops_status.ps1` + read FAIL section | Review output for specific failures |
| Before demo/presentation | `.\ops\prototype_v1.ps1` | Verify environment is ready |
| Ready to publish | `.\ops\ship_main.ps1` | Runs all gates before publishing |
| General health check | `.\ops\ops_status.ps1` | Comprehensive status overview |

---

## C) Leaf Scripts

**IMPORTANT: DO NOT RUN DIRECTLY unless instructed by a senior engineer or specific troubleshooting guide.**

These scripts are called by the Golden 4 Commands or used for specific diagnostic purposes.

### Contract Checks
*These verify API contracts and should only be run as part of gates or troubleshooting.*

- `account_portal_contract_check.ps1` - Account portal API contract verification
- `account_portal_list_contract_check.ps1` - Account portal list API contract
- `account_portal_read_check.ps1` - Account portal read operations
- `boundary_contract_check.ps1` - Boundary contract verification
- `catalog_contract_check.ps1` - Catalog API contract
- `catalog_integrity_check.ps1` - Catalog integrity verification
- `core_persona_contract_check.ps1` - Core persona contract
- `listing_contract_check.ps1` - Listing API contract
- `messaging_contract_check.ps1` - Messaging API contract
- `messaging_write_contract_check.ps1` - Messaging write contract
- `offer_contract_check.ps1` - Offer API contract
- `order_contract_check.ps1` - Order API contract
- `product_contract_check.ps1` - Product API contract
- `rental_contract_check.ps1` - Rental API contract
- `reservation_contract_check.ps1` - Reservation API contract
- `tenant_scope_contract_check.ps1` - Tenant scope contract

### Gates
*These are quality gates that should be run as part of the publish flow.*

- `ci_guard.ps1` - CI drift guard (forbidden files, secrets, non-ASCII paths)
- `conformance.ps1` - Architecture conformance gate
- `public_ready_check.ps1` - Public release readiness check
- `rc0_check.ps1` - RC0 release readiness gate
- `rc0_gate.ps1` - RC0 release gate
- `release_check.ps1` - RC0 release checklist enforcement
- `route_duplicate_guard.ps1` - Route duplicate guard
- `pazar_routes_guard.ps1` - Pazar routes guardrails
- `state_transition_guard.ps1` - State transition guard

### Utilities
*These are utility scripts for specific operations.*

- `baseline_freeze_v1.ps1` - Baseline freeze control
- `baseline_status.ps1` - Read-only baseline status check
- `closeouts_rollover.ps1` - Closeouts rollover
- `closeouts_size_gate.ps1` - Closeouts size gate
- `daily_snapshot.ps1` - Daily evidence snapshot
- `demo_seed.ps1` - Demo seed script
- `demo_seed_root_listings.ps1` - Demo seed root listings
- `demo_seed_showcase.ps1` - Demo seed showcase
- `demo_seed_transaction_modes.ps1` - Demo seed transaction modes
- `doctor.ps1` - Repository health doctor
- `drift_monitor.ps1` - Drift detection monitor
- `ensure_demo_membership.ps1` - Ensure demo membership
- `ensure_product_test_auth.ps1` - Ensure product test auth
- `env_contract.ps1` - Environment & secrets contract check
- `frontend_smoke.ps1` - Frontend smoke test
- `github_sync_safe.ps1` - GitHub sync safe (PR-based flow)
- `graveyard_check.ps1` - Enforce _graveyard/ policy
- `hos_db_recovery.ps1` - HOS-DB corruption recovery
- `hos_db_recovery_commands.ps1` - HOS-DB recovery commands
- `hos_db_reset_safe.ps1` - HOS-DB dev reset + core restore
- `hos_db_verify.ps1` - Post-reset verification
- `idempotency_coverage_check.ps1` - Idempotency coverage check
- `incident_bundle.ps1` - Incident bundle generator
- `listing_discovery_proof.ps1` - Listing discovery proof
- `messaging_journey_check.ps1` - Messaging journey check
- `messaging_proxy_smoke.ps1` - Messaging proxy smoke test
- `observability_status.ps1` - Observability status check
- `openapi_contract.ps1` - OpenAPI contract check
- `ops_drift_guard.ps1` - Ops drift guard
- `pazar_route_surface_diag.ps1` - Route surface diagnostic
- `pazar_spine_check.ps1` - Pazar spine check
- `pazar_storage_posture.ps1` - Pazar storage posture
- `pazar_ui_smoke.ps1` - UI smoke test + logging regression
- `perf_baseline.ps1` - Performance baseline
- `persona_scope_check.ps1` - Persona & scope check
- `product_api_crud_e2e.ps1` - Product API CRUD E2E gate
- `product_api_smoke.ps1` - Product API smoke gate
- `product_e2e.ps1` - Product API E2E gate
- `product_e2e_contract.ps1` - Product API E2E contract gate
- `product_mvp_check.ps1` - Product MVP loop E2E check
- `product_perf_guard.ps1` - Product API performance guardrail
- `product_read_path_check.ps1` - Product read path check
- `product_spine_check.ps1` - Product spine governance gate
- `product_spine_e2e_check.ps1` - Product spine E2E self-audit gate
- `product_spine_governance.ps1` - Product spine governance gate
- `product_spine_smoke.ps1` - Product spine E2E smoke test
- `product_write_spine_check.ps1` - Product write spine check
- `read_snapshot_check.ps1` - Read snapshot check
- `release_bundle.ps1` - RC0 release bundle generator
- `release_note.ps1` - Generate release note from CHANGELOG
- `repo_governance_freeze_v1.ps1` - Repo governance freeze
- `repo_integrity.ps1` - Repository integrity check
- `repo_inventory_report.ps1` - Repository inventory report
- `repo_payload_audit.ps1` - Repo payload audit
- `repo_payload_guard.ps1` - Repo payload guard
- `request_trace.ps1` - Request ID log correlation
- `routes_snapshot.ps1` - Contract gate (route snapshot)
- `run_ops_status.ps1` - Safe ops status runner
- `schema_snapshot.ps1` - DB contract gate (schema snapshot)
- `secret_scan.ps1` - Secret scan script
- `security_audit.ps1` - Route/middleware security audit
- `self_audit.ps1` - Self-audit orchestrator
- `session_posture_check.ps1` - Identity & session posture check
- `slo_check.ps1` - SLO check script
- `smoke.ps1` - Genesis world status smoke test
- `smoke_surface.ps1` - Smoke surface gate
- `stack_down.ps1` - Stack shutdown wrapper
- `stack_up.ps1` - Stack bring-up wrapper
- `start_ngrok_backend.ps1` - ngrok backend public access
- `storage_permissions_check.ps1` - Storage permissions check
- `storage_posture_check.ps1` - Storage posture check
- `storage_write_check.ps1` - Storage write check
- `tenant_boundary_check.ps1` - Tenant boundary isolation check
- `test_wp68_hardening.ps1` - WP-68 hardening test
- `triage.ps1` - Incident triage script
- `update_code_index.ps1` - Update code index
- `verify.ps1` - Stack health verification
- `verify_wp_closeouts.ps1` - WP_CLOSEOUTS.md verification
- `world_spine_check.ps1` - World spine governance check
- `world_status_check.ps1` - World status check script
- `write_snapshot_check.ps1` - Write snapshot check

---

## Troubleshooting

### If a command fails:

1. **Read the output carefully** - Most commands provide specific error messages
2. **Check prerequisites** - Ensure Docker containers are running, services are accessible
3. **Review related leaf scripts** - Some failures may require running specific diagnostic scripts
4. **Check logs** - Docker logs (`docker compose logs <service>`) may provide additional context
5. **Run ops_status** - Get comprehensive system status to identify issues

### Common Issues:

- **Frontend changes not showing**: Run `frontend_refresh.ps1 -Build` and hard refresh browser (Ctrl+F5)
- **Gates failing**: Run `ops_status.ps1` to see which specific checks are failing
- **Services unavailable**: Check Docker containers with `docker compose ps`
- **Git issues**: Ensure working directory is clean before publishing

---

## Notes

- All commands are PowerShell 5.1 compatible
- All outputs are ASCII-only
- No scripts are deleted or moved - only documentation and entrypoint discipline added
- Leaf scripts remain available for advanced troubleshooting

