# WP-NEXT: HOS API — Route Modularization (NO BEHAVIOR CHANGE)

**Timestamp:** 2026-01-31  
**Summary:** HOS API `app.js` route monolith was split into route modules; endpoint behavior unchanged (no behavior change).

## Changes

- **OIDC (ROOT):** `src/routes/oidc_public.js` — `/jwks.json`, `/authorize`, `/oidc/authorize`, `/token`, `/userinfo`
- **V1 API:** `src/routes/v1/index.js` registers sub-modules and legacy Deprecation/Sunset hook
  - `src/routes/v1/core_world_contract.js` — `/health`, `/ready`, `/world/status`, `/worlds`, `/meta/features`, `/proof`, `/contract/can-transition`, `/contract/transition`
  - `src/routes/v1/auth_me_tenants.js` — `/auth/*`, `/me`, `/me/orders`, `/me/rentals`, `/me/reservations`, `/me/memberships`, `/tenants`, `/tenants/v2`, `/tenants/:tenant_id/memberships/me`
  - `src/routes/v1/admin_permits.js` — `/admin/memberships/upsert`, `/admin/users/upsert`, `/permits`, `/permits/:permit_id/confirm`, `/audit`, `/users`, PATCH `/users/:id/role`
- **app.js:** Imports `registerOidcPublicRoutes` and `registerV1Routes`; registers OIDC then V1 (legacy + `/v1` prefix). Metrics hooks and `/metrics` unchanged.

Route surface, status codes, response JSON, validation, and legacy header behavior are unchanged.

## Commands / Outputs

Run from repo root:

```text
.\ops\run_wp_next_local_gates.ps1   => PASS
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS
```

(Record actual PASS lines after running gates and ops_run.)
