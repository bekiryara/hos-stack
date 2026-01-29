# WP-65: Account Portal Refresh Fix + Pazar Base URL Normalization - PASS

**Date:** 2026-01-24  
**HEAD Commit:** (to be filled after commit)  
**Status:** ✅ PASS

## Goal

Fix Account Portal 401 error by normalizing Base URL (detect HOS proxy URLs) and ensuring correct Pazar host usage. Improve error messages with hints. Add auto-fill from demo session.

## Problem (Before)

1. **401 Error on Refresh:**
   - Account Portal sometimes had `/api/marketplace` saved in localStorage (HOS proxy URL)
   - This caused 401 errors because proxy routes to HOS API, not Pazar
   - Account Portal should target Pazar directly at `http://localhost:8080`

2. **Poor Error Messages:**
   - Generic "Request failed" without hints
   - No endpoint information
   - No guidance on what's missing (token, tenant_id, etc.)

3. **No Auto-fill:**
   - Token had to be manually entered
   - No integration with demo session

## Solution (After)

### A) AccountPortalPage.vue Changes

1. **Base URL Normalization:**
   - Added `normalizePazarHost()` function that detects `/api` segments
   - Shows warning if URL contains `/api` (likely HOS proxy)
   - Auto-switches to default `http://localhost:8080` with warning
   - Added "Reset Base URL" button

2. **Token Normalization:**
   - Accepts both raw JWT and "Bearer <token>" format
   - Normalizes to raw JWT before sending (pazarApi adds Bearer prefix)

3. **Auto-fill from Demo Session:**
   - Auto-fills `authToken` from `demoSession.getToken()` if empty
   - Auto-fills `userId` from localStorage `accountPortal_userId` if empty
   - Auto-fills `tenantId` from localStorage `active_tenant_id` if empty (store mode)

4. **Improved Error Messages:**
   - Shows endpoint URL in error
   - Shows status-specific hints:
     - `401 → Token missing or invalid. Check Authorization Token field.`
     - `403 → Forbidden. Check tenant_id/user_id matches your token.`
     - `404 → Endpoint not found: <endpoint>`
     - `0 → Network error. Check Base URL and ensure Pazar service is running.`

5. **API Client Switch:**
   - Switched from `api` client (uses `/api/marketplace` proxy) to `pazarApi` (direct Pazar calls)
   - Uses `personalApi` and `storeApi` from `pazarApi.js`
   - Passes `baseHost` parameter to ensure correct Pazar host

### B) pazarApi.js Changes

1. **Base Host Parameter:**
   - `request()` function now accepts `baseHost` parameter
   - Builds URL as `${baseHost}/api${path}` (e.g., `http://localhost:8080/api/v1/orders`)

2. **Token Normalization:**
   - Exported `normalizeToken()` function
   - Removes "Bearer " prefix if present, then re-adds single Bearer prefix in headers

3. **API Functions Updated:**
   - `personalApi.getOrders/getRentals/getReservations` now accept `baseHost` as first parameter
   - `storeApi.getListings/getOrders/getRentals/getReservations` now accept `baseHost` as first parameter

### C) CreateReservationPage.vue & CreateRentalPage.vue

1. **Improved Error Messages:**
   - Added status-specific hints (401, 404, 422)
   - Better error display with hint section

## Verification

### Test 1: Base URL Normalization

**Before:**
- localStorage had `accountPortal_baseUrl = "/api/marketplace"`
- Refresh → 401 error

**After:**
- Warning shown: "This URL points to HOS API proxy. Pazar host should be http://localhost:8080..."
- Auto-switched to `http://localhost:8080`
- Refresh → Success (if token valid)

### Test 2: Personal Mode Refresh

**Steps:**
1. Set Mode = Personal
2. Enter User ID: `07d9f9b8-3efb-4612-93be-1c03964081c8`
3. Enter Token: `eyJhbGciOiJIUzI1NiIs...` (or "Bearer ...")
4. Click Refresh

**Expected:**
- ✅ No 401 error (if token valid)
- ✅ My Orders, My Rentals, My Reservations tables populated
- ✅ Empty state shown if no data

### Test 3: Store Mode Refresh

**Steps:**
1. Set Mode = Store
2. Enter Tenant ID: `7ef9bc88-2d20-45ae-9f16-525181aad657`
3. Enter Token (optional for GENESIS)
4. Click Refresh

**Expected:**
- ✅ No 401 error
- ✅ Store Listings, Store Orders, Store Rentals, Store Reservations tables populated
- ✅ Empty state shown if no data

### Test 4: Error Messages

**401 Error:**
- Shows: "Status: 401"
- Shows: "Endpoint: http://localhost:8080/api/v1/orders?buyer_user_id=..."
- Shows: "Hint: 401 → Token missing or invalid. Check Authorization Token field."

**Invalid Base URL:**
- Shows warning if URL contains `/api`
- Auto-switches to default
- "Reset Base URL" button available

### Test 5: Auto-fill

**Token:**
- If empty, auto-fills from `demoSession.getToken()`

**User ID:**
- If empty (Personal mode), auto-fills from localStorage `accountPortal_userId`

**Tenant ID:**
- If empty (Store mode), auto-fills from localStorage `active_tenant_id`

## Files Changed

- `work/marketplace-web/src/pages/AccountPortalPage.vue` (MODIFIED)
  - Added base URL normalization and warning
  - Added auto-fill from demo session
  - Improved error messages with hints
  - Switched to pazarApi client

- `work/marketplace-web/src/lib/pazarApi.js` (MODIFIED)
  - Added `baseHost` parameter to `request()` function
  - Exported `normalizeToken()` function
  - Updated API functions to accept `baseHost`

- `work/marketplace-web/src/pages/CreateReservationPage.vue` (MODIFIED)
  - Improved error messages with hints

- `work/marketplace-web/src/pages/CreateRentalPage.vue` (MODIFIED)
  - Improved error messages with hints

## No Regression

- ✅ Create Listing still works (uses existing `api` client with `/api/marketplace` proxy)
- ✅ Publish still works
- ✅ Search navigation still works
- ✅ No hardcoded IDs
- ✅ No duplicated fetch logic (centralized in pazarApi)

## Acceptance Criteria

✅ Account Portal Refresh no longer returns 401 if token is present  
✅ Base URL normalization detects HOS proxy URLs and warns user  
✅ Auto-fill token/userId/tenantId from demo session  
✅ Error messages show endpoint + status + hints  
✅ Personal mode requires token, sends Authorization header  
✅ Store mode requires tenantId, sends X-Active-Tenant-Id header  
✅ No regression in Create Listing / Publish / Search flows  
✅ Build passes without errors  

## Conclusion

✅ **PASS**: Account Portal now correctly targets Pazar host (`http://localhost:8080`) instead of HOS proxy. Base URL normalization prevents proxy URL usage. Error messages provide actionable hints. Auto-fill reduces manual entry. All acceptance criteria met.

