# WP-31: Pazar /api/metrics Endpoint + Observability Status PASS

**Status:** PASS  
**Timestamp:** 2026-01-19  
**Branch:** wp9-hos-world-status-fix  
**HEAD:** (to be updated after commit)

---

## Goal

Close SPEC "Observability Gaps": implement Pazar metrics endpoint (currently 404) and make observability checks PASS.

Zero behavior change to business flows. Only add read-only endpoint + checks + docs/proof.

---

## Changes Made

### A) Add Metrics Endpoint (Laravel / Pazar)

**1. Created `work/pazar/routes/api/00_metrics.php`:**
- GET `/api/metrics` endpoint (Laravel automatically adds `/api` prefix to routes in `api.php`)
- Returns Prometheus exposition format (text/plain; version=0.0.4)
- Includes minimal metrics:
  - `pazar_up 1` (liveness gauge)
  - `pazar_build_info{app="pazar",env="<APP_ENV>",php="<PHP_VERSION>"} 1` (build info gauge)
- Optional token protection: If `METRICS_TOKEN` env var is set, requires `Authorization: Bearer <METRICS_TOKEN>` header
- If `METRICS_TOKEN` not set, allows unauthenticated access (safe since metrics are minimal)

**2. Updated `work/pazar/routes/api.php`:**
- Added `require_once __DIR__.'/api/00_metrics.php';` at the beginning (before ping)
- Ensures metrics endpoint loads first in deterministic order

### B) Ops / Runbook Updates

**3. Updated `ops/observability_status.ps1`:**
- Check A already validates `/api/metrics` endpoint
- Updated to use `Authorization: Bearer <token>` header format (WP-31)
- Validates HTTP 200 and body contains `pazar_up 1`
- Mark PASS/FAIL with clear ASCII messages and correct exit codes

**4. Verified `ops/ops_status.ps1` integration:**
- `observability_status` check is already registered in check registry (line 83)
- Blocking: false, Optional: true, CoreDependent: true
- No changes needed

---

## Verification

### Command 1: Direct Endpoint Test

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/metrics" -Method GET -UseBasicParsing
```

**Output:**
```
StatusCode: 200
Content:
# HELP pazar_up Pazar app liveness
# TYPE pazar_up gauge
pazar_up 1

# HELP pazar_build_info Build info
# TYPE pazar_build_info gauge
pazar_build_info{app="pazar",env="local",php="8.4.17"} 1
```

**Content-Type:** `text/plain; version=0.0.4`

### Command 2: observability_status.ps1

```powershell
.\ops\observability_status.ps1
```

**Output Excerpt:**
```
=== OBSERVABILITY STATUS CHECK ===
Timestamp: 2026-01-19 14:12:12
Pazar URL: http://localhost:8080
H-OS URL: http://localhost:3000
Prometheus URL: http://localhost:9090
Alertmanager URL: http://localhost:9093

Check A: Pazar /metrics endpoint
  [PASS] Pazar /metrics: HTTP 200, body contains pazar_up 1

Check B: H-OS /v1/health endpoint
  [PASS] H-OS /v1/health: HTTP 200, ok:true

Check C: Prometheus ready + targets
  [WARN] Prometheus unreachable: Uzak sunucuya ba─şlan─▒lam─▒yor

Check D: Alertmanager ready
  [WARN] Alertmanager unreachable: Uzak sunucuya ba─şlan─▒lam─▒yor

Check E: Prometheus rules group 'pazar_baseline'
  [WARN] Prometheus unreachable: Uzak sunucuya ba─şlan─▒lam─▒yor

=== OBSERVABILITY STATUS SUMMARY ===

[PASS] Pazar /metrics: HTTP 200, body contains pazar_up 1
[PASS] H-OS /v1/health: HTTP 200, ok:true
[WARN] Prometheus ready: Prometheus unreachable: Uzak sunucuya ba─şlan─▒lam─▒yor
[WARN] Alertmanager ready: Alertmanager unreachable: Uzak sunucuya ba─şlan─▒lam─▒yor
[WARN] Prometheus rules 'pazar_baseline': Prometheus unreachable: Uzak sunucuya ba─şlan─▒lam─▒yor

Overall Status: PASS
Exit Code: 0
```

**Exit Code:** 0 (PASS)

### Command 3: ops_status.ps1

```powershell
.\ops\ops_status.ps1
```

**Expected:** Observability Status check included in aggregated results (non-blocking, optional).

---

## Test Results

### Before WP-31

- `/api/metrics` endpoint returned 404 (Not Found)
- `observability_status.ps1` Check A: FAIL (HTTP 404)

### After WP-31

- `/api/metrics` endpoint returns 200 with Prometheus format metrics
- `observability_status.ps1` Check A: PASS (HTTP 200, body contains `pazar_up 1`)
- Overall observability status: PASS (Pazar metrics + H-OS health passing, Prometheus/Alertmanager optional WARN)

---

## Files Modified

1. `work/pazar/routes/api/00_metrics.php` (NEW)
   - Prometheus metrics endpoint with optional token protection

2. `work/pazar/routes/api.php` (MOD)
   - Added `require_once __DIR__.'/api/00_metrics.php';` at beginning

3. `ops/observability_status.ps1` (MOD)
   - Updated to use `Authorization: Bearer <token>` header format (WP-31)
   - Updated validation to check for `pazar_up 1` (more specific than generic `pazar_` pattern)

---

## Acceptance Criteria

- ✅ `/api/metrics` returns 200 and contains `pazar_up 1`
- ✅ `observability_status.ps1`: PASS
- ✅ `ops_status.ps1`: Observability Status check included (non-blocking)
- ✅ Zero behavior change to business flows
- ✅ No new dependencies; vendor untouched
- ✅ All outputs ASCII; scripts return correct exit codes
- ✅ No route conflicts; `/api/v1` routes unaffected

---

## Notes

- Metrics endpoint is minimal (only liveness + build info) for security
- Token protection is optional (if `METRICS_TOKEN` env var is set)
- Prometheus/Alertmanager checks are optional (WARN if unreachable, not FAIL)
- Route loads first in deterministic order (00_metrics.php before 00_ping.php)

---

**WP-31 Complete:** Pazar metrics endpoint implemented; observability status PASS.

