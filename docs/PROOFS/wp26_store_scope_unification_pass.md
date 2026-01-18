# WP-26: Store-Scope Unification + Middleware Pack v1 - Proof

**Date:** 2026-01-19  
**Status:** PASS  
**Goal:** Unify X-Active-Tenant-Id + membership enforcement in a single middleware. Eliminate code duplication in route handlers. Make boundary_contract_check.ps1 WARN->FAIL for missing header validation.

## Summary

WP-26 created a centralized `TenantScope` middleware that enforces X-Active-Tenant-Id header presence and membership validation for all store-scope write endpoints. This eliminates duplicated inline validation blocks across route files and ensures consistent enforcement.

## Changes Made

### 1. New Middleware: `TenantScope` (`work/pazar/app/Http/Middleware/TenantScope.php`)

**Created:** Centralized middleware for store-scope validation.

**Responsibilities:**
- Enforces X-Active-Tenant-Id header presence (400 missing_header if missing)
- Validates tenant ID format (UUID, 403 FORBIDDEN_SCOPE if invalid)
- Validates membership via MembershipClient (403 FORBIDDEN_SCOPE if denied)
- Attaches resolved `tenant_id` to request attributes for handler use

**Code:**
```php
class TenantScope
{
    public function handle(Request $request, Closure $next): Response
    {
        // Require X-Active-Tenant-Id header
        $tenantIdHeader = $request->header('X-Active-Tenant-Id');
        if (!$tenantIdHeader) {
            return response()->json([
                'error' => 'missing_header',
                'message' => 'X-Active-Tenant-Id header is required'
            ], 400);
        }

        // Validate format and membership via MembershipClient
        $membershipClient = new MembershipClient();
        $userId = $request->attributes->get('requester_user_id') ?? 'genesis-default';
        $authToken = $request->header('Authorization');

        if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
            return response()->json([
                'error' => 'FORBIDDEN_SCOPE',
                'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
            ], 403);
        }

        if (!$membershipClient->validateMembership($userId, $tenantIdHeader, $authToken)) {
            return response()->json([
                'error' => 'FORBIDDEN_SCOPE',
                'message' => 'Invalid membership or tenant access denied'
            ], 403);
        }

        // Attach tenant_id to request attributes
        $request->attributes->set('tenant_id', $tenantIdHeader);

        return $next($request);
    }
}
```

### 2. Middleware Registration (`work/pazar/bootstrap/app.php`)

**Added:** `'tenant.scope' => \App\Http\Middleware\TenantScope::class` to middleware alias array.

### 3. Route Updates (Store-Scope Write Endpoints)

**Updated 7 store-scope write endpoints:**

1. **POST /api/v1/listings** (`03a_listings_write.php`)
   - Before: Inline validation (lines 10-41)
   - After: `Route::middleware('tenant.scope')->post(...)`, removed inline block

2. **POST /api/v1/listings/{id}/publish** (`03a_listings_write.php`)
   - Before: Inline validation (lines 153-184)
   - After: `Route::middleware('tenant.scope')->post(...)`, removed inline block

3. **POST /api/v1/listings/{id}/offers** (`03c_offers.php`)
   - Before: Inline validation (lines 10-41)
   - After: `Route::middleware('tenant.scope')->post(...)`, removed inline block

4. **POST /api/v1/offers/{id}/activate** (`03c_offers.php`)
   - Before: Inline validation (lines 219-250)
   - After: `Route::middleware('tenant.scope')->post(...)`, removed inline block

5. **POST /api/v1/offers/{id}/deactivate** (`03c_offers.php`)
   - Before: Inline validation (lines 296-327)
   - After: `Route::middleware('tenant.scope')->post(...)`, removed inline block

6. **POST /api/v1/reservations/{id}/accept** (`04_reservations.php`)
   - Before: `Route::middleware('auth.ctx')->post(...)` + inline validation (lines 192-223)
   - After: `Route::middleware(['auth.ctx', 'tenant.scope'])->post(...)`, removed inline block

7. **POST /api/v1/rentals/{id}/accept** (`06_rentals.php`)
   - Before: `Route::middleware('auth.ctx')->post(...)` + inline validation (lines 140-171)
   - After: `Route::middleware(['auth.ctx', 'tenant.scope'])->post(...)`, removed inline block

**Code Reduction:**
- Removed ~33 lines of duplicated validation code per endpoint
- Total: ~231 lines removed (7 endpoints × ~33 lines)
- Replaced with single middleware application

### 4. Updated `boundary_contract_check.ps1`

**Changes:**
- Checks for `middleware('tenant.scope')` OR inline header validation
- Changed WARN->FAIL for missing header validation
- Updated message to indicate middleware or inline validation is acceptable

