# Product API Spine Consistency Pass

**Date**: 2026-01-11  
**Purpose**: Verify Product API Spine is consistent across all enabled worlds (commerce, food, rentals) with tenant/world scoping, no 404/500 drift, and proper error contracts.

## Overview

Product API Spine Consistency ensures:
- All enabled worlds (commerce, food, rentals) have GET `/api/v1/{world}/listings` and GET `/api/v1/{world}/listings/{id}` routes
- All routes are tenant-scoped (auth.any + resolve.tenant + tenant.user middleware)
- World defaults are set on routes (WorldResolver can set ctx.world correctly)
- Controllers use ListingReadModel or Listing model with forTenant/forWorld scopes
- Write endpoints return 501 NOT_IMPLEMENTED (still guarded)
- No 404s for defined endpoints
- No cross-tenant leakage (404 for foreign tenant)

## Test Scenario 1: Unauthorized GET Returns 401/403 with Envelope

**Command:**
```bash
curl -i http://localhost:8080/api/v1/commerce/listings
curl -i http://localhost:8080/api/v1/food/listings
curl -i http://localhost:8080/api/v1/rentals/listings
```

**Expected Output:**
```
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{"ok":false,"error_code":"UNAUTHORIZED","message":"Unauthenticated.","request_id":"..."}
```

**Or:**
```
HTTP/1.1 403 Forbidden
Content-Type: application/json

{"ok":false,"error_code":"FORBIDDEN","message":"Tenant context missing.","request_id":"..."}
```

**Verification:**
- ✅ All enabled worlds return 401/403 (NOT 404)
- ✅ Response includes JSON envelope with `ok:false`, `error_code`, `message`, `request_id`
- ✅ No 500 errors

**Result**: ✅ Unauthorized GET returns 401/403 with envelope for all enabled worlds.

## Test Scenario 2: With X-Tenant-Id + Valid Auth, GET Returns 200 ok:true

**Command:**
```bash
# After acquiring token via login
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" http://localhost:8080/api/v1/commerce/listings
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" http://localhost:8080/api/v1/food/listings
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" http://localhost:8080/api/v1/rentals/listings
```

**Expected Output:**
```
HTTP/1.1 200 OK
Content-Type: application/json

{"ok":true,"data":{"items":[...],"cursor":{"next":null},"meta":{"count":0,"limit":20}},"request_id":"..."}
```

**Verification:**
- ✅ All enabled worlds return 200 OK
- ✅ Response includes JSON envelope with `ok:true`, `data.items` array, `request_id`
- ✅ No 404 errors for defined endpoints

**Result**: ✅ Authenticated GET returns 200 ok:true for all enabled worlds.

## Test Scenario 3: Cross-Tenant Access Returns 404 (No Leakage)

**Command:**
```bash
# With Tenant A token, try to access Tenant B listing
curl -i -H "Authorization: Bearer $TENANT_A_TOKEN" -H "X-Tenant-Id: $TENANT_A_ID" http://localhost:8080/api/v1/commerce/listings/$TENANT_B_LISTING_ID
```

**Expected Output:**
```
HTTP/1.1 404 Not Found
Content-Type: application/json

{"ok":false,"error_code":"NOT_FOUND","message":"Listing not found.","request_id":"..."}
```

**Verification:**
- ✅ Cross-tenant access returns 404 NOT_FOUND (NOT 200 with data)
- ✅ Response includes JSON envelope with `ok:false`, `error_code: "NOT_FOUND"`, `request_id`
- ✅ No data leakage (no listing data in response)

**Result**: ✅ Cross-tenant isolation enforced (404 for foreign tenant).

## Test Scenario 4: POST Returns 501 NOT_IMPLEMENTED (Still Guarded)

**Command:**
```bash
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" -H "Content-Type: application/json" -X POST http://localhost:8080/api/v1/commerce/listings -d '{}'
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" -H "Content-Type: application/json" -X POST http://localhost:8080/api/v1/food/listings -d '{}'
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" -H "Content-Type: application/json" -X POST http://localhost:8080/api/v1/rentals/listings -d '{}'
```

