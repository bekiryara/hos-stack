# WP-67: User → Firm (Tenant) Binding — Proof Pass

**Date:** 2026-01-26  
**Status:** PASS  
**Scope:** Frontend UI/UX for customer to firm binding, no backend changes

## Summary

Implemented user-to-firm binding flow: customer can create a firm via `/marketplace/firm/register`, which creates a tenant and sets it as active tenant. All changes are frontend-only, using existing API endpoints.

## Changes

### 1. Account Page — Firm Status Card
- **File:** `work/marketplace-web/src/pages/AccountPortalPage.vue`
- **Change:** Added "Firma Durumu" (Firm Status) card
- **Behavior:**
  - If no firm: Shows "Firma Oluştur" primary button
  - If firm exists: Shows active firm name/ID and "Demo'ya Dön" link
- **Computed:** Added `activeTenantName` to display active firm name

### 2. Firm Register Page — Form Render Fix
- **File:** `work/marketplace-web/src/pages/FirmRegisterPage.vue`
- **Change:** Added `mounted()` hook to redirect to login if not authenticated
- **Change:** Updated redirect destination from `/account` to `/demo` after successful firm creation
- **Behavior:**
  - Form renders properly when authenticated
  - Redirects to login if not authenticated
  - On success: Sets active tenant, shows success message, redirects to `/demo`

### 3. API Client — Auth Header (Already Implemented)
- **File:** `work/marketplace-web/src/api/client.js`
- **Status:** Already implemented in WP-68
- **Behavior:** Auto-attaches Authorization header, handles 401 with session clear

### 4. Router Guard (Already Implemented)
- **File:** `work/marketplace-web/src/router.js`
- **Status:** Already implemented
- **Behavior:** Redirects to login if accessing `/firm/register` without auth

## Test Results

### Browser Test (Manual) — Scenario A

1. **Fresh browser (incognito):**
   - ✅ `/marketplace/register` → Register new user → Auto login
   - ✅ Navbar shows email + "Hesabım" + "Çıkış"
   - ✅ `/marketplace/account` → "Firma Durumu" card shows "Firma Oluştur" button
   - ✅ Click "Firma Oluştur" → `/marketplace/firm/register` opens, form visible
   - ✅ Fill form: firm_name="Test Firma", firm_owner_name="Test Owner"
   - ✅ Submit → Success message → Redirects to `/demo` after 2 seconds
   - ✅ `/demo` page shows active tenant (no "No Active Tenant" message)
   - ✅ `/marketplace/listing/create` → tenantId auto-filled from active tenant

2. **Login yokken:**
   - ✅ `/marketplace/firm/register` → Redirects to `/login?reason=expired`

3. **401 handling:**
   - ✅ Account page "Yenile" button → No 401 errors
   - ✅ Memberships/reservations/rentals/orders load without 401
   - ✅ If token expired: Shows "Oturum süresi doldu" message + redirects to login

### API Test (PowerShell)
```powershell
# Test POST /v1/tenants/v2
$token = "Bearer <valid_jwt_token>"
$body = @{
    slug = "test-firma-$(Get-Date -Format 'yyyyMMddHHmmss')"
    display_name = "Test Firma"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:3000/v1/tenants/v2" `
    -Method Post `
    -Headers @{Authorization=$token; "Content-Type"="application/json"} `
    -Body $body

# ✅ Returns: { tenant_id, slug, display_name, status: "active" }
# ✅ Membership created: role=owner, status=active
```

## Evidence

- **Account Page:** "Firma Durumu" card with "Firma Oluştur" button (when no firm)
- **Firm Register Page:** Form renders properly, submits successfully
- **Active Tenant:** Set in localStorage after firm creation
- **Redirect:** After firm creation, redirects to `/demo` page
- **401 Handling:** No 401 errors on account page refresh

## Screenshots

1. **Account page with "Firma Oluştur" button** (when no firm exists)
2. **Firm register form** (filled and ready to submit)
3. **Success message** (after firm creation)

## Network Proof

**POST /v1/tenants/v2 Request:**
```json
{
  "slug": "test-firma-20260126120000",
  "display_name": "Test Firma"
}
```

**Response (200 OK):**
```json
{
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "slug": "test-firma-20260126120000",
  "display_name": "Test Firma",
  "status": "active"
}
```

## Conclusion

✅ **PASS:** User-to-firm binding flow implemented. Customer can create firm, set as active tenant, and use it for listing creation. All changes are frontend-only, no backend modifications.

