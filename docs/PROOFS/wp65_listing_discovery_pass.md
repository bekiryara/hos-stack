# WP-65: Listing Discovery Completion (Spec-aligned) - PASS

**Date:** 2026-01-24  
**HEAD Commit:** (to be filled after commit)  
**Status:** ✅ PASS

## Goal

Complete the prototype by making published listings discoverable via category and search, strictly aligned with existing SPEC and contracts. No new domain, no new schema.

## Verification

### Proof Script Execution

```powershell
.\ops\listing_discovery_proof.ps1
```

**Output Summary:**
```
=== LISTING DISCOVERY PROOF (WP-65) ===
Timestamp: 2026-01-24 22:46:01

Step 1: Bootstrap JWT token and tenant...
  Token: ***xIre1w
  Tenant ID: 7ef9bc88-2d20-45ae-9f16-525181aad657
  User ID: 07d9f9b8-3efb-4612-93be-1c03964081c8

Step 2: Get a category ID...
  Category ID: 4 (Vehicle)

Step 3: Create listing (draft)...
  Listing ID: f94715b9-e177-4394-8a42-88324bb7ce3a
  Status: draft

Step 4: Verify draft listing NOT in search...
  ✅ Draft listing correctly excluded from search

Step 5: Publish listing...
  Status: published

Step 6: Verify listing in GET /v1/listings (default published)...
  ✅ Listing found in GET /v1/listings
    Title: WP-65 Discovery Test Listing 20260124-224604
    Status: published

Step 7: Verify listing in GET /v1/listings (explicit status=published)...
  ✅ Listing found with explicit status=published

Step 8: Verify listing NOT in status=draft filter...
  ✅ Published listing correctly excluded from draft filter

Step 9: Verify empty filters return published listings...
  ✅ Empty filters return array with 20 published listings
  ✅ Our listing found in empty filter results

=== PROOF PASSED ===
```

## Endpoint Verification

### 1. GET /v1/listings

**Default Behavior:**
- Default `status=published` ✅
- Returns array of published listings ✅
- Supports `category_id` filter (recursive, includes descendants) ✅
- Supports explicit `status` parameter ✅
- Empty filters return published listings array (not null) ✅

**Code Location:** `work/pazar/routes/api/03b_listings_read.php:18-20`
```php
// Filter by status (default: published)
$status = $request->input('status', 'published');
$query->where('status', $status);
```

### 2. GET /v1/search

**Behavior:**
- Requires `category_id` parameter ✅
- Hardcoded `status='published'` ✅
- Returns only published listings ✅
- Supports availability filtering (reservations/rentals) ✅

**Code Location:** `work/pazar/routes/api/03b_listings_read.php:170-173`
```php
// Build query - only published listings
$query = DB::table('listings')
    ->where('status', 'published')
    ->whereIn('category_id', $categoryIds);
```

### 3. GET /v1/listings/{id}

**Behavior:**
- Returns single listing (any status) ✅
- No status filtering (as per spec) ✅

## Frontend Verification

### Existing Pages

1. **`/marketplace`** - Home page (uses existing components)
2. **`/marketplace/categories/{slug}`** - Category tree (links to `/search/{categoryId}`)
3. **`/marketplace/search/{categoryId}`** - Search page (uses `GET /v1/listings?category_id={id}&status=published`)

**Code Verification:**
- `ListingsSearchPage.vue` sends `status: 'published'` ✅
- `CategoryTree.vue` links to `/search/${category.id}` ✅
- No new UI components added ✅

## Spec Alignment

### Contract Compliance

1. **Default Status Filter:**
   - ✅ `GET /v1/listings` defaults to `status=published`
   - ✅ `GET /v1/search` hardcodes `status='published'`
   - ✅ Draft listings excluded from published search

2. **Category Filter:**
   - ✅ `category_id` parameter supported (recursive, includes descendants)
   - ✅ Uses `pazar_category_descendant_ids()` helper

3. **Empty Filters:**
   - ✅ Returns empty array `[]` (not null)
   - ✅ Returns published listings when no filters applied

4. **No Schema Changes:**
   - ✅ No new tables or columns
   - ✅ No new filters beyond existing spec
   - ✅ Uses existing `listings.status` column

## Test Results

### Proof Script Checks

| Check | Status | Details |
|------|--------|---------|
| Draft listing excluded from published search | ✅ PASS | Draft listing correctly filtered out |
| Published listing in GET /v1/listings (default) | ✅ PASS | Listing appears with default status filter |
| Published listing in GET /v1/listings (explicit) | ✅ PASS | Listing appears with explicit status=published |
| Published listing excluded from status=draft | ✅ PASS | Published listing correctly filtered out |
| Empty filters return published listings | ✅ PASS | Returns array with published listings |

## Files Changed

- `ops/listing_discovery_proof.ps1` (NEW) - Proof script for discovery verification
- `docs/PROOFS/wp65_listing_discovery_pass.md` (NEW) - This document

## No Changes Required

The following endpoints already comply with spec:
- `GET /v1/listings` - Default status=published ✅
- `GET /v1/search` - Hardcoded status=published ✅
- Frontend pages use correct status filters ✅

## Conclusion

✅ **PASS**: All discovery endpoints correctly filter by `status=published`. Draft listings are excluded from published search. Empty filters return published listings array. No schema changes or new endpoints required. Spec-aligned behavior confirmed.

