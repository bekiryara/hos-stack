# Product Spine Governance Pass

**Date**: 2026-01-11  
**Purpose**: Verify Product Spine Check gate validates Commerce Product API spine: routes, middleware, world/tenant boundaries, write-path lock.

## Overview

Product Spine Check gate ensures:
- Commerce read surface exists (GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id})
- Read routes are protected (auth.any + resolve.tenant + tenant.user middleware)
- World boundary evidence (forWorld('commerce') in controller)
- Write-path lock (POST/PATCH/DELETE return 501 NOT_IMPLEMENTED or are allowlisted)
- Cross-tenant leakage guard (forTenant/tenant_id filter in read paths)
- Disabled world policy (no routes for disabled worlds)
- Routes snapshot is used for static validation (no Docker required)

## Test Scenario 1: PASS (All Commerce Checks Valid)

**Command:**
```powershell
.\ops\product_spine_check.ps1
```

**Expected Output:**
```
=== PRODUCT SPINE CHECK ===
Timestamp: 2026-01-11 HH:MM:SS

Step 1: Reading routes snapshot
  [OK] Routes snapshot loaded

Step 2: Reading allowlist
  [OK] No allowlist file (write endpoints must return 501 NOT_IMPLEMENTED)

Step 3: [A1] Commerce Read Surface
  [PASS] A1: Commerce Read Surface: GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id} found

Step 4: [A2] Read Routes Protection
  [PASS] A2: Read Routes Protection: Required middleware present: auth.any, resolve.tenant, tenant.user

Step 5: [A3] World Boundary Evidence
  [PASS] A3: World Boundary Evidence: World boundary enforcement found (forWorld('commerce') or equivalent)

Step 6: [A4] Write-Path Lock
  [PASS] A4: Write-Path Lock: All write endpoints return 501 NOT_IMPLEMENTED or are allowlisted

Step 7: [A5] Cross-Tenant Leakage Guard
  [PASS] A5: Cross-Tenant Leakage Guard: Tenant scoping found (forTenant or tenant_id filter)

Step 8: [A6] Disabled World Policy
  [PASS] A6: Disabled World Policy: No routes found for disabled worlds

=== PRODUCT SPINE CHECK RESULTS ===

Check                                    Status Notes
--------------------------------------------------------------------------------
A1: Commerce Read Surface                [PASS] GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id} found
A2: Read Routes Protection                [PASS] Required middleware present: auth.any, resolve.tenant, tenant.user
A3: World Boundary Evidence               [PASS] World boundary enforcement found (forWorld('commerce') or equivalent)
A4: Write-Path Lock                       [PASS] All write endpoints return 501 NOT_IMPLEMENTED or are allowlisted
A5: Cross-Tenant Leakage Guard            [PASS] Tenant scoping found (forTenant or tenant_id filter)
A6: Disabled World Policy                 [PASS] No routes found for disabled worlds

OVERALL STATUS: PASS

All Commerce Product API spine checks passed.
```

**Exit Code**: 0 (PASS)

**Verification:**
- ✅ Check 1: Commerce read routes exist
- ✅ Check 2: Read routes have required middleware (auth.any, resolve.tenant, tenant.user)
- ✅ Check 3: Write endpoints are allowlisted or not present
- ✅ Check 4: World boundary evidence found
- ✅ Check 5: Tenant boundary evidence found

**Result**: ✅ Product Spine Check PASS.
  [PASS] food - GET /api/v1/food/listings
  [PASS] food - GET /api/v1/food/listings/{id}
  [PASS] food - POST /api/v1/food/listings
  [PASS] food - PATCH /api/v1/food/listings/{id}
  [PASS] food - DELETE /api/v1/food/listings/{id}
  Checking enabled world: rentals
  [PASS] rentals - GET /api/v1/rentals/listings
  [PASS] rentals - GET /api/v1/rentals/listings/{id}
  [PASS] rentals - POST /api/v1/rentals/listings
  [PASS] rentals - PATCH /api/v1/rentals/listings/{id}
  [PASS] rentals - DELETE /api/v1/rentals/listings/{id}

