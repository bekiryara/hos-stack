# Product Spine Gate Runbook

**Purpose**: Validates Product API spine through static checks (routes, middleware) and end-to-end tests (create → list → show + tenant boundary).

**Scripts**: 
- `ops/product_spine_check.ps1` - Static checks (routes, middleware, write-path lock)
- `ops/product_spine_e2e_check.ps1` - E2E tests (create → list → show + tenant boundary)

## What It Checks

1. **Enabled Worlds Discovery**: Reads enabled worlds from `work/pazar/config/worlds.php`
2. **Route Discovery**: Validates routes exist for each enabled world:
   - `GET /api/v1/{world}/listings`
   - `GET /api/v1/{world}/listings/{id}`
3. **Middleware Policy**: Validates required middleware is present:
   - `auth.any` (authentication required)
   - `resolve.tenant` (tenant context resolution)
   - `tenant.user` (tenant user validation)

## How to Run

### Local (Interactive)

```powershell
.\ops\product_spine_check.ps1
```

### CI (Automated)

The gate runs automatically on:
- Pull requests to `main` or `develop`
- Pushes to `main` or `develop`

See `.github/workflows/product-spine.yml` for CI configuration.

## Expected Output

### PASS

```
=== PRODUCT SPINE CHECK (Multi-World) ===
Timestamp: 2026-01-11 HH:MM:SS

Step 1: Reading enabled worlds from config/worlds.php
  [PASS] Enabled Worlds: Found 3 enabled world(s): commerce, food, rentals

Step 2: Route Discovery
  [OK] Routes snapshot loaded

Step 3: Validating routes and middleware for enabled worlds
  Checking world: commerce
  [PASS] commerce - Routes Exist: GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id} found
  [PASS] commerce - Middleware: Required middleware present: auth.any, resolve.tenant, tenant.user
  Checking world: food
  [PASS] food - Routes Exist: GET /api/v1/food/listings and GET /api/v1/food/listings/{id} found
  [PASS] food - Middleware: Required middleware present: auth.any, resolve.tenant, tenant.user
  Checking world: rentals
  [PASS] rentals - Routes Exist: GET /api/v1/rentals/listings and GET /api/v1/rentals/listings/{id} found
  [PASS] rentals - Middleware: Required middleware present: auth.any, resolve.tenant, tenant.user

=== PRODUCT SPINE CHECK RESULTS ===

Check                                    Status Notes
--------------------------------------------------------------------------------
Enabled Worlds                           [PASS] Found 3 enabled world(s): commerce, food, rentals
commerce - Routes Exist                   [PASS] GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id} found
commerce - Middleware                     [PASS] Required middleware present: auth.any, resolve.tenant, tenant.user
food - Routes Exist                       [PASS] GET /api/v1/food/listings and GET /api/v1/food/listings/{id} found
food - Middleware                         [PASS] Required middleware present: auth.any, resolve.tenant, tenant.user
rentals - Routes Exist                    [PASS] GET /api/v1/rentals/listings and GET /api/v1/rentals/listings/{id} found
rentals - Middleware                      [PASS] Required middleware present: auth.any, resolve.tenant, tenant.user

OVERALL STATUS: PASS

All enabled worlds have required routes and middleware.
```

**Exit Code**: 0

### WARN

```
=== PRODUCT SPINE CHECK (Multi-World) ===
...

Step 2: Route Discovery
  [WARN] Routes snapshot not found: ops\snapshots\routes.pazar.json
  Attempting to generate snapshot...
  [WARN] Error generating snapshot: ...

Step 3: Validating routes and middleware for enabled worlds
  Checking world: commerce
  [PASS] commerce - Routes Exist: Routes found in filesystem (middleware verified at runtime)
  [WARN] commerce - Middleware: Middleware verification requires routes snapshot or runtime check

OVERALL STATUS: WARN

Note: Some checks were skipped or inconclusive. Generate routes snapshot for full validation.
```

**Exit Code**: 2

**Remediation**: Run `ops/routes_snapshot.ps1` to generate routes snapshot.

