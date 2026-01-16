# APPENDIX: As-Is Analysis - Pazar Marketplace

**Analysis Date:** 2026-01-16  
**Analyst Role:** Senior Staff Engineer / Repo Archaeologist  
**Scope:** `work/pazar/**` (excluding `vendor/`, `node_modules/`, `storage/`, `bootstrap/cache`)  
**Reference:** `docs/SPEC.md` v1.4.0 (especially §§ 1.2, 4.2-4.4, 6.2-6.3, 9.3-9.5)

---

## Executive Summary

The Marketplace (Pazar) codebase implements **canonical spine architecture** (WP-2 Catalog, WP-3 Supply, WP-4 Transactions) via **inline route closures** in `routes/api.php`, aligned with SPEC §1.2 (No Vertical Controllers). However, the codebase contains **49 unused controller files** violating SPEC §1.2, a **duplicate Product model/table** not referenced by canonical routes (canonical uses `listings` per SPEC §4.3), and **orphaned support classes** used only by unused controllers. All canonical endpoints use direct `DB::table()` access; no controllers, services, or request classes are referenced in `routes/api.php`. Middleware is registered in `bootstrap/app.php` and is canonical. Tests, migrations, and seeders align with spine implementation.

---

## Inventory Table

| Path | Category | Reason | Suggested Action |
|------|----------|--------|------------------|
| `app/Http/Controllers/Admin/TenantController.php` | LEGACY | Not referenced in `routes/api.php` or `routes/web.php`. Violates SPEC §1.2 (No Vertical Controllers). | DELETE |
| `app/Http/Controllers/Admin/TenantUserController.php` | LEGACY | Not referenced in routes. Violates SPEC §1.2. | DELETE |
| `app/Http/Controllers/Api/Commerce/ListingController.php` | LEGACY | Not referenced in `routes/api.php`. Canonical routes use inline closures (WP-3, SPEC §4.3). | DELETE |
| `app/Http/Controllers/Api/Food/FoodListingController.php` | LEGACY | Not referenced in routes. Violates SPEC §1.2. | DELETE |
| `app/Http/Controllers/Api/Food/ListingController.php` | LEGACY | Not referenced in routes. Violates SPEC §1.2. | DELETE |
| `app/Http/Controllers/Api/ProductController.php` | LEGACY | Not referenced in routes. Uses `Product` model (not canonical per SPEC §4.3). | DELETE |
| `app/Http/Controllers/Api/Rentals/ListingController.php` | LEGACY | Not referenced in routes. Violates SPEC §1.2. | DELETE |
| `app/Http/Controllers/Api/Rentals/RentalsListingController.php` | LEGACY | Not referenced in routes. Violates SPEC §1.2. | DELETE |
| `app/Http/Controllers/Auth/TokenController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/ListingController.php` | LEGACY | Not referenced in routes. Violates SPEC §1.2. | DELETE |
| `app/Http/Controllers/MetricsController.php` | LEGACY | Not referenced in routes. Uses `Product` model. | DELETE |
| `app/Http/Controllers/Panel/Audit/StatusChangeLogController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Panel/MeController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Panel/OrderController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Panel/PaymentController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Panel/PingController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Panel/ProductController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Panel/ReservationController.php` | LEGACY | Not referenced in routes. Canonical reservations use inline closures (WP-4, SPEC §4.4). | DELETE |
| `app/Http/Controllers/Panel/StatsController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Panel/TenantUserController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Public/OrderController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Public/PaymentController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Public/PaymentWebhookController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Public/ProductController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Public/ReservationController.php` | LEGACY | Not referenced in routes. Canonical reservations use inline closures (WP-4). | DELETE |
| `app/Http/Controllers/Ui/AdminCategoriesController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/AdminControlCenterController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/AdminTenantsController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/AdminUsersController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/CheckoutController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/DashboardController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/EnterController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/LoginController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/MeController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/OidcController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/ShopController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/TenantAvailabilityController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/TenantContextController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/TenantOnboardingController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/TenantOrdersController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/TenantPaymentsController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/TenantProductsController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/TenantReservationsController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Ui/TenantUsersController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/World/Commerce/CommerceHomeController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/World/Food/FoodHomeController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/World/Rentals/RentalsHomeController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/WorldController.php` | LEGACY | Not referenced in routes. | DELETE |
| `app/Http/Controllers/Controller.php` | REVIEW | Base controller class. May be needed if any controller remains. If all controllers deleted, DELETE. | REVIEW |
| `app/Models/Product.php` | DUPLICATE | Canonical routes use `listings` table (SPEC §4.3). `products` table not referenced by canonical endpoints. Only used by unused controllers. | REVIEW |
| `database/migrations/2026_01_11_000000_create_products_table.php` | DUPLICATE | Products table not used by canonical spine (SPEC §4.3 uses `listings`). | REVIEW |
| `app/Support/ApiSpine/ListingQueryModel.php` | ORPHAN | Only used by unused vertical controllers (`Api/Commerce/ListingController`, `Api/Food/FoodListingController`, `Api/Rentals/RentalsListingController`). | DELETE |
| `app/Support/ApiSpine/ListingWriteModel.php` | ORPHAN | Only used by unused vertical controllers. | DELETE |
| `app/Support/ApiSpine/ListingReadModel.php` | ORPHAN | Only used by unused vertical controllers. | DELETE |
| `app/Support/ApiSpine/NotImplemented.php` | ORPHAN | Not referenced anywhere. | DELETE |
| `app/Support/Api/ListingQuery.php` | ORPHAN | Used only by `ApiSpine/ListingQueryModel`, which is orphaned. | DELETE |
| `app/Support/Api/ListingReadDTO.php` | ORPHAN | Used only by `ApiSpine/ListingQueryModel`, which is orphaned. | DELETE |
| `app/Support/Api/Cursor.php` | ORPHAN | Used only by `Support/Api/ListingQuery`, which is orphaned. | DELETE |
| `app/Services/Commerce/ListingService.php` | ORPHAN | Not referenced by canonical routes. Routes use direct `DB::table('listings')` access (WP-3, SPEC §4.3). | DELETE |
| `app/Http/Requests/Commerce/ListingIndexRequest.php` | ORPHAN | Not used by canonical routes. Routes use inline `$request->validate()` (see `routes/api.php` lines 216-224). | DELETE |
| `app/Http/Requests/Commerce/ListingStoreRequest.php` | ORPHAN | Not used by canonical routes. | DELETE |
| `app/Http/Requests/Commerce/ListingUpdateRequest.php` | ORPHAN | Not used by canonical routes. | DELETE |