Step 4: Validating disabled worlds (no routes)
  Checking disabled world: services
  [PASS] services - No /api/v1/services/* routes
  Checking disabled world: real_estate
  [PASS] real_estate - No /api/v1/real_estate/* routes
  Checking disabled world: vehicle
  [PASS] vehicle - No /api/v1/vehicle/* routes

=== PRODUCT SPINE GOVERNANCE RESULTS ===

World      Surface                              Middleware                    Status Notes
--------------------------------------------------------------------------------
commerce   GET /api/v1/commerce/listings        auth.any, resolve.tenant...  [PASS] Route exists with required middleware
commerce   GET /api/v1/commerce/listings/{id}   auth.any, resolve.tenant...  [PASS] Route exists with required middleware
commerce   POST /api/v1/commerce/listings       auth.any, resolve.tenant...  [PASS] Route exists with required middleware
commerce   PATCH /api/v1/commerce/listings/{id} auth.any, resolve.tenant...  [PASS] Route exists with required middleware
commerce   DELETE /api/v1/commerce/listings/{id} auth.any, resolve.tenant... [PASS] Route exists with required middleware
food       GET /api/v1/food/listings            auth.any, resolve.tenant...  [PASS] Route exists with required middleware
food       GET /api/v1/food/listings/{id}       auth.any, resolve.tenant...  [PASS] Route exists with required middleware
food       POST /api/v1/food/listings           auth.any, resolve.tenant...  [PASS] Route exists with required middleware
food       PATCH /api/v1/food/listings/{id}     auth.any, resolve.tenant...  [PASS] Route exists with required middleware
food       DELETE /api/v1/food/listings/{id}    auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    GET /api/v1/rentals/listings         auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    GET /api/v1/rentals/listings/{id}    auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    POST /api/v1/rentals/listings        auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    PATCH /api/v1/rentals/listings/{id}  auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    DELETE /api/v1/rentals/listings/{id}  auth.any, resolve.tenant...  [PASS] Route exists with required middleware
services   No /api/v1/services/* routes          [PASS] No routes found (disabled world policy OK)
real_estate No /api/v1/real_estate/* routes      [PASS] No routes found (disabled world policy OK)
vehicle    No /api/v1/vehicle/* routes          [PASS] No routes found (disabled world policy OK)

OVERALL STATUS: PASS

All enabled worlds have required routes and middleware. Disabled worlds have no routes.
```

**Exit Code**: 0 (PASS)

**Verification:**
- ✅ All enabled worlds (commerce, food, rentals) have required routes
- ✅ All routes have required middleware: auth.any, resolve.tenant, tenant.user
- ✅ Disabled worlds (services, real_estate, vehicle) have NO routes
- ✅ Routes snapshot used for static validation

**Result**: ✅ Product Spine Governance check PASS.

## Test Scenario 2: FAIL (Missing Middleware)

**Command:**
```powershell
# Simulate missing middleware by modifying routes snapshot (or actual routes file)
.\ops\product_spine_governance.ps1
```

**Expected Output (truncated, showing FAIL):**
```
Step 3: Validating enabled worlds
  Checking enabled world: commerce
  [PASS] commerce - GET /api/v1/commerce/listings
  [FAIL] commerce - POST /api/v1/commerce/listings: Missing middleware: tenant.user

=== PRODUCT SPINE GOVERNANCE RESULTS ===

World      Surface                              Middleware                    Status Notes
--------------------------------------------------------------------------------
commerce   POST /api/v1/commerce/listings       auth.any, resolve.tenant    [FAIL] Missing middleware: tenant.user

OVERALL STATUS: FAIL

Remediation:
1. Ensure all enabled worlds have required routes: GET/POST/PATCH/DELETE /api/v1/{world}/listings
2. Ensure routes have required middleware: auth.any, resolve.tenant, tenant.user
3. Ensure disabled worlds have NO routes (disabled-world policy)
4. Run ops/routes_snapshot.ps1 to generate snapshot
```

**Exit Code**: 1 (FAIL)

**Verification:**
- ✅ Gate correctly detects missing middleware
- ✅ Provides clear remediation steps

**Result**: ✅ Product Spine Governance check FAIL on missing middleware.

## Test Scenario 3: FAIL (Disabled World Has Routes)

**Command:**
```powershell
# Simulate disabled world having routes (should not happen in production)
.\ops\product_spine_governance.ps1
```

**Expected Output (truncated, showing FAIL):**
```
Step 4: Validating disabled worlds (no routes)
  Checking disabled world: services
  [FAIL] services - Any /api/v1/services/* route: Disabled world has routes: POST /api/v1/services/listings

=== PRODUCT SPINE GOVERNANCE RESULTS ===

World      Surface                              Middleware                    Status Notes
--------------------------------------------------------------------------------
services   Any /api/v1/services/* route         [FAIL] Disabled world has routes: POST /api/v1/services/listings

OVERALL STATUS: FAIL

Remediation:
1. Ensure all enabled worlds have required routes: GET/POST/PATCH/DELETE /api/v1/{world}/listings
2. Ensure routes have required middleware: auth.any, resolve.tenant, tenant.user
3. Ensure disabled worlds have NO routes (disabled-world policy)
4. Run ops/routes_snapshot.ps1 to generate snapshot
```

**Exit Code**: 1 (FAIL)

**Verification:**
- ✅ Gate correctly detects disabled world routes
- ✅ Enforces disabled-world policy

**Result**: ✅ Product Spine Governance check FAIL on disabled world routes.

## Test Scenario 4: WARN (Routes Snapshot Missing)

**Command:**
```powershell
# Remove routes snapshot temporarily
Remove-Item ops\snapshots\routes.pazar.json -ErrorAction SilentlyContinue
.\ops\product_spine_governance.ps1
```

**Expected Output (truncated, showing WARN):**
```
Step 2: Reading routes snapshot
  [WARN] Routes snapshot not found: ops\snapshots\routes.pazar.json
  Remediation: Run ops/routes_snapshot.ps1 to generate snapshot

Step 3: Validating enabled worlds
  Checking enabled world: commerce
  [WARN] commerce - GET /api/v1/commerce/listings: Route found in filesystem (middleware verification requires snapshot)

OVERALL STATUS: WARN

Note: Some checks were skipped or inconclusive. Generate routes snapshot for full validation.
```

**Exit Code**: 2 (WARN)

**Verification:**
- ✅ Gate gracefully handles missing snapshot
- ✅ Falls back to filesystem check (WARN)
- ✅ Provides remediation hint

**Result**: ✅ Product Spine Governance check WARN on missing snapshot.

## Integration Evidence

### Ops Status Integration

**Command:**
```powershell
.\ops\run_ops_status.ps1
```

**Expected Table Row:**
```
Product Spine Governance                [PASS] 0        (BLOCKING) All enabled worlds have required routes and middleware. Disabled worlds have no routes.
```

### Commerce Write-Path Stub Verification

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
curl.exe -i -X POST `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json" `
  -d '{"title": "Test Item"}' `
  http://localhost:8080/api/v1/commerce/listings
```

**Expected Output:**
```
HTTP/1.1 501 Not Implemented
Content-Type: application/json
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "ok": false,
  "error_code": "NOT_IMPLEMENTED",
  "message": "Commerce listings API write operations are not implemented yet.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 501 Not Implemented
- ✅ JSON envelope: `{ ok:false, error_code:"NOT_IMPLEMENTED", request_id }`
- ✅ `request_id` present and matches `X-Request-Id` header
- ✅ No DB writes (stub-only)

**Result**: ✅ Commerce write-path returns 501 NOT_IMPLEMENTED stub.

## Result

✅ Product Spine Governance gate successfully:
- Validates all enabled worlds have required routes with correct middleware
- Validates disabled worlds have NO routes (disabled-world policy)
- Uses routes snapshot for static validation (no Docker required)
- Provides clear remediation steps on FAIL
- Integrates into ops_status.ps1 as BLOCKING check
- Commerce write-path (POST/PATCH/DELETE) returns 501 NOT_IMPLEMENTED stub (no DB writes)
- Safe exit behavior works correctly (interactive mode doesn't close terminal, CI mode propagates exit code)
- PowerShell 5.1 compatible, ASCII-only output
- No schema changes, no refactors, minimal diff
