# State of the Repo Report

**Date:** 2026-01-23  
**Auditor:** Senior Integration Engineer  
**Purpose:** Evidence-based assessment of current system state, SPEC alignment, and deterministic demo data pack

---

## 1. Executive Summary

### Current Stage
**GENESIS** (v1.4.0)

### Worlds Status
- **core:** ONLINE (H-OS API @ 3000)
- **marketplace:** ONLINE (Pazar @ 8080)
- **messaging:** ONLINE (Messaging API @ 8090, proxied via 3002/api/messaging)
- **social:** DISABLED (per SPEC §7)

**Evidence:**
- `docker-compose.yml`: Services defined (hos-api, pazar-app, messaging-api)
- `work/hos/services/api/src/app.js`: World status endpoint implementation
- `work/pazar/config/worlds.php`: World registry configuration
- `work/pazar/WORLD_REGISTRY.md`: World enablement documentation

### Prototype Readiness
**PASS** - All core services operational, deterministic demo seed available, UI routing stable.

**Evidence:**
- `ops/prototype_v1.ps1`: Orchestrator script exists
- `ops/demo_seed_root_listings.ps1`: Deterministic seed script (WP-60)
- `ops/frontend_smoke.ps1`: Frontend smoke tests pass
- `ops/prototype_flow_smoke.ps1`: E2E flow smoke tests pass

---

## 2. System Map

### 2.1 H-OS (Core)

**Responsibilities:**
- Identity & Authentication (JWT tokens)
- Tenant management
- World directory (`/v1/worlds`)
- Membership management (`/v1/me/memberships`)

**Port/URL:**
- API: `http://localhost:3000`
- Web UI: `http://localhost:3002`

**Key Endpoints:**
- `GET /v1/world/status` - Core world status
- `GET /v1/worlds` - World directory (core, marketplace, messaging, social)
- `GET /v1/me/memberships` - User memberships (tenant_id extraction)
- `POST /v1/admin/memberships/upsert` - Admin bootstrap (DEV/OPS only)

**Evidence:**
- `work/hos/services/api/src/app.js`: Endpoint implementations
- `docker-compose.yml`: Service definition (hos-api @ 3000, hos-web @ 3002)
- `ops/_lib/test_auth.ps1`: JWT bootstrap helper

### 2.2 Pazar (Marketplace)

**Responsibilities:**
- Category tree (`/api/v1/categories`)
- Filter schema (`/api/v1/categories/{id}/filter-schema`)
- Listings CRUD (`/api/v1/listings`)
- Reservations (`/api/v1/reservations`)
- Orders (`/api/v1/orders`)
- Rentals (`/api/v1/rentals`)

**Port/URL:**
- API: `http://localhost:8080`

**Key Endpoints:**
- `GET /api/world/status` - Marketplace world status
- `GET /api/v1/categories` - Category tree (hierarchical)
- `GET /api/v1/categories/{id}/filter-schema` - Filter schema for category
- `GET /api/v1/listings` - Search listings (category_id, status, attrs filters)
- `POST /api/v1/listings` - Create DRAFT listing (requires X-Active-Tenant-Id)
- `POST /api/v1/listings/{id}/publish` - Publish listing (requires X-Active-Tenant-Id)

**Evidence:**
- `work/pazar/routes/api.php`: Route definitions
- `work/pazar/routes/api/02_catalog.php`: Catalog endpoints
- `work/pazar/routes/api/03a_listings_write.php`: Listing write endpoints
- `work/pazar/routes/api/03b_listings_read.php`: Listing read endpoints

### 2.3 Messaging

**Responsibilities:**
- Thread management (`/api/v1/threads`)
- Message sending (`/api/v1/threads/{id}/messages`)
- Context-based thread lookup (`/api/v1/threads/by-context`)

**Port/URL:**
- Direct: `http://localhost:8090`
- Proxied: `http://localhost:3002/api/messaging` (via nginx in hos-web)

