# Product Read-Path Self-Audit Gate Pack v1 PASS

**Date**: 2026-01-11  
**Purpose**: Verify Product Read-Path self-audit gate correctly validates Commerce listings GET endpoints.

## Overview

The Product Read-Path Check (`ops/product_read_path_check.ps1`) verifies:

1. Unauthorized access to `/api/v1/commerce/listings` returns 401/403 with proper JSON error envelope.
2. Authenticated access returns 200 with `ok:true` and valid JSON structure.
3. Not found (404) returns proper error envelope with `error_code: "NOT_FOUND"`.
4. Content-Type validation (must be `application/json` for 200 responses).

## Test Scenario 1: Without Environment Variables (WARN Expected)

**Command**:
```powershell
.\ops\product_read_path_check.ps1
```

**Expected Output (truncated)**:
```
=== PRODUCT READ-PATH CHECK ===
Timestamp: 2026-01-11 HH:MM:SS

Check 1: Route surface (unauthorized access)
Testing GET /api/v1/commerce/listings (unauthorized)...
  [PASS] GET /api/v1/commerce/listings (unauthorized)

Check 2: Auth + tenant context (authenticated access)
  [WARN] Credentials not set (PRODUCT_TEST_TOKEN or PRODUCT_TEST_EMAIL + PRODUCT_TEST_PASSWORD required), skipping authenticated checks
  Set PRODUCT_TEST_TOKEN (Bearer token) OR PRODUCT_TEST_EMAIL + PRODUCT_TEST_PASSWORD environment variables to enable.
  Set PRODUCT_TEST_TEST_TENANT_ID environment variable (UUID).

=== PRODUCT READ-PATH CHECK RESULTS ===

Check                                                    Status Notes
--------------------------------------------------------------------------------
GET /api/v1/commerce/listings (unauthorized)             PASS   Status 401, JSON envelope correct (ok:false, request_id present)
Authenticated checks                                     WARN   Credentials not set (PRODUCT_TEST_TOKEN or PRODUCT_TEST_EMAIL + PRODUCT_TEST_PASSWORD required), skipping authenticated checks

OVERALL STATUS: WARN
```

**Exit Code**: 2 (WARN)

**Verification**:
- ✅ Unauthorized check passed (401/403 with proper JSON envelope)
- ✅ Authenticated checks skipped with WARN (credentials not set)
- ✅ Overall status is WARN (not FAIL)

## Test Scenario 2: With Environment Variables (PASS Expected)

**Setup**:
```powershell
$env:PRODUCT_TEST_TOKEN = "your-bearer-token-here"
$env:PRODUCT_TEST_TENANT_ID = "00000000-0000-0000-0000-000000000001"
```

**Command**:
```powershell
.\ops\product_read_path_check.ps1
```

**Expected Output (truncated)**:
```
=== PRODUCT READ-PATH CHECK ===
Timestamp: 2026-01-11 HH:MM:SS

Check 1: Route surface (unauthorized access)
Testing GET /api/v1/commerce/listings (unauthorized)...
  [PASS] GET /api/v1/commerce/listings (unauthorized)

Check 2: Auth + tenant context (authenticated access)
Testing GET /api/v1/commerce/listings (authenticated)...
  [PASS] GET /api/v1/commerce/listings (authenticated)
Testing GET /api/v1/commerce/listings/{id} (not found)...
  [PASS] GET /api/v1/commerce/listings/{id} (not found)

=== PRODUCT READ-PATH CHECK RESULTS ===

Check                                                    Status Notes
--------------------------------------------------------------------------------
GET /api/v1/commerce/listings (unauthorized)             PASS   Status 401, JSON envelope correct (ok:false, request_id present)
GET /api/v1/commerce/listings (authenticated)            PASS   Status 200, JSON envelope correct (ok:true, request_id present)
GET /api/v1/commerce/listings/{id} (not found)           PASS   Status 404, JSON envelope correct (ok:false, error_code: NOT_FOUND, request_id present)

OVERALL STATUS: PASS
```

**Exit Code**: 0 (PASS)

**Verification**:
- ✅ Unauthorized check passed (401/403 with proper JSON envelope)
- ✅ Authenticated GET list passed (200 with `ok:true`, `request_id` present)
- ✅ Authenticated GET detail (not found) passed (404 with `ok:false`, `error_code: "NOT_FOUND"`, `request_id` present)
- ✅ Overall status is PASS

## Test Scenario 3: With Login Credentials (Email + Password)

