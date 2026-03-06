# Admin Development Guide

## Scope
- This guide defines how admin development must be done in this repository.
- Admin SSOT is H-OS.
- Marketplace (Pazar) must not own platform-admin surface.

## Canonical Entry
- Single admin entry URL: `/admin`
- Do not introduce alternate public admin entries.
- Legacy admin URL variants are retired for active development.

## Where Admin Code Lives
- H-OS Web UI:
  - `work/hos/services/web/src/features/admin/`
- H-OS API:
  - `work/hos/services/api/src/routes/v1/admin/` (target modular path)
  - `work/hos/services/api/src/services/admin/` (target service path)

## Current Frontend Layout
- `api/`: admin HTTP client wrappers
- `layout/`: shared admin shell components
- `pages/`: admin screens (`control center`, `tenants`, `users`, `memberships`, `audit`)
- `routes.tsx`: `/admin*` route resolution

## Development Discipline
- Keep changes small and modular (feature-based).
- Do not grow `ui/App.tsx` with admin business logic.
- Add admin features under `features/admin/*`.
- Preserve SSOT boundary:
  - Allowed: `/v1/admin/*` in H-OS API
  - Forbidden in Pazar: `/admin*`, `/panel*`, platform admin surfaces
- Verify before merge:
  - Web build pass
  - Relevant ops checks pass

## Immediate Next Steps
- Wire `Memberships` page to live API.
- Split admin API surface into modular route files under `routes/v1/admin/`.
- Add admin UI smoke/e2e coverage for `/admin` flow.
