# Proof: SPEC Alignment — Catalog/Categories + Listings/Search (V1)

**Date:** 2026-01-29  
**Scope:** Pazar (Laravel/PHP) only — `work/pazar/routes/api/02_catalog.php`, `03a_listings_write.php`, `03b_listings_read.php`  
**Constraint:** Endpoint surface (paths + response contracts) preserved. No new endpoints.

---

## Contract Map (runtime surface)

- **Categories tree**
  - Route: `GET /api/v1/categories`
  - File: `work/pazar/routes/api/02_catalog.php`
  - DB: `categories` (filtered to `status=active`)
  - Output: hierarchical tree via `pazar_build_tree(...)`

- **Category filter schema**
  - Route: `GET /api/v1/categories/{id}/filter-schema`
  - File: `work/pazar/routes/api/02_catalog.php`
  - DB: `category_filter_schema` + `attributes`
  - Output: `{ category_id, category_slug, filters: [...] }`

- **Listings search/read**
  - Route: `GET /api/v1/listings`
  - File: `work/pazar/routes/api/03b_listings_read.php`
  - DB: `listings` (+ `categories` for category validation; `category_filter_schema` for allowed keys)
  - Filters contract:
    - Primary: `filters[...]` (SPEC-aligned, WP-75)
    - Back-compat: `attrs[...]`
  - Recursive category behavior uses CTE helper for descendant category IDs

- **Listings create/publish**
  - Route: `POST /api/v1/listings`, `POST /api/v1/listings/{id}/publish`
  - File: `work/pazar/routes/api/03a_listings_write.php`
  - Validation: required attributes enforced from `category_filter_schema.required` (if column exists)

---

## SPEC vs Reality Delta (applied fix)

### Delta: Category “title” field

- **SPEC canonical model** expects category title.
- **DB column** is `categories.name`.
- **Fix:** `GET /api/v1/categories` response now includes additive fields:
  - `title` = `name`
  - `status` (already filtered to active)

This is additive (does not remove/rename existing keys), so existing clients remain compatible.

---

## Proof: Commands (PASS)

### Catalog contract check

```powershell
.\ops\catalog_contract_check.ps1
```

Result: **PASS**

### Listing contract check

```powershell
.\ops\listing_contract_check.ps1
```

Result: **PASS**

