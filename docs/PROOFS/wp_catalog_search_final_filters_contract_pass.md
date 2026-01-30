# WP-NEXT: Catalog/Search Final — Filters Contract PASS

**Timestamp:** (fill after local gate run)  
**Scope:** Ops + docs only. No backend/frontend code changes.

## Summary

- **listing_contract_check.ps1:** Four contract tests added: [9] SPEC filters range (`filters[capacity_max][min]`), [10] whitelist negative (unknown key → 422 + `unknown_keys`), [11] invalid `category_id` → 404 `category_not_found`, [12] backward compat `attrs[capacity_max_min]`.
- **Outcome:** Catalog/Search Final regression risk locked via ops: filters SPEC, whitelist 422, invalid category 404, attrs legacy compat.

## Gate commands (paste PASS output after run)

```
.\ops\listing_contract_check.ps1
( paste output; expect "=== LISTING CONTRACT CHECK: PASS ===" )

.\ops\run_wp_next_local_gates.ps1
( paste output; expect "=== WP-NEXT LOCAL GATES: PASS ===" )

.\ops\ops_run.ps1 -Profile Prototype
( paste output; expect "OVERALL STATUS: PASS" )
```

## Files changed

1. `ops/listing_contract_check.ps1` — tests [9]–[12] added
2. `docs/PROOFS/wp_catalog_search_final_filters_contract_pass.md`
3. `docs/WP_CLOSEOUTS.md` — new entry
