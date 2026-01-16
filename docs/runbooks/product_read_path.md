# Product Read-Path Check Runbook

## Overview

The Product Read-Path Check (`ops/product_read_path_check.ps1`) is a self-audit gate that verifies Commerce listings GET endpoints (index/show) comply with the Product API contract. It ensures:

1. **Route Surface**: Unauthorized access to `/api/v1/commerce/listings` returns 401/403 with proper JSON error envelope.
2. **Authenticated Access**: Authorized requests return 200 with `ok:true` and proper JSON structure.
3. **Not Found Handling**: Non-existent listing IDs return 404 with `ok:false`, `error_code: "NOT_FOUND"`, and `request_id`.
4. **Content-Type Validation**: Success responses use `application/json` (not `text/html`).

## What It Checks

### Check 1: Route Surface (Unauthorized Access)

- **Endpoint**: `GET /api/v1/commerce/listings`
- **Headers**: `Accept: application/json` (no auth)
- **Expected**: HTTP 401 or 403
- **Response Validation**: JSON envelope with `ok:false`, `error_code`, and `request_id` (non-null)

### Check 2: Authenticated Access (Requires Environment Variables)

- **Endpoint**: `GET /api/v1/commerce/listings`
- **Headers**: `Authorization: Bearer <token>`, `X-Tenant-Id: <tenant-id>`, `Accept: application/json`
- **Expected**: HTTP 200
- **Response Validation**: JSON envelope with `ok:true`, `data.items` array (or empty), `request_id` (non-null)
- **Content-Type**: Must be `application/json` (not `text/html`)

### Check 3: Not Found Handling (Requires Environment Variables)

- **Endpoint**: `GET /api/v1/commerce/listings/00000000-0000-0000-0000-000000000000`
- **Headers**: `Authorization: Bearer <token>`, `X-Tenant-Id: <tenant-id>`, `Accept: application/json`
- **Expected**: HTTP 404
- **Response Validation**: JSON envelope with `ok:false`, `error_code: "NOT_FOUND"`, and `request_id` (non-null)

## Environment Variables

The authenticated checks require one of the following credential sets:

### Option 1: Bearer Token (Recommended)

```powershell
$env:PRODUCT_TEST_TOKEN = "your-bearer-token-here"
$env:PRODUCT_TEST_TENANT_ID = "your-tenant-uuid-here"
```

### Option 2: Login Credentials

```powershell
$env:PRODUCT_TEST_EMAIL = "test@example.com"
$env:PRODUCT_TEST_PASSWORD = "password"
$env:PRODUCT_TEST_TENANT_ID = "your-tenant-uuid-here"
```

If using Option 2, the script will automatically perform a login request to `/auth/login` to obtain a token.

## Running the Check

### Standalone

```powershell
.\ops\product_read_path_check.ps1
```

### Via Ops Status

```powershell
.\ops\ops_status.ps1
```

The check is automatically included in the unified ops status dashboard.

## Interpreting Results

### PASS (Exit Code 0)

- All checks passed.
- Unauthorized access returns 401/403 with proper JSON envelope.
- Authenticated access returns 200 with `ok:true` and valid structure.
- Not found returns 404 with `ok:false`, `error_code: "NOT_FOUND"`, and `request_id`.

### WARN (Exit Code 2)

- Credentials not set (env vars missing): Authenticated checks are skipped.
- JSON envelope missing `request_id` (but status codes correct).
- Response is not JSON (but status code matches expected).

**Remediation**: Set `PRODUCT_TEST_TOKEN` (or `PRODUCT_TEST_EMAIL` + `PRODUCT_TEST_PASSWORD`) and `PRODUCT_TEST_TENANT_ID` to enable authenticated checks.

### FAIL (Exit Code 1)

- Unauthorized access does not return 401/403.
- Authenticated access does not return 200.
- Not found does not return 404.
- JSON envelope missing required fields (`ok`, `error_code`).
- `ok` field value incorrect (e.g., `ok:false` when `ok:true` expected).
- `error_code` does not match expected value (e.g., `NOT_FOUND`).
- Content-Type is `text/html` for 200 responses (BOM/headers issue).
- Request failed (network error, timeout, etc.).

**Remediation**: Check application logs, verify API endpoints, ensure middleware is correctly configured, verify database connectivity, check for BOM/encoding issues.

## Troubleshooting

### "Credentials not set" Warning

**Symptom**: Check returns WARN with "Credentials not set, skipping authenticated checks"

**Cause**: `PRODUCT_TEST_TOKEN` (or `PRODUCT_TEST_EMAIL` + `PRODUCT_TEST_PASSWORD`) and/or `PRODUCT_TEST_TENANT_ID` are not set.

**Solution**: Set the required environment variables (see above) and re-run the check.

### "Status 200 but Content-Type is not application/json"

**Symptom**: Check fails with "Status 200 but Content-Type is not application/json (got: text/html)"

**Cause**: Application is returning HTML instead of JSON, often due to:
- Error pages being returned instead of JSON responses
- Middleware issues
- BOM/encoding issues in PHP files
- Missing `Accept: application/json` header handling

**Solution**: Check Laravel error logs, verify `ForceJsonForApi` middleware is applied, ensure no BOM in PHP files, verify routes are correctly configured.

### "Login failed"

**Symptom**: Check fails with "Login failed: ..." when using `PRODUCT_TEST_EMAIL` + `PRODUCT_TEST_PASSWORD`

**Cause**: Login endpoint `/auth/login` is not accessible, credentials are incorrect, or login endpoint returns an error.

**Solution**: Verify H-OS/Pazar services are running, check login endpoint is accessible, verify credentials are correct, check application logs.

### "Status 404, but error_code != 'NOT_FOUND'"

**Symptom**: Check fails with "Status 404, but error_code != 'NOT_FOUND'"

**Cause**: 404 response does not include `error_code: "NOT_FOUND"` in JSON envelope.

**Solution**: Verify `ListingController@show` method returns proper error envelope for not found cases, check error handling middleware.

### "Status 401/403, but JSON envelope missing 'request_id'"

**Symptom**: Check returns WARN with "Status 401/403, but JSON envelope missing 'request_id'"

**Cause**: Unauthorized/forbidden responses do not include `request_id` in JSON envelope.

**Solution**: Verify auth middleware adds `request_id` to error responses, check error response helpers.

## Integration

### CI/CD

In CI environments, provide credentials via secrets:

```yaml
env:
  PRODUCT_TEST_TOKEN: ${{ secrets.PRODUCT_TEST_TOKEN }}
  PRODUCT_TEST_TENANT_ID: ${{ secrets.PRODUCT_TEST_TENANT_ID }}
```

**Note**: If secrets are not available, the check will return WARN (not FAIL) and authenticated checks will be skipped.

### Self-Audit

The check is included in `ops/self_audit.ps1` and will be run as part of the self-audit orchestration.

## Related Documentation

- `docs/product/PRODUCT_API_SPINE.md` - Product API Spine specification
- `docs/runbooks/ops_status.md` - Unified ops status dashboard
- `docs/runbooks/self_audit.md` - Self-audit orchestration
- `docs/PROOFS/product_read_path_gate_pass.md` - Proof documentation