---

## Detailed Justifications

### LEGACY: Controllers (49 files)

**Evidence:**
```bash
# No controller imports in routes
$ grep "use App\\Http\\Controllers" routes/api.php
# Returns: No matches

# No controller references in routes
$ grep "Route::.*Controller" routes/api.php
# Returns: No matches
```

**Violation:** SPEC §1.2 states: "No Vertical Controllers - Schema-driven approach prevents controller explosion. Single canonical endpoint family per domain (Catalog, Supply, Transactions)."

**Canonical Replacement:**
- All canonical routes implemented as **inline closures** in `routes/api.php`:
  - Catalog Spine (WP-2, SPEC §4.2): Lines 76-191 (`/v1/categories`, `/v1/categories/{id}/filter-schema`)
  - Supply Spine (WP-3, SPEC §4.3): Lines 195-455 (`/v1/listings`, `/v1/listings/{id}/publish`)
  - Transactions Spine (WP-4, SPEC §4.4): Lines 459-691 (`/v1/reservations`, `/v1/reservations/{id}/accept`)

**Action:** DELETE (49 files)

**Note:** `app/Http/Controllers/Controller.php` (base class) is REVIEW - delete if all controllers removed.

---

### DUPLICATE: Product Model and Table

**Location:** `app/Models/Product.php`, `database/migrations/2026_01_11_000000_create_products_table.php`

**Evidence:**
```bash
# No products table references in canonical routes
$ grep -i "products" routes/api.php
# Returns: No matches

# Product model only used by unused controllers
$ grep "Product::" app/Http/Controllers/**/*.php
# Returns: MetricsController.php, Api/ProductController.php (both unused)
```

**Violation:** SPEC §4.3 (Supply Spine) defines canonical endpoint as `POST /api/v1/listings` using `listings` table. `products` table/model not referenced by canonical routes.

**Canonical Replacement:** `app/Models/Listing.php` + `listings` table (SPEC §4.3, WP-3)

**Action:** REVIEW (may be reserved for future use, but currently unused by spine)

---

