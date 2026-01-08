# SLO Breach Response Runbook

## Overview

This runbook provides step-by-step procedures for responding to SLO breaches detected by `ops/slo_check.ps1`.

## Detection

### Automated Detection
Run `ops/slo_check.ps1` to check current SLO status:
```powershell
.\ops\slo_check.ps1
```

### Interpretation
- **PASS**: All SLOs met (availability ≥ target, latency ≤ targets, error rate < threshold)
- **WARN**: One or more SLOs approaching limits (within 5% of threshold)
- **FAIL**: One or more SLOs breached (availability < target, latency > targets, error rate ≥ threshold)

## Response Procedures

### Step 1: Immediate Assessment (5 minutes)

1. **Check current status**:
   ```powershell
   .\ops\slo_check.ps1
   ```

2. **Identify breached SLOs**:
   - Which service? (Pazar / H-OS)
   - Which metric? (Availability / Latency / Error Rate)
   - How severe? (WARN / FAIL)

3. **Check system health**:
   ```powershell
   .\ops\triage.ps1
   ```

### Step 2: Evidence Collection (10 minutes)

1. **Generate incident bundle**:
   ```powershell
   .\ops\incident_bundle.ps1
   ```
   Note the bundle path for documentation.

2. **Document findings**:
   - Fill in `incident_note.md` in the bundle
   - Record timestamp, breached SLOs, current metrics

### Step 3: Request ID Workflow (if applicable)

If errors are occurring:

1. **Capture request IDs** from error responses:
   - Check `hos_health.txt` and `pazar_up.txt` in incident bundle
   - Extract any error responses with `request_id`

2. **Search logs**:
   ```powershell
   docker compose logs pazar-app | Select-String "request_id.*<uuid>"
   docker compose logs hos-api | Select-String "request_id.*<uuid>"
   ```

3. **Trace the issue**:
   - Use request_id to follow request flow
   - Identify which service is failing
   - Check for patterns (specific endpoints, times, conditions)

### Step 4: Severity Assignment

**Important**: Only **blocking metrics** (availability, p95, error rate) trigger SEV escalation. p50 latency breaches are informational and treated as WARN (non-blocking per Rule 25).

Map SLO breach to SEV level:

| SLO Breach Severity | SEV Level | Response Time |
|---------------------|-----------|---------------|
| Availability < 95% (major outage) | SEV1 | Immediate (15 min) |
| Availability < 99% (partial outage) | SEV2 | Within 1 hour |
| Availability 99-99.5% (approaching limit) | SEV3 | Within 4 hours |
| Latency > 2x target (performance degradation) | SEV2 | Within 1 hour |
| Error rate > 5% (high error rate) | SEV2 | Within 1 hour |
| Error rate 1-5% (threshold breach) | SEV3 | Within 4 hours |

### Step 5: Error Budget Check

1. **Check error budget status**:
   - Review recent `slo_check.ps1` results
   - Calculate remaining budget for the month

2. **Apply error budget policy**:
   - **Two-Day Fail Rule**: If FAIL for 2 consecutive days → freeze non-stability work
   - **Error Rate Threshold**: If error rate > 1% → investigate before features
   - **Monthly Depletion**: If budget depleted → post-mortem required

3. **Communicate freeze** (if applicable):
   - Update repository status
   - Notify team
   - Document in incident bundle

### Step 6: Investigation & Resolution

1. **Use triage script**:
   ```powershell
   .\ops\triage.ps1
   ```

2. **Check service logs**:
   - Review `logs_pazar_app.txt` and `logs_hos_api.txt` in incident bundle
   - Look for error patterns, exceptions, performance issues

3. **Check system resources**:
   - Docker Compose services status
   - Health endpoints responses
   - Recent changes (check git log)

4. **Root cause analysis**:
   - Use request_id workflow if applicable
   - Compare with baseline (previous incident bundles)
   - Identify contributing factors

5. **Implement fix**:
   - Apply stability improvements
   - Monitor with `slo_check.ps1`
   - Verify improvement

### Step 7: Verification

1. **Re-run SLO check**:
   ```powershell
   .\ops\slo_check.ps1
   ```
   Must return PASS to consider resolved.

2. **Verify system health**:
   ```powershell
   .\ops\verify.ps1
   ```

3. **Monitor for 24 hours**:
   - Run `slo_check.ps1` daily
   - Ensure no regression

### Step 8: Documentation

1. **Complete incident bundle**:
   - Update `incident_note.md` with resolution details
   - Document root cause and fix

2. **Update incident runbook** (if new patterns discovered):
   - Add lessons learned
   - Update procedures if needed

3. **Post-mortem** (if SEV1/SEV2 or monthly budget depleted):
   - Review incident timeline
   - Identify improvement opportunities
   - Update SLO targets if needed (see SLO.md review triggers)

## Quick Reference

### Commands
```powershell
# Check SLO status
.\ops\slo_check.ps1

# System health check
.\ops\triage.ps1

# Generate evidence bundle
.\ops\incident_bundle.ps1

# Verify stack
.\ops\verify.ps1
```

### Escalation Path

1. **SEV1** (availability < 95%): Immediate escalation, all hands on deck
2. **SEV2** (availability < 99%): Escalate within 1 hour, team response
3. **SEV3** (approaching limits): Normal queue, investigate within 4 hours

### Error Budget Triggers

- **2-day FAIL**: Freeze non-stability work
- **Error rate > 1%**: Investigate before features
- **Monthly depletion**: Post-mortem required

## Related Documentation

- [SLO Definitions](../ops/SLO.md) - SLO targets and measurement
- [Error Budget Policy](../ops/ERROR_BUDGET.md) - Error budget spending rules
- [Incident Runbook](./incident.md) - General incident response
- [Observability Runbook](./observability.md) - Request ID tracing

