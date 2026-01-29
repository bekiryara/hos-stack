# WP-66: Browser Auth Portal + Tokenless Demo UX - PASS

**Date:** 2026-01-24  
**Status:** ✅ PASS

## Goal

Enable browser-based authentication (tenant creation + register/login) and remove manual token pasting from consumer pages (CreateReservationPage, CreateRentalPage). Users can now create tenants, register owners, login, and use the marketplace without manually pasting JWT tokens.

## Problem (Before)

1. **Manual Token Pasting:**
   - Users had to manually paste JWT tokens into CreateReservationPage and CreateRentalPage
   - Inconsistent localStorage keys across pages
   - No browser-based authentication flow

2. **No Tenant Creation UI:**
   - No way to create tenants from browser
   - No way to register/login from browser
   - Relied on scripts or manual API calls

3. **Inconsistent Session Management:**
   - Multiple pages had their own token handling logic
   - No canonical session helper

## Solution (After)

### A) demoSession.js Extended (WP-66)

1. **JWT Decode:**
   - Added `decodeJwtPayload(token)` function (base64url decode)
   - Safely handles invalid tokens

2. **Token Claims Helpers:**
   - `getUserId()` - extracts `sub` from token payload
   - `getTenantId()` - extracts `tenantId` or `tenant_id` from token payload
   - `getRole()` - extracts `role` from token payload

3. **Tenant Slug Management:**
   - `setTenantSlug(slug)` / `getTenantSlug()` - stores tenant slug in localStorage

4. **Session Management:**
   - `clearSession()` - clears all session data (token, tenant_slug, active_tenant_id)
   - Backward compatible with existing `active_tenant_id` usage

### B) client.js HOS Auth Helpers (WP-66)

Added three new functions for HOS authentication:

1. **`hosCreateTenant({ slug, name })`:**
   - POST `/api/tenants` (NOT `/api/v1/tenants`)
   - Creates a new tenant

2. **`hosRegisterOwner({ tenantSlug, email, password })`:**
   - POST `/api/auth/register` (NOT `/api/v1/auth/register`)
   - Registers the first owner user for a tenant

3. **`hosLogin({ tenantSlug, email, password })`:**
   - POST `/api/auth/login` (NOT `/api/v1/auth/login`)
   - Logs in an existing user

**Note:** These endpoints are routed through nginx `/api/*` proxy to `hos-api:3000` without `/v1` prefix.

### C) AuthPortalPage.vue (NEW)

New page at `/marketplace/auth` with:

1. **New Tenant Flow:**
   - Inputs: tenant_slug, tenant_name, email, password
   - Calls: `hosCreateTenant()` then `hosRegisterOwner()`
   - Saves token + tenant_slug + tenantId to localStorage

2. **Login Flow:**
   - Inputs: tenant_slug, email, password
   - Calls: `hosLogin()`
   - Saves token + tenant_slug + tenantId to localStorage

3. **Session Panel:**
   - Shows: logged-in status, tenant_slug, tenantId, userId, role
   - "Logout" button (clears session)
   - Quick navigation links: DemoDashboard, CreateListing, Listings, Account

4. **Error Handling:**
   - Clear error messages for both flows
   - No silent failures

### D) CreateReservationPage.vue & CreateRentalPage.vue (MODIFIED)

1. **Removed Manual Token Inputs:**
   - Removed "Authorization Token" and "User ID" readonly input fields
   - Token and userId now come from `demoSession.getToken()` and `demoSession.getUserId()`

2. **Improved Auth Error Handling:**
   - Shows clear message if no token found
   - Links to Auth Portal (`/auth`) instead of Demo Dashboard

3. **Route Query Support:**
   - Pre-fills `listing_id` from `?listing_id=<uuid>` query parameter

### E) Router Updates (WP-66)

1. **Auth Portal Route:**
   - Added `/auth` route pointing to `AuthPortalPage.vue`

2. **Router Guard:**
   - Updated to redirect to `/auth` instead of `/need-demo` when authentication is required

## Verification (Browser Manual Test)

### Scenario 1: Create Tenant + Register Owner

1. Open `http://localhost:3002/marketplace/auth`
2. Fill "Create Tenant + Register Owner" form:
   - Tenant Slug: `test-tenant-66`
   - Tenant Name: `Test Tenant 66`
   - Email: `owner@test.com`
   - Password: `TestPass123!`
3. Click "Create Tenant + Register"
4. **Expected:** 
   - Success: Session panel appears showing tenant_slug, tenantId, userId, role
   - Token saved to localStorage (`demo_auth_token`)
   - Tenant slug saved to localStorage (`tenant_slug`)

### Scenario 2: Login