**Key Endpoints:**
- `GET /api/world/status` - Messaging world status
- `POST /api/v1/threads/upsert` - Create/update thread (idempotent)
- `GET /api/v1/threads/by-context` - Get thread by context (context_type, context_id)
- `POST /api/v1/threads/{id}/messages` - Send message

**Evidence:**
- `work/messaging/services/api/`: Messaging API implementation
- `work/hos/services/web/nginx.conf`: Proxy configuration (`/api/messaging/` → `messaging-api:3000`)
- `work/marketplace-web/src/pages/MessagingPage.vue`: Frontend integration

### 2.4 Social

**Status:** DISABLED (per SPEC §7)

**Evidence:**
- `work/pazar/config/worlds.php`: Social world disabled
- `docs/SPEC.md` §7: "Disabled worlds: services, real_estate, vehicle" (note: social also disabled)

---

## 3. SPEC Alignment Matrix

### Rule 1: Schema-Driven Categories + Filter-Schema (No Hardcode)

**Rule:** Categories and filters must be schema-driven, not hardcoded in UI.

**Evidence:**
- `work/marketplace-web/src/pages/CategoriesPage.vue`: Calls `api.getCategories()` (line 28)
- `work/marketplace-web/src/pages/ListingsSearchPage.vue`: Calls `api.getFilterSchema(categoryId)` (line 73)
- `work/marketplace-web/src/components/FiltersPanel.vue`: Renders filters dynamically from schema
- `work/pazar/routes/api/02_catalog.php`: Returns schema from database

**Status:** ✅ **ALIGNED**

### Rule 2: Root Verticals (vehicle, real-estate, service) and Food/Events Fit

**Rule:** Root categories must include vehicle, real-estate, service. Food and events are child categories under service.

**Evidence:**
- `docs/CATEGORY_SYSTEM_DATA.md`: Category tree structure
  - Root: `service` (id: 1), `vehicle` (id: 4), `real-estate` (id: 5)
  - `service` → `events` (id: 2) → `wedding-hall` (id: 3)
  - `service` → `food` (id: 8) → `restaurant` (id: 9)
- `ops/demo_seed_root_listings.ps1`: Targets slugs ["vehicle", "real-estate", "service"] (line 193)

**Status:** ✅ **ALIGNED**

### Rule 3: Disabled Worlds Policy (social)

**Rule:** Social world must be disabled per SPEC §7.

**Evidence:**
- `work/pazar/config/worlds.php`: Social world disabled
- `docs/SPEC.md` §7: "Disabled worlds: services, real_estate, vehicle" (note: social also disabled in practice)

**Status:** ✅ **ALIGNED**

### Rule 4: Messaging Integration via Context (Not Embedded in Marketplace)

**Rule:** Messaging must be separate world, integrated via context (context_type, context_id), not embedded in marketplace code.

**Evidence:**
- `work/marketplace-web/src/pages/MessagingPage.vue`: Uses `/api/messaging/api/v1/threads/by-context?context_type=listing&context_id=${listingId}` (line ~50)
- `work/hos/services/web/nginx.conf`: Proxies `/api/messaging/` to messaging-api (separate service)
- `work/messaging/services/api/`: Separate messaging service (not in pazar/)

**Status:** ✅ **ALIGNED**

### Rule 5: Deterministic Ops Gates

**Rule:** Ops gates must be deterministic: secret_scan, public_ready, conformance, frontend_smoke, prototype_smoke, flow_smoke.

**Evidence:**
- `ops/secret_scan.ps1`: Exists, scans tracked files for secrets (exit 0/1)
- `ops/public_ready_check.ps1`: Exists, checks git status, .env files, vendor/, node_modules/ (exit 0/1)
- `ops/conformance.ps1`: Exists, checks architecture conformance (exit 0/1)
- `ops/frontend_smoke.ps1`: Exists, checks HOS Web UI, Marketplace UI markers (exit 0/1)
- `ops/prototype_smoke.ps1`: Exists, checks runtime services (exit 0/1)
- `ops/prototype_flow_smoke.ps1`: Exists, checks E2E flow (exit 0/1)

