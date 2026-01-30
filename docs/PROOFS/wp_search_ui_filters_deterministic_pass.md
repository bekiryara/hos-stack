# WP-NEXT: Search UI — Filters deterministic + empty-safe PASS

**Timestamp:** 2026-01-30 (local gate run)  
**Scope:** Frontend + docs only. No backend changes.

## Summary

- **Search page:** `work/marketplace-web/src/pages/ListingsSearchPage.vue` (route `/search/:categoryId?`). **FiltersPanel:** `work/marketplace-web/src/components/FiltersPanel.vue`.
- **Filters state:** Single source (filterState); init/restore from route query; state → request mapping deterministic (stable key order via `Object.keys(filterParams).sort()`).
- **Empty filters:** No null/undefined sent; safe defaults (`filterState ?? {}`, `schemaFilters ?? []`); UI null-safe (`(filters || []).length`).
- **Marker:** Root container has `data-marker="marketplace-search"` (stable).

## Gate commands (PASS evidence)

```
.\ops\run_wp_next_local_gates.ps1
=== WP-NEXT LOCAL GATES: PASS ===

.\ops\ops_run.ps1 -Profile Prototype
OVERALL STATUS: PASS
All checks passed.
```

## Files changed

1. `work/marketplace-web/src/pages/ListingsSearchPage.vue` — deterministic params merge, empty-safe defaults
2. `work/marketplace-web/src/components/FiltersPanel.vue` — null-safe filters in template
3. `docs/PROOFS/wp_search_ui_filters_deterministic_pass.md`
4. `docs/WP_CLOSEOUTS.md` — new entry
