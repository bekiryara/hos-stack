# WP-70: Single Auth UX Lock + Demo Cleanup — PASS

**Date:** 2026-01-27  
**Status:** PASS  
**Scope:** Finalize V1 user experience by eliminating demo/admin confusion

## Summary

Locked single auth entry point and removed all demo artifacts. System now feels like a real product, not a playground.

## Changes Made

### 1. Router Cleanup
- **Removed routes:**
  - `/demo` (DemoDashboardPage)
  - `/need-demo` (NeedDemoPage)
- **Removed imports:**
  - `DemoDashboardPage.vue`
  - `NeedDemoPage.vue`
  - `isDemoMode` from `demoMode.js`
- **Removed router guard:**
  - Demo mode check in `router.beforeEach`

### 2. AuthPortalPage Cleanup
- **Removed:**
  - "Demo Dashboard" link (conditional on `isDemoMode`)
  - "Devam Et / Demo" button text → changed to "Ana Sayfa"
  - `isDemoMode` computed property
  - `isDemoMode` import

### 3. HOS Web (3002) — DEV ONLY
- **Added:** "(DEV ONLY)" label to header brand
- **Updated:** Marketplace UI check from `/marketplace/need-demo` to `/marketplace/`
- **Purpose:** Make it clear that HOS Web is internal/dev tool, not part of user-facing product

### 4. PowerShell Script Hygiene
- **Archived to `ops/_archive/`:**
  - `demo_seed.ps1` (old general demo seed)
  - `demo_seed_root_listings.ps1` (old root listings seed)
  - `demo_seed_showcase.ps1` (old showcase seed)
  - `demo_seed_transaction_modes.ps1` (old transaction modes seed)
- **Active seed:**
  - `ops/demo_seed_v1.ps1` (WP-69, idempotent, E2E demo listings)

## Verification

### Single Auth Entry Point
✅ **Login:** `http://localhost:3002/marketplace/login`
- Standard email + password form
- No demo login buttons
- No admin login hints

✅ **Register:** `http://localhost:3002/marketplace/register`
- Standard registration form
- No demo shortcuts
- Clean consumer website UX

### Account Page (Canonical Home)
✅ **URL:** `http://localhost:3002/marketplace/account`

**Sections visible:**
- User Summary Card (email, display name, firm count)
- Firm Status Card:
  - If no firm → "Firma Oluştur" button
  - If firm exists → "Firma Paneli" link
- Rezervasyonlarım (My Reservations)
  - Empty state: "Henüz rezervasyon yok"
  - Table with: ID, Listing ID, Slot Start, Slot End, Party Size, Status
- Kiralamalarım (My Rentals)
  - Empty state: "Henüz kiralama yok"
  - Table with: ID, Listing ID, Start, End, Status
- Siparişlerim (My Orders)
  - Empty state: "Henüz sipariş yok"
  - Table with: ID, Listing ID, Status, Quantity, Created

### Firm Creation (Optional & Additive)
✅ **Access:** Only from Account page (`/firm/register`)
- Uses existing backend
- Does not create new login
- Does not break CUSTOMER role
- Redirects back to Account after creation

### HOS Web (3002) — DEV ONLY
✅ **URL:** `http://localhost:3002`
- Header shows: "H-OS Admin (DEV ONLY)"
- No links from Marketplace Web to HOS Web
- Internal tool, not user-facing

### Demo Artifacts Removed
✅ **Removed:**
- `/demo` route
- `/need-demo` route
- DemoDashboardPage component
- NeedDemoPage component
- `isDemoMode` usage in router
- "Demo Dashboard" link in AuthPortalPage
- Demo mode checks

✅ **Archived:**
- Old demo seed scripts (4 files moved to `ops/_archive/`)

## Proof Screenshots

### Login Screen
```
URL: http://localhost:3002/marketplace/login
- Clean email + password form
- No demo buttons
- Standard consumer website UX
```

### Account Page (Logged In)
```
URL: http://localhost:3002/marketplace/account
- User email visible in header
- Account link in navbar
- Logout button visible
- All sections (Reservations, Rentals, Orders) visible
- Firm section shows correct state (no firm → "Firma Oluştur", has firm → "Firma Paneli")
```

### HOS Web (DEV ONLY)
```
URL: http://localhost:3002
- Header: "H-OS Admin (DEV ONLY)"
- System Status dashboard
- No user-facing navigation to this page
```

## Commands Used

```powershell
# Archive old demo seed scripts
Move-Item -Path "ops\demo_seed.ps1" -Destination "ops\_archive\demo_seed.ps1"
Move-Item -Path "ops\demo_seed_root_listings.ps1" -Destination "ops\_archive\demo_seed_root_listings.ps1"
Move-Item -Path "ops\demo_seed_showcase.ps1" -Destination "ops\_archive\demo_seed_showcase.ps1"
Move-Item -Path "ops\demo_seed_transaction_modes.ps1" -Destination "ops\_archive\demo_seed_transaction_modes.ps1"
```

## Files Changed

1. `work/marketplace-web/src/router.js`
   - Removed `/demo` and `/need-demo` routes
   - Removed demo mode imports and guard

2. `work/marketplace-web/src/pages/AuthPortalPage.vue`
   - Removed "Demo Dashboard" link
   - Changed "Devam Et / Demo" to "Ana Sayfa"
   - Removed `isDemoMode` computed property

3. `work/hos/services/web/src/ui/App.tsx`
   - Added "(DEV ONLY)" label to header
   - Updated Marketplace UI check route

4. `ops/_archive/` (new directory)
   - Archived 4 old demo seed scripts

## Result

✅ **Single auth entry point:** `/login` and `/register` only  
✅ **Account page:** Canonical home with all sections visible  
✅ **Firm creation:** Optional, additive, from Account only  
✅ **HOS Web:** Marked as DEV ONLY, not user-facing  
✅ **Demo artifacts:** Removed or archived  
✅ **System feels like real product:** No playground confusion

## Notes

- `demoMode.js` file still exists but is no longer imported/used
- `DemoDashboardPage.vue` and `NeedDemoPage.vue` files still exist but are not routed
- These can be deleted in a future cleanup if desired
- WP-70 focuses on UX lock, not file deletion

