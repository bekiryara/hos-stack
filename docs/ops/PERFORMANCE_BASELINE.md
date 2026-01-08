# Performance Baseline

## Overview

This document defines the performance baseline measurement methodology for SLO evaluation, including warm-up procedures and cold-start analysis.

## Warm-Up Standard

### Purpose
Warm-up requests eliminate cold-start effects that can skew latency measurements:
- Docker container cold starts
- Application initialization overhead
- Database connection pooling
- Cache warming

### Standard Practice
- **Warm-up requests**: 5 requests per endpoint (not measured)
- **Measured requests**: Default 30 requests per endpoint (configurable)

### Scripts
- **`ops/perf_baseline.ps1`**: Full performance baseline with warm-up and first-hit analysis
- **`ops/slo_check.ps1`**: SLO check with warm-up applied

## Cold Start and Docker Overhead

### Cold Start Effects
Cold start occurs when:
- Container first starts or restarts
- Application process initializes
- Database connections are established
- Caches are empty

### Docker Overhead
Docker adds overhead to first requests:
- Container networking initialization
- Volume mounting delays
- Resource allocation

### First-Hit Penalty
First measured request after warm-up may still show elevated latency due to:
- Remaining initialization
- Connection pool establishment
- First query execution

## Measurement Methodology

### Warm-Up Phase
1. Execute 5 warm-up requests per endpoint
2. Do not measure or record these requests
3. Allow system to stabilize

### Measurement Phase
1. Execute N measured requests (default 30)
2. Record response time and status for each
3. Calculate percentiles (p50, p95, max)
4. Analyze first-hit penalty

### First-Hit Analysis
- Compare first measured request latency to median
- Identify cold-start spikes in first 1-2 requests
- Evaluate remaining requests for stability

## Classification: WARN vs FAIL

### PASS
- p95 latency within SLO target
- No sustained performance issues

### WARN (Cold-Start Spikes Only)
- p95 exceeds target BUT
- Failure is only in first 1-2 measured requests
- Remaining requests (excluding first 2) have p95 within target
- **Action**: Does not block release (per Rule 23)

### FAIL (Sustained Failure)
- p95 exceeds target AND
- Failure persists beyond first 1-2 requests
- Remaining requests (excluding first 2) also fail p95 target
- **Action**: Block release, investigate root cause

## Interpreting Results

### Example 1: PASS
```
p95: 150ms (target: < 200ms)
Status: PASS
```
All requests meet SLO target.

### Example 2: WARN (Cold-Start)
```
p95: 2500ms (target: < 200ms)
First 2 requests: 2500ms, 1800ms
Remaining p95: 45ms
Status: WARN (cold-start spike in first 1-2 requests, rest stable)
```
First requests show cold-start penalty, but system stabilizes quickly.

### Example 3: FAIL (Sustained)
```
p95: 800ms (target: < 200ms)
First 2 requests: 1200ms, 900ms
Remaining p95: 750ms
Status: FAIL (sustained p95 failure)
```
Performance issues persist throughout measurement window.

## Using the Scripts

### Performance Baseline (Full Analysis)
```powershell
.\ops\perf_baseline.ps1 -N 30
```
- Full warm-up and first-hit analysis
- Detailed classification (PASS/WARN/FAIL)
- First-hit penalty reporting

### SLO Check (Quick Validation)
```powershell
.\ops\slo_check.ps1 -N 30
```
- Warm-up applied automatically
- SLO threshold validation
- Quick PASS/WARN/FAIL status

## When to Use Each Script

### Use `perf_baseline.ps1` when:
- Investigating performance issues
- Analyzing cold-start effects
- Baseline establishment
- Deep performance analysis

### Use `slo_check.ps1` when:
- Daily/weekly SLO validation
- Release candidate checks
- Quick performance verification
- CI/CD integration

## Troubleshooting

### High First-Hit Penalty
If first-hit penalty is consistently high (> 500ms):
- Check Docker container startup time
- Review application initialization
- Investigate database connection pooling
- Consider increasing warm-up requests

### Sustained Failures
If p95 failures persist beyond first requests:
- Review application performance
- Check database query performance
- Investigate resource constraints
- Use `ops/triage.ps1` for diagnostics

## Related Documentation

- [SLO Definitions](./SLO.md) - SLO targets and thresholds
- [Error Budget Policy](./ERROR_BUDGET.md) - Error budget and freeze rules
- [SLO Breach Runbook](../runbooks/slo_breach.md) - Response procedures
- [Rules](../RULES.md) - Rule 23 (cold-start spikes do not block release)

## Best Practices

1. **Always use warm-up**: Never measure cold starts for SLO evaluation
2. **Understand context**: Distinguish cold-start spikes from sustained issues
3. **Measure consistently**: Use same N and warm-up count for comparisons
4. **Monitor trends**: Track first-hit penalty over time
5. **Document anomalies**: Record unusual patterns in incident bundles

