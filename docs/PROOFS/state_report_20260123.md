# State of the Repo Report

**Date:** 2026-01-23  
**Auditor:** Repo Auditor (Read-First)  
**Purpose:** Truth-first report of current repo state, SPEC alignment, drift risks, and next minimal-risk WP

---

## Section A: Current HEAD + Ops Gate Matrix

### Git State

**HEAD:** `6517137`  
**Last 5 Commits:**
```
6517137 (HEAD -> main, origin/main, origin/HEAD) WP-REPORT: state report + showcase seed pack
583fe75 WP-60: prototype integration (empty filters fix + root demo seed)
ffa007c WP-60: demo UX auto-search + deterministic demo seed
31daa35 WP-59: demo control panel (scriptless readiness + actions)
3f57826 WP-58: fix smoke test markers (HTML template + fallback checks)
```

**Working Tree Status:**
- Deleted: `docs/GITHUB_PAGES_SETUP.md`, `docs/MERGE_RECOVERY_PLAN.md`
- Untracked: `docs/CONTRACT_CHECKS_INDEX.md`, `docs/PROOFS/wp25_header_contract_enforcement_pass.md`, `docs/PROOFS/wp28_listing_contract_500_fix_pass.md`, `docs/PROOFS/wp30_listing_contract_auth_alignment_pass.md`, `docs/REPORTS/contract_check_report_20260123.md`, `docs/UI_PATHS.md`

### Ops Gate Matrix

| Script | Status | Exit Code | Notes |
|--------|--------|-----------|-------|
| `world_status_check.ps1` | **PASS** | 0 | All worlds ONLINE (core, marketplace, messaging), social DISABLED |
| `catalog_contract_check.ps1` | **PASS** | 0 | Categories tree valid, filter-schema returns expected structure |
| `listing_contract_check.ps1` | **FAIL** | 1 | 401 Unauthorized on POST /api/v1/listings (missing JWT token) |
| `reservation_contract_check.ps1` | **FAIL** | 0 | 401 Unauthorized on POST /api/v1/reservations (missing JWT token) |
| `messaging_contract_check.ps1` | **PASS** | 0 | Thread upsert, message post, by-context lookup all working |
| `frontend_smoke.ps1` | **FAIL** | 1 | Messaging proxy unreachable (404 on /api/messaging/api/world/status) |
| `prototype_smoke.ps1` | **PASS** | 0 | Docker services running, HTTP endpoints accessible, UI marker present |
| `prototype_flow_smoke.ps1` | **PASS** | 0 | Full E2E flow: JWT → tenant_id → listing → publish → messaging → message |

**Summary:**
- **PASS:** 5/8 gates
- **FAIL:** 3/8 gates
- **Critical Failures:**
  1. `listing_contract_check.ps1`: Missing JWT token bootstrap (requires `ops/_lib/test_auth.ps1`)
  2. `reservation_contract_check.ps1`: Missing JWT token bootstrap (requires `ops/_lib/test_auth.ps1`)
  3. `frontend_smoke.ps1`: Messaging proxy 404 (nginx config issue or messaging-api not accessible via proxy)

---

## Section B: SPEC Alignment Summary

### Worlds Status

**Evidence:** `ops/world_status_check.ps1` output

| World | Status | Port/URL | SPEC Reference |
|-------|--------|----------|----------------|
| **core** | ONLINE | `http://localhost:3000` | §4.1, §9.1 |
| **marketplace** | ONLINE | `http://localhost:8080` | §4.1, §9.2 |
| **messaging** | ONLINE | `http://localhost:8090` (direct), `http://localhost:3002/api/messaging` (proxied) | §4.1, §9.5 |
| **social** | DISABLED | N/A | §7, §24.3 |

**Alignment:** ✅ **ALIGNED**
- All enabled worlds are ONLINE
- Social world is DISABLED per SPEC §7
- World status endpoints return expected format per SPEC §4.1

### Marketplace Spine

**Evidence:** `work/pazar/routes/api/02_catalog.php`, `work/pazar/routes/api/03a_listings_write.php`, `work/pazar/routes/api/03b_listings_read.php`

