# Error Budget Policy

## What is Error Budget?

Error budget = 1 - availability target

For our 99.5% availability target:
- **Error Budget**: 0.5% per month
- **Time Budget**: ~3.6 hours of downtime/errors per month

## Error Budget Usage

### Spending Error Budget
Error budget is "spent" when:
- Service is unavailable (HTTP 5xx, timeout)
- Health check fails (non-200 or invalid response)
- SLO check shows availability < 99.5%

### Preserving Error Budget
Error budget is "preserved" when:
- Service meets availability target (≥ 99.5%)
- No incidents or outages
- All SLO checks PASS

## Error Budget Policy (v1)

### Policy Rule 1: Two-Day Fail Rule
**If SLO check fails 2 days in a row:**
- **Action**: Freeze all non-stability work
- **Allowed Work**: Only bug fixes, stability improvements, incident response
- **Blocked Work**: New features, refactoring, architectural changes
- **Requirement**: Must run `ops/slo_check.ps1` and document results

### Policy Rule 2: Error Rate Threshold
**If error rate > 1% (threshold):**
- **Action**: Investigate before adding features
- **Required**: Run `ops/triage.ps1` and `ops/incident_bundle.ps1`
- **Documentation**: Create incident report or investigation note
- **Resolution**: Must bring error rate below 1% before proceeding with features

### Policy Rule 3: Monthly Budget Depletion
**If error budget depleted in a month (< 99.5% availability):**
- **Action**: Post-mortem required
- **Documentation**: Incident bundle + runbook steps completed
- **Review**: SLO targets may need adjustment (see SLO.md review triggers)

## Error Budget Tracking

### Daily Tracking
- Run `ops/slo_check.ps1`
- Record availability percentage
- Track trends over time

### Weekly Review
- Calculate weekly availability average
- Compare against monthly target
- Estimate remaining budget

### Monthly Assessment
- Calculate final monthly availability
- Determine if budget was depleted
- Plan next month (adjust if needed)

## Freeze Procedure

When error budget policy triggers a freeze:

1. **Document the trigger**: Note which rule was violated
2. **Run diagnostics**: `ops/slo_check.ps1`, `ops/triage.ps1`
3. **Create incident bundle**: `ops/incident_bundle.ps1`
4. **Communicate freeze**: Update team/repository status
5. **Focus on stability**: Only stability work allowed
6. **Monitor improvement**: Daily `slo_check.ps1` until PASS
7. **Lift freeze**: When SLO check PASS for 2+ consecutive days

## Example Scenarios

### Scenario 1: Two-Day Fail
- **Day 1**: `slo_check.ps1` returns FAIL (availability 98.5%)
- **Day 2**: `slo_check.ps1` returns FAIL (availability 99.0%)
- **Action**: Freeze non-stability work, focus on fixing issues

### Scenario 2: High Error Rate
- **Check**: Error rate = 2.5% (above 1% threshold)
- **Action**: Investigate root cause before adding features
- **Required**: `ops/triage.ps1` + `ops/incident_bundle.ps1`

### Scenario 3: Monthly Budget Depletion
- **Month End**: Availability = 99.2% (< 99.5% target)
- **Action**: Post-mortem required, document lessons learned
- **Review**: Consider SLO target adjustment if consistently unmet

## Related Documentation

- [SLO Definitions](./SLO.md) - SLO targets and measurement methods
- [SLO Breach Runbook](../runbooks/slo_breach.md) - Response procedures for breaches
- [Incident Runbook](../runbooks/incident.md) - General incident response

