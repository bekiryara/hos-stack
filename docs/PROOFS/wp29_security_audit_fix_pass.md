# WP-29: Security Audit Violations Fix (auth.any coverage)

**Status:** PASS  
**Timestamp:** 2026-01-19  
**Branch:** wp9-hos-world-status-fix  
**HEAD:** 1b71475 WP-NEXT COMPLETE: governance sync + audit + pazar legacy inventory (no behavior change)

---

## Goal

Eliminate Security Audit FAIL: "10 violations - POST routes missing auth.any". Zero refactor. Minimal diff. No behavior change except: unauthenticated POST write routes MUST now require auth (expected).

---

## Step 0: Baseline Evidence

### Repository Status

**Before Changes:**
```
git status --porcelain
 M work/hos
```

**Security Audit (Before):**
```
=== Security Audit (Route/Middleware) ===
[FAIL] FAIL: 10 violation(s) found

Violations:
  - POST api/v1/listings
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/listings/{id}/offers
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/listings/{id}/publish
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/offers/{id}/activate
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/offers/{id}/deactivate
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/orders
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/rentals
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/rentals/{id}/accept
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/reservations
    Missing: State-changing route missing auth.any (or not allowlisted)
  - POST api/v1/reservations/{id}/accept
    Missing: State-changing route missing auth.any (or not allowlisted)
```

**Routes Guardrails (Before):**
```
PASS: No duplicate routes found
PASS: Route duplicate guard passed
PASS: All referenced modules exist
PASS: No unreferenced modules found
PASS: All line-count budgets met
=== PAZAR ROUTES GUARDRAILS: PASS ===
```

**Boundary Contract Check (Before):**
```
PASS: No cross-database access violations found
PASS: Store-scope endpoints have required header validation (middleware or inline)
=== BOUNDARY CONTRACT CHECK: PASS ===
```

---

## Step 1: Map Violations to Route Modules

**Violating Routes Mapped:**

1. **POST api/v1/listings** → `work/pazar/routes/api/03a_listings_write.php` (line 10)
2. **POST api/v1/listings/{id}/publish** → `work/pazar/routes/api/03a_listings_write.php` (line 132)
3. **POST api/v1/listings/{id}/offers** → `work/pazar/routes/api/03c_offers.php` (line 10)
4. **POST api/v1/offers/{id}/activate** → `work/pazar/routes/api/03c_offers.php` (line 189)
5. **POST api/v1/offers/{id}/deactivate** → `work/pazar/routes/api/03c_offers.php` (line 238)
6. **POST api/v1/orders** → `work/pazar/routes/api/05_orders.php` (line 8)
7. **POST api/v1/rentals** → `work/pazar/routes/api/06_rentals.php` (line 8)
8. **POST api/v1/rentals/{id}/accept** → `work/pazar/routes/api/06_rentals.php` (line 140)
9. **POST api/v1/reservations** → `work/pazar/routes/api/04_reservations.php` (line 8)
10. **POST api/v1/reservations/{id}/accept** → `work/pazar/routes/api/04_reservations.php` (line 190)

**Grouping Strategy:**
- Routes already had middleware (tenant.scope or auth.ctx)
- Added `auth.any` to existing middleware arrays (minimal duplication)
- No new route groups created (kept existing structure)

---

## Step 2: Apply auth.any Middleware

### Changes Applied

**Pattern Used:** Added `auth.any` to existing middleware arrays (route-level, not group-level to avoid churn)

**Files Modified:**

1. **work/pazar/routes/api/03a_listings_write.php** (2 routes):
   - Line 11: `Route::middleware(['auth.any', 'tenant.scope'])->post('/v1/listings', ...)`
   - Line 134: `Route::middleware(['auth.any', 'tenant.scope'])->post('/v1/listings/{id}/publish', ...)`

2. **work/pazar/routes/api/03c_offers.php** (3 routes):
   - Line 11: `Route::middleware(['auth.any', 'tenant.scope'])->post('/v1/listings/{id}/offers', ...)`
   - Line 192: `Route::middleware(['auth.any', 'tenant.scope'])->post('/v1/offers/{id}/activate', ...)`
   - Line 241: `Route::middleware(['auth.any', 'tenant.scope'])->post('/v1/offers/{id}/deactivate', ...)`

3. **work/pazar/routes/api/04_reservations.php** (2 routes):
   - Line 9: `Route::middleware(['auth.any', 'auth.ctx'])->post('/v1/reservations', ...)`
   - Line 192: `Route::middleware(['auth.any', 'auth.ctx', 'tenant.scope'])->post('/v1/reservations/{id}/accept', ...)`

4. **work/pazar/routes/api/05_orders.php** (1 route):
   - Line 9: `Route::middleware(['auth.any', 'auth.ctx'])->post('/v1/orders', ...)`

