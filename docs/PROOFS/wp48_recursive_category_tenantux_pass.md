# WP-48: Recursive Category Search + Tenant ID UX + Showcase Demo Listings - PASS

**Date:** 2026-01-23  
**Status:** PASS  
**Purpose:** Fix recursive category search behavior, improve tenant ID UX visibility, and add deterministic showcase listings.

## Summary

WP-48 implements three key improvements:
1. **Recursive Category Search**: Parent categories now include listings from all descendant categories
2. **Tenant ID UX**: Auto-fill tenant ID in Create Listing page and display in Demo Dashboard
3. **Showcase Listings**: Seed 4 deterministic demo listings for better prototyping experience

## Deliverables

### 1. Backend: Recursive Category Search

**File:** `work/pazar/routes/_helpers.php`
- Added `pazar_category_descendant_ids()` helper function
- Recursively collects all descendant category IDs including root

**File:** `work/pazar/routes/api/03b_listings_read.php`
- Updated `GET /api/v1/listings` to use `whereIn('category_id', $categoryIds)` instead of `where('category_id', $categoryId)`
- When `category_id` is a parent/root, results include listings from all descendant categories

### 2. OPS: Recursive Test

**File:** `ops/listing_contract_check.ps1`
- Added Test 8: Recursive category search verification
- Resolves "service" root category by slug
- Creates listing under "wedding-hall" (child of service)
- Verifies that service root search includes wedding-hall listing

### 3. Frontend: Tenant ID UX

**File:** `work/marketplace-web/src/api/client.js`
- Added `hosApiRequest()` helper for HOS API calls via same-origin proxy
- Added `getMyMemberships()` method to fetch memberships from HOS API

**File:** `work/marketplace-web/src/pages/CreateListingPage.vue`
- Auto-fills tenant ID from localStorage or fetches from memberships API
- Shows tenant ID as read-only when auto-filled
- Stores active tenant ID in localStorage for persistence

**File:** `work/marketplace-web/src/pages/DemoDashboardPage.vue`
- Displays active tenant ID with copy button
- Loads tenant ID from localStorage or fetches from memberships API
- Visual feedback for tenant ID management

### 4. Demo Seed: Showcase Listings

**File:** `ops/demo_seed_root_listings.ps1`
- Added Step 6: Showcase listings seeding
- Creates 4 deterministic listings:
  - "Bando Presto (4 kişi)" under events/wedding-hall
  - "Ruyam Tekne Kiralık" under vehicle
  - "Mercedes (Kiralık)" under car-rental/car
  - "Adana Kebap" under restaurant/food
- Idempotent: checks by title+tenant+category before creating

## Verification

### Commands Run

```powershell
cd D:\stack
.\ops\catalog_contract_check.ps1
.\ops\listing_contract_check.ps1
.\ops\demo_seed_root_listings.ps1
```

### Test Results

**catalog_contract_check.ps1:**
- Exit Code: 0 (PASS)
- Categories endpoint returns non-empty tree
- Filter schema endpoint returns valid response

**listing_contract_check.ps1:**
- Exit Code: 0 (PASS)
- Test 8: Recursive category search works
  - Created listing in wedding-hall category (child of service root)
  - Service root search (category_id=1) includes wedding-hall listing
  - Verified: Listing ID `fac95d0a-874d-423c-b404-f371f47c230e` found in results

### UI Manual Check

1. **Tenant ID Auto-fill:**
   - Navigate to: `http://localhost:3002/marketplace/create-listing`
   - Verify: Tenant ID field is auto-filled (read-only, gray background)
   - Verify: Small text shows "Auto-filled from active membership (WP-48)"

2. **Demo Dashboard Tenant ID:**
   - Navigate to: `http://localhost:3002/marketplace/demo`
   - Verify: "Active Tenant ID" section displays UUID
   - Verify: "Copy" button works (copies to clipboard)

3. **Recursive Search:**
   - Navigate to: `http://localhost:3002/marketplace/search/1` (service root)
   - Verify: Listings from child categories (wedding-hall, events, food) appear in results

4. **Showcase Listings:**
   - Run: `.\ops\demo_seed_root_listings.ps1`
   - Verify: 4 showcase listings created/exist
   - Verify: Each listing appears in correct category search page

## Files Changed

1. `work/pazar/routes/_helpers.php` - Added recursive category helper
2. `work/pazar/routes/api/03b_listings_read.php` - Updated listings query to use recursive search
3. `ops/listing_contract_check.ps1` - Added recursive test
4. `work/marketplace-web/src/api/client.js` - Added HOS API helper and memberships method
5. `work/marketplace-web/src/pages/CreateListingPage.vue` - Auto-fill tenant ID
6. `work/marketplace-web/src/pages/DemoDashboardPage.vue` - Display tenant ID
7. `ops/demo_seed_root_listings.ps1` - Added showcase listings seeding

## Notes

- No hardcoded category IDs (all resolved by slug)
- No hardcoded tenant IDs (all resolved from memberships)
- All changes are idempotent
- Minimal diff, no refactoring beyond scope
- Existing endpoints remain stable

## Exit Codes

- `catalog_contract_check.ps1`: 0 (PASS)
- `listing_contract_check.ps1`: 0 (PASS)
- `demo_seed_root_listings.ps1`: 0 (PASS)

## WARNs

None. All tests pass.

