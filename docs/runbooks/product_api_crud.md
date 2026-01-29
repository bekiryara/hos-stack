# Product API CRUD E2E Gate

## Overview

The `product_api_crud_e2e.ps1` gate validates end-to-end CRUD operations for listing endpoints across all enabled worlds (commerce, food, rentals). It ensures that:

- Unauthorized access returns proper error envelopes (401/403)
- Missing tenant context is rejected (403 FORBIDDEN)
- Full CRUD cycle works (Create, Read, Update, Delete)
- Cross-tenant data leakage is prevented (404 NOT_FOUND)

## Required Environment Variables / Secrets

The gate uses existing conventions (do NOT invent new ones):

- `PRODUCT_TEST_AUTH` (or `PRODUCT_TEST_AUTH_TOKEN`): Bearer token for authentication
- `TENANT_A_SLUG` or `TENANT_A_ID`: First tenant identifier
- `TENANT_B_SLUG` or `TENANT_B_ID`: Second tenant identifier (for cross-tenant leakage test)
- `BASE_URL`: API base URL (default: `http://localhost:8080`)

## What the Gate Checks

### Test A: Unauthorized Access
- For each enabled world, GET `/api/v1/{world}/listings` without auth
- Expected: 401 or 403 with standard JSON error envelope (`ok:false`, `error_code`, `request_id`)

### Test B: Missing Tenant Context
- For each enabled world, GET `/api/v1/{world}/listings` with auth but no `X-Tenant-Id` header
- Expected: 403 FORBIDDEN with error envelope

### Test C: Happy Path CRUD
If credentials are provided, performs full CRUD cycle for each enabled world:

1. **POST Create**: Create a listing with minimal payload
   - Expected: 200/201 with `ok:true` envelope and `request_id`
   - Extracts created listing ID from response

2. **GET Index**: List all listings
   - Expected: 200 with `ok:true` envelope
   - Verifies created item appears in list (tenant-scoped)

3. **GET Show**: Get listing detail by ID
   - Expected: 200 with `ok:true` envelope

4. **PATCH Update**: Update listing title
   - Expected: 200 with `ok:true` envelope

5. **DELETE**: Delete listing
   - Expected: 200/204

6. **GET After Delete**: Verify deletion
   - Expected: 404 NOT_FOUND with error envelope

### Test D: Cross-Tenant Leakage
- Creates item with Tenant A
- Attempts to GET same item with Tenant B
- Expected: 404 NOT_FOUND (no leakage)

## Interpreting Failures

### Request ID Tracing
All failed requests include a `request_id` in the error envelope. Use:

```powershell
.\ops\request_trace.ps1 -RequestId <request_id>
```

### Common Failure Scenarios

1. **Unauthorized returns 200 instead of 401/403**
   - Issue: Authentication middleware not applied
   - Fix: Check route middleware configuration

2. **Missing tenant context returns 200 instead of 403**
   - Issue: Tenant resolution middleware not enforcing tenant requirement
   - Fix: Verify `ResolveTenant` middleware is applied

3. **Cross-tenant leakage (200 instead of 404)**
   - Issue: Tenant boundary not enforced in query
   - Fix: Check listing queries include tenant scope

4. **Invalid error envelope (missing `error_code` or `request_id`)**
   - Issue: Error response format doesn't match contract
   - Fix: Ensure all error responses use standard envelope format

## Troubleshooting

### Tenant Header / Auth Token Issues
- Verify `X-Tenant-Id` header matches the tenant identifier format expected by your API
- Check that `PRODUCT_TEST_AUTH` token is valid and not expired
- Ensure token has permissions for the test tenant

### Route Mismatch
- Verify routes match pattern `/api/v1/{world}/listings`
- Check that enabled worlds match `work/pazar/config/worlds.php`

### Docker / Service Availability
- Ensure Docker stack is running: `docker compose up -d`
- Verify services are healthy: `curl http://localhost:8080/up`

## Exit Codes

- `0`: PASS - All checks passed
- `2`: WARN - Some tests skipped (missing credentials) but no failures
- `1`: FAIL - At least one check failed

## Integration

The gate is integrated into `ops_status.ps1` as a blocking check. It runs automatically when:

- `.\ops\ops_status.ps1` is executed
- `.\ops\rc0_check.ps1` is executed (RC0 gate)

## CI Integration

The gate runs in CI via `.github/workflows/product-api-crud-gate.yml` on:
- Pull requests to `main` or `develop`
- Pushes to `main` or `develop`

Required GitHub secrets:
- `PRODUCT_TEST_AUTH`
- `TENANT_A_SLUG` or `TENANT_A_ID`
- `TENANT_B_SLUG` or `TENANT_B_ID`






