| Endpoint | Method | Persona | Status | SPEC Reference |
|----------|--------|---------|--------|----------------|
| `/api/v1/categories` | GET | GUEST+ | ✅ Implemented | §4.2, §6.2 |
| `/api/v1/categories/{id}/filter-schema` | GET | GUEST+ | ✅ Implemented | §4.2, §6.2 |
| `/api/v1/listings` | GET | GUEST+ | ✅ Implemented | §4.3, §6.3 |
| `/api/v1/listings` | POST | STORE | ✅ Implemented | §4.3, §6.3 |
| `/api/v1/listings/{id}/publish` | POST | STORE | ✅ Implemented | §4.3, §6.3 |
| `/api/v1/listings/{id}` | GET | GUEST+ | ✅ Implemented | §4.3, §6.3 |

**Alignment:** ✅ **ALIGNED**
- All endpoints match SPEC §4.2, §4.3
- Persona requirements match SPEC §5.2
- Schema-driven approach prevents vertical controller explosion (SPEC §1.2)

### Messaging Integration

**Evidence:** `ops/messaging_contract_check.ps1` output, `work/hos/services/web/nginx.conf`

| Endpoint | Method | Status | SPEC Reference |
|----------|--------|--------|----------------|
| `/api/v1/threads/upsert` | POST | ✅ Working | §25.4 (PLANNED, but implemented) |
| `/api/v1/threads/by-context` | GET | ✅ Working | §25.4 (PLANNED, but implemented) |
| `/api/v1/threads/{id}/messages` | POST | ✅ Working | §25.4 (PLANNED, but implemented) |

**Alignment:** ⚠️ **DRIFT**
- Messaging endpoints are implemented but SPEC §25.4 marks them as "PLANNED"
- Messaging proxy via nginx (`/api/messaging/`) is implemented but not documented in SPEC
- **Recommendation:** Update SPEC §25.4 to reflect current implementation status

### Social World

**Evidence:** `work/pazar/config/worlds.php`, `ops/world_status_check.ps1`

**Status:** DISABLED per SPEC §7

**Alignment:** ✅ **ALIGNED**
- Social world is correctly disabled in registry
- World status endpoint returns DISABLED

---

## Section C: Category System Deep Check

### Category Tree Structure

**Evidence:** `ops/catalog_contract_check.ps1` output

**Root Categories:**
1. `vehicle` (id: 4, parent_id: null)
   - `car` (id: 10, parent_id: 4)
     - `car-rental` (id: 11, parent_id: 10)
2. `real-estate` (id: 5, parent_id: null)
3. `service` (id: 1, parent_id: null)
   - `events` (id: 2, parent_id: 1)
     - `wedding-hall` (id: 3, parent_id: 2)
   - `food` (id: 8, parent_id: 1)
     - `restaurant` (id: 9, parent_id: 8)

**Alignment:** ✅ **ALIGNED**
- Hierarchical structure matches SPEC §6.2
- All categories have `status: active`
- Tree structure built via `pazar_build_tree()` helper

### Filter Schema Behavior

**Evidence:** `ops/catalog_contract_check.ps1` output, `work/pazar/routes/api/02_catalog.php`

**wedding-hall (id: 3):**
- `capacity_max` (number, required: true, filter_mode: range, ui_component: number)
- Status: ✅ **ALIGNED** - Required attribute present, filter schema returns expected structure

**service (id: 1):**
- `filters: []` (empty array)
- Status: ✅ **ALIGNED** - Empty filter schema is valid per SPEC (not all categories require filters)

**UI Behavior:**
- `work/marketplace-web/src/pages/ListingsSearchPage.vue`: Handles `filters: []` correctly (shows "No filters for this category" instead of "Loading filters...")
- `work/marketplace-web/src/components/FiltersPanel.vue`: Displays empty state with enabled Search button

**Alignment:** ✅ **ALIGNED**
- Filter schema endpoint returns empty array for categories without filters
- UI correctly handles empty filter state (WP-60 fix)

### Category Search Behavior

**Evidence:** `work/pazar/routes/api/03b_listings_read.php`

**Two Endpoints with Different Behavior:**

1. **GET /api/v1/listings?category_id={id}** (Line 8-97)
   - **Behavior:** Exact match only (line 13: `$query->where('category_id', $request->input('category_id'))`)
   - **Status:** ⚠️ **NON-RECURSIVE** - Does not include child categories

