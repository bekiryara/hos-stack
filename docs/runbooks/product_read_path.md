# Marketplace Listings Read-Path (Runbook)

## Reality lock

- Listings API is **marketplace-only** and **not world-prefixed**.
- Canonical endpoints:
  - `GET /api/v1/listings`
  - `GET /api/v1/listings/{id}`

## Gate script

- `ops/product_read_path_check.ps1`

## How to run

```powershell
.\ops\product_read_path_check.ps1
```

## Expected behavior

- `GET /api/v1/listings` is **guest-accessible** and should return HTTP 200.
- `GET /api/v1/listings/{id}` should return:
  - 200 for an existing listing
  - 404 for a missing listing

