# Marketplace Listings Spine Governance (Runbook)

This runbook documents how we govern the **current** Pazar listings spine.

## Reality lock (canonical)

- **Pazar world**: `marketplace` (H-OS world key)
- **Listings API shape**: `/api/v1/listings` (not world-prefixed)
- **Catalog roots**: category vertical roots (tree-only), not worlds

Canonical docs:
- `docs/SPEC.md` (Terminology Lock)
- `docs/CURRENT.md`
- `docs/PRODUCT/PRODUCT_API_SPINE.md` (canonical spine summary; references OpenAPI)

## Gates (what to run)

- **Spine wrapper**: `ops/product_spine_check.ps1`
  - Runs world governance + read-path + smoke (create→publish→show).
- **Doc contract**: `ops/product_contract.ps1`
  - Ensures spine doc matches reality (no retired multiworld routing described).
- **Live probes**: `ops/product_contract_check.ps1`
  - Probes `/api/world/status`, `/api/v1/categories`, `/api/v1/listings`.

## Local commands

```powershell
.\ops\ops.ps1 product-contract
.\ops\ops.ps1 product-read-path
.\ops\ops.ps1 product-api-smoke
```

