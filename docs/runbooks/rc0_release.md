# RC0 Release Readiness Guide

## Overview

The RC0 (Release Candidate 0) gate is a single-command validation that ensures all required checks pass before a release can proceed. It runs all critical gates in a deterministic order and produces a clear PASS/WARN/FAIL result.

## RC0 Definition

RC0 represents the minimum quality bar for a release candidate:
- All blocking checks must PASS
- Optional checks may WARN (missing components) or SKIP (credentials missing)
- No blocking checks may FAIL
- WARN is acceptable only if documented in the release bundle note

## What PASS/WARN/FAIL Means

### PASS (Exit Code 0)
- All blocking checks passed
- Optional checks may have WARN/SKIP, but no blocking failures
- Release can proceed

### WARN (Exit Code 2)
- No blocking checks failed
- One or more checks produced warnings (missing optional components, skipped tests due to missing credentials)
- Release can proceed if warnings are documented and acceptable

### FAIL (Exit Code 1)
- One or more blocking checks failed
- Release **cannot** proceed
- Incident bundle is automatically generated
- Must investigate and fix failures before proceeding

## How to Run RC0 Check Locally

### Prerequisites
- Docker Compose stack running (for service-dependent checks)
- PowerShell 5.1 or later
- Optional: Environment variables/secrets for auth-required tests

### Basic Usage

```powershell
# Run RC0 check
.\ops\rc0_check.ps1
```

### With CI Flag

```powershell
# Run with CI flag (for CI-like behavior)
.\ops\rc0_check.ps1 -Ci
```

### Environment Variables

For full test coverage, set these environment variables:

```powershell
# Tenant testing
$env:TENANT_TEST_EMAIL = "test@example.com"
$env:TENANT_TEST_PASSWORD = "password"
$env:TENANT_A_SLUG = "tenant-a"
$env:TENANT_B_SLUG = "tenant-b"

# Product testing
$env:PRODUCT_TEST_TENANT_ID = "tenant-id"
$env:PRODUCT_TEST_AUTH_TOKEN = "auth-token"
```

**Note:** If credentials are missing, auth-required tests will WARN+SKIP, but public contract tests will still run.

## Checks Performed

The RC0 check runs the following gates in order:

1. **Repository Doctor** (`ops/doctor.ps1`) - Repository integrity
2. **Stack Verification** (`ops/verify.ps1`) - Stack health
3. **Conformance** (`ops/conformance.ps1`) - Code conformance
4. **Security Audit** (`ops/security_audit.ps1`) - Security posture
5. **Environment Contract** (`ops/env_contract.ps1`) - Environment validation
6. **Session Posture** (`ops/session_posture_check.ps1`) - Session security
7. **SLO Check** (`ops/slo_check.ps1 -N 30`) - Service level objectives
8. **Observability Status** (`ops/observability_status.ps1`) - Optional
9. **Product E2E** (`ops/product_e2e.ps1`) - Optional
10. **Tenant Boundary** (`ops/tenant_boundary_check.ps1`) - Tenant isolation

## How to Create Release Bundle

After running RC0 check, create a release bundle for documentation:

```powershell
# Generate RC0 release bundle
.\ops\rc0_release_bundle.ps1
```

The bundle will be created at: `_archive/releases/rc0-YYYYMMDD-HHMMSS/`

### Bundle Contents

- `meta.txt` - Git metadata (branch, commit, status)
- `rc0_check.txt` - Full RC0 check output
- `ops_status.txt` - Ops status dashboard output
- Individual check outputs (conformance, security_audit, etc.)
- `routes_snapshot.txt` - Routes snapshot
- `schema_snapshot.txt` - Schema snapshot
- `logs_pazar_app.txt` - Pazar app logs (if Docker available)
- `logs_hos_api.txt` - H-OS API logs (if Docker available)
- `release_note.md` - Release note template with checklist

## What to Attach to Issues

When reporting RC0 failures:

1. **Full RC0 Check Output** - Copy the entire output from `rc0_check.ps1`
2. **Incident Bundle** - If FAIL occurred, incident bundle is auto-generated at `_archive/incidents/incident-YYYYMMDD-HHMMSS/`
3. **Release Bundle** - If you created one, attach the release bundle folder
4. **Request IDs** - For API-related failures, include request IDs from error responses
5. **Environment Details** - OS, PowerShell version, Docker version, environment variables set

## Troubleshooting

### "Script not found" Errors

- Ensure you're running from the repository root
- Check that the script exists in `ops/` directory
- For optional scripts, this will WARN, not FAIL

### "Failed to connect" Errors

- Ensure Docker Compose stack is running: `docker compose up -d`
- Wait for services to be ready (30-60 seconds)
- Check service health: `curl http://localhost:8080/up` and `curl http://localhost:3000/v1/health`

### "Auth credentials missing" Warnings

- These are expected if credentials are not set
- Auth-required tests will SKIP with WARN
- Public contract tests will still run
- To run full suite, set environment variables as shown above

### Exit Code Confusion

- **0 = PASS** - All checks passed
- **2 = WARN** - Warnings present, but no failures
- **1 = FAIL** - Blocking check failed

## CI Integration

The RC0 check runs automatically in CI on:
- Pull requests to `main` or `develop`
- Pushes to `main` or `develop`

See `.github/workflows/rc0-check.yml` for details.

## Release Process

1. Run `.\ops\rc0_check.ps1` locally
2. If PASS/WARN, proceed to create release bundle: `.\ops\rc0_release_bundle.ps1`
3. Review bundle contents, especially `rc0_check.txt` and `release_note.md`
4. Update `release_note.md` with actual results
5. If all checks pass, proceed with release
6. If FAIL, investigate using incident bundle and fix issues

## Related Documentation

- `docs/runbooks/ops_status.md` - Ops status dashboard
- `docs/RULES.md` - Governance rules (including RC0 gate rule)
- `docs/PROOFS/cleanup_pass.md` - Proof of successful RC0 implementation
