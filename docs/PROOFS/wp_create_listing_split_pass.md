# WP-NEXT: Create Listing split — PASS

**Timestamp:** 2026-01-31  
**Summary:** CreateListingPage orchestrator'a indirildi; form ve success UI ayrı component oldu. Davranış değişmedi, sadece yapı iyileşti.

## Changes

### New Components
- `work/marketplace-web/src/components/listing/create/CreateListingForm.vue`
  - Props: categories, filterSchema, tenantId, tenantIdLoadError, loading
  - Local state: category_id, title, description, transaction_modes[], attributes{}
  - Emits: category-change(category_id), submit(formSnapshot)
  - Template: tenant block (readonly), category select, title, description, transaction modes, attributes-from-schema, submit button

- `work/marketplace-web/src/components/listing/create/CreateListingSuccessBox.vue`
  - Props: success, publishing, publishError
  - Emits: copy-id(id), publish, go-search(categoryId)
  - Template: View Listing link, Publish now, Go to Search, publish error box

### Modified
- `work/marketplace-web/src/pages/CreateListingPage.vue`
  - Page: data fetch (getCategoriesTree, tenant auto-fill), loadFilterSchema on category-change, onFormSubmit (normalize attributes, api.createListing), handlePublish, copyListingId, goToCategorySearch
  - Template: h2, error box, success ? CreateListingSuccessBox : CreateListingForm
  - Same API calls, same routes, same field behavior

## No Behavior Change

- Same fields: category_id, title, description, transaction_modes, attributes (from filter-schema)
- Same API: api.createListing(payload, tenantId), api.publishListing(id, tenantId)
- Same attributes normalize: null/undefined/"" excluded; boolean false and number 0 kept
- Same tenant auto-fill: getActiveTenantId → memberships → setActiveTenantId

## Commands / Evidence

From repo root (D:\stack):

```text
.\ops\run_wp_next_local_gates.ps1   => WP-NEXT LOCAL GATES: PASS
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS (after commit)
```

## Rationale

Create Listing write-path modülerleştirildi; patlama riski düşürüldü. Sonraki geliştirmeler (Listing Detail attrs, Firm listing actions, Customer account lists) bu zeminde güvenle ilerleyecek.
