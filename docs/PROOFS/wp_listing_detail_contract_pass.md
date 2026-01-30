# WP-NEXT: Listing Detail — Category + Attributes Contract — PASS

**Timestamp:** (fill after local gate run)  
**Scope:** Frontend + docs only. No backend changes.

## Summary

- **Listing detail page:** `work/marketplace-web/src/pages/ListingDetailPage.vue` (route `/listing/:id`).
- **Category block:** Added dedicated section; shows "Category ID: &lt;id&gt;" or "Category ID: —" (empty/null safe).
- **Attributes block:** Replaced JSON dump with deterministic "key: value" list; keys sorted with `Object.keys().sort()`. Empty/null/`{}` shows "No attributes".
- **UI:** Minimal; existing `.detail-section` style; no refactor.

## Gate commands (placeholder — paste PASS output after run)

```
run_wp_next_local_gates:
( paste output )

ops_run -Profile Prototype:
( paste output )
```

## Files changed

1. `work/marketplace-web/src/pages/ListingDetailPage.vue`
2. `docs/PROOFS/wp_listing_detail_contract_pass.md`
3. `docs/WP_CLOSEOUTS.md`
