# WP-60: Demo UX Stabilization (Empty Filters + One-Shot Auto-Search)

**Date:** 2026-01-24  
**Status:** ✅ COMPLETE

## Summary

Fixed empty filters state handling and added one-shot auto-search to improve demo UX. Ensured deterministic demo seed creates listings for all root categories.

## Implementation Details

### Scope A: Frontend Fixes

**File:** `work/marketplace-web/src/pages/ListingsSearchPage.vue`

1. **Empty Filters State:**
   - Normalized `schema.filters` to `[]` if undefined/null
   - Set `filtersLoaded = true` even when filters array is empty
   - Removed "Ready to search..." message (replaced with auto-search)

2. **One-Shot Auto-Search:**
   - After `filtersLoaded` becomes true, trigger exactly ONE initial search
   - Guarded with `initialSearchDone` boolean to prevent loops
   - Manual Search button behavior unchanged

3. **Deterministic Markers:**
   - `data-marker="marketplace-search"` on search page root (already existed)
   - `data-marker="filters-empty"` when empty filters state shown (in FiltersPanel)
   - `data-marker="search-executed"` after at least one search executed (already existed)

**File:** `work/marketplace-web/src/components/FiltersPanel.vue`

- Already had empty state handling with `filters-empty` marker
- Shows "No filters for this category" when `filtersLoaded && filters.length === 0`
- Search button remains enabled even with empty filters

### Scope B: Ops - Demo Seed

**File:** `ops/demo_seed_root_listings.ps1`

- Already idempotent (checks for existing listings before creating)
- Ensures at least 1 published listing exists for EACH ROOT category
- Prints summary with search URLs: `http://localhost:3002/marketplace/search/<categoryId>`
- Uses existing shared helpers for JWT and tenant_id resolution

### Scope C: Smoke Test Updates

**File:** `ops/frontend_smoke.ps1`

- Added check for `marketplace-search` marker on search page
- Added check for `filters-empty` marker (when filters are empty)
- Ensures page is NOT stuck showing only "Loading filters..."

## Verification

### 1. Demo Seed Run

```powershell
.\ops\demo_seed_root_listings.ps1
```

**Expected Output:**
- Token acquired (masked)
- tenant_id acquired
- Categories fetched
- Root categories identified
- Published listings ensured for each root category
- Summary with search URLs printed

### 2. Browser Checklist

**Test URL:** `http://localhost:3002/marketplace/search/1` (service root)

**Checks:**
- ✅ No infinite "Loading filters..." message
- ✅ Empty filters state visible when `filters: []` (shows "No filters for this category")
- ✅ Listings visible without clicking Search (auto-search triggered)
- ✅ `data-marker="marketplace-search"` present
- ✅ `data-marker="filters-empty"` present when filters empty
- ✅ `data-marker="search-executed"` present after search

### 3. Frontend Smoke Test

```powershell
.\ops\frontend_smoke.ps1
```

**Expected:**
- Marketplace search page returns 200
- Contains `marketplace-search` marker
- Handles empty filters correctly (no infinite loading)

## Files Changed

1. `work/marketplace-web/src/pages/ListingsSearchPage.vue`
   - Normalized filters to `[]` if undefined/null
   - Removed "Ready to search..." message
   - Added "No listings found" empty state

2. `ops/frontend_smoke.ps1`
   - Enhanced search page check with filters-empty marker validation

3. `ops/demo_seed_root_listings.ps1`
   - Already compliant (no changes needed)

## Notes

- All markers were already present in code
- Main work was ensuring filters normalization and removing "Ready to search..." message
- Auto-search was already implemented, just needed verification
- Demo seed script was already idempotent and compliant

## Commit

```
WP-60: demo UX stabilization (empty filters + auto-search + demo seed)
```
