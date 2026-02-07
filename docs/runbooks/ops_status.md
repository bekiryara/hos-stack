# Ops Status Dashboard Runbook

## Overview

The Unified Ops Status Dashboard is exposed via `.\ops\ops.ps1 status` (internally backed by `ops/ops_status.ps1`). It aggregates operational checks into a single command, providing a comprehensive view of system health, security, and compliance.

## Running Locally

### Recommended Usage (Terminal-Safe)

```powershell
.\ops\ops.ps1 status-safe
```

This wrapper prevents the terminal from closing and preserves exit codes. It's the recommended way to run ops_status locally.

### Direct Usage (Alternative)

```powershell
.\ops\ops.ps1 status
```

**Note:** Ops scripts now use safe exit behavior: in interactive PowerShell sessions, the terminal will not close (exit codes are set via `$global:LASTEXITCODE`). In CI environments (GitHub Actions), exit codes are properly propagated. This applies to ops entrypoints plus scripts under `ops/_checks/` and `ops/_tools/`.

**Safe Exit Behavior:**
- **Interactive Mode**: Scripts set `$global:LASTEXITCODE` and return (terminal stays open)
- **CI Mode**: Scripts call `exit $Code` (proper exit code propagation for CI/CD pipelines)
- **Detection**: Automatically detects CI environment via `$env:CI` or `$env:GITHUB_ACTIONS`

**ASCII-Only Output:**
- All ops scripts use ASCII-only output markers: `[PASS]`, `[FAIL]`, `[WARN]`, `[INFO]`
- No Unicode glyphs in output (use the markers above only)
- Ensures consistent rendering across all terminals and CI environments

### CI Usage

```powershell
.\ops\ops.ps1 status-safe -Ci
```

The `-Ci` switch ensures proper exit code propagation for CI/CD pipelines.

### Prerequisites

- Docker Compose services must be running
- Ops checks/tools must be present under `ops/`, `ops/_checks/`, `ops/_tools/`
- PowerShell 5.1+ or PowerShell Core

## Interpreting Results

### Status Values

- **PASS**: Check completed successfully
- **WARN**: Check completed with warnings (non-blocking)
- **FAIL**: Check failed (blocking)
- **SKIP**: Check not executed (script not found or intentionally skipped)

### Decision Matrix

The dashboard determines overall status based on individual check results and blocking semantics:

- **PASS**: Release allowed
  - All blocking checks PASS
  - Non-blocking checks may PASS, WARN, or SKIP

- **WARN**: Release allowed (with review)
  - All blocking checks PASS
  - One or more non-blocking checks WARN
  - Non-blocking checks that can WARN:
    - SLO Check (p50-only latency warnings)
    - Observability Status (WARN when Prometheus/Alertmanager absent but not blocking)
    - Storage Posture (legacy/non-critical warnings)

- **FAIL**: Blocks release + auto incident bundle
  - Any blocking check FAIL
  - Blocking checks: doctor, verify, conformance, env-contract, auth-security, tenant-boundary, session-posture, error-contract, routes-snapshot, schema-snapshot, product_spine_check, ops_drift_guard
  - Incident bundle is automatically generated and path is printed

### Overall Status

The dashboard determines overall status based on blocking semantics:

- **FAIL**: Any blocking check has status FAIL
- **WARN**: No blocking FAIL, but at least one non-blocking check WARN
- **PASS**: All blocking checks PASS (non-blocking checks may WARN)

### Exit Codes

- `0`: PASS (all checks passed)
- `2`: WARN (warnings present, no failures)
- `1`: FAIL (one or more failures)

## Checks Performed

The dashboard runs the following checks in order (run individually via `.\ops\ops.ps1 <command>` where available):

1. **Repository Doctor** (`.\ops\ops.ps1 doctor`, script: `ops/_checks/doctor.ps1`)
   - Docker Compose services status
   - Health endpoints
   - Repository structure

2. **Stack Verification** (`.\ops\ops.ps1 verify`, script: `ops/_checks/verify.ps1`)
   - Docker Compose services
   - H-OS health endpoint
   - Pazar health endpoint

3. **Incident Triage** (`.\ops\ops.ps1 triage`, script: `ops/_checks/triage.ps1`)
   - Quick health check for all services
   - Service status summary

4. **SLO Check** (script: `ops/_checks/slo_check.ps1`)
   - Service Level Objectives validation
   - Availability, latency, error rate checks

5. **Security Audit** (`.\ops\ops.ps1 security-audit`, script: `ops/_checks/security_audit.ps1`)
   - Route/middleware security validation
   - Admin/panel surface protection
   - State-changing route protection

6. **Conformance** (`.\ops\ops.ps1 conformance`, script: `ops/_checks/conformance.ps1`)
   - Architecture conformance checks
   - World registry validation
   - Documentation compliance

7. **World Spine Governance** (`.\ops\ops.ps1 world-spine`, script: `ops/_checks/world_spine_check.ps1`)
   - World spine route validation
   - Enabled/disabled world policy enforcement

8. **Routes Snapshot** (`.\ops\ops.ps1 routes-snapshot`, script: `ops/_checks/routes_snapshot.ps1`)
   - API route contract validation
   - Route changes detection

9. **Schema Snapshot** (`.\ops\ops.ps1 schema-snapshot`, script: `ops/_checks/schema_snapshot.ps1`)
   - Database schema contract validation
   - Schema changes detection

10. **Error Contract** (inline check)
   - Error envelope validation (422, 404)
   - Standard error format compliance

11. **Product Contract** (script: `ops/_checks/product_contract.ps1`)
   - Product API spine documentation validation
   - Spine endpoints vs routes snapshot alignment
   - Middleware posture validation
   - Error-contract posture smoke

## Incident Bundle on FAIL

When overall status is **FAIL**, the dashboard automatically:

1. Runs `.\ops\ops.ps1 incident-bundle` (script: `ops/_checks/incident_bundle.ps1`) to generate an incident bundle
2. Prints the bundle path: `INCIDENT_BUNDLE_PATH=incident_bundles/incident_bundle_YYYYMMDD_HHMMSS`

The incident bundle contains:
- System diagnostics
- Service logs
- Configuration snapshots
- Health check results

## CI Integration

The dashboard is integrated into CI via `.github/workflows/ops-status.yml`:

- Runs on pull requests and pushes
- Uploads incident bundle artifact on failure
- Always cleans up Docker Compose services

## Troubleshooting

### All Checks Fail

1. **Check Docker Compose**: Ensure services are running
   ```powershell
   docker compose ps
   ```

2. **Check Service Health**: Verify endpoints are accessible
   ```powershell
   curl.exe http://localhost:3000/v1/health
   curl.exe http://localhost:8080/up
   ```

3. **Review Individual Scripts**: Run each check individually to identify the issue
   ```powershell
   .\ops\ops.ps1 doctor
   .\ops\ops.ps1 verify
   ```

### Specific Check Fails

1. **SLO Check**: May fail due to performance issues; check SLO targets
2. **Security Audit**: Review route middleware configuration
3. **Conformance**: Check architecture rules in `docs/RULES.md`
4. **Routes/Schema Snapshot**: Update snapshots if changes are intentional

### Incident Bundle Not Generated

If incident bundle generation fails:
1. Check `ops/_checks/incident_bundle.ps1` is executable
2. Verify `incident_bundles/` directory exists or can be created
3. Check disk space and permissions

## Related Documentation

- `docs/RULES.md` - Rule 27: New ops gates must be integrated into ops_status.ps1
- `.\ops\ops.ps1 incident-bundle` - Incident bundle generation
- Individual ops script runbooks in `docs/runbooks/`

