# Product Spine Governance Gate Runbook

**Purpose**: Validates Commerce Product API spine: routes, middleware, world/tenant boundaries, write-path lock. Ensures Commerce read-path is implemented correctly and write-path is locked (501 NOT_IMPLEMENTED or allowlisted).

**Script**: `ops/product_spine_check.ps1`

## What It Checks

1. **Check 1: Commerce READ Routes Exist**: Validates GET `/api/v1/commerce/listings` and GET `/api/v1/commerce/listings/{id}` routes exist in snapshot. Accepts `{id}` parameter variations (`{listing}`, `{id}`, etc.). FAIL if missing.
2. **Check 2: Middleware Contract**: Validates read routes have required middleware: `auth.any`, `resolve.tenant` (or `tenant.resolve` alias), `tenant.user` (or `ensure.tenant.user` alias). FAIL if missing any.
3. **Check 3: Write-Path Lock**: Validates POST/PUT/PATCH/DELETE endpoints under `/api/v1/commerce/listings*` are either: a) not present in snapshot, b) present but routed to stub returning 501 NOT_IMPLEMENTED, or c) explicitly allowlisted in `ops/policy/product_spine_allowlist.json`. FAIL if violated (snapshot-only approach).
4. **Check 4: World Boundary Evidence**: Validates world boundary enforcement. Snapshot-based: checks if action contains "World" namespace or "Commerce" controller. Fallback: minimal file I/O check for `forWorld('commerce')` in ListingController.php. WARN-only if cannot be proven.
5. **Check 5: Tenant Boundary Evidence**: Validates tenant scoping. Minimal file I/O check for `forTenant` or `tenant_id` filter in ListingController.php. WARN-only if cannot be proven.

## How to Run

### Local (Interactive)

```powershell
.\ops\product_spine_check.ps1
```

### CI (Automated)

The gate runs automatically via `ops/ops_status.ps1` (integrated as BLOCKING check).

## Expected Output

### PASS

```
=== PRODUCT SPINE CHECK ===
Timestamp: 2026-01-11 HH:MM:SS

Step 1: Reading routes snapshot
  [OK] Routes snapshot loaded

Step 2: Reading allowlist
  [OK] No allowlist file (write endpoints must return 501 NOT_IMPLEMENTED)

Step 3: [A1] Commerce Read Surface
  [PASS] A1: Commerce Read Surface: GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id} found

Step 4: [A2] Read Routes Protection
  [PASS] A2: Read Routes Protection: Required middleware present: auth.any, resolve.tenant, tenant.user

Step 5: [A3] World Boundary Evidence
  [PASS] A3: World Boundary Evidence: World boundary enforcement found (forWorld('commerce') or equivalent)

Step 6: [A4] Write-Path Lock
  [PASS] A4: Write-Path Lock: All write endpoints return 501 NOT_IMPLEMENTED or are allowlisted

Step 7: [A5] Cross-Tenant Leakage Guard
  [PASS] A5: Cross-Tenant Leakage Guard: Tenant scoping found (forTenant or tenant_id filter)

Step 8: [A6] Disabled World Policy
  [PASS] A6: Disabled World Policy: No routes found for disabled worlds

=== PRODUCT SPINE CHECK RESULTS ===

Check                                    Status Notes
--------------------------------------------------------------------------------
A1: Commerce Read Surface                [PASS] GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id} found
A2: Read Routes Protection                [PASS] Required middleware present: auth.any, resolve.tenant, tenant.user
A3: World Boundary Evidence               [PASS] World boundary enforcement found (forWorld('commerce') or equivalent)
A4: Write-Path Lock                       [PASS] All write endpoints return 501 NOT_IMPLEMENTED or are allowlisted
A5: Cross-Tenant Leakage Guard            [PASS] Tenant scoping found (forTenant or tenant_id filter)
A6: Disabled World Policy                 [PASS] No routes found for disabled worlds

OVERALL STATUS: PASS

All Commerce Product API spine checks passed.
  [PASS] food - GET /api/v1/food/listings
  [PASS] food - GET /api/v1/food/listings/{id}
  [PASS] food - POST /api/v1/food/listings
  [PASS] food - PATCH /api/v1/food/listings/{id}
  [PASS] food - DELETE /api/v1/food/listings/{id}
  Checking enabled world: rentals
  [PASS] rentals - GET /api/v1/rentals/listings
  [PASS] rentals - GET /api/v1/rentals/listings/{id}
  [PASS] rentals - POST /api/v1/rentals/listings
  [PASS] rentals - PATCH /api/v1/rentals/listings/{id}
  [PASS] rentals - DELETE /api/v1/rentals/listings/{id}

Step 4: Validating disabled worlds (no routes)
  Checking disabled world: services
  [PASS] services - No /api/v1/services/* routes
  Checking disabled world: real_estate
  [PASS] real_estate - No /api/v1/real_estate/* routes
  Checking disabled world: vehicle
  [PASS] vehicle - No /api/v1/vehicle/* routes

=== PRODUCT SPINE GOVERNANCE RESULTS ===

World      Surface                              Middleware                    Status Notes
--------------------------------------------------------------------------------
commerce   GET /api/v1/commerce/listings        auth.any, resolve.tenant...  [PASS] Route exists with required middleware
commerce   GET /api/v1/commerce/listings/{id}   auth.any, resolve.tenant...  [PASS] Route exists with required middleware
commerce   POST /api/v1/commerce/listings       auth.any, resolve.tenant...  [PASS] Route exists with required middleware
commerce   PATCH /api/v1/commerce/listings/{id} auth.any, resolve.tenant...  [PASS] Route exists with required middleware
commerce   DELETE /api/v1/commerce/listings/{id} auth.any, resolve.tenant... [PASS] Route exists with required middleware
food       GET /api/v1/food/listings            auth.any, resolve.tenant...  [PASS] Route exists with required middleware
food       GET /api/v1/food/listings/{id}        auth.any, resolve.tenant...  [PASS] Route exists with required middleware
food       POST /api/v1/food/listings           auth.any, resolve.tenant...  [PASS] Route exists with required middleware
food       PATCH /api/v1/food/listings/{id}      auth.any, resolve.tenant...  [PASS] Route exists with required middleware
food       DELETE /api/v1/food/listings/{id}     auth.any, resolve.tenant... [PASS] Route exists with required middleware
rentals    GET /api/v1/rentals/listings         auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    GET /api/v1/rentals/listings/{id}    auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    POST /api/v1/rentals/listings        auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    PATCH /api/v1/rentals/listings/{id}  auth.any, resolve.tenant...  [PASS] Route exists with required middleware
rentals    DELETE /api/v1/rentals/listings/{id}  auth.any, resolve.tenant...  [PASS] Route exists with required middleware
services   No /api/v1/services/* routes          [PASS] No routes found (disabled world policy OK)
real_estate No /api/v1/real_estate/* routes      [PASS] No routes found (disabled world policy OK)
vehicle    No /api/v1/vehicle/* routes          [PASS] No routes found (disabled world policy OK)

OVERALL STATUS: PASS

All enabled worlds have required routes and middleware. Disabled worlds have no routes.
```

