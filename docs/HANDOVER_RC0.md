# Handover RC0 - Repository Convergence

**Date:** 2026-01-10  
**Branch:** `rc0/convergence`  
**Status:** Ready for RC0 cut

## Current State Summary

### Core Stack (root docker-compose.yml)
- **H-OS API**: `hos-api` service on port 3000
- **H-OS Web**: `hos-web` service on port 3002
- **H-OS DB**: PostgreSQL database
- **Pazar App**: Laravel application on port 8080
- **Pazar DB**: PostgreSQL database

### Observability Stack (work/hos/docker-compose.yml, obs profile)
- **Prometheus**: Metrics collection and alerting
- **Alertmanager**: Alert routing and notification
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **Promtail**: Log collection
- **Tempo**: Distributed tracing
- **OTEL Collector**: OpenTelemetry data collection
- **Postgres Exporter**: Database metrics
- **Alert Webhook**: Webhook receiver for alerts (with `/last` endpoint)

### Guards / Gates
- **Storage Posture Check**: Verifies Pazar storage writability (`ops/storage_posture_check.ps1`)
- **Alert Pipeline Proof**: Verifies Alertmanager -> Webhook pipeline (`ops/alert_pipeline_proof.ps1`)
- **Repo Integrity Check**: Non-destructive drift detection (`ops/repo_integrity.ps1`)
- **Ops Status Dashboard**: Unified ops checks (`ops/ops_status.ps1`)

## Canonical Entrypoints

### Stack Management
```powershell
# Start core stack
.\ops\stack_up.ps1 -Profile core

# Start observability stack (no port conflicts)
.\ops\stack_up.ps1 -Profile obs

# Start all stacks
.\ops\stack_up.ps1 -Profile all

# Shutdown
.\ops\stack_down.ps1 -Profile core|obs|all
```

### Ops Status (Safe Wrapper)
```powershell
# Run ops status (terminal-safe, does not close terminal)
.\ops\run_ops_status.ps1

# With pause for double-click runs
.\ops\run_ops_status.ps1 -Pause

# CI mode (exit code propagation)
.\ops\run_ops_status.ps1 -Ci
```

### Individual Checks
```powershell
# Storage posture
.\ops\storage_posture_check.ps1

# Alert pipeline proof (requires obs profile running)
.\ops\alert_pipeline_proof.ps1

# Repo integrity
.\ops\repo_integrity.ps1

# Repository doctor
.\ops\doctor.ps1

# Stack verification
.\ops\verify.ps1
```

## CI Gates List

### GitHub Actions Workflows
1. **repo-guard.yml**: Prevents root artifacts (zip/rar/temp files)
2. **smoke.yml**: Basic health checks
3. **ops-status.yml**: Ops status dashboard (calls `run_ops_status.ps1 -Ci`)
4. **conformance.yml**: Architecture rule validation
5. **contracts.yml**: API contract validation (route snapshots)
6. **db-contracts.yml**: Database schema validation
7. **error-contract.yml**: Error response envelope validation
8. **env-contract.yml**: Environment variables and production guardrails
9. **session-posture.yml**: Session cookie security validation

### Ops Gates (run locally or in CI)
- Storage Posture: `ops/storage_posture_check.ps1` (PASS required before release)
- Alert Pipeline Proof: `ops/alert_pipeline_proof.ps1` (PASS required if obs profile enabled)
- Repo Integrity: `ops/repo_integrity.ps1` (PASS/WARN acceptable)
- Conformance: `ops/conformance.ps1` (PASS required)
- Security Audit: `ops/security_audit.ps1` (PASS required)

## Known Risks

### Nested Repository
- **work/hos/.git exists**: `work/hos` is a nested Git repository and is **NOT tracked** in the root repository
- **Impact**: Changes to `work/hos` must be committed separately in that nested repo
- **Handover Note**: When updating observability config (prometheus, alertmanager, grafana), commit changes in `work/hos` repo, not root repo
- **Dual Canonical Strategy**: Root compose = core stack, work/hos compose = obs stack (nested repo)

### Storage Permissions (Windows)
- **Issue**: Windows Docker bind mounts do not preserve Linux file permissions
- **Solution**: Named volumes (`pazar_storage`, `pazar_cache`) for runtime-writable directories
- **Verification**: Run `ops/storage_posture_check.ps1` after container recreates

### Port Conflicts
- **Solution**: Obs profile uses explicit service list, does not start core services (api/web/db)
- **Verification**: `ops/stack_up.ps1 -Profile obs` should not cause port 3000/3002 conflicts

## Next 5 Engineering Steps

1. **Verify RC0 branch**: Run all ops checks on `rc0/convergence` branch
   ```powershell
   .\ops\run_ops_status.ps1
   .\ops\storage_posture_check.ps1
   .\ops\repo_integrity.ps1
   ```

2. **Test observability stack**: If obs profile is needed
   ```powershell
   .\ops\stack_up.ps1 -Profile obs
   .\ops\alert_pipeline_proof.ps1
   ```

3. **Create PR**: Open PR from `rc0/convergence` to `main` with:
   - Summary of all packs consolidated
   - Verification checklist
   - Known risks section

4. **CI Verification**: Ensure all CI gates pass on PR
   - repo-guard, smoke, ops-status, conformance, contracts, etc.

5. **RC0 Tag**: After PR merge, tag as `v0.2.0-rc0` or similar
   ```powershell
   git tag -a v0.2.0-rc0 -m "RC0: Repository convergence complete"
   ```

## Verification Checklist

Before cutting RC0, verify:

- [ ] `git status` is clean (no untracked files except work/hos nested repo)
- [ ] All ops checks PASS: `.\ops\run_ops_status.ps1`
- [ ] Storage posture PASS: `.\ops\storage_posture_check.ps1`
- [ ] Repo integrity PASS/WARN: `.\ops\repo_integrity.ps1`
- [ ] UI loads without 500 errors: `curl.exe http://localhost:8080/ui/admin/control-center`
- [ ] Obs stack works (if needed): `.\ops\alert_pipeline_proof.ps1` (PASS or WARN if obs not running)
- [ ] No archive/diag/backup files tracked: `git ls-files | Select-String "_archive|_diag|\.bak"`
- [ ] All proof docs present: `ls docs/PROOFS/*.md`
- [ ] All runbooks present: `ls docs/runbooks/*.md`

## Repository Structure

```
D:\stack/
├── .github/workflows/     # CI/CD workflows
├── docs/
│   ├── PROOFS/           # Proof documentation (tracked)
│   ├── runbooks/         # Operational runbooks (tracked)
│   └── HANDOVER_RC0.md   # This file
├── ops/
│   ├── _lib/             # Shared ops utilities
│   └── *.ps1             # Ops scripts (all tracked)
├── work/
│   ├── hos/              # NESTED REPO (not tracked in root)
│   └── pazar/            # Pazar application code
├── docker-compose.yml    # Core stack (canonical)
└── .gitignore            # Excludes _archive, _diag, backups
```

## Related Documentation

- `docs/RULES.md` - Development rules and gates
- `docs/REPO_LAYOUT.md` - Repository layout contract
- `docs/ARCHITECTURE.md` - Architecture overview
- `docs/runbooks/storage_permissions.md` - Storage troubleshooting
- `docs/runbooks/alerts_pipeline.md` - Alert pipeline verification
- `CHANGELOG.md` - Change history










