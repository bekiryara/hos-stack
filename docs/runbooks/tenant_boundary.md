# Tenant Boundary Runbook

## Overview

Tenant Boundary Pack v1 ensures proper tenant isolation, preventing cross-tenant data access and unauthorized access to tenant-scoped resources.

## Tenant Isolation Policy

### Core Principle

Users authenticated to one tenant **must not** be able to access resources belonging to another tenant, even if they are authenticated.

### Enforcement

Tenant isolation is enforced by:

1. **Middleware**: `tenant.user` middleware checks if the authenticated user belongs to the requested tenant
2. **Authorization**: `EnsureTenantUser` middleware validates `TenantUser` relationship
3. **Route Protection**: All `/panel/{tenant_slug}/*` routes require `tenant.user` middleware

### Expected Behavior

- **Authorized Access**: User authenticated to Tenant A accessing `/panel/tenant-a/*` → **200 OK**
- **Cross-Tenant Access**: User authenticated to Tenant A accessing `/panel/tenant-b/*` → **403 FORBIDDEN**
- **Unauthorized Access**: Unauthenticated user accessing `/panel/{tenant}/*` → **401 UNAUTHORIZED**

## Reproducing Locally

### Prerequisites

1. **Test Credentials**: Create test user with access to at least two tenants
2. **Tenant Slugs**: Identify two different tenant slugs (Tenant A and Tenant B)
3. **Routes Snapshot**: Ensure `ops/snapshots/routes.pazar.json` exists

### Setting Up Test Credentials

Set environment variables:

```powershell
$env:TENANT_TEST_EMAIL = "test@example.com"
$env:TENANT_TEST_PASSWORD = "password"
$env:TENANT_A_SLUG = "tenant-a"
$env:TENANT_B_SLUG = "tenant-b"
```

Or in CI, set GitHub secrets:
- `TENANT_TEST_EMAIL`
- `TENANT_TEST_PASSWORD`
- `TENANT_A_SLUG`
- `TENANT_B_SLUG`

### Running the Check

```powershell
.\ops\tenant_boundary_check.ps1
```

### Expected Output

```
=== TENANT BOUNDARY CHECK ===
Timestamp: 2026-01-08 12:00:00

Reading routes snapshot...
Selected admin route: GET /admin/tenants
Selected panel route: GET /panel/{tenant_slug}/ping

Testing Admin Unauthorized Access...
Testing Panel Unauthorized Access...
Testing tenant boundary isolation...
  Logging in as test user...
  Accessing tenant A (tenant-a)...
  Accessing tenant B (tenant-b)...

=== TENANT BOUNDARY CHECK RESULTS ===

Check                      Status ExitCode Notes
-----                      ------ -------- -----
Admin Unauthorized Access  PASS         0 Status 401, JSON envelope correct (error_code: UNAUTHORIZED)
Panel Unauthorized Access  PASS         0 Status 401, JSON envelope correct (error_code: UNAUTHORIZED)
Tenant Boundary Isolation  PASS         0 Tenant boundary enforced: Tenant A access OK, Tenant B blocked (403 FORBIDDEN)

OVERALL STATUS: PASS (All checks passed)
```

## Common Failures

### Cross-Tenant Access Allowed

**Symptom**: User authenticated to Tenant A can access Tenant B resources (200 OK instead of 403)

**Cause**: Missing or incorrect `tenant.user` middleware

**Fix**:
1. Verify route middleware in `routes/panel.php`
2. Ensure `tenant.user` middleware is applied
3. Check `EnsureTenantUser` middleware logic

### Unauthorized Access Returns 200

**Symptom**: Unauthenticated user accessing `/panel/*` returns 200 OK

**Cause**: Missing `auth.any` middleware

**Fix**:
1. Verify route middleware includes `auth.any`
2. Check middleware registration in `bootstrap/app.php`

### JSON Envelope Missing

**Symptom**: 403 response doesn't include JSON envelope (`ok:false`, `error_code`)

**Cause**: Error envelope middleware not applied or exception handler issue

**Fix**:
1. Verify `ErrorEnvelope` middleware is registered
2. Check exception handler in `bootstrap/app.php`

## Request ID and Logs

All requests include `X-Request-Id` header for traceability:

```powershell
# Check request ID in response
curl.exe -i -H "Accept: application/json" http://localhost:8080/panel/tenant-a/ping

# Response includes:
# X-Request-Id: <uuid>
# 
# {
#   "ok": false,
#   "error_code": "UNAUTHORIZED",
#   "message": "...",
#   "request_id": "<same uuid>"
# }
```

### Logging

Check application logs for tenant boundary violations:

```powershell
# View logs with request_id
docker compose logs pazar-app | Select-String "request_id"
```

## Troubleshooting

### Test Credentials Not Working

1. **Verify User Exists**: Check database for test user
2. **Verify Tenant Membership**: Ensure user is member of Tenant A
3. **Check Password**: Verify password is correct
4. **Check Token**: Verify login returns valid token

### Routes Not Found

1. **Update Snapshot**: Run `ops/routes_snapshot.ps1` to update snapshot
2. **Check Route Format**: Verify route format matches snapshot
3. **Check Middleware**: Ensure routes have required middleware

### Tenant Not Resolved

1. **Check Tenant Slug**: Verify tenant slug exists in database
2. **Check ResolveTenant Middleware**: Ensure `resolve.tenant` middleware is applied
3. **Check Route Parameter**: Verify route parameter name is `{tenant_slug}`

## Related Documentation

- `docs/RULES.md` - Rule 29: Tenant-boundary gate PASS required for merge
- `ops/tenant_boundary_check.ps1` - Tenant boundary check script
- `.github/workflows/tenant-boundary.yml` - CI workflow
- `work/pazar/app/Http/Middleware/EnsureTenantUser.php` - Tenant user middleware
- `work/pazar/routes/panel.php` - Panel routes

