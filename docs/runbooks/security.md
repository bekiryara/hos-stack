# Security Runbook

## Overview

Security audit ensures that all routes comply with security policies, preventing unsafe exposure of admin/panel surfaces and state-changing operations.

## Security Policy

### 1. Admin Surface Protection
Any route path starting with `/admin` must include:
- `auth.any` middleware
- `super.admin` middleware

### 2. Panel Surface Protection
Any route path starting with `/panel` must include:
- `auth.any` middleware

### 3. Tenant-Scoped Panel Routes
Any route containing `{tenant}` and path starting with `/panel` must include:
- `tenant.resolve` or `resolve.tenant` middleware
- `tenant.user` middleware

### 4. State-Changing Routes Protection
Any route with methods `POST`, `PUT`, `PATCH`, or `DELETE` must:
- Include `auth.any` middleware, OR
- Be explicitly allowlisted (e.g., `/up`, health endpoints)

Allowlisted paths:
- `/up` (health check)
- `/health` (health check alternative)
- `/api/health` (API health check)
- `/v1/health` (H-OS health check)

## Running the Audit

### Local Execution

```powershell
# Run security audit
.\ops\security_audit.ps1
```

Expected output:
- **PASS**: `0 violations found` - All routes comply with security policy
- **FAIL**: List of violations with method, URI, and missing middleware

### CI Execution

The security audit runs automatically on:
- Pull requests (any branch)
- Pushes to any branch

If violations are found, the CI gate will fail and upload an artifact with violation details.

## Fixing Violations

If the audit reports violations:

1. **Identify the violation**: Check the output for method, URI, and missing middleware
2. **Review route definition**: Locate the route in `work/pazar/routes/*.php`
3. **Add required middleware**: Update the route to include the required middleware

Example fixes:

```php
// Admin route - add auth.any and super.admin
Route::get('/admin/users', [AdminUsersController::class, 'index'])
    ->middleware(['auth.any', 'super.admin']);

// Panel route - add auth.any
Route::get('/panel/dashboard', [PanelController::class, 'index'])
    ->middleware('auth.any');

// Tenant-scoped panel route - add tenant.resolve and tenant.user
Route::get('/panel/{tenant}/products', [PanelProductsController::class, 'index'])
    ->middleware(['auth.any', 'tenant.resolve', 'tenant.user']);

// State-changing route - add auth.any
Route::post('/api/products', [ProductsController::class, 'store'])
    ->middleware('auth.any');
```

## Verification

After fixing violations:

1. Run the audit locally: `.\ops\security_audit.ps1`
2. Ensure it passes: `✓ PASS: 0 violations found`
3. Verify existing gates still pass: `.\ops\verify.ps1`, `.\ops\doctor.ps1`
4. Push changes and verify CI gate passes

## Related Documentation

- `docs/RULES.md` - Rule 25: PR merge requires security-gate PASS
- `ops/security_audit.ps1` - Security audit script
- `.github/workflows/security-gate.yml` - CI workflow

