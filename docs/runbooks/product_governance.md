# Product Governance Runbook

## Overview

Product Governance Pack ensures Product API contract compliance and catches drift automatically. It consists of two gates:

1. **Product Contract Gate** (`ops/product_contract.ps1`): Static validation of route surface and middleware posture
2. **Product E2E Gate** (`ops/product_e2e.ps1`): Optional end-to-end CRUD validation (requires credentials)

## What It Checks

### Product Contract Gate

**Enabled Worlds (commerce, food, rentals):**
- Required routes exist:
  - `GET /api/v1/<world>/listings`
  - `GET /api/v1/<world>/listings/{id}`
  - `POST /api/v1/<world>/listings`
  - `PATCH /api/v1/<world>/listings/{id}` (or PUT, WARN if PUT)
  - `DELETE /api/v1/<world>/listings/{id}`
- Required middleware present:
  - `auth.any`
  - `tenant.resolve` (or `resolve.tenant`)
  - `tenant.user` (or `ensure.tenant.user`)
- Optional middleware (WARN if missing):
  - `world.resolve`

**Disabled Worlds (services, real_estate, vehicle):**
- **ZERO TOLERANCE**: No routes starting with `/api/v1/<world>/` allowed
- If any route found for disabled world → FAIL

### Product E2E Gate

**For each enabled world:**
- CREATE: POST → 201 CREATED, ok:true, item.id
- LIST: GET → 200 OK, created id found in items
- SHOW: GET → 200 OK, id matches
- UPDATE: PATCH (or PUT) → 200 OK, title updated
- DELETE: DELETE → 204/200 OK
- SHOW (after delete): GET → 404 NOT_FOUND, ok:false, error_code, request_id

**Validates:**
- Response envelopes (ok:true/false, error_code, request_id)
- Status codes match expected values
- Created items appear in list
- Delete removes item (404 on subsequent show)

## How to Run

### Local (Product Contract)

```powershell
.\ops\product_contract.ps1
```

**No Docker required** - static file analysis only.

### Local (Product E2E)

```powershell
# Set environment variables
$env:PRODUCT_TEST_AUTH = "your-bearer-token"
$env:PRODUCT_TENANT_ID = "your-tenant-id"
$env:BASE_URL = "http://localhost:8080"  # Optional, defaults to localhost:8080

.\ops\product_e2e.ps1
```

**Docker required** - stack must be running.

### CI

- **Product Contract**: Runs automatically on PR/push when routes or config change
- **Product E2E**: Runs automatically on PR/push when Pazar code changes (requires secrets)

## Interpretation

### Product Contract

- **PASS**: All enabled worlds have required routes + middleware, disabled worlds have no routes
- **WARN**: Optional middleware missing, PATCH found as PUT
- **FAIL**: Missing required routes, missing required middleware, disabled world has routes

### Product E2E

- **PASS**: All CRUD operations succeed for all enabled worlds
- **WARN**: Credentials missing (skips tests), some operations return unexpected status codes
- **FAIL**: Critical operations fail (CREATE, DELETE), response envelopes invalid

## Common Failures

### Product Contract

**"Missing: GET /listings"**
- **Cause**: Route not found in routes/api.php
- **Fix**: Add route: `Route::get('/listings', [Controller::class, 'index'])`

**"Missing middleware: auth.any"**
- **Cause**: Middleware not applied to route group
- **Fix**: Add middleware to route group: `Route::middleware(['auth.any', ...])->group(...)`

**"Disabled world services has routes"**
- **Cause**: Route found for disabled world (ZERO TOLERANCE)
- **Fix**: Remove route or move to enabled world

### Product E2E

**"CREATE: HTTP 401"**
- **Cause**: Authentication failed
- **Fix**: Check PRODUCT_TEST_AUTH or PRODUCT_TEST_EMAIL/PASSWORD env vars

**"CREATE: HTTP 403"**
- **Cause**: Tenant context missing
- **Fix**: Check PRODUCT_TENANT_ID env var

**"LIST: Created id not found"**
- **Cause**: List endpoint not returning created item (timing or scoping issue)
- **Fix**: Check tenant/world scoping in controller

**"SHOW (after delete): Expected 404, got 200"**
- **Cause**: Delete not working or soft delete not returning 404
- **Fix**: Check delete implementation (should be hard delete or return 404 for soft-deleted items)

## Drift Examples

### Route Drift

**Scenario**: Developer adds route for disabled world `services`

```php
// routes/api.php
Route::prefix('v1/services')->group(function () {
    Route::get('/listings', [Controller::class, 'index']);
});
```

**Detection**: Product Contract Gate FAILs with "Disabled world services has routes"

**Remediation**: Remove route or enable world in config/worlds.php

### Middleware Drift

**Scenario**: Developer removes `tenant.user` middleware from route group

```php
// Before
Route::middleware(['auth.any', 'resolve.tenant', 'tenant.user'])->group(...)

// After (drift)
Route::middleware(['auth.any', 'resolve.tenant'])->group(...)
```

**Detection**: Product Contract Gate FAILs with "Missing middleware: tenant.user"

**Remediation**: Add `tenant.user` back to middleware array

### Response Envelope Drift

**Scenario**: Controller returns response without `ok` field

```php
// Before
return response()->json(['ok' => true, 'item' => $item]);

// After (drift)
return response()->json(['item' => $item]);
```

**Detection**: Product E2E Gate FAILs with "Invalid response format (ok:true expected)"

**Remediation**: Add `ok: true` to response envelope

## Integration

### ops_status.ps1

Both gates are integrated into `ops/ops_status.ps1`:

- **Product Contract**: Blocking check (after Tenant Boundary, before Conformance)
- **Product E2E**: Non-blocking check (optional, WARN if credentials missing)

### CI Workflows

- **`.github/workflows/product-contract.yml`**: Runs on routes/config changes (no Docker)
- **`.github/workflows/product-e2e.yml`**: Runs on Pazar code changes (requires Docker + secrets)

## Troubleshooting

### Product Contract: "Routes file not found"

**Fix**: Ensure `work/pazar/routes/api.php` exists

### Product Contract: "No enabled worlds found"

**Fix**: Check `work/pazar/config/worlds.php` has `'enabled' => [...]` array

### Product E2E: "Credentials missing"

**Fix**: Set `PRODUCT_TEST_AUTH` (Bearer token) or `PRODUCT_TEST_EMAIL` + `PRODUCT_TEST_PASSWORD` + `PRODUCT_TENANT_ID`

### Product E2E: "Connection refused"

**Fix**: Ensure Docker stack is running: `docker compose up -d`

## Related

- **Product Spine Check**: `ops/product_spine_check.ps1` (Commerce-specific, snapshot-driven)
- **Product API Smoke**: `ops/product_api_smoke.ps1` (Write-path smoke tests)
- **Product Read Path Check**: `ops/product_read_path_check.ps1` (Read-path validation)


