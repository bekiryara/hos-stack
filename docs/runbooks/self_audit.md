# Self-Audit Runbook

**Purpose:** Deterministic self-audit orchestration and drift detection for non-stop governance.

## Overview

The self-audit system provides:
- **Automated audit records**: Every run produces a timestamped audit folder with evidence
- **Drift detection**: Compare current state against baseline to detect changes
- **Zero-drift discipline**: Maintains RC0 governance standards

## Running Self-Audit

### Basic Usage

```powershell
.\ops\self_audit.ps1
```

**Expected output:**
```
=== SELF-AUDIT ORCHESTRATOR ===
Timestamp: 2026-01-11 12:00:00

[INFO] Creating audit folder: _archive\audits\audit-20260111-120000

=== Collecting Metadata ===
  [OK] meta.json

=== Running Canonical Checks ===
Running Repository Doctor...
  [PASS] Repository Doctor
Running Ops Status...
  [PASS] Ops Status
Running Conformance...
  [PASS] Conformance
...

=== Writing Summary ===
  [OK] summary.json

[INFO] === SELF-AUDIT COMPLETE ===

AUDIT_PATH=_archive\audits\audit-20260111-120000
AUDIT_OVERALL=PASS
```

**Output location:** `_archive/audits/audit-YYYYMMDD-HHMMSS/`

**Contents:**
- `meta.json` - Timestamp, git metadata, hostname, versions
- `summary.json` - Check results with overall status
- `doctor.txt` - Repository Doctor output
- `ops_status.txt` - Ops Status output
- `conformance.txt` - Conformance check output
- `env_contract.txt` - Environment Contract output (if available)
- `security_audit.txt` - Security Audit output (if available)
- `auth_security.txt` - Auth Security Check output (if available)
- `tenant_boundary.txt` - Tenant Boundary Check output (if available)
- `session_posture.txt` - Session Posture Check output (if available)
- `observability_status.txt` - Observability Status output (if available)

### With Ops Status Integration

```powershell
.\ops\ops_status.ps1 -RecordAudit
```

This runs ops status checks and then automatically records an audit.

## Running Drift Monitor

### Basic Usage (compare with previous audit)

```powershell
.\ops\drift_monitor.ps1
```

This automatically finds the latest audit and compares it with the previous one.

### Compare Specific Audits

```powershell
.\ops\drift_monitor.ps1 -CurrentPath "_archive\audits\audit-20260111-120000" -BaselinePath "_archive\audits\audit-20260110-120000"
```

**Expected output:**
```
=== DRIFT MONITOR ===
Timestamp: 2026-01-11 12:05:00

Current audit: _archive\audits\audit-20260111-120000
Baseline audit: _archive\audits\audit-20260110-120000

=== Collecting Current Hashes ===
  [OK] ops\snapshots\routes.pazar.json
  [OK] ops\snapshots\schema.pazar.sql
  ...

=== Loading Baseline Hashes ===
  [OK] Loaded baseline hashes

=== Writing Drift Hashes ===
  [OK] drift_hashes.json

=== Generating Drift Report ===
  [OK] drift_report.md

[INFO] === DRIFT MONITOR COMPLETE ===

DRIFT_STATUS=NO_DRIFT
DRIFT_REPORT=_archive\audits\audit-20260111-120000\drift_report.md
```

**Output files:**
- `drift_report.md` - Human-readable drift report (in current audit folder)
- `drift_hashes.json` - File hashes for governance surfaces (in current audit folder)

## Interpreting Results

### Audit Overall Status

- **PASS (exit 0)**: All checks passed (or only SKIP for optional checks)
- **WARN (exit 2)**: Some checks returned WARN, but no FAIL
- **FAIL (exit 1)**: At least one check FAILed

### Drift Status

- **NO_DRIFT**: Governance surfaces match baseline (no changes)
- **DRIFT_DETECTED**: Changes detected in governance surfaces (hash or size changed)
- **NO_BASELINE**: First run, no baseline available for comparison

### WARN vs FAIL

**WARN (non-blocking):**
- Optional checks missing (script not found)
- Check returned exit code 2 (WARN)
- Docker/Compose not available (metadata collection)

**FAIL (blocking):**
- Required check script missing (e.g., doctor.ps1, conformance.ps1)
- Check returned exit code 1 (FAIL)
- Folder creation failed
- Critical error during execution

## Integration with PRs and Incidents

### PR Requirements

Any stability/security/ops change must include:
1. Latest `AUDIT_PATH` in PR description
2. `drift_report.md` summary (if drift detected)

**Example PR description:**
```
## Changes
- Updated ops/self_audit.ps1 to include new check

## Self-Audit Evidence
AUDIT_PATH=_archive\audits\audit-20260111-120000

DRIFT_REPORT=_archive\audits\audit-20260111-120000\drift_report.md
DRIFT_STATUS=DRIFT_DETECTED (expected - ops script changed)
```

### Incident Reports

Include audit path in incident reports for evidence trail:

```
## Incident Evidence
AUDIT_PATH=_archive\audits\audit-20260111-120000
```

## Workflow Recommendations

### Daily/Regular Audits

```powershell
# Run self-audit
.\ops\self_audit.ps1

# Check for drift
.\ops\drift_monitor.ps1

# Review drift_report.md if DRIFT_DETECTED
```

### Pre-PR Audit

```powershell
# Run audit before creating PR
.\ops\self_audit.ps1

# Capture AUDIT_PATH for PR description
# Run drift_monitor to generate drift_report.md
.\ops\drift_monitor.ps1
```

### CI Integration

```powershell
# In CI pipeline
.\ops\self_audit.ps1
.\ops\drift_monitor.ps1

# Upload _archive/audits/ as CI artifact
```

## Troubleshooting

### Audit Folder Creation Fails

- Check disk space
- Verify `_archive/audits/` directory is writable
- Review error message in console output

### Missing Baseline for Drift Monitor

- First run: This is expected (no baseline available)
- Subsequent runs: Ensure previous audit exists in `_archive/audits/`
- Use `-BaselinePath` to specify explicit baseline

### Script Not Found Warnings

- Optional checks: WARN is acceptable (script may not exist)
- Required checks: FAIL if script missing (should not happen in normal operation)
- Verify ops scripts are present in `ops/` directory

## Related Documentation

- `docs/runbooks/ops_status.md` - Ops Status Dashboard
- `docs/runbooks/rc0_gate.md` - RC0 Gate details
- `docs/RULES.md` - Governance rules (Rule 43)