**Exit Code**: 0

### WARN

```
=== PRODUCT SPINE GOVERNANCE CHECK ===
...

Step 2: Reading routes snapshot
  [WARN] Routes snapshot not found: ops\snapshots\routes.pazar.json
  Remediation: Run ops/routes_snapshot.ps1 to generate snapshot

Step 3: Validating enabled worlds
  Checking enabled world: commerce
  [WARN] commerce - GET /api/v1/commerce/listings: Route found in filesystem (middleware verification requires snapshot)

OVERALL STATUS: WARN

Note: Some checks were skipped or inconclusive. Generate routes snapshot for full validation.
```

**Exit Code**: 2

**Remediation**: Run `ops/routes_snapshot.ps1` to generate routes snapshot.

### FAIL

```
=== PRODUCT SPINE CHECK ===
...

Step 4: [A2] Read Routes Protection
  [FAIL] A2: Read Routes Protection: Missing middleware: /api/v1/commerce/listings: tenant.user

Step 6: [A4] Write-Path Lock
  [FAIL] A4: Write-Path Lock: Write endpoints not locked: POST /api/v1/commerce/listings. Must return 501 NOT_IMPLEMENTED or be allowlisted.

Step 8: [A6] Disabled World Policy
  [FAIL] A6: Disabled World Policy: Disabled worlds have routes: services: 1 route(s)

OVERALL STATUS: FAIL

Remediation:
1. Ensure all enabled worlds have required routes: GET/POST/PATCH/DELETE /api/v1/{world}/listings
2. Ensure routes have required middleware: auth.any, resolve.tenant, tenant.user
3. Ensure disabled worlds have NO routes (disabled-world policy)
4. Run ops/routes_snapshot.ps1 to generate snapshot
```

**Exit Code**: 1

**Remediation**:
1. Check `work/pazar/routes/api.php` for missing routes or incorrect middleware
2. Ensure disabled worlds have NO routes (remove any `/api/v1/{disabled_world}/*` routes)
3. Run `ops/routes_snapshot.ps1` to regenerate snapshot

## Troubleshooting

### Routes Snapshot Missing

**Symptom**: WARN status, "Routes snapshot not found"

**Solution**: Run `ops/routes_snapshot.ps1` to generate snapshot.

### Missing Required Routes

**Symptom**: FAIL status, "Route not found"

**Solution**:
1. Check `work/pazar/routes/api.php` for route definitions
2. Ensure routes match pattern: `GET/POST/PATCH/DELETE /api/v1/{world}/listings` and `GET /api/v1/{world}/listings/{id}`
3. Verify enabled worlds in `work/pazar/config/worlds.php`

### Missing Required Middleware

**Symptom**: FAIL status, "Missing middleware"

**Solution**:
1. Check `work/pazar/routes/api.php` for middleware configuration
2. Ensure routes are under `Route::middleware(['auth.any', 'resolve.tenant', 'tenant.user'])`
3. Run `ops/routes_snapshot.ps1` to regenerate snapshot

### Disabled World Has Routes

**Symptom**: FAIL status, "Disabled world has routes"

**Solution**:
1. Remove any routes for disabled worlds (e.g., `/api/v1/services/*`, `/api/v1/real_estate/*`, `/api/v1/vehicle/*`)
2. Verify disabled worlds in `work/pazar/config/worlds.php`
3. Run `ops/routes_snapshot.ps1` to regenerate snapshot

### Config File Not Found

**Symptom**: FAIL status, "config/worlds.php not found"

**Solution**: Ensure `work/pazar/config/worlds.php` exists with enabled/disabled arrays.

## Related Documentation

- `docs/product/PRODUCT_API_SPINE.md` - Product API contract
- `docs/PROOFS/product_spine_governance_pass.md` - Acceptance tests
- `docs/RULES.md` - Rule 54: Product spine governance gate PASS required

## Incident Response

If Product Spine Governance Check fails in CI:
1. Check PR description for route/middleware changes
2. Verify `work/pazar/routes/api.php` has correct middleware for enabled worlds
3. Verify disabled worlds have NO routes
4. Run `ops/routes_snapshot.ps1` locally to regenerate snapshot
5. Re-run CI check