### ORPHAN: ApiSpine Support Classes

**Location:** `app/Support/ApiSpine/*.php` (4 files)

**Evidence:**
```bash
# ApiSpine classes only used by unused controllers
$ grep "ApiSpine" app/Http/Controllers/**/*.php
# Returns: Api/Commerce/ListingController.php, Api/Food/FoodListingController.php, Api/Rentals/RentalsListingController.php
# All three controllers are not referenced in routes/api.php
```

**Why it exists:** Likely created for vertical controller architecture (pre-SPEC §1.2).

**Why not used:** Canonical routes use direct `DB::table()` access, no abstraction layer.

**Action:** DELETE (4 files)

---

### ORPHAN: Support/Api Classes

**Location:** `app/Support/Api/*.php` (3 files: `ListingQuery.php`, `ListingReadDTO.php`, `Cursor.php`)

**Evidence:**
```bash
# Support/Api classes only used by ApiSpine classes
$ grep "Support\\Api" app/**/*.php
# Returns: ApiSpine/ListingQueryModel.php, ApiSpine/ListingReadModel.php (both orphaned)
```

**Why it exists:** Dependency of ApiSpine abstraction layer.

**Why not used:** ApiSpine classes are orphaned (only used by unused controllers).

**Action:** DELETE (3 files)

---

### ORPHAN: ListingService

**Location:** `app/Services/Commerce/ListingService.php`

**Evidence:**
```bash
# ListingService not referenced in routes
$ grep "ListingService" routes/api.php
# Returns: No matches

# Only referenced in composer autoload (vendor)
$ grep "ListingService" app/**/*.php
# Returns: Only in Services/Commerce/ListingService.php itself
```

**Why it exists:** Business logic abstraction for vertical controllers.

**Why not used:** Canonical routes use direct `DB::table('listings')` access (see `routes/api.php` lines 298-311, 370-386).

**Action:** DELETE

---

### ORPHAN: Request Classes

**Location:** `app/Http/Requests/Commerce/*.php` (3 files)

**Evidence:**
```bash
# Request classes not used in canonical routes
$ grep "ListingIndexRequest\|ListingStoreRequest\|ListingUpdateRequest" routes/api.php
# Returns: No matches

# Canonical routes use inline validation
$ grep "validate(" routes/api.php | head -3
# Returns: Lines 216, 470 (inline $request->validate())
```

**Why it exists:** Form request validation for vertical controllers.

**Why not used:** Canonical routes use inline validation (see `routes/api.php` line 216).

**Action:** DELETE (3 files)

---

## NO-TOUCH LIST

Files that **must never** be deleted (canonical spine and infrastructure):

### Routes (Canonical Spine)
- `routes/api.php` - Canonical route definitions (WP-2, WP-3, WP-4)
- `routes/web.php` - Root route (WP-1)

### Models (Canonical)
- `app/Models/Listing.php` - Canonical Listing model (SPEC §4.3, WP-3)

### Infrastructure (Required)
- `app/Worlds/WorldRegistry.php` - World registry (SPEC §7, §24.3)
- `config/worlds.php` - World configuration (SPEC §7)
- `config/logging.php` - Laravel logging config
- `bootstrap/app.php` - Laravel application bootstrap (registers middleware)
- `WORLD_REGISTRY.md` - World documentation

### H-OS Integration
- `app/Hos/Contract/BaseContract.php` - H-OS contract interface
- `app/Hos/Remote/RemoteHosHttpClient.php` - H-OS remote client

### Middleware (Registered in bootstrap/app.php)
- `app/Http/Middleware/Cors.php` - Registered line 37
- `app/Http/Middleware/SecurityHeaders.php` - Registered line 38
- `app/Http/Middleware/ForceJsonForApi.php` - Registered line 41
- `app/Http/Middleware/RequestId.php` - Registered lines 45, 48
- `app/Http/Middleware/ErrorEnvelope.php` - Registered line 52
- `app/Http/Middleware/ResolveTenant.php` - Aliased line 67
- `app/Http/Middleware/EnsureTenantUser.php` - Aliased line 68
- `app/Http/Middleware/WorldResolver.php` - Aliased line 76
- `app/Http/Middleware/WorldLock.php` - Aliased line 77
- `app/Http/Middleware/AuthAny.php` - Aliased line 70

