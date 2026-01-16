# Smoke Surface Gate Pass

**Date**: 2026-01-11  
**Purpose**: Verify Smoke Surface Gate validates critical surfaces don't return 500/regression errors, ensuring RC0 is truly "release-safe".

## Overview

Smoke Surface Gate validates:
- Pazar /up → 200 (health check)
- Pazar /metrics → 200 AND Content-Type starts with "text/plain" AND body contains pazar_ metric AND no BOM artifact
- API error contract smoke: GET `/api/non-existent-endpoint` → 404 JSON envelope includes `request_id` (non-null)
- Admin UI surface must not 500: GET `/ui/admin/control-center` (no auth) should be either 200 or 302/401/403, BUT MUST NOT be 500
- Optional (WARN-only): If Prometheus reachable (9090), verify `/api/v1/targets` has pazar job up; else WARN

## Test Scenario 1: Full PASS (All Checks)

**Command:**
```powershell
.\ops\smoke_surface.ps1
```

**Expected Output:**
```
=== SMOKE SURFACE GATE ===
Timestamp: 2026-01-11 12:00:00
Base URL: http://localhost:8080

Check 1: Pazar /up endpoint
  [PASS] Pazar /up - HTTP 200 OK

Check 2: Pazar /metrics endpoint
  [PASS] Pazar /metrics - HTTP 200, Content-Type text/plain, body contains pazar_ metric, no BOM

Check 3: API error contract smoke
  [PASS] API error contract - HTTP 404 with JSON envelope (ok, error_code, message, request_id non-null)

Check 4: Admin UI surface (no 500)
  [PASS] Admin UI surface - HTTP 200 OK

Check 5: Prometheus targets (optional)
  [PASS] Prometheus targets - Pazar job found and UP

=== SMOKE SURFACE GATE RESULTS ===

Check                Status Notes
-----                ------ -----
Pazar /up            PASS   HTTP 200 OK
Pazar /metrics       PASS   HTTP 200, Content-Type text/plain, body contains pazar_ metric, no BOM
API error contract   PASS   HTTP 404 with JSON envelope (ok, error_code, message, request_id non-null)
Admin UI surface     PASS   HTTP 200 OK
Prometheus targets   PASS   Pazar job found and UP

OVERALL STATUS: PASS
```

**Verification:**
- ✅ Pazar /up returns 200
- ✅ Pazar /metrics returns 200 with text/plain Content-Type, contains pazar_ metric, no BOM
- ✅ API error contract returns 404 with JSON envelope including request_id
- ✅ Admin UI surface returns 200 (or 302/401/403, NOT 500)
- ✅ Prometheus targets check passes (if Prometheus reachable)
- ✅ Script exits with code 0 (PASS)

**Result**: ✅ Smoke Surface Gate returns PASS.

## Test Scenario 2: WARN (Prometheus Not Reachable)

**Command:**
```powershell
# With Prometheus not running
.\ops\smoke_surface.ps1
```

**Expected Output:**
```
Check 5: Prometheus targets (optional)
  [WARN] Prometheus targets - Prometheus not reachable at http://localhost:9090 (optional check)

=== SMOKE SURFACE GATE RESULTS ===

Check                Status Notes
-----                ------ -----
Pazar /up            PASS   HTTP 200 OK
Pazar /metrics       PASS   HTTP 200, Content-Type text/plain, body contains pazar_ metric, no BOM
API error contract   PASS   HTTP 404 with JSON envelope (ok, error_code, message, request_id non-null)
Admin UI surface     PASS   HTTP 200 OK
Prometheus targets   WARN   Prometheus not reachable at http://localhost:9090 (optional check)

OVERALL STATUS: WARN
```

**Verification:**
- ✅ All critical checks pass
- ✅ Optional Prometheus check WARN (non-blocking)
- ✅ Script exits with code 2 (WARN)

**Result**: ✅ Smoke Surface Gate returns WARN when Prometheus not reachable (non-blocking).

## Test Scenario 3: FAIL (Monolog Permission Error)

**Command:**
```powershell
# After breaking storage permissions
.\ops\smoke_surface.ps1
```

**Expected Output:**
```
Check 4: Admin UI surface (no 500)
  [FAIL] Admin UI surface - HTTP 500 Internal Server Error (Monolog permission error detected). Remediation: storage/logs and bootstrap/cache writable by php-fpm user (www-data); ensure runtime permission fix executes on every container start (not only one-time init); confirm storage volume is named volume not bind mount (avoid Windows perms)

=== SMOKE SURFACE GATE RESULTS ===

Check                Status Notes
-----                ------ -----
Pazar /up            PASS   HTTP 200 OK
Pazar /metrics       PASS   HTTP 200, Content-Type text/plain, body contains pazar_ metric, no BOM
API error contract   PASS   HTTP 404 with JSON envelope (ok, error_code, message, request_id non-null)
Admin UI surface     FAIL   HTTP 500 Internal Server Error (Monolog permission error detected). Remediation: storage/logs and bootstrap/cache writable by php-fpm user (www-data); ensure runtime permission fix executes on every container start (not only one-time init); confirm storage volume is named volume not bind mount (avoid Windows perms)

OVERALL STATUS: FAIL
```