2. **GET /api/v1/search?category_id={id}** (Line 127-284)
   - **Behavior:** Recursive (includes all descendant categories)
   - **Implementation:** Lines 147-166 use `$getDescendantCategoryIds()` helper to recursively fetch all child category IDs
   - **Status:** ✅ **RECURSIVE** - Includes child categories

**Drift Risk:**
- **Issue:** `/api/v1/listings` endpoint does NOT include child categories, while `/api/v1/search` does
- **Impact:** UI using `/api/v1/listings` will not show listings from child categories when searching a parent category
- **Evidence:** `work/marketplace-web/src/pages/ListingsSearchPage.vue` uses `/api/v1/listings` endpoint (not `/api/v1/search`)
- **Recommendation:** Either:
  1. Update `/api/v1/listings` to include recursive category search (align with `/api/v1/search`)
  2. Update UI to use `/api/v1/search` endpoint instead of `/api/v1/listings`
  3. Document the difference in SPEC and ensure UI uses the correct endpoint

**Hardcoded Category IDs:**

**Evidence:** `grep -r "category_id.*=.*\d+" ops/`

| File | Line | Hardcoded ID | Risk |
|------|------|--------------|------|
| `ops/tenant_scope_contract_check.ps1` | 29, 72, 131 | `category_id = 3` (wedding-hall) | ⚠️ **MEDIUM** - Assumes wedding-hall ID is 3 |
| `ops/persona_scope_check.ps1` | 147, 197 | `category_id = 3` (wedding-hall) | ⚠️ **MEDIUM** - Assumes wedding-hall ID is 3 |

**Alignment:** ⚠️ **DRIFT RISK**
- Hardcoded category IDs in ops scripts assume specific IDs from seeder
- If seeder changes or IDs drift, scripts will fail
- **Recommendation:** Update scripts to resolve category IDs by slug (like `ops/demo_seed_root_listings.ps1` does)

---

## Section D: Risk Assessment

### 1. Code Duplication

**Evidence:** `work/pazar/routes/api/03b_listings_read.php`

**Risk:** ⚠️ **MEDIUM**
- Two similar listing search endpoints (`/api/v1/listings` and `/api/v1/search`) with different behaviors
- `/api/v1/listings` does exact category match
- `/api/v1/search` does recursive category match + additional filters (city, date_from, date_to, capacity_min, transaction_mode)
- **Impact:** Confusion about which endpoint to use, potential for inconsistent results

**Recommendation:** Consolidate or clearly document the difference in SPEC

### 2. Hardcoded IDs

**Evidence:** `grep -r "category_id.*=.*\d+" ops/`, `grep -r "tenant_id.*=.*\d+" ops/`

**Risk:** ⚠️ **MEDIUM**
- Hardcoded `category_id = 3` in multiple ops scripts
- Hardcoded `tenant_id` values in some scripts (though most use `ops/_lib/test_auth.ps1` to bootstrap)
- **Impact:** Scripts fail if IDs change between seeds or environments

**Recommendation:** Update all ops scripts to resolve IDs by slug/name (like `ops/demo_seed_root_listings.ps1`)

### 3. Authentication Drift

**Evidence:** `ops/listing_contract_check.ps1`, `ops/reservation_contract_check.ps1` outputs

**Risk:** ⚠️ **HIGH**
- Contract check scripts fail with 401 Unauthorized
- Scripts do not bootstrap JWT tokens using `ops/_lib/test_auth.ps1`
- **Impact:** Contract checks cannot validate write endpoints (POST operations)

**Recommendation:** Update `listing_contract_check.ps1` and `reservation_contract_check.ps1` to:
1. Bootstrap JWT using `ops/_lib/test_auth.ps1`
2. Get `tenant_id` from memberships API
3. Include `Authorization` and `X-Active-Tenant-Id` headers in requests

### 4. Messaging Proxy Configuration

**Evidence:** `ops/frontend_smoke.ps1` output, `work/hos/services/web/nginx.conf`

**Risk:** ⚠️ **MEDIUM**
- Messaging proxy returns 404 on `/api/messaging/api/world/status`
- Proxy configuration may be incorrect or messaging-api service not accessible
- **Impact:** Frontend cannot access messaging API via same-origin proxy

