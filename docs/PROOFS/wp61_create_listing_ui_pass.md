# WP-61: Marketplace Create Listing UI Auth Wiring (PASS)
**Date:** 2025-01-24  
**Scope:** Fix 401 Unauthorized by wiring demo token to Create Listing POST request

---

## Problem (Before)
- Browser console showed: `401 Unauthorized / "Unauthenticated."` when POSTing to `http://localhost:8080/api/v1/listings`
- Tenant ID was auto-filled, but request lacked `Authorization` header
- CORS preflight passed (WP-61 CORS fix), but auth.any middleware rejected request

---

## Solution (After)
- `createListing()` function now accepts `authToken` parameter
- `CreateListingPage.vue` reads demo token via `getToken()` and passes it to `createListing()`
- `buildPersonaHeaders()` sets `Authorization: Bearer <token>` header when token exists
- Router guard added: `/listing/create` route requires `requiresAuth: true` (redirects to `/need-demo` if no token)

---

## Changes Made

### 1. `work/marketplace-web/src/api/client.js`
- Extended `createListing(data, tenantId, authToken)` to accept `authToken` parameter
- Pass `authToken` to `buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken })`
- `buildPersonaHeaders()` already supports `authToken` for STORE persona (optional Authorization header)

### 2. `work/marketplace-web/src/pages/CreateListingPage.vue`
- Added token check in `handleSubmit()`:
  ```javascript
  const demoToken = getToken();
  if (!demoToken) {
    this.error = { message: 'Demo session yok. /demo sayfasından oturum başlat.', status: 401 };
    return;
  }
  ```
- Pass `demoToken` to `api.createListing(payload, tenantId, demoToken)`

### 3. `work/marketplace-web/src/router.js`
- Added `meta: { requiresAuth: true }` to:
  - `/listing/create` (CreateListingPage)
  - `/reservation/create` (CreateReservationPage)
  - `/rental/create` (CreateRentalPage)
- Router guard redirects to `/need-demo` if token missing

---

## Verification Steps

### A) Manual UI Test
1. **Start demo session:**
   - Open: `http://localhost:3002/demo` (or HOS Web demo panel)
   - Click "Enter Demo" → JWT token stored in `localStorage['demo_auth_token']`

2. **Navigate to Create Listing:**
   - Go to: `http://localhost:3002/marketplace/listing/create`
   - Confirm: Form loads, tenant ID auto-filled (if active tenant set)

3. **Create listing:**
   - Fill form: Category, Title, Transaction Mode (at least one)
   - Click "Create Listing"
   - **Expected:** Success message with listing ID (no 401 error)
   - **Browser console:** No CORS/401 errors

4. **Verify request headers (Network tab):**
   - `POST http://localhost:8080/api/v1/listings`
   - Headers:
     - ✅ `Authorization: Bearer <token>` (masked: `...xxxxxx`)
     - ✅ `X-Active-Tenant-Id: <tenant_id>`
     - ✅ `Idempotency-Key: <uuid>`
     - ✅ `Content-Type: application/json`

5. **Verify response:**
   - Status: `201 Created` or `200 OK`
   - Body: `{ "id": "...", "status": "draft", ... }`

### B) Token Missing Test
1. Clear `localStorage['demo_auth_token']` (or open incognito)
2. Navigate to: `http://localhost:3002/marketplace/listing/create`
3. **Expected:** Router guard redirects to `/need-demo` (or form shows error if guard bypassed)

---

## Test Results

**Date:** 2025-01-24  
**Environment:** Local development (docker compose)

### Before Fix:
- ❌ POST `/api/v1/listings` → 401 Unauthorized
- ❌ Console error: "Unauthenticated."
- ❌ No Authorization header in request

### After Fix:
- ✅ POST `/api/v1/listings` → 201 Created
- ✅ Authorization header present: `Bearer <token>` (masked: `...xxxxxx`)
- ✅ Listing created successfully
- ✅ No CORS/401 errors in console

---

## Key Findings

1. **Token Flow:**
   - `getToken()` reads from `localStorage['demo_auth_token']`
   - Token passed to `createListing()` → `buildPersonaHeaders()` → `Authorization` header

2. **Backend Middleware Chain:**
   - `PersonaScope:store` → ✅ X-Active-Tenant-Id present
   - `auth.any` → ✅ Authorization header present → JWT validation → ✅ PASS
   - `tenant.scope` → ✅ Membership validation → ✅ PASS
   - Handler → ✅ Create listing → 201 Created

3. **Router Guard:**
   - `/listing/create` requires `requiresAuth: true`
   - Redirects to `/need-demo` if token missing
   - Provides consistent UX for write operations

---

## Conclusion
✅ **PASS** - Create Listing now works end-to-end with demo token authentication. The 401 Unauthorized error is resolved by wiring the demo token to the `Authorization` header in the POST request.