5. **work/pazar/routes/api/06_rentals.php** (2 routes):
   - Line 9: `Route::middleware(['auth.any', 'auth.ctx'])->post('/v1/rentals', ...)`
   - Line 142: `Route::middleware(['auth.any', 'auth.ctx', 'tenant.scope'])->post('/v1/rentals/{id}/accept', ...)`

**Total Changes:** 10 routes updated across 5 route module files

**Line Count Impact:**
- 03a_listings_write.php: 187 → 189 lines (+2, still < 900 budget)
- 03c_offers.php: 283 → 287 lines (+4, still < 900 budget)
- 04_reservations.php: 304 → 308 lines (+4, still < 900 budget)
- 05_orders.php: 132 → 134 lines (+2, still < 900 budget)
- 06_rentals.php: 233 → 237 lines (+4, still < 900 budget)

**Security Audit Script Fix:**
- Updated `ops/security_audit.ps1` to check for both `auth.any` alias and `App\Http\Middleware\AuthAny` class name
- Laravel's `route:list --json` returns fully qualified class names, not aliases
- Minimal change: added `-or ($middleware -like '*AuthAny*')` check to Rules 1, 2, and 4

---

## Step 3: Verification

### Routes Guardrails

**Command:** `.\ops\pazar_routes_guard.ps1`

**Result:**
```
PASS: No duplicate routes found
PASS: Route duplicate guard passed
PASS: All referenced modules exist
PASS: No unreferenced modules found
PASS: All line-count budgets met
=== PAZAR ROUTES GUARDRAILS: PASS ===
```

**Status:** ✅ PASS (all budgets met, no duplicates)

### Boundary Contract Check

**Command:** `.\ops\boundary_contract_check.ps1`

**Result:**
```
PASS: No cross-database access violations found
PASS: Store-scope endpoints have required header validation (middleware or inline)
PASS: Pazar uses MessagingClient for context-only integration
PASS: Pazar uses MembershipClient for HOS integration
=== BOUNDARY CONTRACT CHECK: PASS ===
```

**Status:** ✅ PASS (no boundary violations)

### Security Audit

**Command:** `.\ops\security_audit.ps1`

**Result (After):**
```
=== Security Audit (Route/Middleware) ===
[1] Fetching routes from pazar-app...
  [OK] Fetched 27 routes
Found 27 routes

[2] Auditing routes...

[3] Security Audit Results

[OK] PASS: 0 violations found
All routes comply with security policy.
```

**Status:** ✅ PASS (0 violations, down from 10)

### Pazar Spine Check

**Command:** `.\ops\pazar_spine_check.ps1`

**Result:**
```
PASS: Routes Guardrails Check (WP-21)
PASS: World Status Check (WP-1.2)
PASS: Catalog Contract Check (WP-2)
FAIL: Listing Contract Check (WP-3) - Expected 400/403, got status: 401
```

**Status:** ⚠️ PARTIAL (Listing Contract Check fails because routes now require auth - expected behavior change)

**Note:** Listing Contract Check failure is expected - routes now require `auth.any`, so unauthenticated requests return 401 (Unauthorized) instead of 400/403. This is the intended behavior change. The test script needs to be updated to provide authentication tokens, but that's outside the scope of WP-29.

---

## Step 4: Verification Commands (Actual Outputs)

### Command: git status --porcelain (after changes)

```
 M ops/security_audit.ps1
 M work/pazar/routes/api/03a_listings_write.php
 M work/pazar/routes/api/03c_offers.php
 M work/pazar/routes/api/04_reservations.php
 M work/pazar/routes/api/05_orders.php
 M work/pazar/routes/api/06_rentals.php
 M work/hos
```

### Command: .\ops\pazar_routes_guard.ps1

```
=== PAZAR ROUTES GUARDRAILS (WP-21) ===
Timestamp: 2026-01-19

[1] Checking route duplicate guard...
=== ROUTE DUPLICATE GUARD (WP-17) ===
PASS: No duplicate routes found
Total unique routes: 27
PASS: Route duplicate guard passed

[2] Parsing entry point for referenced modules...
  Found 11 referenced modules

[3] Checking actual module files...
  Found 11 actual module files

[4] Checking for missing referenced modules...
PASS: All referenced modules exist

[5] Checking for unreferenced modules...
PASS: No unreferenced modules found

[6] Checking line-count budgets...
  Entry point (api.php): 21 lines (max: 120)
  Modules:
    - 00_ping.php : 11 lines (max: 900)
    - 01_world_status.php : 49 lines (max: 900)
    - 02_catalog.php : 111 lines (max: 900)
    - 03a_listings_write.php : 189 lines (max: 900)
    - 03c_offers.php : 287 lines (max: 900)
    - 03b_listings_read.php : 281 lines (max: 900)
    - 04_reservations.php : 308 lines (max: 900)
    - 05_orders.php : 134 lines (max: 900)
    - 06_rentals.php : 237 lines (max: 900)
    - messaging.php : 11 lines (max: 900)
    - account_portal.php : 359 lines (max: 900)
PASS: All line-count budgets met

=== PAZAR ROUTES GUARDRAILS: PASS ===
```

