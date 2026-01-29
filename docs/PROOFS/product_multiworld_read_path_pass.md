# Product Multi-World Read Path v2 - Proof of Acceptance

**Date:** 2026-01-15  
**Scope:** Food and Rentals read-path implementation + self-audit gate

## What Changed

### Files Created
1. `work/pazar/app/Http/Controllers/Api/Food/FoodListingController.php` - Food listing controller (GET implemented, writes 501 stub)
2. `work/pazar/app/Http/Controllers/Api/Rentals/RentalsListingController.php` - Rentals listing controller (GET implemented, writes 501 stub)
3. `ops/product_read_path_check.ps1` - Self-audit gate for read-path validation

### Files Updated
1. `work/pazar/routes/api.php` - Updated to use FoodListingController and RentalsListingController (removed aliases)
2. `docs/product/PRODUCT_API_SPINE.md` - Updated controller references, marked food/rentals GET as IMPLEMENTED
3. `ops/ops_status.ps1` - Added product_read_path check to registry

## Guarantees Preserved

✅ **Auth.any + resolve.tenant + tenant.user middleware**: All routes use the same middleware chain  
✅ **Tenant boundary**: `Listing::query()->forTenant($tenantId)` enforced in all controllers  
✅ **World boundary**: `->forWorld('food')` / `->forWorld('rentals')` enforced in all controllers  
✅ **Error contract**: Standard envelope (`ok:false`, `error_code`, `message`, `request_id`) preserved  
✅ **Request ID**: All responses include `request_id` in body and `X-Request-Id` header  
✅ **No cross-tenant leakage**: Cross-tenant access returns 404 NOT_FOUND (not 403)  
✅ **Write endpoints remain stubbed**: Food and Rentals write endpoints return 501 NOT_IMPLEMENTED

## Acceptance Evidence

### 1. Routes Reference Real Classes

**Verification:**
```bash
# Check controller files exist
ls work/pazar/app/Http/Controllers/Api/Food/FoodListingController.php
ls work/pazar/app/Http/Controllers/Api/Rentals/RentalsListingController.php

# Validate PHP syntax
php -l work/pazar/app/Http/Controllers/Api/Food/FoodListingController.php
php -l work/pazar/app/Http/Controllers/Api/Rentals/RentalsListingController.php
```

**Expected:** Files exist, PHP syntax valid (no errors)

### 2. Example Responses

#### Success Response (200 OK)

**Request:**
```bash
curl -i -X GET "http://localhost:8080/api/v1/food/listings" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-Id: $TENANT_ID"
```

**Response:**
```json
{
  "ok": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "title": "Food Listing",
        "description": "Description",
        "price_amount": 10000,
        "currency": "TRY",
        "status": "draft",
        "created_at": "2026-01-15T12:00:00Z",
        "updated_at": "2026-01-15T12:00:00Z"
      }
    ],
    "cursor": {
      "next": "base64-encoded-cursor"
    },
    "meta": {
      "count": 1,
      "limit": 20
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### Unauthorized Response (401 UNAUTHORIZED)

**Request:**
```bash
curl -i -X GET "http://localhost:8080/api/v1/food/listings" \
  -H "Accept: application/json"
```

**Response:**
```json
{
  "ok": false,
  "error_code": "UNAUTHORIZED",
  "message": "Unauthenticated.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### Not Found Response (404 NOT_FOUND)

**Request:**
```bash
curl -i -X GET "http://localhost:8080/api/v1/food/listings/cross-tenant-id" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-Id: $TENANT_ID"
```

**Response:**
```json
{
  "ok": false,
  "error_code": "NOT_FOUND",
  "message": "Listing not found.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### Write Endpoint Stub (501 NOT_IMPLEMENTED)

**Request:**
```bash
curl -i -X POST "http://localhost:8080/api/v1/food/listings" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-Id: $TENANT_ID" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test"}'
```

**Response:**
```json
{
  "ok": false,
  "error_code": "NOT_IMPLEMENTED",
  "message": "Write endpoints are not implemented yet.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 3. Self-Audit Gate

**Verification:**
```bash
# Run self-audit gate
.\ops\product_read_path_check.ps1
```

**Expected Output:**
```
=== PRODUCT READ PATH CHECK ===
[PASS] Found enabled worlds: commerce, food, rentals
[PASS] Routes snapshot found
[PASS] Found GET /api/v1/food/listings route
[PASS] Found GET /api/v1/food/listings/{id} route
[PASS] Found GET /api/v1/rentals/listings route
[PASS] Found GET /api/v1/rentals/listings/{id} route
[PASS] Controller exists and PHP syntax valid: FoodListingController.php
[PASS] Controller exists and PHP syntax valid: RentalsListingController.php
[WARN] Live checks skipped (credentials not provided)

OVERALL STATUS: WARN
```

## Summary

✅ Food and Rentals controllers created with correct class names  
✅ Routes updated to reference new controllers  
✅ Read-path implemented (index + show) with tenant/world boundaries  
✅ Write endpoints return 501 NOT_IMPLEMENTED (stub)  
✅ Self-audit gate created and integrated into ops_status  
✅ Documentation updated  
✅ No schema changes, no refactors, minimal diff