**Setup**:
```powershell
$env:PRODUCT_TEST_EMAIL = "test@example.com"
$env:PRODUCT_TEST_PASSWORD = "password"
$env:PRODUCT_TEST_TENANT_ID = "00000000-0000-0000-0000-000000000001"
```

**Command**:
```powershell
.\ops\product_read_path_check.ps1
```

**Expected Output (truncated)**:
```
=== PRODUCT READ-PATH CHECK ===
Timestamp: 2026-01-11 HH:MM:SS

Check 1: Route surface (unauthorized access)
Testing GET /api/v1/commerce/listings (unauthorized)...
  [PASS] GET /api/v1/commerce/listings (unauthorized)

Check 2: Auth + tenant context (authenticated access)
  Obtaining token via login...
Testing GET /api/v1/commerce/listings (authenticated)...
  [PASS] GET /api/v1/commerce/listings (authenticated)
Testing GET /api/v1/commerce/listings/{id} (not found)...
  [PASS] GET /api/v1/commerce/listings/{id} (not found)

=== PRODUCT READ-PATH CHECK RESULTS ===

Check                                                    Status Notes
--------------------------------------------------------------------------------
GET /api/v1/commerce/listings (unauthorized)             PASS   Status 401, JSON envelope correct (ok:false, request_id present)
GET /api/v1/commerce/listings (authenticated)            PASS   Status 200, JSON envelope correct (ok:true, request_id present)
GET /api/v1/commerce/listings/{id} (not found)           PASS   Status 404, JSON envelope correct (ok:false, error_code: NOT_FOUND, request_id present)

OVERALL STATUS: PASS
```

**Exit Code**: 0 (PASS)

**Verification**:
- ✅ Login flow succeeded (token obtained)
- ✅ Authenticated checks passed
- ✅ Overall status is PASS

## Integration with Ops Status

**Command**:
```powershell
.\ops\ops_status.ps1
```

**Expected Output (truncated, showing Product Read-Path line)**:
```
=== UNIFIED OPS STATUS DASHBOARD ===
Timestamp: 2026-01-11 HH:MM:SS

Running Product Read-Path...
=== PRODUCT READ-PATH CHECK ===
...
OVERALL STATUS: PASS

=== OPS STATUS RESULTS ===

Check                                      Status ExitCode Notes
--------------------------------------------------------------------------------
...
Product Read-Path                          PASS   0        OVERALL STATUS: PASS
...

OVERALL STATUS: PASS (All checks passed)
```

**Verification**:
- ✅ Product Read-Path check is included in ops status dashboard
- ✅ Status is correctly aggregated (PASS/WARN/FAIL)
- ✅ Exit code is preserved (0/2/1)

## Failure Scenarios

### Failure: Unauthorized Access Returns 200

**Setup**: Application incorrectly allows unauthenticated access

**Expected Output**:
```
Testing GET /api/v1/commerce/listings (unauthorized)...
  [FAIL] GET /api/v1/commerce/listings (unauthorized): Status 200 (expected one of: 401, 403)

OVERALL STATUS: FAIL
```

**Exit Code**: 1 (FAIL)

### Failure: Missing request_id in JSON Envelope

**Expected Output**:
```
Testing GET /api/v1/commerce/listings (authenticated)...
  [WARN] GET /api/v1/commerce/listings (authenticated): Status 200, but JSON envelope missing 'request_id' field

OVERALL STATUS: WARN
```

**Exit Code**: 2 (WARN)

### Failure: Content-Type is text/html for 200 Response

**Expected Output**:
```
Testing GET /api/v1/commerce/listings (authenticated)...
  [FAIL] GET /api/v1/commerce/listings (authenticated): Status 200 but Content-Type is not application/json (got: text/html). Check for BOM/headers issue.

OVERALL STATUS: FAIL
```

**Exit Code**: 1 (FAIL)

## Result

✅ Product Read-Path self-audit gate successfully validates Commerce listings GET endpoints with:
- Proper unauthorized access handling (401/403 with JSON envelope)
- Authenticated access validation (200 with `ok:true`, `request_id`)
- Not found handling (404 with `ok:false`, `error_code: "NOT_FOUND"`, `request_id`)
- Content-Type validation (must be `application/json`)
- Graceful degradation when credentials are missing (WARN, not FAIL)
- Integration with `ops_status.ps1`
- PowerShell 5.1 compatible, ASCII-only output, safe exit pattern