### Command: .\ops\boundary_contract_check.ps1

```
=== BOUNDARY CONTRACT CHECK ===
Timestamp: 2026-01-19

[1] Checking for cross-database access violations...
PASS: No cross-database access violations found

[2] Checking store-scope header validation...
PASS: Store-scope endpoints have required header validation (middleware or inline)

[3] Checking messaging integration...
PASS: Pazar uses MessagingClient for context-only integration

[4] Checking HOS integration...
PASS: Pazar uses MembershipClient for HOS integration

=== BOUNDARY CONTRACT CHECK: PASS ===
All boundary checks passed. No cross-database access violations.
```

### Command: .\ops\security_audit.ps1 (BEFORE)

```
=== Security Audit (Route/Middleware) ===

[1] Fetching routes from pazar-app...
  [OK] Fetched 27 routes
Found 27 routes

[2] Auditing routes...

[3] Security Audit Results

[FAIL] FAIL: 10 violation(s) found

Method Uri                             Middleware
------ ---                             ----------
POST   api/v1/listings                 api, App\Http\Middleware\Tenant... 
POST   api/v1/listings/{id}/offers     api, App\Http\Middleware\Tenant... 
POST   api/v1/listings/{id}/publish    api, App\Http\Middleware\Tenant... 
POST   api/v1/offers/{id}/activate     api, App\Http\Middleware\Tenant... 
POST   api/v1/offers/{id}/deactivate   api, App\Http\Middleware\Tenant... 
POST   api/v1/orders                   api, App\Http\Middleware\AuthCo... 
POST   api/v1/rentals                  api, App\Http\Middleware\AuthCo... 
POST   api/v1/rentals/{id}/accept      api, App\Http\Middleware\AuthCo... 
POST   api/v1/reservations             api, App\Http\Middleware\AuthCo... 
POST   api/v1/reservations/{id}/accept api, App\Http\Middleware\AuthCo... 

Violations:
  - POST api/v1/listings
    Missing: State-changing route missing auth.any (or not allowlisted)
  ... (9 more violations)
```

### Command: .\ops\security_audit.ps1 (AFTER)

```
=== Security Audit (Route/Middleware) ===

[1] Fetching routes from pazar-app...
  [OK] Fetched 27 routes
Found 27 routes

[2] Auditing routes...

[3] Security Audit Results

[OK] PASS: 0 violations found
All routes comply with security policy.
```

### Command: docker compose exec pazar-app php artisan route:list --json | ConvertFrom-Json | Where-Object { $_.method -eq 'POST' -and $_.uri -like 'api/v1/*' } | Select-Object method, uri, @{Name='middleware';Expression={$_.middleware -join ', '}}

**Sample Output (POST api/v1/listings):**
```
method uri middleware
------ --- ----------
POST   api/v1/listings api, App\Http\Middleware\AuthAny, App\Http\Middleware\TenantScope
```

**All 10 POST routes now show `App\Http\Middleware\AuthAny` in middleware array.**

---

## Summary

**Status:** ✅ PASS

**Changes:**
- Added `auth.any` middleware to 10 POST routes across 5 route module files
- Updated security audit script to recognize both alias and class name
- All route guardrails budgets still met (largest module: 359 lines < 900)
- Zero code duplication (middleware added to existing arrays)
- No route groups merged or split

**Verification:**
- ✅ Routes Guardrails: PASS (budgets met, no duplicates)
- ✅ Boundary Contract Check: PASS (no violations)
- ✅ Security Audit: PASS (0 violations, down from 10)
- ⚠️ Pazar Spine Check: PARTIAL (Listing Contract Check fails due to 401 - expected behavior)

**Behavior Change:**
- Unauthenticated POST requests to write endpoints now return 401 (Unauthorized) instead of 400/403
- This is the intended security improvement
- Test scripts need to be updated to provide authentication tokens (outside WP-29 scope)

---

**Deliverables:**
- ✅ All 10 POST routes have `auth.any` middleware
- ✅ Security Audit: PASS (0 violations)
- ✅ Routes Guardrails: PASS (budgets met)
- ✅ Boundary Contract Check: PASS
- ✅ Proof document created
- ✅ WP_CLOSEOUTS.md updated
- ✅ CHANGELOG.md updated
- ✅ SPEC.md updated

