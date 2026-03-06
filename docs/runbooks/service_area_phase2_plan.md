# Service Area Phase-2 Plan (Preparation Only)

Status: planning only, not active rollout.

## Goal

Prepare deterministic support for `location_scope=service_area` without enabling broad category rollout yet.

## Current Repo Reality (2026-03-06)

- Service-area create/edit UI scaffold exists in `CreateListingForm.vue`.
- Backend write/read normalization exists:
  - `routes/api/03a_listings_write.php` (`location.service_area` validation + sync)
  - `routes/api/03b_listings_read.php` (service-area projection)
- Persistence table exists: `listing_service_areas`.
- Policy activation is intentionally narrow:
  - Allowed active service-area row: `food:sale`.
  - No broad service-area category rollout in this phase.

## Scope (Phase-2 Prep)

- Keep current point-address flow stable.
- Define service-area payload and validation contract clearly.
- Add check coverage before any large category activation.

## Planned Contract

`location.service_area[]` rows:

- `city` (required)
- `all_districts` (bool)
- `districts[]` (required when `all_districts=false`)

## Backend Readiness Checklist

1. Write-side strict validation already deterministic.
2. Read-side projection for service_area rows verified.
3. Search/filter behavior for service_area defined and testable.

## UI Readiness Checklist

1. Service-area editor row add/remove deterministic.
2. City/district options source remains HOS-only.
3. Error messages are explicit for empty/invalid rows.

## Gate Before Activation

Before enabling service_area-heavy categories:

1. Add/extend matrix rows in `policy_variant_matrix_check`.
2. Run `.\ops\ops.ps1 service-area-phase2` (prep contract guard).
3. Run `.\ops\ops.ps1 run -Profile Release`
4. Ensure route/schema snapshots PASS.
