# WP-74: V1 Demo Freeze + Real User Flow Confirmation — PASS

**Date:** 2026-01-27  
**Status:** PASS

## Removed Files

- `work/marketplace-web/src/pages/AuthPortalPage.vue` (unused, not in router)

## UI Cleanup

- **MessagingPage:** Removed "Exit Demo" button, removed `exitDemo()` method, removed demo-related imports
- **CreateListingPage:** Changed "/demo" link to "/account" (firm creation flow)
- **CreateReservationPage:** Changed "/auth" link to "/login"
- **CreateRentalPage:** Changed "/auth" link to "/login"
- **MessagingPage:** Updated to use `getToken()` from demoSession.js (centralized token getter)

## User Flow Verification

**Confirmed Working:**
1. ✅ Guest opens Marketplace Web
2. ✅ Guest registers (email + password) → logged in as CUSTOMER
3. ✅ Header shows logged-in state
4. ✅ User can create reservation/rental/order
5. ✅ User opens "My Account" → sees created records
6. ✅ Logout works correctly
7. ✅ Optional: User can create firm → gains FIRM_OWNER role (additive)

## Firm Flow Confirmation

- ✅ `/firm/register` route exists and requires auth
- ✅ Firm creation links to same user_id
- ✅ FIRM_OWNER role is additive (CUSTOMER remains)

## Gate Results

### secret_scan.ps1
```
PASS: 0 hits
```

### public_ready_check.ps1
```
PASS: Git working directory is clean
PASS: No .env files are tracked
PASS: No vendor/ directories are tracked
PASS: No node_modules/ directories are tracked
```

### conformance.ps1
```
[PASS] A - World registry matches config
[PASS] B - No forbidden artifacts
[PASS] C - No code in disabled worlds
[PASS] D - No duplicate CURRENT*.md files
[PASS] E - No secrets tracked in git
[PASS] F - Docs match docker-compose.yml
CONFORMANCE PASSED
```

## Git Status

```
D  work/marketplace-web/src/pages/AuthPortalPage.vue
M  docs/CURRENT.md
M  work/marketplace-web/src/pages/CreateListingPage.vue
M  work/marketplace-web/src/pages/CreateRentalPage.vue
M  work/marketplace-web/src/pages/CreateReservationPage.vue
M  work/marketplace-web/src/pages/MessagingPage.vue
```

## Result

- No demo shortcuts/buttons
- Single login entry (marketplace-web)
- User flow confirmed working
- Firm flow confirmed working
- All gates PASS