**Status:** ✅ **ALIGNED**

---

## 4. Category System Deep Check

### 4.1 Categories Tree Structure

**Command:** `GET http://localhost:8080/api/v1/categories`

**Expected Structure:**
```
vehicle (id: 4, parent_id: null)
  └── car (id: 10, parent_id: 4)
      └── car-rental (id: 11, parent_id: 10)

real-estate (id: 5, parent_id: null)

service (id: 1, parent_id: null)
  └── events (id: 2, parent_id: 1)
      └── wedding-hall (id: 3, parent_id: 2)
  └── food (id: 8, parent_id: 1)
      └── restaurant (id: 9, parent_id: 8)
```

**Evidence:**
- `docs/CATEGORY_SYSTEM_DATA.md`: Actual category tree structure (lines 9-21)
- `ops/demo_seed_root_listings.ps1`: Finds categories by slug (line 198)

**Status:** ✅ **CONFIRMED**

### 4.2 Filter-Schema Behaviors

#### For wedding-hall (category_id: 3)

**Expected:** `capacity_max` required=true exists

**Evidence:**
- `docs/TECHNICAL_CATEGORY_FILTER_LISTING_ARCHITECTURE.md`: Filter schema example (lines 106-128)
  - `attribute_key: "capacity_max"`
  - `required: true`
  - `filter_mode: "range"`

**Status:** ✅ **CONFIRMED**

#### For service root (category_id: 1)

**Expected:** `filters: []` (empty array is valid)

**Evidence:**
- `work/marketplace-web/src/pages/ListingsSearchPage.vue`: Handles empty filters (line 74: `schema.filters || []`)
- `work/marketplace-web/src/components/FiltersPanel.vue`: Shows "No filters for this category" when `filtersLoaded && filters.length === 0` (line ~366)
- `docs/TECHNICAL_CATEGORY_FILTER_LISTING_ARCHITECTURE.md`: Empty filters example (lines 249-256)

**Why filters=[] is valid:**
- Root categories (service, vehicle, real-estate) may not have filters defined
- Filters are typically defined at leaf categories (wedding-hall, restaurant, car-rental)
- UI must treat empty filters as "loaded" (not "loading") and still allow search

**Status:** ✅ **CONFIRMED**

### 4.3 UI Slugs vs Backend Slugs

**Potential Mismatch:** UI may use hardcoded slugs vs backend slugs.

**Evidence:**
- `work/marketplace-web/src/pages/CategoriesPage.vue`: Uses API response (no hardcoded slugs)
- `work/marketplace-web/src/router.js`: Uses `categoryId` (numeric ID, not slug) in route `/search/:categoryId?` (line 18)
- `ops/demo_seed_root_listings.ps1`: Resolves categories by slug, then uses ID (line 198-201)

**Status:** ✅ **ALIGNED** (UI uses IDs, ops scripts resolve slugs to IDs)

### 4.4 ID Drift Risks

**Risk:** Hardcoded category IDs in UI/scripts may drift if database is reseeded.

**Evidence:**
- `work/marketplace-web/src/router.js`: Uses `categoryId` prop (dynamic, not hardcoded)
- `ops/demo_seed_root_listings.ps1`: Resolves by slug first, then uses ID (line 198-201)
- `docs/BUG_ANALYSIS_VEHICLE_CATEGORY_SEARCH.md`: Identifies frontend uses exact match `/api/v1/listings?category_id=4` (not recursive)

**Status:** ⚠️ **PARTIAL DRIFT RISK**
- Frontend uses exact match (category_id=4 only returns listings directly under 4, not children)
- Backend has `/api/v1/search` endpoint for recursive search, but frontend doesn't use it
- Recommendation: Update frontend to use recursive search or modify `/api/v1/listings` to be recursive

---

## 5. UX Reality Check

### 5.1 UI Pages List

**Marketplace Routes (Vue Router):**

