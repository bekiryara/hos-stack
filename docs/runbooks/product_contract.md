# Marketplace Listings Contract (Runbook)

This runbook describes the **current** contract checks for marketplace listings.

## Doc contract (static)

- `ops/product_contract.ps1`
  - Ensures `docs/PRODUCT/PRODUCT_API_SPINE.md` matches reality (and references OpenAPI).

## Live probes (runtime)

- `ops/product_contract_check.ps1`
  - Probes:
    - `GET /api/world/status` (must report `marketplace`)
    - `GET /api/v1/categories`
    - `GET /api/v1/listings`

## How to run

```powershell
.\ops\product_contract.ps1
.\ops\product_contract_check.ps1
```