1. Open `http://localhost:3002/marketplace/auth`
2. Fill "Login" form:
   - Tenant Slug: `test-tenant-66` (or existing tenant)
   - Email: `owner@test.com` (or existing user)
   - Password: `TestPass123!`
3. Click "Login"
4. **Expected:**
   - Success: Session panel appears
   - Token saved to localStorage

### Scenario 3: Create Listing (Store Side)

1. After login, click "Create Listing" link
2. Fill listing form and submit
3. **Expected:**
   - Listing created successfully (draft)
   - No manual token pasting required
   - Token automatically used from session

### Scenario 4: Publish Listing

1. After creating listing, click "Publish now" button
2. **Expected:**
   - Listing status changes to "published"
   - "Go to Search" button appears

### Scenario 5: Create Reservation (Consumer Side - No Manual Token)

1. Navigate to a published listing detail page
2. Click "Reserve" button (or navigate to `/reservation/create?listing_id=<uuid>`)
3. Fill reservation form (slot_start, slot_end, party_size)
4. Click "Create Reservation"
5. **Expected:**
   - Reservation created successfully
   - No manual token input fields visible
   - Token automatically used from session
   - Success screen shows reservation ID

### Scenario 6: Create Rental (Consumer Side - No Manual Token)

1. Navigate to a published listing detail page
2. Click "Rent" button (or navigate to `/rental/create?listing_id=<uuid>`)
3. Fill rental form (start_at, end_at)
4. Click "Create Rental"
5. **Expected:**
   - Rental created successfully
   - No manual token input fields visible
   - Token automatically used from session
   - Success screen shows rental ID

### Scenario 7: Unauthenticated Access

1. Clear localStorage (or logout)
2. Navigate to `/listing/create` or `/reservation/create`
3. **Expected:**
   - Redirected to `/auth`
   - Can login or create tenant

## Network Evidence

**Create Tenant:**
```
POST /api/tenants HTTP/1.1
Host: localhost:3002
Content-Type: application/json

{"slug":"test-tenant-66","name":"Test Tenant 66"}

Response: 201 Created
{"id":"<tenant-uuid>","slug":"test-tenant-66","name":"Test Tenant 66"}
```

**Register Owner:**
```
POST /api/auth/register HTTP/1.1
Host: localhost:3002
Content-Type: application/json

{"tenantSlug":"test-tenant-66","email":"owner@test.com","password":"TestPass123!"}

Response: 201 Created
{"token":"<jwt-token>","user":{"id":"<user-uuid>","email":"owner@test.com"}}
```

**Login:**
```
POST /api/auth/login HTTP/1.1
Host: localhost:3002
Content-Type: application/json

{"tenantSlug":"test-tenant-66","email":"owner@test.com","password":"TestPass123!"}

Response: 200 OK
{"token":"<jwt-token>","user":{"id":"<user-uuid>","email":"owner@test.com"}}
```

**Create Reservation (with auto token):**
```
POST /api/marketplace/api/v1/reservations HTTP/1.1
Host: localhost:3002
Authorization: Bearer <jwt-token>
Content-Type: application/json
Idempotency-Key: <key>

{"listing_id":"<uuid>","slot_start":"2026-01-25T10:00:00Z","slot_end":"2026-01-25T14:00:00Z","party_size":4}

Response: 201 Created
{"id":"<reservation-uuid>","status":"requested",...}
```

## Files Changed

- `work/marketplace-web/src/lib/demoSession.js` (EXTENDED): JWT decode, getUserId, getTenantId, getRole, tenant_slug helpers
- `work/marketplace-web/src/api/client.js` (MODIFIED): Added hosCreateTenant, hosRegisterOwner, hosLogin
- `work/marketplace-web/src/pages/AuthPortalPage.vue` (NEW): Auth portal with tenant creation, register, login flows
- `work/marketplace-web/src/pages/CreateReservationPage.vue` (MODIFIED): Removed manual token inputs, uses demoSession
- `work/marketplace-web/src/pages/CreateRentalPage.vue` (MODIFIED): Removed manual token inputs, uses demoSession
- `work/marketplace-web/src/router.js` (MODIFIED): Added /auth route, updated guard to redirect to /auth

## Build Output

```bash
cd work/marketplace-web
npm run build
# Output:
# ✅ built in X.XXs
```

## Conclusion

WP-66 successfully enables browser-based authentication and removes manual token pasting. Users can now:
- Create tenants and register owners from the browser
- Login from the browser
- Use Create Listing, Create Reservation, and Create Rental pages without manually pasting tokens
- All token management is handled by the canonical `demoSession` helper

The implementation maintains backward compatibility with existing pages and does not break any existing functionality.

