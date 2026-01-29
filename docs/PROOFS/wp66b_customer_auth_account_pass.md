# WP-66B: Customer Auth + My Account (Public Register/Login) - Proof

**Date:** 2026-01-25  
**Status:** Partially Complete (Backend validation issue needs resolution)

## Summary

Implemented public customer registration and login flow without requiring tenant membership. Frontend is complete and ready; backend has a validation issue that needs resolution.

## Backend Changes

### Files Modified
- `work/hos/services/api/src/app.js`

### Changes Made
1. Made `tenantSlug` optional in `/v1/auth/register` and `/v1/auth/login` endpoints
2. Added public customer registration logic (uses "public" tenant for storage, no membership)
3. Added `/v1/me/orders`, `/v1/me/rentals`, `/v1/me/reservations` endpoints (proxy to Pazar API)
4. Updated `requireAuth` to allow null `tenantId` for public customers

### Known Issue
Backend validation still requires `tenantSlug` field (even as empty string). The validation logic needs investigation to properly handle missing `tenantSlug`.

**Workaround:** Frontend sends `tenantSlug: ''` (empty string) to trigger public registration path.

## Frontend Changes

### Files Modified
- `work/marketplace-web/src/lib/api.js` - Removed tenantSlug from public registration/login (with workaround)
- `work/marketplace-web/src/lib/session.js` - Changed token key to `demo_auth_token` (unified with demo flow)
- `work/marketplace-web/src/pages/AccountPortalPage.vue` - Updated to use `/v1/me/*` endpoints

### Changes Made
1. Updated `login()` and `register()` to send empty `tenantSlug` for public customers
2. Updated `AccountPortalPage` to use `/v1/me/orders`, `/v1/me/rentals`, `/v1/me/reservations`
3. Unified token storage to use `demo_auth_token` key (compatible with demo flow)

## Test Results

### Backend API Tests
```powershell
# Registration (with workaround)
$body = @{email="test@example.com";password="TestPass123!";tenantSlug=""} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3002/api/v1/auth/register" -Method POST -Body $body -ContentType "application/json"
# Expected: 201 with token
# Actual: 400 (validation issue - needs fix)

# Login (with workaround)  
$body = @{email="test@example.com";password="TestPass123!";tenantSlug=""} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3002/api/v1/auth/login" -Method POST -Body $body -ContentType "application/json"
# Expected: 200 with token
# Actual: 400 (validation issue - needs fix)

# /v1/me endpoint
$headers = @{Authorization="Bearer <token>"}
Invoke-RestMethod -Uri "http://localhost:3002/api/v1/me" -Method GET -Headers $headers
# Expected: 200 with user info
# Status: Ready (once registration/login works)
```

### Frontend Browser Tests
**URLs to test:**
1. `http://localhost:3002/marketplace/register` - Public registration form
2. `http://localhost:3002/marketplace/login` - Public login form  
3. `http://localhost:3002/marketplace/account` - My Account page (shows orders/rentals/reservations)

**Expected Flow:**
1. Register new user → Redirect to `/marketplace/account`
2. Navbar shows email + "Hesabım" + "Çıkış"
3. Account page shows empty state for orders/rentals/reservations
4. Logout → Redirect to `/marketplace/login`
5. Login → Redirect to `/marketplace/account`

**Status:** Frontend ready, blocked by backend validation issue

## Next Steps

1. **Fix backend validation:** Investigate why `tenantSlug` validation is still required even when field is optional
2. **Test end-to-end:** Once backend is fixed, verify full registration/login/account flow
3. **Transaction creation:** Verify customers can create orders/rentals/reservations on published listings
4. **Data isolation:** Verify users only see their own data (no cross-user data leakage)

## Commands to Verify

```powershell
# 1. Test public registration (once backend is fixed)
$email = "test-$(Get-Date -Format 'HHmmss')@example.com"
$body = @{email=$email;password="TestPass123!"} | ConvertTo-Json
$reg = Invoke-RestMethod -Uri "http://localhost:3002/api/v1/auth/register" -Method POST -Body $body -ContentType "application/json"
$token = $reg.token

# 2. Test /v1/me
$headers = @{Authorization="Bearer $token"}
$me = Invoke-RestMethod -Uri "http://localhost:3002/api/v1/me" -Method GET -Headers $headers
Write-Host "User: $($me.email), Memberships: $($me.memberships_count)"

# 3. Test /v1/me/orders (should return empty array for new user)
$orders = Invoke-RestMethod -Uri "http://localhost:3002/api/v1/me/orders" -Method GET -Headers $headers
Write-Host "Orders count: $($orders.data.Count)"
```

## Limitations

1. **Backend validation issue:** `tenantSlug` validation needs to be fixed to properly support optional field
2. **Public tenant:** Uses a special "public" tenant for storage (users table requires tenant_id)
3. **No membership records:** Public customers don't have membership records (by design)

## Files Changed

- `work/hos/services/api/src/app.js` (backend auth endpoints, /v1/me/* endpoints)
- `work/marketplace-web/src/lib/api.js` (public registration/login)
- `work/marketplace-web/src/lib/session.js` (token storage key)
- `work/marketplace-web/src/pages/AccountPortalPage.vue` (use /v1/me/* endpoints)


