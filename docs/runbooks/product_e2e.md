# Product E2E Gate Runbook

## Overview

The Product E2E Gate (`ops/product_e2e.ps1`) validates Product API contract, boundary enforcement, error envelope compliance, request_id traceability, and basic health/metrics endpoints. This gate provides end-to-end validation of the Product API surface for enabled worlds (commerce, food, rentals).

## What It Checks

The gate performs the following validations:

### 1. H-OS Health Check
- **Endpoint:** `GET {HosBaseUrl}/v1/health`
- **Expected:** 200 OK with `ok:true` in JSON response
- **Purpose:** Validates H-OS service is healthy

### 2. Pazar Metrics Endpoint
- **Endpoint:** `GET {BaseUrl}/metrics`
- **Expected:** 200 OK with `Content-Type: text/plain`
- **Purpose:** Validates metrics endpoint is accessible

### 3. Product Spine Validation
- **Endpoint:** `GET {BaseUrl}/api/v1/products` (without world param)
- **Expected:** 422 VALIDATION_ERROR with error envelope (`ok:false`, `error_code`, `request_id`)
- **Purpose:** Validates world parameter is required

### 3b. Product with World but No Auth
- **Endpoint:** `GET {BaseUrl}/api/v1/products?world=commerce` (without auth)
- **Expected:** 401/403 with error envelope
- **Purpose:** Validates authentication is required

### 4. Listings per Enabled World (Unauthorized)
- **Endpoints:** `GET {BaseUrl}/api/v1/{world}/listings` for each enabled world (commerce, food, rentals)
- **Expected:** 401/403 with error envelope
- **Purpose:** Validates listings endpoints require authentication

### 5. Auth-Required E2E (Only if Credentials Provided)
If `TenantId` and `AuthToken` are provided, performs full CRUD cycle:

- **POST Create:** Creates listing with minimal deterministic body
  - Expected: 200/201 OK with `ok:true` and `id` in response
- **GET Show:** Retrieves created listing
  - Expected: 200 OK with `ok:true`
- **PATCH Update:** Updates listing title
  - Expected: 200 OK with `ok:true`
- **DELETE:** Deletes listing
  - Expected: 200/204 OK
- **GET After Delete:** Attempts to retrieve deleted listing
  - Expected: 404 NOT_FOUND with error envelope

### 5f. Cross-Tenant Leakage Check (Optional)
If `TenantBId` is provided:
- Attempts to access Tenant A's resource with Tenant B's headers
- Expected: 404 NOT_FOUND (no leakage)
- FAIL if 200 OK (leakage detected)

## Running Locally

### Basic Usage (Public Contract Tests Only)

```powershell
.\ops\product_e2e.ps1
```

This runs public contract tests (health, metrics, unauthorized checks). Auth-required tests will be skipped with WARN.

### With Credentials (Full E2E)

```powershell
$env:PRODUCT_TEST_TENANT_ID = "your-tenant-id"
$env:PRODUCT_TEST_AUTH_TOKEN = "your-bearer-token"
.\ops\product_e2e.ps1
```

### With Cross-Tenant Leakage Check

```powershell
$env:PRODUCT_TEST_TENANT_ID = "tenant-a-id"
$env:PRODUCT_TEST_AUTH_TOKEN = "your-bearer-token"
$env:PRODUCT_TEST_TENANT_B_ID = "tenant-b-id"
.\ops\product_e2e.ps1
```

### Custom URLs

```powershell
.\ops\product_e2e.ps1 -BaseUrl "http://localhost:8080" -HosBaseUrl "http://localhost:3000"
```

### Verbose Mode

```powershell
.\ops\product_e2e.ps1 -Verbose
```

Shows request/response snippets for debugging.

## Environment Variables

The gate reads the following environment variables:

- `BASE_URL` (default: `http://localhost:8080`) - Pazar API base URL
- `HOS_BASE_URL` (default: `http://localhost:3000`) - H-OS API base URL
- `PRODUCT_TEST_TENANT_ID` - Tenant ID for auth-required tests (optional)
- `PRODUCT_TEST_AUTH_TOKEN` - Bearer token for auth-required tests (optional)
- `PRODUCT_TEST_TENANT_B_ID` - Tenant B ID for cross-tenant leakage check (optional)

## Interpreting Results

### Status Values

- **PASS**: All checks passed
- **WARN**: Warnings present (e.g., auth credentials missing, tests skipped)
- **FAIL**: Failures detected (e.g., contract violation, missing request_id, wrong status code)

### Exit Codes

- `0`: PASS (all checks passed)
- `2`: WARN (warnings present, no failures)
- `1`: FAIL (one or more failures)

### Output Format