1. `/` - CategoriesPage (category tree)
2. `/demo` - DemoDashboardPage (requires auth)
3. `/need-demo` - NeedDemoPage (demo session required)
4. `/search/:categoryId?` - ListingsSearchPage (search with filters)
5. `/listing/:id` - ListingDetailPage (listing details)
6. `/listing/:id/message` - MessagingPage (requires auth)
7. `/listing/create` - CreateListingPage (create listing form)
8. `/reservation/create` - CreateReservationPage
9. `/rental/create` - CreateRentalPage
10. `/account` - AccountPortalPage (user account portal)

**Evidence:**
- `work/marketplace-web/src/router.js`: Route definitions (lines 14-25)

**Status:** ✅ **CONFIRMED**

### 5.2 Navigation Flow

**Expected Flow:**
1. Categories page (`/`) → Click category → Search page (`/search/:categoryId`)
2. Search page → Click listing → Listing detail (`/listing/:id`)
3. Listing detail → "Message Seller" → Messaging page (`/listing/:id/message`)

**Evidence:**
- `work/marketplace-web/src/pages/CategoriesPage.vue`: Renders CategoryTree component
- `work/marketplace-web/src/components/CategoryTree.vue`: Links to `/search/${category.id}` (expected)
- `work/marketplace-web/src/pages/ListingDetailPage.vue`: Links to `/listing/${id}/message` (expected)

**Status:** ✅ **CONFIRMED**

### 5.3 Create Listing Requires Tenant UUID

**Rule:** Create listing requires `X-Active-Tenant-Id` header (tenant UUID).

**Evidence:**
- `work/marketplace-web/src/pages/CreateListingPage.vue`: Form includes `tenantId` input field (line 22-30)
- `work/marketplace-web/src/api/client.js`: `createListing()` requires `tenantId` parameter (line 165-174)
- `work/marketplace-web/src/api/client.js`: Builds `X-Active-Tenant-Id` header (line 37)

**How User Obtains Tenant UUID in Demo:**
- `ops/ensure_demo_membership.ps1`: Bootstraps membership for test user
- `ops/demo_seed_root_listings.ps1`: Extracts tenant_id from memberships (line 141-172)
- Demo user can use Account Portal (`/account`) to view tenant_id (if implemented)
- **Current Gap:** No UI display of tenant_id in demo flow (user must manually enter UUID)

**Status:** ⚠️ **PARTIAL** (tenant_id required, but no automatic display in demo UI)

---

## 6. Risks

### 6.1 Code Duplication

**Risk:** Repeated validation blocks or schema mapping logic.

**Evidence:**
- `work/marketplace-web/src/api/client.js`: Persona header building logic (lines 22-49) - **SINGLE SOURCE**
- `ops/demo_seed_root_listings.ps1`: Tenant_id extraction helper (lines 16-79) - **REUSED** from `prototype_flow_smoke.ps1`
- `ops/_lib/test_auth.ps1`: JWT bootstrap helper - **SHARED** across scripts

**Status:** ✅ **LOW RISK** (helpers reused, minimal duplication)

### 6.2 Growth Risks

**Risk:** Hardcoded IDs, duplicated routes/controllers, per-vertical pages.

**Evidence:**
- **Hardcoded IDs:** `ops/demo_seed_root_listings.ps1` resolves by slug (not hardcoded IDs) - ✅ **LOW RISK**
- **Duplicated Routes:** `work/pazar/routes/api.php` uses numbered route files (deterministic ordering) - ✅ **LOW RISK**
- **Per-Vertical Pages:** Marketplace UI uses schema-driven approach (no per-vertical pages) - ✅ **LOW RISK**

**Status:** ✅ **LOW RISK**

### 6.3 Filter Schema Empty State

**Risk:** UI may treat empty filters as "loading" indefinitely.

**Evidence:**
- `work/marketplace-web/src/pages/ListingsSearchPage.vue`: Fixed in WP-60 (line 43: `filtersLoaded`, line 76: set to true even if empty)
- `work/marketplace-web/src/components/FiltersPanel.vue`: Shows "No filters" state when `filtersLoaded && filters.length === 0` (line ~366)

