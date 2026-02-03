# Pazar Marketplace API Spine (Canonical)

> **OpenAPI (single source of truth)**: `docs/PRODUCT/openapi.yaml`

This repository previously contained an experimental **multiworld** “product spine”.

That model is **retired** and must not be used as reference.

## Canonical Terminology (locked)

- **World (`world_key` / `ctx.world`)**: H-OS world directory keys like `core`, `marketplace`, `messaging`, `social`.
- **Pazar service world**: Pazar is the `marketplace` world.
- **Catalog vertical roots (category roots, NOT worlds)**: `service`, `real_estate`, `vehicle` (also seen as slug `real-estate`).
- **Transaction mode**: `sale | rental | reservation` (cross-vertical intent for listings).

See `docs/SPEC.md` (§4.1.1 Terminology Lock) and `docs/CURRENT.md`.

## World enablement (Pazar ownership lock)

Pazar must declare only its own world enablement locally:

- `work/pazar/config/worlds.php`: enabled `[marketplace]`, disabled `[]`
- `work/pazar/WORLD_REGISTRY.md` must match it exactly (conformance gate).

## Canonical API Surface (Pazar)

Pazar API routes are **not** namespaced as `/api/v1/{world}/...`.

### Catalog (guest)

- `GET /api/v1/categories`
- `GET /api/v1/categories/{id}/filter-schema`

### Listings (marketplace)

- `POST /api/v1/listings`
  - Requires store persona + `X-Active-Tenant-Id`
  - Authorization is optional in GENESIS depending on `GENESIS_ALLOW_UNAUTH_STORE`
- `POST /api/v1/listings/{id}/publish`
  - Requires store persona + `X-Active-Tenant-Id`
- `GET /api/v1/listings` (guest search/read)
- `GET /api/v1/listings/{id}` (guest read)

### Transactions (marketplace)

See `work/pazar/routes/api.php` which includes:

- reservations: `work/pazar/routes/api/04_reservations.php`
- orders: `work/pazar/routes/api/05_orders.php`
- rentals: `work/pazar/routes/api/06_rentals.php`

## Ops / Gates (real measurement)

- Read path check: `ops/product_read_path_check.ps1` (validates `/api/v1/listings`)
- Smoke gate: `ops/product_api_smoke.ps1` (creates + publishes a listing using real payload/headers)
- Perf guard: `ops/product_perf_guard.ps1` (measures `GET /api/v1/listings`)