```
=== Check Results ===
Check | Status | ExitCode | Notes
--------------------------------------------------------------------------------
H-OS Health                    [PASS]     0        200 OK, ok:true
Pazar Metrics                   [PASS]     0        200 OK, Content-Type: text/plain
Product Spine Validation        [PASS]     0        422 VALIDATION_ERROR, request_id present
Product No-Auth                 [PASS]     0        401 with error envelope
commerce Listings No-Auth       [PASS]     0        401 with error envelope
food Listings No-Auth           [PASS]     0        401 with error envelope
rentals Listings No-Auth        [PASS]     0        401 with error envelope
Auth-Required E2E               [WARN]     2        TenantId or AuthToken missing - tests skipped
```

## Troubleshooting

### FAIL: H-OS Health Check Failed

**Symptom:** `H-OS Health: FAIL - Request failed`

**Cause:** H-OS service not running or unreachable

**Fix:**
1. Check if H-OS service is running: `docker compose ps hos-api`
2. Check H-OS health endpoint: `curl http://localhost:3000/v1/health`
3. Verify `HOS_BASE_URL` environment variable is correct

### FAIL: Metrics Endpoint Failed

**Symptom:** `Pazar Metrics: FAIL - Expected 200, got 404`

**Cause:** Metrics endpoint not available or wrong URL

**Fix:**
1. Check if Pazar service is running: `docker compose ps pazar-app`
2. Check metrics endpoint: `curl http://localhost:8080/metrics`
3. Verify `BASE_URL` environment variable is correct

### FAIL: Product Spine Validation Failed

**Symptom:** `Product Spine Validation: FAIL - Expected 422, got 200`

**Cause:** World parameter validation not working

**Fix:**
1. Check route definition in `work/pazar/routes/api.php`
2. Verify validation middleware is applied
3. Check controller validation logic

### WARN: Auth-Required E2E Skipped

**Symptom:** `Auth-Required E2E: WARN - TenantId or AuthToken missing - tests skipped`

**Cause:** Credentials not provided

**Fix:**
1. Set `PRODUCT_TEST_TENANT_ID` environment variable
2. Set `PRODUCT_TEST_AUTH_TOKEN` environment variable
3. Re-run the gate

### FAIL: Cross-Tenant Leakage Detected

**Symptom:** `Cross-Tenant Leakage: FAIL - 200 OK - LEAKAGE DETECTED`

**Cause:** Tenant boundary not enforced

**Fix:**
1. Check tenant isolation in controller/model
2. Verify `X-Tenant-Id` header is used for scoping
3. Review tenant boundary check: `ops/tenant_boundary_check.ps1`

### FAIL: Missing Request ID

**Symptom:** `FAIL - 422 but missing error_code or request_id`

**Cause:** Error envelope not compliant

**Fix:**
1. Check error envelope middleware
2. Verify `request_id` is generated and included in responses
3. Review error contract: `ops/contract.ps1`

## Request ID Tracing

When a test fails, the gate captures `request_id` from responses. Use this for debugging:

```powershell
.\ops\request_trace.ps1 -RequestId <request_id>
```

This shows full request/response details for the failed request.

## Incident Bundle

On FAIL, generate an incident bundle:

```powershell
.\ops\incident_bundle.ps1
```

The bundle includes:
- System diagnostics
- Service logs
- Configuration snapshots
- Health check results
- Request traces (if available)

## CI Integration

The gate is integrated into CI via `.github/workflows/product-e2e.yml`:

- Runs on push/PR to `main`/`develop`
- Triggers on changes to:
  - `work/pazar/routes/api.php`
  - `work/pazar/app/Http/Controllers/Api/**/*.php`
  - `ops/product_e2e.ps1`
- Brings up Docker Compose stack
- Uses GitHub Secrets for credentials
- Uploads logs and incident bundle on failure

## Best Practices

1. **Run Public Contract Tests First**: Always run without credentials first to validate public contract
2. **Use Credentials for Full E2E**: Provide credentials for complete validation
3. **Check Request IDs**: Always verify `request_id` is present in responses
4. **Review WARNs**: Even though WARNs don't block, review and fix credential gaps
5. **Use Verbose Mode for Debugging**: Enable `-Verbose` to see request/response details

## Related Documentation

- `ops/product_contract.ps1` - Product contract gate (spine validation)
- `ops/product_contract_check.ps1` - Product contract check (E2E validation)
- `ops/product_e2e_contract.ps1` - Product E2E contract gate
- `ops/request_trace.ps1` - Request tracing tool
- `ops/incident_bundle.ps1` - Incident bundle generator
- `docs/RULES.md` - Rule 64: Product-e2e gate release öncesi PASS/WARN