**Expected Output:**
```
HTTP/1.1 501 Not Implemented
Content-Type: application/json

{"ok":false,"error_code":"NOT_IMPLEMENTED","message":"Commerce listings API write operations are not implemented yet.","request_id":"..."}
```

**Verification:**
- ✅ All enabled worlds return 501 NOT_IMPLEMENTED for POST
- ✅ Response includes JSON envelope with `ok:false`, `error_code: "NOT_IMPLEMENTED"`, `request_id`
- ✅ Endpoint is still guarded (requires auth + tenant)

**Result**: ✅ Write endpoints return 501 NOT_IMPLEMENTED (still guarded).

## Test Scenario 5: No 404s for Defined Endpoints

**Command:**
```bash
# Test all enabled world endpoints exist (not 404)
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" http://localhost:8080/api/v1/commerce/listings
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" http://localhost:8080/api/v1/food/listings
curl -i -H "Authorization: Bearer $TOKEN" -H "X-Tenant-Id: $TENANT_ID" http://localhost:8080/api/v1/rentals/listings
```

**Expected Output:**
```
HTTP/1.1 200 OK
...
```

**Must NOT be:**
```
HTTP/1.1 404 Not Found
```

**Verification:**
- ✅ All enabled world endpoints return 200/401/403/501 (NOT 404)
- ✅ No 404 errors for defined endpoints

**Result**: ✅ No 404s for defined endpoints.

## Test Scenario 6: Product Spine Check Validates All Enabled Worlds

**Command:**
```powershell
.\ops\product_spine_check.ps1
```

**Expected Output:**
```
Step 8: [Check 6] All Enabled Worlds READ Routes
  [OK] Found 3 enabled world(s): commerce, food, rentals
  [PASS] Check 6: All Enabled Worlds READ Routes - All enabled worlds (commerce, food, rentals) have GET /listings and GET /listings/{id} routes

OVERALL STATUS: PASS
```

**Verification:**
- ✅ Product spine check validates all enabled worlds
- ✅ Check 6 (All Enabled Worlds READ Routes) passes
- ✅ All worlds (commerce, food, rentals) have required routes

**Result**: ✅ Product spine check validates all enabled worlds.

## Test Scenario 7: World Defaults Set on Routes

**Command:**
```bash
# Check routes snapshot or route list
php artisan route:list | grep "api/v1/commerce\|api/v1/food\|api/v1/rentals"
```

**Expected Output:**
```
GET|HEAD  api/v1/commerce/listings  ...  Api\Commerce\ListingController@index
GET|HEAD  api/v1/commerce/listings/{id}  ...  Api\Commerce\ListingController@show
GET|HEAD  api/v1/food/listings  ...  Api\Food\ListingController@index
GET|HEAD  api/v1/food/listings/{id}  ...  Api\Food\ListingController@show
GET|HEAD  api/v1/rentals/listings  ...  Api\Rentals\ListingController@index
GET|HEAD  api/v1/rentals/listings/{id}  ...  Api\Rentals\ListingController@show
```

**Verification:**
- ✅ All enabled world routes exist
- ✅ Routes have world defaults set (via ->defaults('world', 'commerce') etc.)

**Result**: ✅ World defaults set on routes.

## Result

✅ Product API Spine Consistency successfully:
- All enabled worlds (commerce, food, rentals) have GET /listings and GET /listings/{id} routes
- All routes are tenant-scoped (auth.any + resolve.tenant + tenant.user middleware)
- World defaults are set on routes (WorldResolver can set ctx.world correctly)
- ListingReadModel supports forTenant/forWorld methods
- Controllers use Listing model with forTenant/forWorld scopes
- Write endpoints return 501 NOT_IMPLEMENTED (still guarded)
- No 404s for defined endpoints
- Cross-tenant isolation enforced (404 for foreign tenant)
- Product spine check validates all enabled worlds
- No 500 errors (storage self-heal prevents Monolog permission errors)



