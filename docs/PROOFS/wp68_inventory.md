# WP-68 Inventory: Token/User Storage and Header Injection Points

## Canonical Storage Keys

- **Token Key**: `demo_auth_token` (localStorage)
  - Location: `work/marketplace-web/src/lib/demoSession.js`
  - Function: `getToken()` returns raw JWT token
  - Function: `getBearerToken()` returns "Bearer <token>" format

- **User Key**: `demo_user` (localStorage)
  - Location: `work/marketplace-web/src/lib/demoSession.js`
  - Function: `getUser()` returns parsed user object { email, id? }
  - Stored as JSON string

- **Active Tenant Key**: `active_tenant_id` (localStorage)
  - Location: `work/marketplace-web/src/lib/demoSession.js`
  - Function: `getActiveTenantId()` / `setActiveTenantId()`

## Header Injection Points

### Current State

1. **`work/marketplace-web/src/lib/api.js`** - `apiRequest()`
   - Auto-attaches Authorization header when `requireAuth=true`
   - Uses `getBearerToken()` from `demoSession.js`
   - Used for HOS API calls (`/api/v1/*`)

2. **`work/marketplace-web/src/api/client.js`** - `hosApiRequest()`
   - **ISSUE**: Does NOT auto-attach Authorization header
   - Used by `api.getMyOrders()`, `api.getMyRentals()`, `api.getMyReservations()`
   - Currently requires manual token passing

3. **`work/marketplace-web/src/lib/pazarApi.js`** - `request()`
   - Accepts `token` parameter and normalizes it
   - Adds Authorization header if token provided
   - Used by `personalApi` and `storeApi` helpers

### Pages Calling /api/v1/me/*

1. **AccountPortalPage.vue**
   - Calls `api.getMyOrders(userId, token)` - manual token passing
   - Calls `api.getMyRentals(userId, token)` - manual token passing
   - Calls `api.getMyReservations(userId, token)` - manual token passing
   - Also calls `apiRequest('/v1/me')` for user refresh

2. **CreateReservationPage.vue**
   - Calls `api.createReservation(payload, token, userId)` - manual token passing

3. **CreateRentalPage.vue**
   - Calls `api.createRental(payload, token, userId)` - manual token passing

## Root Cause of 401 Errors

- `hosApiRequest()` in `client.js` does not auto-attach Authorization header
- Pages manually pass tokens, but if token is missing or wrong key is read, 401 occurs
- No single source of truth for token retrieval in API calls

## Solution

- Update `hosApiRequest()` to auto-attach Authorization header from `getBearerToken()`
- Update all API methods in `client.js` to use auto-attached headers
- Remove manual token passing from pages
- Ensure all API calls go through unified gateway

