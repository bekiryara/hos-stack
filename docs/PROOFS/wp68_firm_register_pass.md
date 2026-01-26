# WP-68: Firm (Tenant) Registration — Proof Pass

**Date:** 2026-01-25  
**Status:** PASS  
**Scope:** Backend tenant creation endpoint, frontend firm registration page, active tenant selection

## Summary

Implemented firm (tenant) registration flow: user can create a firm via `/marketplace/firm/register`, which creates a tenant and membership (role=owner), and sets it as active tenant. Active tenant selection UX added to account page.

## Changes

### 1. Backend Tenant Creation
- **File:** `work/hos/services/api/src/app.js`
- **Endpoint:** `POST /v1/tenants/v2` (already exists, WP-8)
- **Auth:** Required (JWT token)
- **Body:** `{ slug, display_name }`
- **Behavior:**
  - Creates tenant with slug and display_name
  - Auto-creates membership: role=owner, status=active
  - Returns: `{ tenant_id, slug, display_name, status }`

### 2. Frontend API Client
- **File:** `work/marketplace-web/src/api/client.js`
- **Change:** Updated `hosCreateTenant()` to use `/v1/tenants/v2` endpoint
- **Added:** `getMe()` function for `/v1/me` endpoint

### 3. Firm Registration Page
- **File:** `work/marketplace-web/src/pages/FirmRegisterPage.vue` (NEW)
- **Route:** `/marketplace/firm/register`
- **Auth:** Required (router guard)
- **Form Fields:**
  - `firm_name` (required): Used to generate slug
  - `firm_owner_name` (optional): Used as display_name
- **Behavior:**
  - Generates slug from firm_name (lowercase, dash-separated)
  - Calls `POST /v1/tenants/v2`
  - Sets `active_tenant_id` in localStorage on success
  - Redirects to `/account` after 2 seconds

### 4. Active Tenant Selection UX
- **File:** `work/marketplace-web/src/pages/AccountPortalPage.vue`
- **Change:** Added memberships list with "Set as Active" button
- **Display:**
  - Shows all active memberships
  - Highlights active tenant
  - "Set as Active" button for non-active tenants
- **Behavior:**
  - Fetches memberships from `/v1/me/memberships`
  - Sets `active_tenant_id` in localStorage
  - Updates UI to show active state

### 5. Create Listing Auto-Fill
- **File:** `work/marketplace-web/src/pages/CreateListingPage.vue`
- **Status:** Already implemented (WP-51, WP-62)
- **Behavior:** Auto-fills `tenantId` from `active_tenant_id` in localStorage

### 6. Router Update
- **File:** `work/marketplace-web/src/router.js`
- **Change:** Added route `/firm/register` with auth requirement

## Test Results

### Browser Test (Manual)
1. **Firm Registration**
   - ✅ Navigate to `/marketplace/firm/register` (requires login)
   - ✅ Fill form: firm_name="ABC Teknoloji", firm_owner_name="John Doe"
   - ✅ Submit → Success message
   - ✅ `active_tenant_id` set in localStorage
   - ✅ Redirect to `/account` after 2 seconds

2. **Active Tenant Selection**
   - ✅ Account page shows memberships list
   - ✅ Active tenant highlighted
   - ✅ Click "Set as Active" → tenant becomes active
   - ✅ `active_tenant_id` updated in localStorage

3. **Create Listing with Active Tenant**
   - ✅ Navigate to `/listing/create`
   - ✅ `tenantId` field auto-filled with active tenant ID
   - ✅ Can create listing without manual tenant ID entry

### API Test (PowerShell)
```powershell
# Test POST /v1/tenants/v2
$token = "Bearer <valid_jwt_token>"
$body = @{
    slug = "test-firm-$(Get-Date -Format 'yyyyMMddHHmmss')"
    display_name = "Test Firm"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:3000/v1/tenants/v2" `
    -Method Post `
    -Headers @{Authorization=$token; "Content-Type"="application/json"} `
    -Body $body

# ✅ Returns: { tenant_id, slug, display_name, status: "active" }

# Verify membership created
$memberships = Invoke-RestMethod -Uri "http://localhost:3000/v1/me/memberships" `
    -Headers @{Authorization=$token}
# ✅ Returns: { items: [{ tenant_id, tenant_slug, tenant_name, role: "owner", status: "active" }] }
```

## Evidence

- **Backend Endpoint:** `POST /v1/tenants/v2` creates tenant and membership
- **Frontend Page:** `/marketplace/firm/register` with form
- **Active Tenant:** Stored in localStorage `active_tenant_id`
- **Auto-Fill:** Create Listing page uses active tenant ID

## Conclusion

✅ **PASS:** Firm registration flow implemented. User can create firm, set as active, and use it for listing creation.

