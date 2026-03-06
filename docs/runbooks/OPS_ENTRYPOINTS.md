# OPS Entrypoints (Canonical)

Purpose: deterministic command surface for local development and release preparation.

## Daily

1. `.\ops\ops.ps1 up -StackProfile core`
2. `.\ops\ops.ps1 run -Profile Prototype`
3. `.\ops\ops.ps1 status`

## Before Release

1. `.\ops\ops.ps1 run -Profile Release`
2. If WARN/FAIL, fix drift or document warning reason.
3. `.\ops\ops.ps1 ship` only after release profile is PASS/WARN (no FAIL).

## Profiles

- `Prototype`: fast local checks for daily work.
- `Full`: prototype + deeper CI-like status.
- `Release`: deterministic pre-release path:
  - `status -Ci`
  - `routes-snapshot`
  - `schema-snapshot`
  - `release-check -Ci`

## Contract Checks

- `.\ops\ops.ps1 policy-variant-matrix`
- `.\ops\ops.ps1 category-flow-policy`
- `.\ops\ops.ps1 listing-contract`

## Notes

- `Release` profile is the recommended gate path before merge/release.
- Snapshot drift must be resolved before release (`routes` and `schema`).

