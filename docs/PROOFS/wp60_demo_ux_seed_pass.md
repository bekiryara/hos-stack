# WP-60: Demo UX Stabilization + Deterministic Demo Data - PASS

**Date:** 2026-01-23  
**Status:** PASS  
**Purpose:** Make prototype demo usable like a real product: user lands on search and sees results automatically, and demo data is deterministic across all root categories.

## Summary

Implemented auto-run initial search on marketplace search page and deterministic demo seed script. Users now:
- See listings automatically when opening a category search page (no need to click Search)
- Have guaranteed demo data in all root categories (service, vehicle, real-estate)
- Can navigate to any category and see results immediately

## Browser Steps Verification

### 1) Auto-Search on Category Page
- **Step:** Open http://localhost:3002/marketplace/search/1
- **Result:** Filters load, then search runs automatically, listings appear
- **Status:** PASS
- **Notes:** No "No listings found" until after search completes. Initial search runs once only (guarded by `initialSearchDone` flag).

### 2) Multiple Categories Have Listings
- **Step:** Open http://localhost:3002/marketplace/search/1 (Services)
- **Result:** Listings visible automatically
- **Status:** PASS
- **Step:** Open http://localhost:3002/marketplace/search/4 (Vehicle)
- **Result:** Listings visible automatically
- **Status:** PASS
- **Step:** Open http://localhost:3002/marketplace/search/5 (Real Estate)
- **Result:** Listings visible automatically
- **Status:** PASS

### 3) Manual Search Still Works
- **Step:** Change filters, click "Search" button
- **Result:** Search runs with new filters
- **Status:** PASS
- **Notes:** Auto-search does not interfere with manual search

## Demo Seed Script Results

```powershell
.\ops\demo_seed.ps1
```

**Expected Output:**
- PASS: Token acquired (masked)
- PASS: tenant_id acquired
- PASS: Categories fetched
- PASS: Found 3 root categories (service, vehicle, real-estate)
- Summary showing EXISTS/CREATED per category with URLs

**Sample Output:**
```
=== DEMO SEED (WP-60) ===
Timestamp: 2026-01-23 07:57:09

[1] Acquiring JWT token...
PASS: Token acquired (***RBH440)

[2] Getting tenant_id from memberships...
PASS: tenant_id acquired: 7ef9bc88-2d20-45ae-9f16-525181aad657

[3] Fetching categories...
PASS: Categories fetched

[4] Identifying root categories...
  Found: service (id: 1)
  Found: vehicle (id: 4)
  Found: real-estate (id: 5)
PASS: Found 3 root categories

[5] Ensuring published listings per category...
  Category: Services (id: 1, slug: service)
    CREATED: Listing created and published (id: fa294a1e-317f-41a7-ba0a-c8887a214b49)
  Category: Vehicle (id: 4, slug: vehicle)
    EXISTS: Published listing found (id: ecefbd75-c7a2-46ab-938e-bf2126445ed8)
  Category: Real Estate (id: 5, slug: real-estate)
    CREATED: Listing created and published (id: b2395bf0-9d26-44a6-80d4-020f5e62d716)

=== DEMO SEED SUMMARY ===
[CREATED] Services (slug: service)
  Category ID: 1
  Listing ID: fa294a1e-317f-41a7-ba0a-c8887a214b49
  Search URL: http://localhost:3002/marketplace/search/1
  Listing URL: http://localhost:3002/marketplace/listing/fa294a1e-317f-41a7-ba0a-c8887a214b49

[EXISTS] Vehicle (slug: vehicle)
  Category ID: 4
  Listing ID: ecefbd75-c7a2-46ab-938e-bf2126445ed8
  Search URL: http://localhost:3002/marketplace/search/4
  Listing URL: http://localhost:3002/marketplace/listing/ecefbd75-c7a2-46ab-938e-bf2126445ed8

[CREATED] Real Estate (slug: real-estate)
  Category ID: 5
  Listing ID: b2395bf0-9d26-44a6-80d4-020f5e62d716
  Search URL: http://localhost:3002/marketplace/search/5
  Listing URL: http://localhost:3002/marketplace/listing/b2395bf0-9d26-44a6-80d4-020f5e62d716

=== DEMO SEED: PASS ===
```

## Deliverables

1. **work/marketplace-web/src/pages/ListingsSearchPage.vue** (MODIFIED)
   - Added `initialSearchDone` flag to prevent infinite loops
   - Auto-runs initial search after filters load (once only)
   - Updated UI: "No listings found" only shows after search executed
   - Guard ensures auto-search runs exactly once per page load

2. **ops/demo_seed.ps1** (NEW)
   - Bootstrap JWT using test_auth.ps1 helper (reused, not duplicated)
   - Get tenant_id from memberships (reused Get-TenantIdFromMemberships helper)
   - Fetch categories from Pazar API
   - Identify root categories (target slugs: service, vehicle, real-estate)
   - For each category: check for published listing, create if missing
   - Idempotent: running twice does not create duplicates
   - Prints summary with marketplace URLs

3. **ops/prototype_v1.ps1** (MODIFIED)
   - Added `-SeedDemo` switch (optional, default: false)
   - Calls demo_seed.ps1 before smoke tests if switch provided
   - Default behavior unchanged (backward compatible)

## Key Features

- **Auto-Search:** Search page automatically runs initial search after filters load
- **Deterministic Data:** At least 1 published listing per root category guaranteed
- **Idempotent Seed:** Running demo_seed multiple times is safe (checks before creating)
- **No Infinite Loops:** Guard flag prevents auto-search from running multiple times
- **Backward Compatible:** Default behavior unchanged, -SeedDemo is optional

## Acceptance Criteria

✅ Search page auto-runs initial search (no user click required)  
✅ "No listings found" only appears after search executed  
✅ Demo seed ensures listings in all root categories  
✅ Demo seed is idempotent (safe to run multiple times)  
✅ Manual search still works (auto-search does not interfere)  
✅ All existing smokes still pass  
✅ Minimal diff, no refactor, no domain redesign  

## URLs

- Marketplace Search (Services): http://localhost:3002/marketplace/search/1
- Marketplace Search (Vehicle): http://localhost:3002/marketplace/search/4
- Marketplace Search (Real Estate): http://localhost:3002/marketplace/search/5

## Notes

- Auto-search runs once per page load (guarded by `initialSearchDone` flag)
- Demo seed uses APIs only (no direct DB writes)
- Demo seed reuses existing helpers (test_auth.ps1, Get-TenantIdFromMemberships)
- Token masking: only last 6 chars shown in outputs
- ASCII-only outputs for PowerShell 5.1 compatibility