**Before:**
```powershell
$hasTenantHeaderCheck = ($routeContent -match "X-Active-Tenant-Id|XActiveTenantId")
if (-not $hasTenantHeaderCheck) {
    Write-Host "WARN: ..." -ForegroundColor Yellow
}
```

**After:**
```powershell
$hasTenantScopeMiddleware = ($routeContent -match "middleware\(['""]tenant\.scope['""]|middleware\(\[[^]]*['""]tenant\.scope['""]")
$hasInlineHeaderCheck = ($routeContent -match "X-Active-Tenant-Id|XActiveTenantId")
if (-not $hasTenantScopeMiddleware -and -not $hasInlineHeaderCheck) {
    Write-Host "FAIL: ..." -ForegroundColor Red
    $hasFailures = $true
}
```

## Verification

### 1. Boundary Contract Check (PASS)

```powershell
PS D:\stack> .\ops\boundary_contract_check.ps1
=== BOUNDARY CONTRACT CHECK ===
Timestamp: 2026-01-19 00:56:38

[1] Checking for cross-database access violations...
PASS: No cross-database access violations found

[2] Checking store-scope endpoints for required headers...
PASS: Store-scope endpoints have required header validation (middleware or inline)

[3] Checking context-only integration pattern...
PASS: Pazar uses MessagingClient for context-only integration
PASS: Pazar uses MembershipClient for HOS integration

=== BOUNDARY CONTRACT CHECK: PASS ===
```

### 2. Pazar Spine Check (PASS)

```powershell
PS D:\stack> .\ops\pazar_spine_check.ps1
...
[Summary] All checks PASS
```

### 3. Route Files Verification

**Verified all store-scope write endpoints use `tenant.scope` middleware:**

- `work/pazar/routes/api/03a_listings_write.php`: Lines 9, 152
- `work/pazar/routes/api/03c_offers.php`: Lines 9, 218, 295
- `work/pazar/routes/api/04_reservations.php`: Line 189
- `work/pazar/routes/api/06_rentals.php`: Line 139

**Verified inline validation blocks removed:**

- No `$membershipClient = new \App\Core\MembershipClient();` in route handlers
- No inline `X-Active-Tenant-Id` header checks in route handlers
- All endpoints use `$tenantId = $request->attributes->get('tenant_id');`

### 4. Middleware Registration

**Verified `tenant.scope` middleware registered in `bootstrap/app.php`:**

```php
$middleware->alias([
    ...
    'tenant.scope' => \App\Http\Middleware\TenantScope::class, // WP-26
    ...
]);
```

## Behavior Verification

### Zero Behavior Change

- All endpoints return identical responses (400 missing_header, 403 FORBIDDEN_SCOPE)
- Membership validation logic unchanged (strict mode support preserved)
- Tenant ownership checks remain in route handlers (provider_tenant_id match, etc.)

### Code Quality Improvements

- **DRY Principle:** Single source of truth for store-scope validation
- **Maintainability:** Changes to validation logic only need to be made in one place
- **Consistency:** All store-scope endpoints enforce the same rules
- **Testability:** Middleware can be tested independently

## Acceptance Criteria

✅ All existing spine checks remain PASS  
✅ `boundary_contract_check.ps1` produces PASS with zero WARN for header validation  
✅ No cross-db access introduced  
✅ `git status` clean (only WP-26 changes)  
✅ Zero behavior change (identical responses)  

## Files Changed

- `work/pazar/app/Http/Middleware/TenantScope.php` (NEW)
- `work/pazar/bootstrap/app.php` (MOD): Added `tenant.scope` alias
- `work/pazar/routes/api/03a_listings_write.php` (MOD): 2 endpoints updated
- `work/pazar/routes/api/03c_offers.php` (MOD): 3 endpoints updated
- `work/pazar/routes/api/04_reservations.php` (MOD): 1 endpoint updated
- `work/pazar/routes/api/06_rentals.php` (MOD): 1 endpoint updated
- `ops/boundary_contract_check.ps1` (MOD): Middleware detection + WARN->FAIL
- `docs/PROOFS/wp26_store_scope_unification_pass.md` (NEW): This proof document
- `docs/WP_CLOSEOUTS.md` (MOD): Added WP-26 entry
- `CHANGELOG.md` (MOD): Added WP-26 entry

## Conclusion

WP-26 successfully unified store-scope validation into a single `TenantScope` middleware, eliminating code duplication across 7 write endpoints. All endpoints now use consistent validation logic, and `boundary_contract_check.ps1` correctly detects middleware usage.

**Result:** Zero behavior change, ~231 lines of duplicated code removed, deterministic PASS. ✅

