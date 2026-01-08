# Service Level Objectives (SLOs)

## Overview

SLOs define the reliability and performance targets for our services. This document establishes v1 SLOs for H-OS and Pazar services.

## Availability SLOs

### Pazar Service
- **Target**: 99.5% monthly availability
- **Measurement**: `GET /up` endpoint returns HTTP 200
- **Calculation**: `success_count / total_requests`
- **Measurement Window**: 30-day rolling window

### H-OS Service
- **Target**: 99.5% monthly availability
- **Measurement**: `GET /v1/health` endpoint returns HTTP 200 with `{"ok":true}`
- **Calculation**: `success_count / total_requests`
- **Measurement Window**: 30-day rolling window

## Latency SLOs

### Pazar Service (`/up`)
- **p50 Target**: < 50ms
- **p95 Target**: < 200ms
- **Measurement**: Response time from request start to response received
- **Measurement Window**: 30-day rolling window

### H-OS Service (`/v1/health`)
- **p50 Target**: < 100ms
- **p95 Target**: < 500ms
- **Measurement**: Response time from request start to response received
- **Measurement Window**: 30-day rolling window

## Error Rate SLOs

### Both Services
- **Target**: < 1% error rate (non-2xx responses)
- **Calculation**: `(total_requests - success_count) / total_requests`
- **Measurement Window**: 30-day rolling window

## Measurement Method

### Automated Checks
- **Script**: `ops/slo_check.ps1`
- **Sample Size**: N=30 requests (configurable)
- **Concurrency**: 1 (sequential requests)
- **Frequency**: Manual or scheduled (not automated in v1)

### Manual Calculation
For monthly reporting, aggregate results from daily/weekly `slo_check.ps1` runs or use application logs to calculate:
- Total requests in 30-day window
- Success count (HTTP 200 + valid JSON for H-OS)
- Response time percentiles

## Reporting Cadence

### Daily (Optional)
- Run `ops/slo_check.ps1` to get current snapshot
- Check for immediate issues (FAIL/WARN)

### Weekly (Recommended)
- Run `ops/slo_check.ps1` and record results
- Calculate weekly averages
- Track trends

### Monthly (Required)
- Aggregate all measurements
- Calculate 30-day availability, error rate, latency percentiles
- Compare against SLO targets
- Document any breaches in incident reports

## SLO Review Triggers

SLOs should be revisited when:

1. **Infrastructure Changes**: New deployment method, container orchestration changes
2. **Architecture Changes**: Service split/merge, new dependencies
3. **Traffic Pattern Changes**: >50% increase in request volume
4. **Consistent Breaches**: SLO breached 3+ consecutive months
5. **New Service Endpoints**: Critical endpoints added that affect availability

## SLO Targets (v1)

| Service | Endpoint | Availability | p50 Latency | p95 Latency | Error Rate |
|---------|----------|-------------|-------------|-------------|------------|
| Pazar | `/up` | 99.5% | < 50ms | < 200ms | < 1% |
| H-OS | `/v1/health` | 99.5% | < 100ms | < 500ms | < 1% |

## Error Budget

Error budget = 1 - availability target

- **Pazar**: 0.5% monthly error budget (~3.6 hours/month)
- **H-OS**: 0.5% monthly error budget (~3.6 hours/month)

See [ERROR_BUDGET.md](./ERROR_BUDGET.md) for error budget policy and spending guidelines.

## Related Documentation

- [Error Budget Policy](./ERROR_BUDGET.md) - Error budget spending and freeze policy
- [SLO Breach Runbook](../runbooks/slo_breach.md) - What to do when SLOs are breached
- [Incident Runbook](../runbooks/incident.md) - General incident response procedures

