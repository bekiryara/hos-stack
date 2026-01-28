# WP-69: Catalog + Search + Frontend Wiring (Schema-driven, No Duplication) — PASS

Timestamp: 2026-01-28

## Goal
- Frontend `/search/:categoryId?` uses API-driven categories + filter-schema (no hardcoded vertical logic).
- Frontend builds correct `/api/v1/listings` query using `category_id`, `status=published`, and `attrs[...]` (incl `_min/_max` ranges).
- Deterministic demo seed exists for immediate testing (bando/boat/car/kebab).

## Seed (idempotent)

Command:

```text
docker compose exec -T pazar-app php artisan db:seed --class=CatalogSpineSeeder
```

Output:

```text
INFO  Seeding database.

Inserted attributes: capacity_max, guests_max, party_size, price_min, seats, cuisine, city, brand, spicy_level
Upserted root categories: vehicle, real-estate, service
Upserted branch categories (expanded roots + example leaves).
Inserted filter schemas:
  - wedding-hall: capacity_max (required, range)
  - restaurant: cuisine (optional, select)
  - bando: capacity_max (optional, range), city (optional, exact)
  - car-rental: seats (optional, range)
  - car-rental: brand (optional, exact)
  - headphones: price_min (required, range)
  - hotel-room: guests_max (required, range)
  - apartment-sale: price_min (required, range)
  - boat-rental: seats (optional, range)
  - kebab: cuisine (optional, select), spicy_level (optional, range)
Inserted demo listings: bando, boat rental, car rental, kebab
Catalog spine seeding completed.
```

## API checks (curl)

### Categories tree (`GET /api/v1/categories`)

```text
curl.exe -s http://localhost:8080/api/v1/categories
```

Response (trimmed):

```json
[
  {
    "id": 4,
    "slug": "vehicle",
    "children": [
      { "slug": "car", "children": [ { "id": 11, "slug": "car-rental" } ] },
      { "slug": "boat", "children": [ { "id": 15, "slug": "boat-rental" } ] }
    ]
  },
  { "id": 5, "slug": "real-estate" },
  {
    "id": 1,
    "slug": "service",
    "children": [
      { "slug": "events", "children": [ { "id": 22, "slug": "bando" } ] },
      { "slug": "food", "children": [ { "id": 23, "slug": "kebab" } ] }
    ]
  }
]
```

### Filter schema #1 (`GET /api/v1/categories/11/filter-schema`) — car-rental

```text
curl.exe -s http://localhost:8080/api/v1/categories/11/filter-schema
```

Response:

```json
{
  "category_id": 11,
  "category_slug": "car-rental",
  "filters": [
    { "attribute_key": "seats", "value_type": "number", "filter_mode": "range", "ui_component": "number" },
    { "attribute_key": "brand", "value_type": "string", "filter_mode": "exact", "ui_component": "text" }
  ]
}
```

### Filter schema #2 (`GET /api/v1/categories/23/filter-schema`) — kebab

```text
curl.exe -s http://localhost:8080/api/v1/categories/23/filter-schema
```

Response:

```json
{
  "category_id": 23,
  "category_slug": "kebab",
  "filters": [
    { "attribute_key": "cuisine", "value_type": "enum", "filter_mode": "exact", "ui_component": "select", "rules": { "options": ["Turkish","Italian","Chinese","Japanese"] } },
    { "attribute_key": "spicy_level", "value_type": "number", "filter_mode": "range", "ui_component": "number" }
  ]
}
```

### Descendant category behavior (parent returns child listings)

Vehicle root (id `4`) returns listings from descendant categories (car-rental + boat-rental):

```text
powershell -NoProfile -Command "(Invoke-RestMethod -Uri 'http://localhost:8080/api/v1/listings?category_id=4&status=published&per_page=50' -TimeoutSec 10).title"
```

Output (proof includes demo titles):

```text
Mercedes Kiralık
Rüyam Tekne Kiralama
```

### attrs exact match narrows results

```text
powershell -NoProfile -Command "(Invoke-RestMethod -Uri 'http://localhost:8080/api/v1/listings?category_id=11&status=published&per_page=50&attrs%5Bbrand%5D=Mercedes' -TimeoutSec 10).title"
```

Output:

```text
Mercedes Kiralık
```

### Numeric min/max range works

Example: max filter for bando (`capacity_max_max=10`) keeps only small-capacity listings:

```text
powershell -NoProfile -Command "(Invoke-RestMethod -Uri 'http://localhost:8080/api/v1/listings?category_id=22&status=published&per_page=50&attrs%5Bcapacity_max_max%5D=10' -TimeoutSec 10).title"
```

Output:

```text
Bando Presto 4 kişi
```

## Frontend manual proof (browser)
1. Open `http://localhost:3002/marketplace/search` (or `.../search/{categoryId}`).
2. Pick a category from the selector (e.g. **car-rental** or **kebab**) → filters load from `/api/v1/categories/{id}/filter-schema`.
3. Change filters → “Applied” list updates; **Clear filters** resets filter state.
4. Click **Search** → listings render; query is built from schema-driven filter keys (including `_min/_max` for range).

## Gates (PASS)

### `ops/conformance.ps1` (PASS)
```text
[PASS] CONFORMANCE PASSED - All architecture rules validated
```

### `ops/frontend_smoke.ps1` (PASS)
```text
=== FRONTEND SMOKE TEST: PASS ===
```

### `ops/public_ready_check.ps1` (PASS)
```text
PASS: Secret scan - no secrets detected
PASS: Git working directory is clean
=== PUBLIC READY CHECK: PASS ===
```

## Files changed
- `work/pazar/database/seeders/CatalogSpineSeeder.php`
- `work/pazar/routes/api/02_catalog.php`
- `work/marketplace-web/src/components/FiltersPanel.vue`
- `work/marketplace-web/src/pages/ListingsSearchPage.vue`
- `docs/PROOFS/wp69_catalog_search_frontend_alignment_pass.md`

