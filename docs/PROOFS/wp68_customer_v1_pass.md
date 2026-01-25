# WP-68: Customer V1 — Single Auth, Single Session, Zero-401 Account, Clean UX

**Status:** ✅ PASS  
**Date:** 2025-01-XX  
**Author:** WP-68 Implementation

## Summary

Implemented professional customer-side authentication and account management with zero 401 errors. Single source of truth for session management, automatic Authorization header attachment, and clean UX throughout.

## Endpoints Tested

### Authentication
- ✅ `POST /api/v1/auth/register` (public customer, no tenantSlug)
- ✅ `POST /api/v1/auth/login` (public customer, no tenantSlug)
- ✅ `GET /api/v1/me` (auto-auth via wrapper)

### Account Portal (Personal Scope)
- ✅ `GET /api/v1/orders?buyer_user_id={userId}` (auto-auth)
- ✅ `GET /api/v1/rentals?renter_user_id={userId}` (auto-auth)
- ✅ `GET /api/v1/reservations?requester_user_id={userId}` (auto-auth)

### Customer Actions
- ✅ `POST /api/v1/reservations` (auto-auth)
- ✅ `POST /api/v1/rentals` (auto-auth)

## Implementation Details

### Single Source of Truth: Session Module
- **File:** `work/marketplace-web/src/lib/demoSession.js`
- **Storage Keys:**
  - Token: `demo_auth_token` (localStorage)
  - User: `demo_user` (localStorage)
  - Active Tenant: `active_tenant_id` (localStorage)
- **Functions:**
  - `saveSession(token, user)` - Normalizes and stores token + user
  - `clearSession()` - Clears all session data
  - `isLoggedIn()` - Checks if token exists
  - `getUser()` - Returns user object from localStorage or token
  - `getBearerToken()` - Returns "Bearer <token>" or ""
  - `getUserId()` - Extracts user ID from token payload (sub claim)

### One API Gateway: Auto-Attach Authorization
- **File:** `work/marketplace-web/src/api/client.js`
- **Changes:**
  - `apiRequest()` now auto-attaches Authorization header when token exists
  - `hosApiRequest()` now auto-attaches Authorization header when token exists
  - Public calls use `skipAuth=true` parameter to opt-out
  - 401 responses automatically clear session

### Pages Updated

1. **LoginPage.vue**
   - Uses `saveSession()` on success
   - Redirects to `/account`
   - Shows error box on failure

2. **RegisterPage.vue**
   - Uses `saveSession()` on success
   - Redirects to `/account`
   - Shows error box on failure

3. **AccountPortalPage.vue**
   - Auto-fetches `/v1/me` on mount (token auto-attached)
   - Auto-fetches reservations/rentals/orders (token auto-attached)
   - Handles 401 with auto-logout + redirect to `/login?reason=expired`
   - Shows empty-state messages
   - "Yenile" button refreshes all data

4. **CreateReservationPage.vue**
   - Removed manual token passing
   - Uses `api.createReservation(data, userId)` - token auto-attached
   - On success: shows success panel + link to `/account`

5. **CreateRentalPage.vue**
   - Removed manual token passing
   - Uses `api.createRental(data, userId)` - token auto-attached
   - On success: shows success panel + link to `/account`

6. **CreateListingPage.vue**
   - Gated for firm-only (requires active tenant)
   - Shows friendly "Firma hesabı gerekli" message if no active tenant
   - No 401 spam

### Router Guards

- **Protected Routes:** `/account`, `/reservation/create`, `/rental/create`, `/listing/:id/message`, `/demo`
- **Firm-Only Routes:** `/listing/create` (requires active tenant)
- **Behavior:** Redirects to `/login?reason=expired` if not authenticated

### Navbar (App.vue)

- **Logged Out:** Shows "Giriş", "Kayıt Ol"
- **Logged In:** Shows `<email>`, "Hesabım", "Çıkış"
- Uses `isLoggedIn()` and `getUser()` from session module

## Test Scenarios

### E2E Browser Test

1. ✅ Register new user → Login → Navbar shows email + Hesabım + Çıkış
2. ✅ Open `/marketplace/account` → NO 401, shows user email
3. ✅ Create reservation → Success → Appears in account
4. ✅ Create rental → Success → Appears in account
5. ✅ Logout → Navbar shows Giriş/Kayıt
6. ✅ Login again → Account still loads
7. ✅ Token expired → Auto-logout + redirect to `/login?reason=expired`

### API Sanity (PowerShell)

```powershell
# Register/Login → obtain token
$token = Get-DevTestJwtToken

# GET /api/v1/me with Authorization → 200
curl -H "Authorization: Bearer $token" http://localhost:3000/v1/me

# GET /api/v1/me/memberships with Authorization → 200 ([]) for customer
curl -H "Authorization: Bearer $token" http://localhost:3000/v1/me/memberships
```

## Key Improvements

1. **Zero 401 Errors:** All authenticated calls auto-attach Authorization header
2. **Single Source of Truth:** `demoSession.js` is the only place that manages tokens
3. **Clean UX:** Friendly error messages, auto-logout on 401, empty states
4. **No Technical Debt:** No demo hacks, minimal but clean implementation
5. **Firm Gating:** Create Listing properly gated with friendly message

## Files Changed

- `work/marketplace-web/src/lib/demoSession.js` - Single source of truth (already existed, used consistently)
- `work/marketplace-web/src/api/client.js` - Auto-attach Authorization header
- `work/marketplace-web/src/lib/api.js` - Already had auto-auth (used for HOS API)
- `work/marketplace-web/src/pages/LoginPage.vue` - Uses session module
- `work/marketplace-web/src/pages/RegisterPage.vue` - Uses session module
- `work/marketplace-web/src/pages/AccountPortalPage.vue` - Auto-auth, 401 handling
- `work/marketplace-web/src/pages/CreateReservationPage.vue` - Removed manual token
- `work/marketplace-web/src/pages/CreateRentalPage.vue` - Removed manual token
- `work/marketplace-web/src/pages/CreateListingPage.vue` - Firm gating
- `work/marketplace-web/src/router.js` - Added `/account` to protected routes
- `work/marketplace-web/src/App.vue` - Already using session module (no changes)

## Screenshots Checklist

- [ ] Login page with error box
- [ ] Register page with error box
- [ ] Account page showing reservations/rentals/orders
- [ ] Create Reservation success → appears in account
- [ ] Create Rental success → appears in account
- [ ] Navbar logged in state
- [ ] Navbar logged out state
- [ ] Create Listing firm gating message

## URLs

- Login: `http://localhost:5173/marketplace/login`
- Register: `http://localhost:5173/marketplace/register`
- Account: `http://localhost:5173/marketplace/account`
- Create Reservation: `http://localhost:5173/marketplace/reservation/create`
- Create Rental: `http://localhost:5173/marketplace/rental/create`
- Create Listing: `http://localhost:5173/marketplace/listing/create`

## Notes

- `/api/v1/me/orders` endpoint may not exist yet - gracefully degrades in UI
- Customer can create reservation/rental/order and immediately see them in My Account
- No "demo hacks" leaking into V1 UX
- Single identity, single token, single session store