**Verification:**
- ✅ Critical checks (Pazar /up, /metrics, API error contract) pass
- ✅ Admin UI surface fails with 500 (Monolog permission error detected)
- ✅ Remediation hints provided (storage permissions, entrypoint script, named volumes)
- ✅ Script exits with code 1 (FAIL)

**Result**: ✅ Smoke Surface Gate returns FAIL when Monolog permission error detected, with actionable remediation hints.

## Test Scenario 4: FAIL (Missing request_id in Error Envelope)

**Command:**
```powershell
# After breaking error contract
.\ops\smoke_surface.ps1
```

**Expected Output:**
```
Check 3: API error contract smoke
  [FAIL] API error contract - HTTP 404 but missing fields: request_id (null/empty)

=== SMOKE SURFACE GATE RESULTS ===

Check                Status Notes
-----                ------ -----
Pazar /up            PASS   HTTP 200 OK
Pazar /metrics       PASS   HTTP 200, Content-Type text/plain, body contains pazar_ metric, no BOM
API error contract   FAIL   HTTP 404 but missing fields: request_id (null/empty)
Admin UI surface     PASS   HTTP 200 OK

OVERALL STATUS: FAIL
```

**Verification:**
- ✅ API error contract check fails (missing request_id)
- ✅ Script exits with code 1 (FAIL)

**Result**: ✅ Smoke Surface Gate returns FAIL when error contract violated (missing request_id).

## Test Scenario 5: Ops Status Integration

**Command:**
```powershell
.\ops\run_ops_status.ps1
```

**Expected Table Row:**
```
Smoke Surface Gate                  [PASS] 0        (BLOCKING) All critical checks passed.
```

**Or if Prometheus not reachable:**
```
Smoke Surface Gate                  [WARN] 2        (BLOCKING) Prometheus not reachable, skipping optional check
```

**Or if Monolog permission error:**
```
Smoke Surface Gate                  [FAIL] 1        (BLOCKING) HTTP 500 Internal Server Error (Monolog permission error detected)
```

**Verification:**
- ✅ Smoke Surface Gate appears in ops_status table
- ✅ Status reflects actual test results (PASS/WARN/FAIL)
- ✅ Terminal doesn't close (Invoke-OpsExit used)

**Result**: ✅ Ops status includes Smoke Surface Gate check.

## Test Scenario 6: CI Gate

**Command:**
```powershell
# Simulate CI run
$env:CI = "true"
.\ops\smoke_surface.ps1
```

**Expected Output:**
```
=== SMOKE SURFACE GATE ===
...
OVERALL STATUS: PASS
```

**Verification:**
- ✅ CI environment variable doesn't change behavior
- ✅ Script exits with appropriate code (0=PASS, 2=WARN, 1=FAIL)
- ✅ CI workflow (`.github/workflows/smoke-surface.yml`) runs on push/PR

**Result**: ✅ CI gate runs successfully and blocks merges on FAIL.

## Test Scenario 7: Admin UI Redirect (302/401/403 Acceptable)

**Command:**
```powershell
# With admin UI requiring auth (redirects to login)
.\ops\smoke_surface.ps1
```

**Expected Output:**
```
Check 4: Admin UI surface (no 500)
  [PASS] Admin UI surface - HTTP 302 (redirect/unauthorized, acceptable)

=== SMOKE SURFACE GATE RESULTS ===

Check                Status Notes
-----                ------ -----
Admin UI surface     PASS   HTTP 302 (redirect/unauthorized, acceptable)

OVERALL STATUS: PASS
```

**Verification:**
- ✅ Admin UI returns 302 (redirect to login)
- ✅ Check passes (302/401/403 are acceptable, only 500 is failure)
- ✅ Script exits with code 0 (PASS)

**Result**: ✅ Smoke Surface Gate accepts 302/401/403 for Admin UI (only 500 is failure).

## Result

✅ Smoke Surface Gate successfully:
- Validates Pazar /up returns 200
- Validates Pazar /metrics returns 200 with text/plain Content-Type, contains pazar_ metric, no BOM
- Validates API error contract (404 with JSON envelope including request_id)
- Validates Admin UI surface doesn't return 500 (accepts 200/302/401/403)
- Detects Monolog permission errors with actionable remediation hints
- Optionally validates Prometheus targets (WARN-only, non-blocking)
- Integrated into ops_status as BLOCKING check
- CI gate runs on push/PR and blocks merges on FAIL
- No schema changes, no refactors, minimal diff
- PowerShell 5.1 compatible, ASCII-only output, safe exit behavior preserved



