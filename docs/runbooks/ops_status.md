# Ops Status Dashboard Runbook

## Overview

The Unified Ops Status Dashboard (`ops/ops_status.ps1`) aggregates all operational checks into a single command, providing a comprehensive view of system health, security, and compliance.

## Running Locally

### Basic Usage

```powershell
.\ops\ops_status.ps1
```

### Prerequisites

- Docker Compose services must be running
- All ops scripts must be available in `ops/` directory
- PowerShell 5.1+ or PowerShell Core

## Interpreting Results

### Status Values

- **PASS**: Check completed successfully
- **WARN**: Check completed with warnings (non-blocking)
- **FAIL**: Check failed (blocking)

### Overall Status

The dashboard determines overall status based on individual check results:

- **FAIL**: Any check has status FAIL
- **WARN**: No FAIL, but at least one WARN
- **PASS**: All checks PASS

### Exit Codes

- `0`: PASS (all checks passed)
- `2`: WARN (warnings present, no failures)
- `1`: FAIL (one or more failures)

## Checks Performed

The dashboard runs the following checks in order:

1. **Repository Doctor** (`ops/doctor.ps1`)
   - Docker Compose services status
   - Health endpoints
   - Repository structure

2. **Stack Verification** (`ops/verify.ps1`)
   - Docker Compose services
   - H-OS health endpoint
   - Pazar health endpoint

3. **Incident Triage** (`ops/triage.ps1`)
   - Quick health check for all services
   - Service status summary

4. **SLO Check** (`ops/slo_check.ps1`)
   - Service Level Objectives validation
   - Availability, latency, error rate checks

5. **Security Audit** (`ops/security_audit.ps1`)
   - Route/middleware security validation
   - Admin/panel surface protection
   - State-changing route protection

6. **Conformance** (`ops/conformance.ps1`)
   - Architecture conformance checks
   - World registry validation
   - Documentation compliance

7. **Routes Snapshot** (`ops/routes_snapshot.ps1`)
   - API route contract validation
   - Route changes detection

8. **Schema Snapshot** (`ops/schema_snapshot.ps1`)
   - Database schema contract validation
   - Schema changes detection

9. **Error Contract** (inline check)
   - Error envelope validation (422, 404)
   - Standard error format compliance

## Incident Bundle on FAIL

When overall status is **FAIL**, the dashboard automatically:

1. Runs `ops/incident_bundle.ps1` to generate an incident bundle
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
   .\ops\doctor.ps1
   .\ops\verify.ps1
   ```

### Specific Check Fails

1. **SLO Check**: May fail due to performance issues; check SLO targets
2. **Security Audit**: Review route middleware configuration
3. **Conformance**: Check architecture rules in `docs/RULES.md`
4. **Routes/Schema Snapshot**: Update snapshots if changes are intentional

### Incident Bundle Not Generated

If incident bundle generation fails:
1. Check `ops/incident_bundle.ps1` is executable
2. Verify `incident_bundles/` directory exists or can be created
3. Check disk space and permissions

## Related Documentation

- `docs/RULES.md` - Rule 27: New ops gates must be integrated into ops_status.ps1
- `ops/incident_bundle.ps1` - Incident bundle generation
- Individual ops script runbooks in `docs/runbooks/`

