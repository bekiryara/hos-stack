# WP-75: SPEC-Aligned Listing Search Filters (filters[]), Backward Compatible (attrs[]) — PASS

Timestamp: 2026-01-28

## Summary
- Backend listing search now supports SPEC-style `filters[...]` parameters (preferred) while keeping existing `attrs[...]` behavior working.
- Frontend search now sends `filters[...]` to `/api/v1/listings`.

## Backend proofs (curl)

### SPEC format: range (max)
```text
curl.exe -s "http://localhost:8080/api/v1/listings?category_id=22&status=published&filters[capacity_max][max]=10"
```

Observed response (trimmed):
```json
[
  { "id": "510e1bc9-4e08-40cd-a4d0-fc430142a96b", "category_id": 22, "title": "Bando Presto 4 kişi" }
]
```

### SPEC format: equality
```text
curl.exe -s "http://localhost:8080/api/v1/listings?category_id=11&status=published&filters[brand]=Mercedes"
```

Observed response (trimmed):
```json
[
  { "id": "9f425e36-2dd2-4787-88a0-a459406f35a9", "category_id": 11, "title": "Mercedes Kiralık" }
]
```

### Backward compatibility: attrs range (max)
```text
curl.exe -s "http://localhost:8080/api/v1/listings?category_id=22&status=published&attrs[capacity_max_max]=10"
```

Observed response (trimmed):
```json
[
  { "id": "510e1bc9-4e08-40cd-a4d0-fc430142a96b", "category_id": 22, "title": "Bando Presto 4 kişi" }
]
```

### Backward compatibility: attrs equality
```text
curl.exe -s "http://localhost:8080/api/v1/listings?category_id=11&status=published&attrs[brand]=Mercedes"
```

Observed response (trimmed):
```json
[
  { "id": "9f425e36-2dd2-4787-88a0-a459406f35a9", "category_id": 11, "title": "Mercedes Kiralık" }
]
```

## Frontend verification (manual)
1. Open `http://localhost:3002/marketplace/search/11` (car-rental) or use category selector.
2. Set `brand=Mercedes` or `seats` min/max and click **Search**.
3. Verify network request to `.../api/v1/listings` includes `filters[...]` parameters (not `attrs[...]`).

## Files changed
- `work/pazar/routes/api/03b_listings_read.php`
- `work/marketplace-web/src/pages/ListingsSearchPage.vue`
- `docs/PROOFS/wp75_filters_array_pass.md`

