# Marketplace Listings E2E Gate (Runbook)

This runbook documents end-to-end validation for marketplace listings.

## Gate scripts

- `ops/product_api_smoke.ps1` (create → publish → show)
- `ops/product_e2e_contract.ps1` (wrapper → runs live probes)

## Notes

- Local dev: missing credentials → WARN is acceptable (tests may skip store-scope parts).
- CI: credentials should be provided so the smoke flow PASSes.