### FAIL

```
=== PRODUCT SPINE CHECK (Multi-World) ===
...

Step 3: Validating routes and middleware for enabled worlds
  Checking world: food
  [FAIL] food - Routes Exist: GET /api/v1/food/listings route not found
  [FAIL] food - Middleware: Routes not found, cannot verify middleware

OVERALL STATUS: FAIL

Remediation:
1. Ensure all enabled worlds have routes: GET /api/v1/{world}/listings and GET /api/v1/{world}/listings/{id}
2. Ensure routes have required middleware: auth.any, resolve.tenant, tenant.user
3. Run routes_snapshot.ps1 to generate routes snapshot
```

**Exit Code**: 1

**Remediation**:
1. Check `work/pazar/routes/api.php` for missing routes
2. Ensure routes are under `auth.any + resolve.tenant + tenant.user` middleware
3. Run `ops/routes_snapshot.ps1` to regenerate snapshot

## Product Spine E2E Smoke Test

The `ops/product_spine_smoke.ps1` script provides a comprehensive end-to-end smoke test for the Product API spine across all enabled worlds (commerce, food, rentals).

### Purpose

Validates:
1. **Read-path surface exists**: All GET endpoints return 401/403 when unauthorized
2. **Write governance exists**: All write endpoints (POST/PATCH/DELETE) are protected and return 501 NOT_IMPLEMENTED when authorized
3. **Contract compliance**: All responses include standard JSON envelope with `ok`, `error_code`, `message`, and `request_id`

### Running the Smoke Test

**Basic (unauthorized checks only):**
```powershell
.\ops\product_spine_smoke.ps1
```

**With authentication (full E2E):**
```powershell
$env:PRODUCT_TEST_EMAIL = "test@example.com"
$env:PRODUCT_TEST_PASSWORD = "password123"
$env:PRODUCT_TEST_TENANT_ID = "tenant-a-uuid"
.\ops\product_spine_smoke.ps1
```

**Or with bearer token:**
```powershell
$env:PRODUCT_TEST_TOKEN = "your-bearer-token"
$env:PRODUCT_TEST_TENANT_ID = "tenant-a-uuid"
.\ops\product_spine_smoke.ps1
```

### Required Environment Variables

For authenticated checks (optional, but recommended):
- `PRODUCT_TEST_TOKEN` (Bearer token) OR
- `PRODUCT_TEST_EMAIL` + `PRODUCT_TEST_PASSWORD` (for login flow)
- `PRODUCT_TEST_TENANT_ID` (tenant UUID)

If credentials are missing, authenticated checks are skipped with WARN (non-blocking).

### Expected Output

**PASS (with credentials):**
```
=== PRODUCT SPINE E2E SMOKE TEST ===
Timestamp: 2026-01-11 12:00:00
Base URL: http://localhost:8080

Step 1: Read-path surface (unauthorized access)
  [PASS] GET /api/v1/commerce/listings (unauthorized)
  [PASS] GET /api/v1/food/listings (unauthorized)
  [PASS] GET /api/v1/rentals/listings (unauthorized)

Step 2: Write governance (unauthorized access)
  [PASS] POST /api/v1/commerce/listings (unauthorized)
  [PASS] PATCH /api/v1/commerce/listings/1 (unauthorized)
  [PASS] DELETE /api/v1/commerce/listings/1 (unauthorized)
  [PASS] POST /api/v1/food/listings (unauthorized)
  [PASS] PATCH /api/v1/food/listings/1 (unauthorized)
  [PASS] DELETE /api/v1/food/listings/1 (unauthorized)
  [PASS] POST /api/v1/rentals/listings (unauthorized)
  [PASS] PATCH /api/v1/rentals/listings/1 (unauthorized)
  [PASS] DELETE /api/v1/rentals/listings/1 (unauthorized)

Step 3: Authenticated checks (read-path + write-stub)
  Obtaining token via login...
  [PASS] GET /api/v1/commerce/listings (authenticated)
  [PASS] GET /api/v1/food/listings (authenticated)
  [PASS] GET /api/v1/rentals/listings (authenticated)
  [PASS] POST /api/v1/commerce/listings (authenticated, stub)
  [PASS] PATCH /api/v1/commerce/listings/1 (authenticated, stub)
  [PASS] DELETE /api/v1/commerce/listings/1 (authenticated, stub)
  [PASS] POST /api/v1/food/listings (authenticated, stub)
  [PASS] PATCH /api/v1/food/listings/1 (authenticated, stub)
  [PASS] DELETE /api/v1/food/listings/1 (authenticated, stub)
  [PASS] POST /api/v1/rentals/listings (authenticated, stub)
  [PASS] PATCH /api/v1/rentals/listings/1 (authenticated, stub)
  [PASS] DELETE /api/v1/rentals/listings/1 (authenticated, stub)

=== PRODUCT SPINE SMOKE TEST RESULTS ===

Check                                    Status Notes
-----                                    ------ -----
GET /api/v1/commerce/listings (unauth)   PASS   Status 401, JSON envelope correct
...
POST /api/v1/commerce/listings (auth)    PASS   Status 501, JSON envelope correct (ok:false, error_code: NOT_IMPLEMENTED, request_id present)
...

OVERALL STATUS: PASS
```

