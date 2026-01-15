# Product Core Query Pack v3 Pass

**Date:** 2026-01-15  
**Scope:** Unified DTO + Filters + Stable Cursor (RC0-safe, no schema changes)

## Evidence Items

### 1. Files Changed

**New Files:**
- `work/pazar/app/Support/Api/ListingReadDTO.php` - Unified DTO for listing responses
- `work/pazar/app/Support/Api/Cursor.php` - Cursor encode/decode helpers
- `work/pazar/app/Support/Api/ListingQuery.php` - Query builder with filters

**Updated Files:**
- `work/pazar/app/Http/Controllers/Api/Commerce/ListingController.php` - Uses DTO, Cursor, ListingQuery
- `work/pazar/app/Http/Controllers/Api/Food/FoodListingController.php` - Uses DTO, Cursor, ListingQuery
- `work/pazar/app/Http/Controllers/Api/Rentals/RentalsListingController.php` - Uses DTO, Cursor, ListingQuery
- `ops/product_read_path_check.ps1` - Added DTO import checks and documentation schema checks
- `docs/product/PRODUCT_API_SPINE.md` - Updated query params and response schema
- `CHANGELOG.md` - Added Product Core Query Pack v3 entry

### 2. Guarantees Preserved

✅ **Tenant Boundary:** All controllers still enforce `forTenant($tenantId)` scope  
✅ **World Boundary:** All controllers still enforce `forWorld('<world>')` scope  
✅ **No Schema Changes:** No migrations, no new tables, no model changes  
✅ **Error Contract:** Standard envelope (`ok:false`, `error_code`, `message`, `request_id`) preserved  
✅ **Request ID:** All responses include `request_id` and `X-Request-Id` header  
✅ **Middleware Contract:** Unchanged (`auth.any + resolve.tenant + tenant.user`)  
✅ **RC0 Gates:** All ops_status checks remain PASS/WARN (no regressions)

### 3. New Features

✅ **Unified DTO:** `ListingReadDTO::fromModel()` produces stable, world-agnostic payload  
✅ **Cursor Pagination:** Base64 JSON-encoded cursor with sort/dir/after fields  
✅ **Query Filters:** `q` (search), `status`, `from`/`to` (date range), `limit` (1-50)  
✅ **Stable Ordering:** `created_at DESC, id DESC` (deterministic cursor pagination)  
✅ **Invalid Cursor Handling:** Returns 400 INVALID_CURSOR with standard error envelope

### 4. Example Success Payload

**Request:**
```bash
GET /api/v1/commerce/listings?q=pizza&status=published&limit=10
Authorization: Bearer <token>
X-Tenant-Id: <tenant-id>
```

**Response (200 OK):**
```json
{
  "ok": true,
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "tenant_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "world": "commerce",
      "title": "Pizza Margherita",
      "description": "Classic Italian pizza",
      "price_amount": 5000,
      "currency": "TRY",
      "status": "published",
      "created_at": "2026-01-15T12:00:00Z",
      "updated_at": "2026-01-15T12:00:00Z"
    }
  ],
  "cursor": {
    "next": "eyJzb3J0IjoiY3JlYXRlZF9hdCIsImRpciI6ImRlc2MiLCJhZnRlciI6IjIwMjYtMDEtMTVUMTI6MDA6MDBaIzU1MGU4NDAwLWUyOWItNDFkNC1hNzE2LTQ0NjY1NTQ0MDAwMCJ9"
  },
  "meta": {
    "limit": 10
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Headers:**
```
HTTP/1.1 200 OK
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json
```

### 5. Example Invalid Cursor Error

**Request:**
```bash
GET /api/v1/commerce/listings?cursor=invalid-base64-string
Authorization: Bearer <token>
X-Tenant-Id: <tenant-id>
```

**Response (400 Bad Request):**
```json
{
  "ok": false,
  "error_code": "INVALID_CURSOR",
  "message": "Invalid cursor value",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Headers:**
```
HTTP/1.1 400 Bad Request
X-Request-Id: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json
```

### 6. Verification Commands

**Check DTO imports in controllers:**
```powershell
# Commerce
Select-String -Path "work\pazar\app\Http\Controllers\Api\Commerce\ListingController.php" -Pattern "ListingReadDTO|Cursor|ListingQuery"

# Food
Select-String -Path "work\pazar\app\Http\Controllers\Api\Food\FoodListingController.php" -Pattern "ListingReadDTO|Cursor|ListingQuery"

# Rentals
Select-String -Path "work\pazar\app\Http\Controllers\Api\Rentals\RentalsListingController.php" -Pattern "ListingReadDTO|Cursor|ListingQuery"
```

**Check documentation schema indicators:**
```powershell
Select-String -Path "docs\product\PRODUCT_API_SPINE.md" -Pattern "cursor.*next|meta.*limit|\bitems\b"
```

**Run ops gate:**
```powershell
.\ops\product_read_path_check.ps1
```

**Expected output:**
- Check 5: All controllers import DTO/Cursor/ListingQuery (PASS)
- Check 6: Documentation has response schema indicators (PASS)
- Overall status: PASS

## Summary

✅ Unified DTO created and integrated into all 3 world controllers  
✅ Cursor pagination helpers implemented (encode/decode with validation)  
✅ Query filters implemented (q, status, from/to, limit)  
✅ Response format updated to `{ ok:true, items:[...], cursor:{next}, meta:{limit} }`  
✅ Invalid cursor returns 400 INVALID_CURSOR with standard envelope  
✅ All guarantees preserved (tenant/world boundaries, error contract, request_id)  
✅ No schema changes, no refactors outside API read-path  
✅ Ops gate updated to validate DTO imports and documentation schema



