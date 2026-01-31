# WP-NEXT: Marketplace — Google OAuth Login Entry (frontend)

**Timestamp:** 2026-02-01  
**Summary:** Marketplace login sayfasına "Google ile Giriş Yap" butonu eklendi; tenantSlug hardcode yok; feature flag ile kontrol.

## Changes

- **Modified:** `work/marketplace-web/src/pages/LoginPage.vue`
  - Added Google OAuth section (only visible when `googleOAuthConfigured: true`)
  - Tenant slug input (from query param → localStorage → user input)
  - "Google ile Giriş Yap" button with official Google icon
  - Validation: slug required before redirect
  - Redirect URL: `/api/v1/auth/google/start?tenantSlug={slug}` (nginx proxies to HOS API)
  - Saves tenant slug to localStorage for future sessions
  - Feature flag check via `GET /api/v1/meta/features`

## No Hardcodes

- ✅ `tenantSlug`: From `?tenantSlug=` query param → `localStorage` → user input
- ✅ API base URL: Uses `/api/*` (nginx proxy to HOS API, no localhost:3000 hardcode)
- ✅ Google OAuth enabled: Dynamically checked via `/v1/meta/features`

## Manual Test Steps

1. Navigate to `http://localhost:3002/login`
2. Verify "Google ile Giriş Yap" button is visible (if Google OAuth is configured)
3. Enter a tenant slug (e.g., `tenant-a`) in the "Organizasyon (Tenant)" field
4. Click "Google ile Giriş Yap"
5. Verify browser redirects to `/api/v1/auth/google/start?tenantSlug=tenant-a`
6. Verify this proxies to HOS API and starts Google OAuth flow

Alternative with query param:
- Navigate to `http://localhost:3002/login?tenantSlug=tenant-a`
- Verify tenant slug field is pre-filled

## Commands / Evidence

From repo root:

```text
.\ops\run_wp_next_local_gates.ps1   => WP-NEXT LOCAL GATES: PASS
.\ops\ops_run.ps1 -Profile Prototype => Prototype Verification PASS (Public Ready FAILs until commit)
```

**Gate results:**
- Secret Scan: PASS
- Conformance: PASS
- Prototype Verification: PASS
- Public Ready: FAIL (only because uncommitted changes - clears after commit)
