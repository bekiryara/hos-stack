# Marketplace Listings “CRUD” Gate (Runbook)

The historical full CRUD (PATCH/DELETE) gate is **retired** for listings.

Current canonical flow is:
- create draft
- publish
- read (list/show)

## Gate script

- `ops/product_api_crud_e2e.ps1` (wrapper → runs `ops/product_api_smoke.ps1`)

## Endpoints covered

- `POST /api/v1/listings`
- `POST /api/v1/listings/{id}/publish`
- `GET /api/v1/listings`
- `GET /api/v1/listings/{id}`

