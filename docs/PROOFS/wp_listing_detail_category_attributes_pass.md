# WP-NEXT: Listing Detail — Category + Attributes (contract-safe) PASS

**Timestamp:** 2026-02-01  
**Summary:** Listing detail page now renders category name (best-effort from getCategoriesTree) and attributes with contract-safe normalization. No backend/API change; display only.

## Changes

### ListingDetailPage.vue
- **Category:** Resolve category name via getCategoriesTree(); find node by listing.category_id (recursive walk). Display: "Category: categoryName (ID: x)" when found; fallback "Category ID: x". Fallback when no category_id: "Category ID: —".
- **Attributes:** normalizedAttributes = listing.attributes ?? {} (null/undefined → {}). sortedAttributeKeys = Object.keys(normalizedAttributes).sort(). renderAttributeValue(value): "" / null / undefined → "—"; 0 and false preserved. Template uses normalizedAttributes and renderAttributeValue for each key.
- **API:** api.getListing(id) unchanged. getCategoriesTree() from catalogSpine (uses api.getCategories()).
- **UI language:** EN preserved (Loading listing..., No attributes, Category, etc.).
- **Styles:** Existing detail-section / attributes-list scoped CSS; no new global CSS.

## No Behavior Change (fetch)

- Same route: /listing/:id → ListingDetailPage.
- Same API: api.getListing(this.id).
- Same error handling and loading state.

## Commands / Evidence

From repo root (e.g. D:\stack):

```text
.\ops\run_wp_next_local_gates.ps1   => WP-NEXT LOCAL GATES: PASS
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS
```

Commit: 564969b
