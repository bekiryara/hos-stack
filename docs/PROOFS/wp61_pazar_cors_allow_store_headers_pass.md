# WP-61: Pazar CORS Allow Store Headers (Create Listing Unblock)
**Date:** 2025-01-24  
**Scope:** Fix CORS preflight to allow `X-Active-Tenant-Id` and `Idempotency-Key` headers for store-scope write operations

---

## Problem

Browser console showed CORS error:
```
Request header field x-active-tenant-id is not allowed by Access-Control-Allow-Headers
```

**Request:** `POST http://localhost:8080/api/v1/listings` from origin `http://localhost:3002`

**Root Cause:** Pazar CORS middleware did not include `X-Active-Tenant-Id` and `Idempotency-Key` in `Access-Control-Allow-Headers`.

---

## Changes

### 1. CORS Middleware Update

**File:** `work/pazar/app/Http/Middleware/Cors.php`

**Changes:**
- Added `ALLOWED_HEADERS` constant with deterministic ordering
- Included `X-Active-Tenant-Id` (required for store-scope write)
- Included `Idempotency-Key` (used by reservations and future UI flows)
- Applied to both normal response and preflight handler

**Before:**
```php
$response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept');
```

**After:**
```php
protected const ALLOWED_HEADERS = 'Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept, X-Active-Tenant-Id, Idempotency-Key';
// Used in both handle() and handlePreflight()
```

### 2. Security Edge Runbook Update

**File:** `docs/runbooks/security_edge.md`

**Changes:**
- Updated `Access-Control-Allow-Headers` documentation to include new headers

---

## Verification

### A. Preflight Test

**Command:**
```powershell
curl.exe -i -X OPTIONS "http://localhost:8080/api/v1/listings" `
  -H "Origin: http://localhost:3002" `
  -H "Access-Control-Request-Method: POST" `
  -H "Access-Control-Request-Headers: content-type,x-active-tenant-id"
```

**Expected Response:**
- HTTP 204 (No Content)
- `Access-Control-Allow-Headers` contains `X-Active-Tenant-Id` (case-insensitive)

**Result:** ✅ PASS
- Status: 204
- `Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept, X-Active-Tenant-Id, Idempotency-Key`

### B. Manual UI Test

**Steps:**
1. Open: `http://localhost:3002/marketplace/listing/create`
2. Fill form (Category, Title, Transaction Mode)
3. Submit draft listing

**Expected:**
- No CORS error in browser console
- Request reaches backend (success or validation error acceptable, but NOT CORS blocked)

**Result:** ✅ PASS
- No CORS error in console
- POST request reaches backend
- Backend returns response (401/422/201 depending on auth/validation)

### C. Gates

**Commands:**
```powershell
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Results:**
- ✅ secret_scan.ps1: PASS
- ✅ public_ready_check.ps1: PASS
- ✅ conformance.ps1: PASS

---

## Summary

**Fixed:**
- CORS preflight now allows `X-Active-Tenant-Id` header
- CORS preflight now allows `Idempotency-Key` header
- UI Create Listing no longer blocked by CORS

**Impact:**
- Marketplace UI can now make store-scope write requests (POST /api/v1/listings)
- CORS preflight passes for all required headers
- No breaking changes (only added headers to allowlist)

**Files Modified:**
- `work/pazar/app/Http/Middleware/Cors.php` (added store-scope headers)
- `docs/runbooks/security_edge.md` (updated documentation)

**Minimal Diff:**
- Single constant definition reused in both handlers
- No refactor, no redesign
- Deterministic header ordering

