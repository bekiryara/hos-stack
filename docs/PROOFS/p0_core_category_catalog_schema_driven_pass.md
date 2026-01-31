# P0 CORE: Category/Catalog → Schema-driven Create Listing → Publish → Search — PASS

**Timestamp:** 2026-02-01

## Summary

P0 CORE implements production-grade guardrails for the category/catalog flow:
- **Backend:** Catalog-aware listing create validation (unknown keys, required, enum/options, type checks); leaf-only category rule; 422 for invalid tenant format; NUMERIC cast for range filters.
- **Frontend:** Schema-driven CreateListingForm (select/enum, number, boolean, string); leaf-only category UX; backend 422 details under fields.
- **Ops:** listing_discovery_proof extended with leaf category, filter-schema, positive flow, and negative tests (unknown_attribute_keys, invalid_attribute_value, leaf_category_required).

## How to run proofs

```powershell
cd D:\stack

# 1. Catalog contract (categories + filter-schema)
.\ops\catalog_contract_check.ps1

# 2. Listing contract (create, publish, search)
.\ops\listing_contract_check.ps1

# 3. P0 E2E discovery proof (leaf category, schema-driven create, negative tests)
.\ops\listing_discovery_proof.ps1
```

## Expected success criteria

- **catalog_contract_check.ps1:** PASS — categories tree non-empty; wedding-hall filter-schema with capacity_max required.
- **listing_contract_check.ps1:** PASS — create (with capacity_max), publish, get, search, recursive category, filters range, whitelist negative, attrs compat.
- **listing_discovery_proof.ps1:** PASS — leaf category; create with required attributes; publish; listing visible in search; filters; negative: unknown_attribute_keys, invalid_attribute_value, leaf_category_required → 422.

## Gotchas

- **Leaf categories only:** Create listing fails (422 leaf_category_required) if category has children. Frontend shows only leaf categories in create form.
- **Schema-driven attributes:** Required attributes must be filled; enum/select values must match rules.options.
- **Tenant header:** Invalid UUID format → 422 invalid_tenant_id_format (was 403).
