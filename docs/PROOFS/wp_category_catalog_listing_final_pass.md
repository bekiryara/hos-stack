# WP-FINAL: Category / Catalog / Listing Finalization — PASS

Timestamp: 2026-01-28

## What is locked
- Single listing read engine: `GET /api/v1/listings` (no new endpoints).
- Primary filter contract: `filters[...]` (SPEC-aligned).
- Backward compatibility: `attrs[...]` still works.
- If `filters[...]` exists → it is used.
- Else if `attrs[...]` exists → legacy behavior is used.
- Category provides only the tree; filter definitions come from catalog schema; listings apply only provided filters.

## Backend proof (filters[] works)

Range (max):
```text
curl.exe -s "http://localhost:8080/api/v1/listings?category_id=22&status=published&filters[capacity_max][max]=10"
```

Equality:
```text
curl.exe -s "http://localhost:8080/api/v1/listings?category_id=11&status=published&filters[brand]=Mercedes"
```

## Backward compatibility proof (attrs[] still works)
```text
curl.exe -s "http://localhost:8080/api/v1/listings?category_id=22&status=published&attrs[capacity_max_max]=10"
curl.exe -s "http://localhost:8080/api/v1/listings?category_id=11&status=published&attrs[brand]=Mercedes"
```

## Catalog whitelist proof (unknown keys rejected when category is known)
```text
curl.exe -s -i "http://localhost:8080/api/v1/listings?category_id=11&status=published&filters[not_real_key]=x"
```
Expected: HTTP 422.

## Frontend proof (manual)
1. Open `http://localhost:3002/marketplace/search/11` (car-rental).
2. Choose filters and click **Search**.
3. Verify the request to `.../api/v1/listings` includes `filters[...]` parameters.

## Files changed
- `work/pazar/routes/api/03b_listings_read.php`
- `work/marketplace-web/src/pages/ListingsSearchPage.vue`
- `docs/PROOFS/wp75_filters_array_pass.md`
- `docs/PROOFS/wp_category_catalog_listing_final_pass.md`
- `docs/WP_CLOSEOUTS.md`
- `CHANGELOG.md`