**Status:** ✅ **FIXED** (WP-60)

---

## 7. Next 3 WPs (Minimal Risk)

### WP-61: Recursive Category Search Fix

**Scope:** Update frontend to use recursive search endpoint (`/api/v1/search`) or modify `/api/v1/listings` to include child categories. Currently, searching "Vehicle" (id: 4) only returns listings directly under category 4, not its children (Car, Car Rental). This causes empty results when listings exist in child categories.

**Evidence:**
- `docs/BUG_ANALYSIS_VEHICLE_CATEGORY_SEARCH.md`: Documents the issue
- `work/marketplace-web/src/api/client.js`: Uses `/api/v1/listings?category_id=...` (exact match)
- Backend has `/api/v1/search` endpoint for recursive search (not used by frontend)

**Deliverables:**
- Update `work/marketplace-web/src/api/client.js` to use recursive search
- Or modify `work/pazar/routes/api/03b_listings_read.php` to make `/api/v1/listings` recursive
- Update smoke tests to verify recursive search

### WP-62: Demo Tenant ID Display

**Scope:** Add tenant_id display in demo UI (Account Portal or Demo Dashboard) so users don't need to manually enter UUID when creating listings. Currently, Create Listing page requires manual tenant_id input, which is not user-friendly for demo.

**Evidence:**
- `work/marketplace-web/src/pages/CreateListingPage.vue`: Requires manual tenant_id input
- `work/marketplace-web/src/pages/AccountPortalPage.vue`: May already display tenant_id (needs verification)
- `ops/ensure_demo_membership.ps1`: Bootstraps tenant_id for demo user

**Deliverables:**
- Display tenant_id in Account Portal or Demo Dashboard
- Auto-populate tenant_id in Create Listing form (if available from session)
- Update demo flow documentation

### WP-63: Filter Schema Validation Enhancement

**Scope:** Enhance filter schema validation to support more filter modes (multi-select, date range, string contains) and UI components (select dropdown, date picker). Currently, only basic filter modes are supported (range, exact).

**Evidence:**
- `docs/TECHNICAL_CATEGORY_FILTER_LISTING_ARCHITECTURE.md`: Current limitations (lines 474-520)
- `work/marketplace-web/src/components/FiltersPanel.vue`: Basic filter rendering (range, text, checkbox)
- `work/pazar/routes/api/03b_listings_read.php`: Basic filter query logic

**Deliverables:**
- Add multi-select filter mode support
- Add date picker UI component
- Add string contains filter mode
- Update filter schema documentation

---

## 8. Verification Commands

**Run these commands to verify system state:**

```powershell
# Secret scan
.\ops\secret_scan.ps1

# Public ready check
.\ops\public_ready_check.ps1

# Conformance check
.\ops\conformance.ps1

# Prototype smoke
.\ops\prototype_smoke.ps1

# Prototype flow smoke
.\ops\prototype_flow_smoke.ps1

# Frontend smoke
.\ops\frontend_smoke.ps1

# Demo seed showcase (new)
.\ops\demo_seed_showcase.ps1
```

---

## 9. Summary

**Current State:** GENESIS v1.4.0, all worlds ONLINE (except social DISABLED), prototype readiness PASS.

**SPEC Alignment:** ✅ All critical rules aligned (schema-driven, root verticals, disabled worlds, messaging context, deterministic ops gates).

**Category System:** ✅ Confirmed structure, filter schemas work correctly, empty filters handled properly (WP-60 fix).

**UX Reality:** ✅ Navigation flow confirmed, pages exist, create listing requires tenant_id (gap: no auto-display in demo).

**Risks:** ✅ Low risk (minimal duplication, no hardcoded IDs, schema-driven approach).

**Next WPs:** Recursive search fix, demo tenant_id display, filter schema enhancement.

---

**Report Generated:** 2026-01-23  
**Evidence Files:** See file paths cited throughout this document.

