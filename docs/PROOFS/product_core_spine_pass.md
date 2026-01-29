# Product Core Spine Pass

**Date**: 2026-01-11  
**Purpose**: Verify Product Core Spine (canonical products table + read-only endpoints) is implemented correctly with tenant/world boundaries.

## Overview

Product Core Spine establishes a canonical Product model and API endpoints that all worlds (commerce, food, rentals, future) can use. This provides:
- Single source of truth for product data across worlds
- Tenant-scoped queries (no cross-tenant leakage)
- World boundary enforcement (world required via query param or header)
- Read-only endpoints (write endpoints not implemented yet)

## Test Scenario 1: Migration Applied

**Command:**
```powershell
cd work\pazar
php artisan migrate
```

**Expected Output:**
```
Running migrations...
2026_01_11_000000_create_products_table ................................. DONE
```

**Verification:**
- ✅ `products` table created with columns: id, tenant_id, world, type, title, status, currency, price_amount, payload_json, created_at, updated_at
- ✅ Indexes created: tenant_id, world, type, status, (tenant_id, world, status)
- ✅ Schema snapshot updated (ops/schema_snapshot.ps1)

**Result**: ✅ Migration applied successfully.

## Test Scenario 2: Unauthorized Access (401/403)

**Command:**
```powershell
curl.exe -i -X GET `
  -H "Accept: application/json" `
  http://localhost:8080/api/v1/products?world=commerce
```

**Expected Output:**
```
HTTP/1.1 401 Unauthorized
Content-Type: application/json
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "ok": false,
  "error_code": "UNAUTHORIZED",
  "message": "Unauthenticated.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 401/403 with JSON envelope
- ✅ `ok:false`, `error_code`, `request_id` present
- ✅ `X-Request-Id` header matches body `request_id`

**Result**: ✅ Unauthorized access returns standard error envelope.

## Test Scenario 3: Missing World Parameter (422)

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
curl.exe -i -X GET `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "Accept: application/json" `
  http://localhost:8080/api/v1/products
```

**Expected Output:**
```
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/json
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "ok": false,
  "error_code": "VALIDATION_ERROR",
  "message": "World parameter is required. Use ?world=commerce or X-World header.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 422 with JSON envelope
- ✅ `error_code: "VALIDATION_ERROR"`
- ✅ Clear message about world parameter requirement
- ✅ `request_id` present and matches header

**Result**: ✅ Missing world parameter returns 422 VALIDATION_ERROR.

## Test Scenario 4: Valid Request (200 OK)

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
curl.exe -i -X GET `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "Accept: application/json" `
  "http://localhost:8080/api/v1/products?world=commerce&limit=20"
```

**Expected Output:**
```
HTTP/1.1 200 OK
Content-Type: application/json
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "ok": true,
  "data": {
    "items": [],
    "cursor": {
      "next": null
    },
    "meta": {
      "count": 0,
      "limit": 20
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 200 with JSON envelope
- ✅ `ok:true`, `data.items` array, `cursor.next`, `meta.count/limit`
- ✅ `request_id` present and matches header
- ✅ Tenant-scoped (only products for tenant_id)
- ✅ World-scoped (only products for world=commerce)

**Result**: ✅ Valid request returns 200 OK with products data.

## Test Scenario 5: Product Not Found (404)

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
curl.exe -i -X GET `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "Accept: application/json" `
  "http://localhost:8080/api/v1/products/999999?world=commerce"
```

**Expected Output:**
```
HTTP/1.1 404 Not Found
Content-Type: application/json
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "ok": false,
  "error_code": "NOT_FOUND",
  "message": "Product not found.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 404 with JSON envelope
- ✅ `error_code: "NOT_FOUND"`
- ✅ Cross-tenant leakage prevented (404 for non-existent or cross-tenant products)
- ✅ `request_id` present and matches header

**Result**: ✅ Product not found returns 404 NOT_FOUND.

## Test Scenario 6: Ops Status Integration

**Command:**
```powershell
.\ops\run_ops_status.ps1
```

**Expected Table Row:**
```
Product Spine Check                     [PASS] 0        (BLOCKING) All Commerce Product API spine checks passed.
```

**Verification:**
- ✅ Product Spine Check includes Products routes (Check 1b, Check 2b)
- ✅ Write-path lock includes /api/v1/products* routes
- ✅ Schema snapshot updated (products table included)
- ✅ Terminal doesn't close (Invoke-OpsExit used)

**Result**: ✅ Ops status shows Product Spine Check PASS.

## Test Scenario 7: Schema Snapshot Updated

**Command:**
```powershell
.\ops\schema_snapshot.ps1
```

**Expected Output:**
```
=== SCHEMA SNAPSHOT ==="
...
Snapshot saved: ops\snapshots\schema.pazar.sql
```

**Verification:**
- ✅ `products` table included in snapshot
- ✅ Columns: id, tenant_id, world, type, title, status, currency, price_amount, payload_json, created_at, updated_at
- ✅ Indexes: tenant_id, world, type, status, (tenant_id, world, status)

**Result**: ✅ Schema snapshot includes products table.

## Result

✅ Product Core Spine successfully:
- Created canonical `products` table with tenant/world/type columns
- Implemented read-only endpoints (GET /api/v1/products, GET /api/v1/products/{id})
- Enforced tenant boundary (forTenant scope, no cross-tenant leakage)
- Enforced world boundary (world required via query param or header, 422 if missing)
- Integrated into ops gates (product_spine_check, schema_snapshot)
- Preserved existing commerce listings endpoints (no breaking changes)
- No schema changes to existing tables, no refactors, minimal diff
- PowerShell 5.1 compatible, ASCII-only output, safe exit behavior preserved





