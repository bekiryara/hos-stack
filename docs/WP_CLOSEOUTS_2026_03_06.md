# WP Closeouts Addendum (2026-03-06)

Purpose:
- Current closeout layer for recent completed work without rewriting legacy encoded file.
- Canonical historical file remains: `docs/WP_CLOSEOUTS.md`.

## WP-NEXT: Variant-level deterministic policy + matrix gate - PASS

- Outcome:
  - `offer_variant` based effective policy is active across backend + create/edit behavior.
  - Primitive behavior is locked by matrix check discipline.
- Evidence:
  - `ops/_checks/policy_variant_matrix_check.ps1` -> PASS
  - `ops/_checks/category_flow_policy_check.ps1` -> PASS
  - `ops/_checks/listing_contract_check.ps1` -> PASS
  - Commit chain: `73a335c`, `7e90a09`, `0ebea20`, `14941fe`

## WP-NEXT: Pricing Engine v1 totals snapshot spine - PASS

- Outcome:
  - Deterministic `unit/multiplier/total` snapshot on transaction pricing path.
  - Rental/Reservation totals persistence is active.
- Evidence:
  - `ops/_checks/order_contract_check.ps1` -> PASS
  - `ops/_checks/rental_contract_check.ps1` -> PASS
  - `ops/_checks/reservation_contract_check.ps1` -> PASS
  - Commit chain: `16f3463`, `a9fb3bf`, `2108478`, `bd2f786`

## WP-NEXT: HOS-only address transition + firm/listing address spine - PASS

- Outcome:
  - Address options source is HOS.
  - Firm address write/read and listing preload/autofill are stabilized.
- Evidence:
  - `ops/_checks/listing_contract_check.ps1` -> PASS
  - `ops/_checks/pazar_spine_check.ps1` -> PASS
  - Commit chain: `65c4d73`, `de765cd`, `32fe2d6`, `5c57e67`, `839fde1`, `e377249`

## WP-NEXT: Search filters-only + error-envelope cleanup - PASS

- Outcome:
  - Listing search accepts `filters[...]` only (legacy attrs path retired).
  - Legacy dead error-envelope conversion path removed.
- Evidence:
  - `ops/_checks/listing_contract_check.ps1` -> PASS
  - Commit chain: `69505d5`, `8fdbf3f`, `f95febb`

## Notes

- Legacy file `docs/WP_CLOSEOUTS.md` has non-UTF8 encoding; this addendum avoids destructive recoding.
- If needed, a separate controlled encoding normalization can be executed in a dedicated maintenance step.

