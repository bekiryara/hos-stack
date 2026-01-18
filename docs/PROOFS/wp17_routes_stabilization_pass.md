# WP-17 Routes Stabilization v2 - Proof

**Timestamp:** 2026-01-18 19:24  
**Command:** Routes stabilized with helper extraction, categories redeclare risk eliminated  
**WP:** WP-17 Routes Stabilization v2

## Implementation Summary

WP-17 Routes Stabilization v2 completed. Extracted `buildTree` closure to `pazar_build_tree` helper function with `function_exists` guard, split routes into numbered modular files (00-06), zero behavior change.

## Before/After Line Counts

**Before:** `work/pazar/routes/api.php` was ~1700+ lines (monolithic file)  
**After:** `work/pazar/routes/api.php` is 18 lines (thin loader)

## Step 1 — Root-Cause Validation

### Double-Call Test

**Command:**
```powershell
curl http://localhost:8080/api/v1/categories
curl http://localhost:8080/api/v1/categories
```

**Result:** ✅ PASS
- First call: 200 OK
- Second call: 200 OK (no 500, no "Cannot redeclare" error)

**Conclusion:** Helper function with `function_exists` guard eliminates redeclare risk.

## Step 2 — Helper File Creation

**File:** `work/pazar/routes/_helpers.php`

**Functions:**
1. `pazar_active_tenant_id()` - Gets X-Active-Tenant-Id header
2. `pazar_build_tree(array $categories, $parentId = null)` - Builds category tree recursively

**Key Feature:** All functions wrapped with `function_exists()` guard to prevent redeclare fatal.

```php
if (!function_exists('pazar_build_tree')) {
    function pazar_build_tree(array $categories, $parentId = null) {
        $branch = [];
        foreach ($categories as $category) {
            if ($category['parent_id'] == $parentId) {
                $children = pazar_build_tree($categories, $category['id']);
                if (!empty($children)) {
                    $category['children'] = $children;
                }
                $branch[] = $category;
            }
        }
        return $branch;
    }
}
```

## Step 3 — Route Module Split

**Created modular route files in `work/pazar/routes/api/`:**

1. **`00_ping.php`** - Ping endpoint
   - `GET /ping`

2. **`01_world_status.php`** - World status endpoint
   - `GET /world/status`

3. **`02_catalog.php`** - Catalog endpoints
   - `GET /v1/categories` (uses `pazar_build_tree()` helper)
   - `GET /v1/categories/{id}/filter-schema`

4. **`03_listings.php`** - Listings and offers endpoints
   - All listing + offers routes (exactly as-is)

5. **`04_reservations.php`** - Reservations endpoints
   - Reservation create/accept/list/get blocks (exactly as-is)

6. **`05_orders.php`** - Orders endpoints
   - Orders list/create (exactly as-is)

7. **`06_rentals.php`** - Rentals endpoints
   - Rentals list/create/accept/get (exactly as-is)

**Key Change:** Only `02_catalog.php` changed: removed inner `function buildTree` closure, replaced with `pazar_build_tree(...)` call.

## Step 4 — Main api.php Thin Loader

**File:** `work/pazar/routes/api.php` (18 lines)

```php
<?php

use Illuminate\Support\Facades\Route;

// Load helpers first (WP-17 v2)
require_once __DIR__.'/_helpers.php';

// Load route modules in deterministic order (WP-17 v2: numbered files for explicit ordering)
// Order: ping -> world_status -> catalog -> listings -> reservations -> orders -> rentals
require_once __DIR__.'/api/00_ping.php';
require_once __DIR__.'/api/01_world_status.php';
require_once __DIR__.'/api/02_catalog.php';
require_once __DIR__.'/api/03_listings.php';
require_once __DIR__.'/api/04_reservations.php';
require_once __DIR__.'/api/05_orders.php';
require_once __DIR__.'/api/06_rentals.php';
```

**Key Features:**
- Deterministic load order (numbered files)
- `require_once` prevents double-registration
- Zero behavior change

## Step 5 — Verification Results

### Route List

**Command:** `docker compose exec pazar-app php artisan route:list`

**Result:** ✅ PASS
```
Showing [27] routes
```

All routes loaded correctly:
- `GET /ping`
- `GET /world/status`
- `GET /api/v1/categories`
- `GET /api/v1/categories/{id}/filter-schema`
- All listings, reservations, orders, rentals routes
- (Plus messaging and account_portal routes from additional modules)

### Catalog Contract Check

**Command:** `.\ops\catalog_contract_check.ps1`

**Result:** ✅ PASS
```
=== CATALOG CONTRACT CHECK (WP-2) ===
[1] Testing GET /api/v1/categories...
PASS: Categories endpoint returns non-empty tree
  Root categories: 3
  Found wedding-hall category (id: 3)
  PASS: All required root categories present (vehicle, real-estate, service)
  WP-17: Testing double-call to prevent redeclare fatal...
  PASS: Second call succeeded (no redeclare fatal)

[2] Testing GET /api/v1/categories/3/filter-schema...
PASS: Filter schema endpoint returns valid response
  Category ID: 3
  Category Slug: wedding-hall
  Active filters: 1
  PASS: wedding-hall has capacity_max filter with required=true

=== CATALOG CONTRACT CHECK: PASS ===
```

**Key Verification:**
- ✅ Double-call test PASS (no redeclare fatal)
- ✅ Categories tree returns correctly
- ✅ Filter schema endpoint works

### "Cannot Redeclare" Risk Explanation

**Problem:** Closure içinde `function buildTree` tanımı PHP-FPM'de ikinci request'te "Cannot redeclare function buildTree" fatal error'ına yol açabilir.

**Solution:** Function'ı `_helpers.php`'ye taşıdık ve `function_exists()` guard ile koruduk. Bu sayede:
- İlk request'te function tanımlanır
- İkinci request'te `function_exists()` true döner, tekrar tanımlama yapılmaz
- Redeclare riski sıfırlanır

## Files Changed

**Created:**
- `work/pazar/routes/_helpers.php` (helper functions with function_exists guards)
- `work/pazar/routes/api/00_ping.php`
- `work/pazar/routes/api/01_world_status.php`
- `work/pazar/routes/api/02_catalog.php` (uses pazar_build_tree helper)
- `work/pazar/routes/api/03_listings.php`
- `work/pazar/routes/api/04_reservations.php`
- `work/pazar/routes/api/05_orders.php`
- `work/pazar/routes/api/06_rentals.php`

**Modified:**
- `work/pazar/routes/api.php` (thin loader, 18 lines)

**Total:** 1 modified, 8 created

## Zero Behavior Change Verification

- ✅ URL paths unchanged
- ✅ Response body formats unchanged
- ✅ Status codes unchanged
- ✅ Middleware attachments unchanged
- ✅ Validation rules unchanged
- ✅ Only structural changes (file organization + helper extraction)

## Acceptance Criteria

- ✅ All contract checks PASS
- ✅ No routes missing (27 routes loaded)
- ✅ No 500 on second categories call
- ✅ git diff shows only route-file split + helper addition (no domain edits)

## Conclusion

WP-17 Routes Stabilization v2 completed successfully. Helper extraction eliminates redeclare risk deterministically. Route modularization improves maintainability without any behavior change.

**Status:** ✅ COMPLETE
