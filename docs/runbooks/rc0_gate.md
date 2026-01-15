# RC0 Gate Runbook

## Overview

The RC0 Gate (`ops/rc0_gate.ps1`) is the single source of truth for RC0 release readiness. It validates all blocking and non-blocking requirements, providing a deterministic PASS/WARN/FAIL status with exit codes suitable for CI/CD pipelines.

## Purpose

**RC0 (Release Candidate 0)** is the first stabilized release candidate. The RC0 Gate ensures:
- All blocking checks pass (no critical failures)
- Non-blocking checks are evaluated appropriately (warnings don't block release)
- Release bundle is generated for evidence
- Deterministic decision logic (no false PASS/WARN/FAIL counts)

## Usage

### Local Execution

```powershell
.\ops\rc0_gate.ps1
```

**Safe Exit Behavior:**
- In interactive PowerShell sessions: Terminal does not close (exit codes set via `$global:LASTEXITCODE`)
- In CI environments: Exit codes properly propagated

### CI Execution

The `.github/workflows/rc0-gate.yml` workflow automatically runs this check on pull requests and pushes.

## Checks Performed (13 Total)

### Blocking Checks (Must Pass for RC0)

1. **A) Repository Doctor** (`ops/doctor.ps1`)
   - Docker Compose services status
   - Health endpoints
   - Repository structure integrity

2. **B) Stack Verification** (`ops/verify.ps1`)
   - All core services running and healthy
   - Network connectivity

3. **C) Architecture Conformance** (`ops/conformance.ps1`)
   - World registry drift check (WORLD_REGISTRY.md ↔ config/worlds.php)
   - Forbidden artifacts
   - Disabled-world code policy
   - Canonical docs single-source
   - Secrets safety

4. **D) Environment Contract** (`ops/env_contract.ps1`)
   - Required environment variables
   - Production guardrails (CORS, session security)

5. **E) Security Audit** (`ops/security_audit.ps1`)
   - Security violations check
   - Secrets exposure

6. **F) Auth Security Check** (`ops/auth_security_check.ps1`)
   - Authentication endpoint security posture
   - Rate limiting headers
   - Security headers

7. **G) Tenant Boundary Check** (`ops/tenant_boundary_check.ps1`)
   - Tenant isolation validation
   - **Note:** If secrets are not configured, this check will WARN (non-blocking for RC0)

8. **H) Session Posture Check** (`ops/session_posture_check.ps1`)
   - Session cookie security flags (Secure, HttpOnly, SameSite)
   - **Note:** In local/dev mode, FAIL is mapped to WARN (non-blocking for RC0)

9. **L) Schema Snapshot** (`ops/schema_snapshot.ps1`)
   - DB schema contract validation
   - Schema drift detection

10. **M) Error Contract** (`ops/error_contract_check.ps1` or inline check)
    - Standard error envelope format (422, 404)
    - Error code mapping

11. **N) Release Bundle** (`ops/release_bundle.ps1`)
    - Must produce release artifact at RC0 end
    - Evidence folder generation

### Non-Blocking Checks (WARN if Failed)

12. **I) SLO Check** (`ops/slo_check.ps1 -N 10`)
    - Lightweight performance benchmark (10 requests per endpoint)
    - p50 latency is non-blocking (policy exists in script)
    - **Note:** FAIL is automatically mapped to WARN (non-blocking)

13. **K) Routes Snapshot** (`ops/routes_snapshot.ps1`)
    - API route contract validation
    - **Note:** Real FAIL is FAIL (not auto-mapped), but routes change may be intentional

14. **J) Observability Status** (inline check)
    - Prometheus/Alertmanager readiness
    - Alert pipeline verification
    - **Note:** WARN only - observability is optional for RC0

## Interpreting Results

### PASS (Exit Code: 0)

All blocking checks passed. RC0 release is approved.

```
RC0 GATE: PASS (All blocking checks passed)
RC0 release is approved.
```

**Action:** Proceed with RC0 release and tagging.

### WARN (Exit Code: 2)

No blocking failures, but at least one warning present.

```
RC0 GATE: WARN (X warnings, no blocking failures)
RC0 can proceed with warnings. Review warnings before release.
```

**Action:** Review warnings (typically observability, SLO, or optional features). RC0 can proceed after review.

### FAIL (Exit Code: 1)

One or more blocking checks failed.

```
RC0 GATE: FAIL (X blocking failures)
INCIDENT_BUNDLE_PATH=_archive/incidents/incident-YYYYMMDD-HHMMSS
```

**Action:** **DO NOT PROCEED** with RC0 release. Review failures and incident bundle.

## Decision Logic

**Overall Status Determination:**
- **FAIL**: Any blocking check has status "FAIL"
- **WARN**: No blocking FAIL, but at least one "WARN" exists (or non-blocking FAIL mapped to WARN)
- **PASS**: All blocking checks are "PASS" (or only "SKIP")

**Summary Count:**
- Counts are based on actual results array (no false zero counts)
- Format: `X PASS, Y WARN, Z FAIL, N SKIP`

## Typical Remediations

### World Registry Drift (Conformance A)

**Symptom:** `WORLD_REGISTRY.md` and `config/worlds.php` mismatch

**Remediation:**
1. Check `work/pazar/WORLD_REGISTRY.md` for enabled/disabled world lists
2. Check `work/pazar/config/worlds.php` for matching arrays
3. Ensure both files have same enabled/disabled worlds
4. Update one to match the other (WORLD_REGISTRY.md is canonical)

### Missing Files (Conformance A)

**Symptom:** `WORLD_REGISTRY.md` or `config/worlds.php` not found

**Remediation:**
1. Create `work/pazar/WORLD_REGISTRY.md` with enabled/disabled sections
2. Create `work/pazar/config/worlds.php` with enabled/disabled arrays
3. See `docs/ops/VERSIONING.md` for format reference

### Other Failures

See individual runbooks for specific remediation:
- `docs/runbooks/ops_status.md` - Unified ops dashboard
- `docs/runbooks/incident.md` - Incident response procedures
- `docs/runbooks/release.md` - Release workflow

## Incident Bundle

On FAIL, the script automatically generates an incident bundle at `_archive/incidents/incident-YYYYMMDD-HHMMSS/`.

The bundle contains:
- Metadata (git branch, commit, status)
- Service logs
- Health check results
- System state snapshots

In CI, the incident bundle is uploaded as an artifact.

**Usage:**
1. Download artifact from CI run (if applicable)
2. Review `incident_note.md`
3. Check logs and system state
4. Use for troubleshooting and documentation

## Release Bundle

The RC0 Gate always runs `release_bundle.ps1` at the end (check N) to generate a release artifact. This ensures:
- Evidence folder is created for RC0
- All outputs are collected (RC0 gate, ops status, etc.)
- Release bundle path is reported

## Exit Codes

- `0` = PASS (RC0 approved)
- `2` = WARN (RC0 can proceed with review)
- `1` = FAIL (RC0 blocked)

## ASCII-Only Output

All output is ASCII-only (no Unicode characters) for:
- Cross-platform compatibility
- Consistent logging across environments
- CI/CD artifact readability

## Related Documentation

- `docs/RULES.md` - Rule 37: RC0 gate must PASS/WARN before RC0 tag
- `docs/runbooks/release.md` - Complete release workflow
- `docs/runbooks/ops_status.md` - Unified ops dashboard
- `ops/rc0_gate.ps1` - RC0 Gate script implementation
- `docs/PROOFS/rc0_gate_pass.md` - Proof documentation with sample outputs
