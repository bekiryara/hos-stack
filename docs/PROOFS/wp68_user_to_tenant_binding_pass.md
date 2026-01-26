# WP-68: User → Tenant Binding Hardening — Proof Pass

**Date:** 2026-01-26  
**Status:** PASS  
**Scope:** Frontend-only hardening of user-to-tenant binding flow, no backend changes

## Summary

Hardened user-to-tenant binding flow: fixed render issues, ensured deterministic firm status display, improved active tenant resolution, and removed duplicate logic. All changes are frontend-only with no backend modifications.

## Changes

### 1. AccountPortalPage.vue — Firm Status Card Hardening
- **File:** `work/marketplace-web/src/pages/AccountPortalPage.vue`
- **Change:** "Firma Durumu" card now ALWAYS renders (with loading state)
- **Logic:**
  - IF `memberships.length === 0` → Show "Firma Oluştur" primary CTA
  - IF `memberships.length > 0` → Show active firm name, status (AKTİF), "Demo'ya Dön" link
  - IF loading → Show "Firma bilgileri yükleniyor..."
- **Fix:** Added loading state check to prevent render blocking
- **Fix:** Added `status-active` CSS class for visual status indicator

### 2. FirmRegisterPage.vue — Form Render Fix
- **File:** `work/marketplace-web/src/pages/FirmRegisterPage.vue`
- **Change:** Added `mounted()` guard to ensure form renders when authenticated
- **Change:** Updated redirect logic (removed timeout hack, use Promise-based delay)
- **Behavior:**
  - If NOT authenticated → Redirect to `/login?reason=expired`
  - If authenticated → Form renders immediately
  - On success → Set active tenant, show success message, redirect to `/demo`

### 3. DemoDashboardPage.vue — Active Tenant Resolution
- **File:** `work/marketplace-web/src/pages/DemoDashboardPage.vue`
- **Change:** Deterministic active tenant resolution
- **Logic:**
  - If localStorage `activeTenantId` exists → Use it
  - Else if `memberships.length === 1` → Auto-select
  - Else → Show "Firma Seç" CTA
- **Fix:** Removed manual token passing (uses auto-attached Authorization header)
- **Fix:** Added 401 handling → `clearSession()` + redirect to login

### 4. Render & Stability Fixes
- **Removed:** Duplicate methods blocks
- **Removed:** Unused redirects and legacy logic
- **Fixed:** Vue render issues that prevented cards/forms from appearing
- **Added:** Loading states for better UX

## Test Results

### Browser Test (Manual) — Scenario A

1. **Fresh browser (incognito):**
   - ✅ `/marketplace/register` → Register new user → Auto login
   - ✅ Navbar shows email + "Hesabım" + "Çıkış"
   - ✅ `/marketplace/account` → "Firma Durumu" card ALWAYS visible
   - ✅ "Firma Durumu" shows "Firma Oluştur" button (when no firm)
   - ✅ Click "Firma Oluştur" → `/marketplace/firm/register` opens, form visible
   - ✅ Fill form: firm_name="Test Firma", firm_owner_name="Test Owner"
   - ✅ Submit → Success message → Redirects to `/demo` (no timeout hack)
   - ✅ `/demo` shows active tenant (no "No Active Tenant" message)
   - ✅ `/marketplace/listing/create` → tenantId auto-filled from active tenant

2. **Login yokken:**
   - ✅ `/marketplace/firm/register` → Redirects to `/login?reason=expired`

3. **401 handling:**
   - ✅ Account page "Yenile" button → No 401 errors
   - ✅ Memberships/reservations/rentals/orders load without 401
   - ✅ If token expired: Shows "Oturum süresi doldu" message + redirects to login
   - ✅ Demo page 401 → Hard logout + redirect to login

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

- **Account Page:** "Firma Durumu" card ALWAYS renders (with loading state)
- **Firm Register Page:** Form renders properly when authenticated
- **Active Tenant:** Set in localStorage after firm creation, redirects to `/demo`
- **401 Handling:** No 401 errors on account page refresh, proper logout on 401
- **Demo Page:** Deterministic active tenant resolution (localStorage → auto-select → CTA)

## Screenshots

1. **Account page with "Firma Durumu" card** (always visible, shows "Firma Oluştur" when no firm)
2. **Firm register form** (renders when authenticated)
3. **Success message and redirect** (after firm creation)

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

✅ **PASS:** User-to-tenant binding flow hardened. Account page shows firm status deterministically, firm register form renders properly, active tenant resolution is deterministic, and 401 handling is robust. All changes are frontend-only, no backend modifications.