**Recommendation:** Verify nginx configuration and messaging-api service accessibility

### 5. Growth Risks

**Evidence:** `work/pazar/routes/api/` directory structure

**Risk:** ✅ **LOW**
- Routes are organized by domain (catalog, listings_write, listings_read, reservations, orders, rentals)
- No per-vertical controllers (aligned with SPEC §1.2)
- Schema-driven approach prevents controller explosion

**Recommendation:** Continue schema-driven approach, avoid per-vertical endpoints

---

## Section E: Next 3 Minimal-Risk WPs

### WP-61: Contract Check Authentication Fix

**Scope:**
- Update `ops/listing_contract_check.ps1` to bootstrap JWT token using `ops/_lib/test_auth.ps1`
- Update `ops/reservation_contract_check.ps1` to bootstrap JWT token using `ops/_lib/test_auth.ps1`
- Get `tenant_id` from memberships API (reuse pattern from `ops/demo_seed_root_listings.ps1`)
- Include `Authorization` and `X-Active-Tenant-Id` headers in all write requests
- Ensure all contract checks PASS

**Acceptance Criteria:**
- `listing_contract_check.ps1` PASS (exit code 0)
- `reservation_contract_check.ps1` PASS (exit code 0)
- All write endpoints (POST /api/v1/listings, POST /api/v1/listings/{id}/publish, POST /api/v1/reservations) validated
- No hardcoded tenant_id or category_id values
- Tokens masked in output (last 6 chars only)

**Risk:** ✅ **LOW** - Only ops script updates, no backend changes

---

### WP-62: Category Search Consistency

**Scope:**
- Document the difference between `/api/v1/listings` (exact match) and `/api/v1/search` (recursive) in SPEC
- Update UI (`work/marketplace-web/src/pages/ListingsSearchPage.vue`) to use `/api/v1/search` endpoint for category-based searches
- OR: Update `/api/v1/listings` to include recursive category search (align with `/api/v1/search`)
- Ensure consistent behavior: parent category search includes child category listings

**Acceptance Criteria:**
- SPEC documents the difference between `/api/v1/listings` and `/api/v1/search`
- UI search for parent category (e.g., "vehicle") includes listings from child categories (e.g., "car-rental")
- Contract check validates recursive category search behavior
- No breaking changes to existing API contracts

**Risk:** ⚠️ **MEDIUM** - May require UI changes and API behavior change (choose one approach)

---

### WP-63: Ops Script Hardcoded ID Elimination

**Scope:**
- Update all ops scripts with hardcoded `category_id` values to resolve IDs by slug
- Reuse pattern from `ops/demo_seed_root_listings.ps1` (resolve category by slug via categories tree)
- Update: `ops/tenant_scope_contract_check.ps1`, `ops/persona_scope_check.ps1`
- Add helper function in `ops/_lib/` if needed to avoid duplication

**Acceptance Criteria:**
- No hardcoded `category_id = 3` or similar values in ops scripts
- All category IDs resolved by slug via `/api/v1/categories` endpoint
- Scripts work regardless of seeder changes or ID drift
- Helper function reusable across scripts

**Risk:** ✅ **LOW** - Only ops script updates, no backend changes

---

## Summary

**Current State:**
- **HEAD:** `6517137` (WP-REPORT: state report + showcase seed pack)
- **Ops Gates:** 5/8 PASS, 3/8 FAIL (authentication issues in contract checks, messaging proxy 404)
- **SPEC Alignment:** Mostly aligned, minor drift in messaging endpoints (implemented but marked PLANNED)
- **Category System:** Functional, but inconsistent search behavior between `/api/v1/listings` and `/api/v1/search`
- **Risks:** Medium risk from authentication drift, hardcoded IDs, and category search inconsistency

**Next Steps:**
1. Fix contract check authentication (WP-61) - **HIGH PRIORITY**
2. Resolve category search consistency (WP-62) - **MEDIUM PRIORITY**
3. Eliminate hardcoded IDs in ops scripts (WP-63) - **LOW PRIORITY**

---

**Report Generated:** 2026-01-23  
**Auditor:** Repo Auditor (Read-First)  
**Method:** Evidence-based inspection (no code changes)