**WARN (without credentials):**
```
Step 3: Authenticated checks (read-path + write-stub)
  [WARN] Credentials not set, skipping authenticated checks
  Set PRODUCT_TEST_TOKEN (Bearer token) OR PRODUCT_TEST_EMAIL + PRODUCT_TEST_PASSWORD environment variables to enable.
  Set PRODUCT_TEST_TENANT_ID environment variable (UUID).

OVERALL STATUS: WARN
```

### Troubleshooting

**FAIL: Missing routes**
- Check that routes are defined in `work/pazar/routes/api.php`
- Verify middleware groups are correctly applied

**FAIL: Wrong envelope**
- Check that controllers use `NotImplemented::response()` for write endpoints
- Verify error envelope includes `ok:false`, `error_code: "NOT_IMPLEMENTED"`, `message`, `request_id`

**FAIL: Write endpoints doing DB work**
- Write endpoints should never query the database
- They should immediately return 501 NOT_IMPLEMENTED via `NotImplemented::response()`

**WARN: Credentials missing**
- This is expected in local/dev environments
- Set environment variables to enable full E2E validation

## Troubleshooting

### Routes Snapshot Missing

**Symptom**: WARN status, "Routes snapshot not found"

**Solution**: Run `ops/routes_snapshot.ps1` to generate snapshot.

### Routes Not Found

**Symptom**: FAIL status, "Routes not found"

**Solution**:
1. Check `work/pazar/routes/api.php` for route definitions
2. Ensure routes match pattern: `GET /api/v1/{world}/listings` and `GET /api/v1/{world}/listings/{id}`
3. Verify enabled worlds in `work/pazar/config/worlds.php`

### Middleware Missing

**Symptom**: FAIL status, "Missing middleware"

**Solution**:
1. Check `work/pazar/routes/api.php` for middleware configuration
2. Ensure routes are under `Route::middleware(['auth.any', 'resolve.tenant', 'tenant.user'])`
3. Run `ops/routes_snapshot.ps1` to regenerate snapshot

### Config File Not Found

**Symptom**: FAIL status, "config/worlds.php not found"

**Solution**: Ensure `work/pazar/config/worlds.php` exists with enabled/disabled arrays.

## Related Documentation

- `docs/product/PRODUCT_API_SPINE.md` - Product API contract
- `docs/PROOFS/product_multiworld_read_path_pass.md` - Acceptance tests
- `docs/RULES.md` - Rule 53: Enabled worlds product read-path routes MUST be tenant-scoped

## Incident Response

If Product Spine Check fails in CI:
1. Check PR description for route/middleware changes
2. Verify `work/pazar/routes/api.php` has correct middleware
3. Run `ops/routes_snapshot.ps1` locally to regenerate snapshot
4. Re-run CI check
