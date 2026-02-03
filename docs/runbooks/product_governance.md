# Marketplace Listings Governance (Runbook)

This repo’s “product/listings” governance is **marketplace-only**.

## Canonical references

- Terminology lock: `docs/SPEC.md` + `docs/CURRENT.md`
- Spine summary: `docs/PRODUCT/PRODUCT_API_SPINE.md`
- OpenAPI: `docs/PRODUCT/openapi.yaml`

## Gates (what must stay true)

- **World ownership lock**: Pazar declares only `marketplace` in `work/pazar/config/worlds.php`.
- **Listings routing shape**: listings endpoints are not world-prefixed.

## Ops scripts

- `ops/product_contract.ps1` (doc contract)
- `ops/product_contract_check.ps1` (live probes)
- `ops/product_read_path_check.ps1` (read path)
- `ops/product_api_smoke.ps1` (create → publish → show; WARN if credentials missing locally)
- `ops/product_spine_check.ps1` (wrapper)