**Note:** Middleware classes referenced but not found (`EnsureTenantRole`, `EnsureSuperAdmin`, `EnsureUiSuperAdmin`, `ResolveUiTenant`) are referenced in `bootstrap/app.php` lines 69-74 but files don't exist. This is a code quality issue but not a deletion concern.

### Migrations (Canonical Spine Schema)
- `database/migrations/2026_01_15_100000_create_categories_table.php` - Catalog Spine (SPEC §4.2, WP-2)
- `database/migrations/2026_01_15_100001_create_attributes_table.php` - Catalog Spine (SPEC §4.2, WP-2)
- `database/migrations/2026_01_15_100002_create_category_filter_schema_table.php` - Catalog Spine (SPEC §4.2, WP-2)
- `database/migrations/2026_01_16_100000_update_category_filter_schema_add_fields.php` - Catalog Spine update
- `database/migrations/2026_01_16_100001_fix_categories_table_schema.php` - Catalog Spine fix
- `database/migrations/2026_01_10_000000_create_listings_table.php` - Supply Spine (SPEC §4.3, WP-3)
- `database/migrations/2026_01_16_100002_update_listings_table_wp3.php` - Supply Spine update (WP-3)
- `database/migrations/2026_01_16_100003_create_reservations_table.php` - Transactions Spine (SPEC §4.4, WP-4)
- `database/migrations/2026_01_16_100004_create_idempotency_keys_table.php` - Transactions Spine (SPEC §4.4, §17.4, WP-4)
- `database/migrations/2026_01_16_141957_create_sessions_table.php` - Laravel sessions (required for web routes)

### Seeders (Canonical Data)
- `database/seeders/CatalogSpineSeeder.php` - Canonical catalog seeder (WP-2, WP-4.4)
- `database/seeders/ListingApiSpineSeeder.php` - Listing seeder (WP-3)

### Tests (Canonical Verification)
- `tests/Feature/WorldSpineTest.php` - World spine tests (WP-1)
- `tests/Feature/ListingCoreTest.php` - Listing core tests
- `tests/Feature/Api/CommerceListingSpineTest.php` - Supply spine tests (WP-3)
- `tests/Feature/Api/CommerceListingMvpTest.php` - Supply spine tests (WP-3)

### Views (World UI)
- `resources/views/worlds/home.blade.php` - Enabled world home page
- `resources/views/worlds/closed.blade.php` - Disabled world page

### Configuration Files
- `composer.json` - PHP dependencies
- `composer.lock` - Dependency lock file
- `artisan` - Laravel CLI
- `docker/Dockerfile` - Container build
- `docker/docker-entrypoint.sh` - Container entrypoint
- `docker/ensure_storage.sh` - Storage setup
- `docker/nginx/default.conf` - Nginx config
- `docker/supervisord.conf` - Supervisor config

---

## Summary Statistics

- **Total Files Analyzed:** ~75 (excluding vendor, tests, views, config)
- **Canonical Files:** 33 (routes, models, migrations, seeders, middleware, world registry, H-OS integration)
- **Legacy Files:** 49 (controllers)
- **Duplicate Files:** 2 (Product model + migration)
- **Orphan Files:** 11 (ApiSpine, Support/Api, Services, Requests)
- **Review Files:** 1 (Controller.php base class)

**Deletion Candidates:**
- **DELETE:** 60 files (49 controllers + 11 orphans)
- **REVIEW:** 3 files (Controller.php base class + 2 Product files)

**Risk Level:** LOW (all deletion candidates are not referenced in canonical routes)

---

## Evidence Summary

| Classification | Evidence Method | Result |
|----------------|----------------|--------|
| Controllers not referenced | `grep "use App\\Http\\Controllers" routes/api.php` | No matches |
| Product not in routes | `grep -i "products" routes/api.php` | No matches |
| ApiSpine only in unused controllers | `grep "ApiSpine" app/Http/Controllers/**/*.php` | Only unused controllers |
| ListingService not in routes | `grep "ListingService" routes/api.php` | No matches |
| Request classes not in routes | `grep "ListingIndexRequest\|ListingStoreRequest" routes/api.php` | No matches |
| Routes use inline closures | `grep "Route::" routes/api.php \| wc -l` | 11 routes, all closures |
| Middleware registered | `grep "Middleware" bootstrap/app.php` | 10 middleware registered |

---

**End of Report**
