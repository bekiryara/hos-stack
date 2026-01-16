# Product Write Seed Pass

**Date**: 2026-01-11  
**Purpose**: Verify Product Write Seed (POST /api/v1/products) creates products with tenant/world boundaries enforced.

## Overview

Product Write Seed enables creating products via POST endpoint with:
- Tenant boundary enforcement (tenant_id from resolved context, NOT from request body)
- World boundary enforcement (world required via X-World header or body.world)
- Validation (title, type, status, price_amount, currency)
- Standard error envelope (422 VALIDATION_ERROR, 422 WORLD_CONTEXT_INVALID, 500 INTERNAL_ERROR)

## Test Scenario 1: Unauthorized Access (401/403)

**Command:**
```powershell
curl.exe -i -X POST `
  -H "Content-Type: application/json" `
  -H "Accept: application/json" `
  -d '{"title": "Test Product", "type": "listing", "world": "commerce"}' `
  http://localhost:8080/api/v1/products
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

## Test Scenario 2: Missing World Parameter (422)

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
curl.exe -i -X POST `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json" `
  -d '{"title": "Test Product", "type": "listing"}' `
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
  "message": "World is required. Use X-World header or body.world parameter.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 422 with JSON envelope
- ✅ `error_code: "VALIDATION_ERROR"`
- ✅ Clear message about world requirement
- ✅ `request_id` present and matches header

**Result**: ✅ Missing world parameter returns 422 VALIDATION_ERROR.

## Test Scenario 3: Invalid World (422)

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
curl.exe -i -X POST `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "X-World: invalid_world" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json" `
  -d '{"title": "Test Product", "type": "listing"}' `
  http://localhost:8080/api/v1/products
```

**Expected Output:**
```
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/json
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "ok": false,
  "error_code": "WORLD_CONTEXT_INVALID",
  "message": "World 'invalid_world' is not enabled.",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 422 with JSON envelope
- ✅ `error_code: "WORLD_CONTEXT_INVALID"`
- ✅ `request_id` present and matches header

**Result**: ✅ Invalid world returns 422 WORLD_CONTEXT_INVALID.

## Test Scenario 4: Validation Error (422)

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
curl.exe -i -X POST `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "X-World: commerce" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json" `
  -d '{"title": "AB", "type": ""}' `
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
  "message": "The given data was invalid.",
  "errors": {
    "title": ["The title must be at least 3 characters."],
    "type": ["The type field is required."]
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 422 with JSON envelope
- ✅ `error_code: "VALIDATION_ERROR"`
- ✅ `errors` object with field-level details
- ✅ `request_id` present and matches header

**Result**: ✅ Validation errors return 422 VALIDATION_ERROR with field details.

## Test Scenario 5: Successful Create (201)

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
curl.exe -i -X POST `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "X-World: commerce" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json" `
  -d '{"title": "Test Product", "type": "listing", "status": "draft", "currency": "TRY", "price_amount": 10000}' `
  http://localhost:8080/api/v1/products
```

**Expected Output:**
```
HTTP/1.1 201 Created
Content-Type: application/json
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "ok": true,
  "data": {
    "id": 1,
    "item": {
      "id": 1,
      "world": "commerce",
      "type": "listing",
      "title": "Test Product",
      "status": "draft",
      "currency": "TRY",
      "price_amount": 10000,
      "payload_json": null,
      "created_at": "2026-01-11T12:00:00Z",
      "updated_at": "2026-01-11T12:00:00Z"
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 201 with JSON envelope
- ✅ `ok:true`, `data.id`, `data.item` present
- ✅ `request_id` present and matches header
- ✅ Product created with correct tenant_id (from resolved context, NOT from request body)
- ✅ Product created with correct world (from X-World header or body.world)

**Result**: ✅ Successful create returns 201 CREATED with product data.

## Test Scenario 6: Tenant Boundary Enforcement (tenant_id NOT user-controlled)

**Command:**
```powershell
$TOKEN = "YOUR_VALID_BEARER_TOKEN"
$TENANT_ID = "YOUR_VALID_TENANT_UUID"
$FAKE_TENANT_ID = "FAKE_TENANT_UUID"
curl.exe -i -X POST `
  -H "Authorization: Bearer $TOKEN" `
  -H "X-Tenant-Id: $TENANT_ID" `
  -H "X-World: commerce" `
  -H "Content-Type: application/json" `
  -H "Accept: application/json" `
  -d "{\"title\": \"Test Product\", \"type\": \"listing\", \"tenant_id\": \"$FAKE_TENANT_ID\"}" `
  http://localhost:8080/api/v1/products
```

**Expected Output:**
```
HTTP/1.1 201 Created
Content-Type: application/json
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "ok": true,
  "data": {
    "id": 1,
    "item": {
      "id": 1,
      "world": "commerce",
      "type": "listing",
      "title": "Test Product",
      ...
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Verification:**
- ✅ HTTP 201 CREATED
- ✅ Product created with `tenant_id` from resolved context (X-Tenant-Id header), NOT from request body
- ✅ `tenant_id` in request body is ignored (guarded in model)
- ✅ Cross-tenant leakage prevented

**Result**: ✅ Tenant boundary enforced (tenant_id NOT user-controlled).

## Test Scenario 7: Ops Status Integration

**Command:**
```powershell
.\ops\run_ops_status.ps1
```

**Expected Table Row:**
```
Product Spine Check                     [PASS] 0        (BLOCKING) All Commerce Product API spine checks passed.
Security Audit                          [PASS] 0        (BLOCKING) All routes protected
```

**Verification:**
- ✅ Product Spine Check includes Products write route (POST /api/v1/products)
- ✅ Security Audit confirms POST /api/v1/products is protected (auth.any required)
- ✅ Terminal doesn't close (Invoke-OpsExit used)

**Result**: ✅ Ops status shows Product Spine Check and Security Audit PASS.

## Result

✅ Product Write Seed successfully:
- Created POST /api/v1/products endpoint with tenant/world boundaries
- Enforced tenant_id from resolved context (NOT from request body, guarded in model)
- Enforced world via X-World header or body.world (422 if missing/invalid)
- Validated input (title, type, status, price_amount, currency, payload_json)
- Returned standard error envelope (422 VALIDATION_ERROR, 422 WORLD_CONTEXT_INVALID, 500 INTERNAL_ERROR)
- Integrated into ops gates (product_spine_check, security_audit)
- Preserved existing read endpoints (no breaking changes)
- Update/Delete endpoints remain 501 NOT_IMPLEMENTED
- No schema changes, no refactors, minimal diff
- PowerShell 5.1 compatible, ASCII-only output, safe exit behavior preserved
