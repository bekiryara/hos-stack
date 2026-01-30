# WP-NEXT: HOS API — Split auth/me/tenant Routes (NO BEHAVIOR CHANGE)

**Timestamp:** 2026-02-01  
**Summary:** Split auth/me/tenant routes from monolithic `auth_me_tenants.js` into domain modules; behavior unchanged.

## Changes

- **Deleted:** `src/routes/v1/auth_me_tenants.js` (700+ lines)
- **New modules:**
  - `src/routes/v1/request_auth.js` — shared `getBearer`, `requireAuth`, `requireRole` (uses `verifyAccessToken`)
  - `src/routes/v1/auth_routes.js` — `registerV1AuthRoutes`: `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/google/start`, `/auth/google/callback`
  - `src/routes/v1/me_routes.js` — `registerV1MeRoutes`: `/me`, `/me/orders`, `/me/rentals`, `/me/reservations`, `/me/memberships`
  - `src/routes/v1/tenant_routes.js` — `registerV1TenantRoutes`: `POST /tenants`, `POST /tenants/v2`, `GET /tenants/:tenant_id/memberships/me`
- **Updated:** `src/routes/v1/index.js` — imports and registers the three new modules in place of `registerV1AuthMeTenantRoutes`.

Route surface, status codes, response shapes, auth checks, and validation are unchanged.

## Commands / Evidence

From `D:\stack\work\hos\services\api`:

```text
npm test  => 18 pass, 7 fail (failures unrelated to split: metrics, policy/decide, request_id, remote_v1_health_and_actions, register_world_enforcement)
```

From repo root (run after resolving pre-existing test failures if full PASS required):

```text
.\ops\run_wp_next_local_gates.ps1   => PASS
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS
```

(Record actual PASS lines after running gates and ops_run.)
