# SPEC v1.4 - Canonical Specification

**Version:** 1.4.0  
**Last Updated:** 2026-01-19  
**Status:** GENESIS  
**Single Source of Truth:** This document is the canonical specification for hos-stack.

---

## §1. Principles

### §1.1. Baseline Freeze
- Baseline services, ports, and health endpoints are **frozen** (cannot be changed)
- Baseline definition: `docs/RELEASES/BASELINE.md`
- Baseline verification: `ops/baseline_status.ps1`

### §1.2. No Vertical Controllers
- Schema-driven approach prevents controller explosion
- Single canonical endpoint family per domain (Catalog, Supply, Transactions)
- UI/search driven by schema, not code

### §1.3. Single Source of Truth
- `docs/SPEC.md` - Canonical specification (this document)
- `docs/CURRENT.md` - Current system state
- `docs/DECISIONS.md` - Baseline decisions
- `docs/ONBOARDING.md` - Quick start guide

### §1.4. Proof-Driven Development
- Every code change requires proof document in `docs/PROOFS/`
- Proof documents contain real command outputs
- SPEC references proof documents, not raw outputs

---

## §2. Ownership Map

### §2.1. Repository Structure
- **Application Code:** `work/hos/`, `work/pazar/`
- **Operations:** `ops/`
- **Documentation:** `docs/`
- **Configuration:** Root (`docker-compose.yml`, `.gitignore`)
- **Archive:** `_archive/` (historical docs, snapshots)
- **Graveyard:** `_graveyard/` (unused code, with NOTE.md)

### §2.2. Service Ownership
- **H-OS API:** `work/hos/services/api/` (Fastify/Node.js)
- **H-OS Web:** `work/hos/services/web/` (Frontend)
- **Pazar (Marketplace):** `work/pazar/` (Laravel/PHP)
- **Database:** PostgreSQL (hos-db, pazar-db)

### §2.3. Port Assignments (Frozen)
- H-OS API: `3000`
- H-OS Web: `3002`
- Pazar App: `8080`
- H-OS DB: `5432` (internal)
- Pazar DB: `5433` (internal)

---

## §3. Folder Skeleton

```
hos-stack/
├── work/
│   ├── hos/
│   │   └── services/
│   │       ├── api/          # H-OS API (Fastify)
│   │       └── web/           # H-OS Web (Frontend)
│   └── pazar/                 # Marketplace (Laravel)
│       ├── routes/
│       ├── database/
│       └── config/
├── ops/                        # Operations scripts
├── docs/                       # Documentation
│   ├── SPEC.md                 # Canonical spec (this file)
│   ├── CURRENT.md              # Current system state
│   ├── PROOFS/                 # Proof documents
│   └── WP_CLOSEOUTS.md         # WP closeout summaries
├── _archive/                   # Historical docs, snapshots
├── _graveyard/                 # Unused code (with NOTE.md)
└── docker-compose.yml          # Service orchestration
```

---

## §4. API Spine

### §4.1. World Status Contract (§24.3-§24.4)

**GET /world/status** (Marketplace/Pazar)

Response format:
```json
{
  "world_key": "marketplace",
  "availability": "ONLINE|OFFLINE|DISABLED",
  "phase": "GENESIS",
  "version": "1.4.0",
  "commit": "<short_sha>" // optional
}
```

**GET /v1/worlds** (Core/H-OS API)

Response format:
```json
[
  {
    "world_key": "core",
    "availability": "ONLINE",
    "phase": "GENESIS",
    "version": "1.4.0"
  },
  {
    "world_key": "marketplace",
    "availability": "ONLINE",
    "phase": "GENESIS",
    "version": "1.4.0"
  }
]
```

**World Disabled Response (§17.5):**

HTTP 503 Service Unavailable:
```json
{
  "error_code": "WORLD_DISABLED",
  "message": "World 'marketplace' is disabled",
  "world_key": "marketplace"
}
```

### §4.2. Catalog Spine (§6.2)

**GET /api/v1/categories**
- Returns hierarchical category tree
- Only active categories
- Tree structure with parent_id relationships

**GET /api/v1/categories/{id}/filter-schema**
- Returns filter schema for category
- Includes required attributes, UI components, filter modes
- Schema-driven validation rules

### §4.3. Supply Spine (§6.3)

**POST /api/v1/listings**
- Creates DRAFT listing
- Requires `X-Active-Tenant-Id` header
- Validates required attributes against `category_filter_schema`

**POST /api/v1/listings/{id}/publish**
- Publishes listing (draft -> published)
- Requires `X-Active-Tenant-Id` header
- Tenant ownership enforced

**GET /api/v1/listings**
- Search listings (category_id, status, attrs filters)

**GET /api/v1/listings/{id}**
- Get single listing

### §4.4. Transactions Spine (§6.3, §6.7, §17.4)

**POST /api/v1/reservations**
- Creates reservation (status=requested)
- Requires `Idempotency-Key` header
- Validates: listing published, party_size <= capacity_max, no slot overlap
- Returns 201 Created or 200 OK (idempotency replay)

**POST /api/v1/reservations/{id}/accept**
- Accepts reservation (requested -> accepted)
- Requires `X-Active-Tenant-Id` header
- Tenant ownership enforced (provider_tenant_id must match)

**GET /api/v1/reservations/{id}**
- Get single reservation (debug/read)

**Invariants:**
1. Capacity Constraint (§6.3): party_size <= capacity_max
2. No Double-Booking (§6.7): Slot overlaps -> CONFLICT (409)

**Idempotency (§17.4):**
- Write operations require `Idempotency-Key` header
- Same (scope, key, request_hash) returns same response
- Stored in `idempotency_keys` table with TTL (24 hours)

---

## §5. Persona & Scope Lock (WP-8)

### §5.1. Persona Definitions

- **GUEST**: Unauthenticated user (no Authorization header)
- **PERSONAL**: Authenticated user performing personal transactions (Authorization: Bearer token required)
- **STORE**: Authenticated tenant performing store/provider operations (X-Active-Tenant-Id header required)

### §5.2. Required Header Contract

**PERSONAL write/read operations:**
- `Authorization: Bearer <token>` header **REQUIRED**
- Missing header → 401 + `error_code: AUTH_REQUIRED`

**STORE operations:**
- `X-Active-Tenant-Id: <tenant_id>` header **REQUIRED**
- Missing header → 400/403 + `error_code: missing_header` or `FORBIDDEN_SCOPE`
- In GENESIS: Authorization optional (only tenant header enforced)
- Future: Authorization may be required for full membership validation

### §5.3. Endpoint-Persona Matrix

| Endpoint | Method | Persona | Required Headers |
|----------|--------|---------|------------------|
| `/api/v1/categories` | GET | GUEST+ | None |
| `/api/v1/categories/{id}/filter-schema` | GET | GUEST+ | None |
| `/api/v1/listings` | GET | GUEST+ | None |
| `/api/v1/listings/{id}` | GET | GUEST+ | None |
| `/api/v1/listings` | POST | STORE | `X-Active-Tenant-Id` |
| `/api/v1/listings/{id}/publish` | POST | STORE | `X-Active-Tenant-Id` |
| `/api/v1/reservations` | POST | PERSONAL | `Authorization`, `Idempotency-Key` |
| `/api/v1/reservations/{id}` | GET | PERSONAL/STORE | `Authorization` (if read owner/provider) |
| `/api/v1/reservations/{id}/accept` | POST | STORE | `X-Active-Tenant-Id` |
| `/api/v1/rentals` | POST | PERSONAL | `Authorization`, `Idempotency-Key` |
| `/api/v1/rentals/{id}` | GET | PERSONAL/STORE | `Authorization` (if read owner/provider) |
| `/api/v1/rentals/{id}/accept` | POST | STORE | `X-Active-Tenant-Id` |
| `/api/v1/orders` | POST | PERSONAL | `Authorization`, `Idempotency-Key` |
| `/api/v1/orders/{id}` | GET | PERSONAL/STORE | `Authorization` (if read owner/provider) |

**Messaging endpoints:**
- Thread/message read/write: PERSONAL/STORE (Authorization required) + participant validation
- WP-16 (PLANNED): POST /api/v1/threads (idempotent), POST /api/v1/messages (direct send)

---

## §5A. Error Codes (§17.5)

- **WORLD_DISABLED**: World is disabled in registry/config
- **VALIDATION_ERROR**: Validation failed (e.g., party_size > capacity_max) (§6.3)
- **CONFLICT**: Resource conflict (e.g., slot overlap) (§6.7)
- **AUTH_REQUIRED**: Missing Authorization header for PERSONAL operations (§5.2)
- **missing_header**: Required header missing (X-Active-Tenant-Id, Idempotency-Key)
- **FORBIDDEN_SCOPE**: Invalid tenant scope or membership denied (§5.2)
- **invalid_tenant_id**: Tenant ID format invalid
- **unauthorized**: Tenant ownership mismatch
- **listing_not_found**: Listing does not exist
- **listing_not_published**: Listing must be published

---

## §6. Workspace Done (§12.A)

Workspace is considered "done" when:
- All core services are running
- Health endpoints return 200 OK
- World status endpoints are accessible
- Smoke tests pass (`ops/smoke.ps1`)

---

## §7. World Enablement (§24.3)

Worlds are enabled/disabled via:
- `work/pazar/config/worlds.php` (canonical source)
- `work/pazar/WORLD_REGISTRY.md` (documentation)

Enabled worlds: `commerce`, `food`, `rentals`  
Disabled worlds: `services`, `real_estate`, `vehicle`

---

## §8. Governance Lock (§25.2)

### §8.1. PR Requirements

Every PR MUST include:
- **SPEC Reference**: `VAR — §X.Y` or `YOK → EK — §X.Y`
- **Proof**: `ops/doctor` + `ops/smoke` outputs attached
- **Contracts changed?**: yes/no (API/DB)
- **Proof Doc Path**: Link to proof document in `docs/PROOFS/`

### §8.2. CI Gate

CI workflow `.github/workflows/gate-spec.yml` enforces:
- `docs/SPEC.md` exists
- `docs/CURRENT.md` exists
- PR description contains "SPEC Reference" line

---

## §9. Completed Work Packages

This section lists all Work Packages (WP) that have been completed and evidenced by proof documents in `docs/PROOFS/`.

### Completed WPs (WP-17 through WP-28B)

- **WP-17:** Routes Stabilization Finalization - Finalized Pazar API route modularization, removed duplicate routes, updated route duplicate guard. Proof: `docs/PROOFS/wp17_routes_stabilization_finalization_pass.md`
- **WP-19:** Messaging Write Alignment + Ops Hardening - Aligned messaging write endpoints with ops scripts, hardened contract check script. Proof: `docs/PROOFS/wp19_messaging_write_alignment_pass.md`
- **WP-20:** Reservation Routes + Auth Preflight Stabilization - Made Reservation Contract Check deterministic, eliminated 500 errors, required real JWT tokens. Proof: `docs/PROOFS/wp20_reservation_auth_stabilization_pass.md`
- **WP-21:** Routes Guardrails (Budget + Drift) - Added deterministic guard enforcing line-count budgets and preventing unreferenced route module drift. Proof: `docs/PROOFS/wp21_routes_guardrails_pass.md`
- **WP-22:** Listings Routes Headroom - Ensured listings routes remain within budget after additions. Proof: `docs/PROOFS/wp22_listings_routes_headroom_pass.md`
- **WP-23:** Test Auth Bootstrap + Spine Check Determinism - Made Marketplace verification deterministic, eliminated manual PRODUCT_TEST_AUTH setup. Proof: `docs/PROOFS/wp23_spine_determinism_pass.md`
- **WP-24:** Write-Path Lock - Locked write-path determinism, created write snapshot, added CI gate scripts. Proof: `docs/PROOFS/wp24_write_path_lock_pass.md`
- **WP-25:** Header Contract Enforcement - Eliminated false-positive WARN messages in boundary_contract_check.ps1. Proof: `docs/PROOFS/wp25_header_contract_enforcement_pass.md`
- **WP-26:** Store-Scope Unification + Middleware Pack - Unified X-Active-Tenant-Id + membership enforcement into TenantScope middleware. Proof: `docs/PROOFS/wp26_store_scope_unification_pass.md`
- **WP-27:** Repo Hygiene + Closeout Alignment - Made repository clean and deterministic after recent WPs. Proof: `docs/PROOFS/wp27_repo_hygiene_closeout_pass.md`
- **WP-28:** Listing 500 Elimination + Store-Scope Header Hardening - Fixed HTTP 500 errors on POST /api/v1/listings endpoints. Proof: `docs/PROOFS/wp28_listing_contract_500_fix_pass.md`
- **WP-28B:** Fix tenant.scope Middleware Binding - Fixed Composer autoload cache issue preventing tenant.scope middleware resolution. Proof: `docs/PROOFS/wp28_listing_contract_500_fix_pass.md` (updated)

For detailed closeout summaries, see `docs/WP_CLOSEOUTS.md`.

---

## §9A. Current Stable Invariants

These invariants are enforced across all endpoints and must not be violated by any code changes.

### §9A.1. Idempotency

- All write operations (POST, PUT, PATCH, DELETE) require `Idempotency-Key` header
- Same (scope, key, request_hash) returns same response (stored in `idempotency_keys` table)
- Idempotency keys expire after 24 hours (TTL)
- Replay detection prevents duplicate processing

**Enforcement:** `ops/idempotency_coverage_check.ps1` validates all required endpoints have idempotency implemented.

### §9A.2. Scope Validation

- Store-scope endpoints require `X-Active-Tenant-Id` header (enforced via `tenant.scope` middleware)
- Tenant ID format validated (UUID)
- Membership validated via MembershipClient (strict mode via HOS API)
- Missing/invalid header → 400/403 with appropriate error codes

**Enforcement:** `ops/boundary_contract_check.ps1` validates header presence and middleware usage.

### §9A.3. Determinism

- Route modules loaded in deterministic order (numbered prefixes: 00_ping.php, 01_world_status.php, ...)
- Stable naming scheme (numbered for ordering, descriptive for identification)
- Route duplicate guard prevents duplicate route definitions
- Line-count budgets enforced (entry point max 120 lines, modules max 900 lines)

**Enforcement:** `ops/pazar_routes_guard.ps1` validates budgets and detects unreferenced modules.

### §9A.4. Guardrails

- Route duplicate detection (27 unique routes, no duplicates)
- Module reference validation (all referenced modules exist, no unreferenced modules)
- Line-count budget enforcement (prevents monolith regrowth)
- Write-path snapshot validation (prevents unauthorized endpoint changes)

**Enforcement:** Multiple guard scripts in `ops/` directory validate these invariants.

---

## §9B. Workspace Packages (WP) Status

### §9B.1. WP-0: Governance Lock (§25.2)

**Status:** ✅ COMPLETE

**Purpose:** Enforce SPEC governance via CI gates and PR requirements.

**Deliverables:**
- `docs/SPEC.md` (canonical specification)
- `.github/workflows/gate-spec.yml` (CI gate)
- `.github/pull_request_template.md` (PR template with SPEC reference)

**Proof:** See `docs/WP_CLOSEOUTS.md` §WP-0

---

### §9.2. WP-1: GENESIS World Status (§25.2)

**Status:** ✅ COMPLETE

**Purpose:** Implement world status endpoints for core and marketplace.

**Endpoints:**
- `GET /world/status` (Marketplace) - Returns marketplace world status
- `GET /v1/world/status` (Core) - Returns core world status
- `GET /v1/worlds` (Core) - Returns directory of all worlds

**Acceptance Criteria:**
- Marketplace endpoint returns ONLINE when Pazar is running
- Core endpoint returns array with core, marketplace, messaging, social
- Smoke test (`ops/smoke.ps1`) passes

**Proof:** `docs/PROOFS/wp1_1_world_status_smoke_pass.md`, `docs/PROOFS/wp1_3_marketplace_ping_pass.md`

**Closeout:** See `docs/WP_CLOSEOUTS.md` §WP-1.2

---

### §9.3. WP-2: Marketplace Catalog Spine (§6.2)

**Status:** ✅ COMPLETE

**Purpose:** Implement canonical category, attribute, and filter-schema backbone.

**Endpoints:**
- `GET /api/v1/categories` - Returns category tree
- `GET /api/v1/categories/{id}/filter-schema` - Returns filter schema

**Database:**
- `categories` table (hierarchical with parent_id)
- `attributes` table (global attribute catalog)
- `category_filter_schema` table (maps attributes to categories)

**Acceptance Criteria:**
- Categories endpoint returns non-empty tree
- Filter schema endpoint returns active schema rows
- Seeder populates example categories (wedding-hall, restaurant, car-rental)
- Contract check (`ops/catalog_contract_check.ps1`) passes

**Proof:** `docs/PROOFS/wp2_catalog_spine_pass.md`

**Closeout:** See `docs/WP_CLOSEOUTS.md` §WP-2

---

### §9.4. WP-3: Supply Spine (§6.3)

**Status:** ✅ COMPLETE

**Purpose:** Implement canonical Listing (Supply) backbone with schema-validated attributes.

**Endpoints:**
- `POST /api/v1/listings` - Creates DRAFT listing
- `POST /api/v1/listings/{id}/publish` - Publishes listing
- `GET /api/v1/listings` - Search listings
- `GET /api/v1/listings/{id}` - Get single listing

**Database:**
- `listings` table (with category_id, transaction_modes_json, attributes_json, location_json)

**Acceptance Criteria:**
- Listing creation validates required attributes against category_filter_schema
- Tenant ownership enforced via X-Active-Tenant-Id header
- Publish endpoint transitions draft -> published
- Contract check (`ops/listing_contract_check.ps1`) passes

**Proof:** `docs/PROOFS/wp3_supply_spine_pass.md`

**Closeout:** See `docs/WP_CLOSEOUTS.md` §WP-3

---

### §9.5. WP-4: Reservation Thin Slice (§6.3, §6.7, §17.4)

**Status:** ✅ COMPLETE (Code Ready)

**Purpose:** Implement first real thin-slice of Marketplace Transactions spine: RESERVATIONS.

**Endpoints:**
- `POST /api/v1/reservations` - Creates reservation (with idempotency)
- `POST /api/v1/reservations/{id}/accept` - Accepts reservation
- `GET /api/v1/reservations/{id}` - Get single reservation

**Database:**
- `reservations` table (listing_id, provider_tenant_id, slot_start, slot_end, party_size, status)
- `idempotency_keys` table (scope_type, scope_id, key, request_hash, response_json, expires_at)

**Invariants:**
1. Capacity Constraint (§6.3): party_size <= capacity_max
2. No Double-Booking (§6.7): Slot overlaps -> CONFLICT (409)

**Idempotency (§17.4):**
- Write operations require `Idempotency-Key` header
- Same (scope, key, request_hash) returns same response

**Acceptance Criteria:**
- Reservation creation validates party_size <= capacity_max
- Slot overlap detection returns 409 CONFLICT
- Idempotency replay returns same reservation ID
- Tenant ownership enforced for accept endpoint
- Contract check (`ops/reservation_contract_check.ps1`) passes

**Proof:** `docs/PROOFS/wp4_reservation_spine_pass.md`

**Closeout:** See `docs/WP_CLOSEOUTS.md` §WP-4

---

## §10. References

### §10.1. Proof Documents

- WP-1.1: `docs/PROOFS/wp1_1_world_status_smoke_pass.md`
- WP-1.3: `docs/PROOFS/wp1_3_marketplace_ping_pass.md`
- WP-2: `docs/PROOFS/wp2_catalog_spine_pass.md`
- WP-3: `docs/PROOFS/wp3_supply_spine_pass.md`
- WP-4: `docs/PROOFS/wp4_reservation_spine_pass.md`

### §10.2. Closeout Summaries

See `docs/WP_CLOSEOUTS.md` for detailed closeout summaries of each WP.

---

## §25. Work Packages (WP)

### §25.2. WP List

- **WP-0:** Governance Lock
- **WP-1:** GENESIS World Status
- **WP-2:** Catalog Spine
- **WP-3:** Supply Spine (Listings)
- **WP-4:** Reservation Spine
- **WP-5:** Messaging Integration
- **WP-6:** Orders Spine
- **WP-7:** Rentals Spine
- **WP-8:** Persona & Scope Lock + Core Persona Switch
- **WP-9:** Marketplace Web (Read-First) Thin Slice
- **WP-16:** Messaging Write Thin Slice (PLANNED)

### §25.3. WP-9: Marketplace Web (Read-First) Thin Slice

**Purpose:** Read-first web interface for Marketplace: Category tree → Listing search → Listing detail.

**Rules:**
- No backend code changes (routes, controllers, DB, migrations untouched)
- No business logic in UI (only displays and calls API)
- No hardcoded categories/filters (all from API `/categories` and `/filter-schema`)
- UI renders dynamically from API responses

**Deliverables:**
- Vue 3 + Vite frontend project (`work/marketplace-web/`)
- 3 pages: CategoriesPage, ListingsSearchPage, ListingDetailPage
- 3 components: CategoryTree, FiltersPanel, ListingsGrid
- API client consuming existing Marketplace endpoints

**Proof:** `docs/PROOFS/wp9_marketplace_web_read_spine_pass.md`

**Closeout:** See `docs/WP_CLOSEOUTS.md` §WP-9

### §25.4. WP-16: Messaging Write Thin Slice (PLANNED)

**Purpose:** Add messaging write endpoints (POST /api/v1/threads, POST /api/v1/messages) with authorization, idempotency, and thread ownership enforcement.

**Status:** PLANNING (NO IMPLEMENTATION YET)

**Rules:**
- Authorization required (JWT token)
- Thread ownership enforced (participant validation)
- Idempotency-Key required
- Minimal thin slice (2 endpoints)
- Frontend stub only (disabled CTA)

**Planned Endpoints:**
- POST /api/v1/threads (idempotent thread creation)
- POST /api/v1/messages (direct message send)

**Plan:** See `docs/WP16_PLAN.md`

**Closeout:** See `docs/WP_CLOSEOUTS.md` §WP-16 (PLANNED)

---

## §26. Next WP Candidate

### Recommended Next Step

**WP-NEXT: Governance Sync + Routes/Status Audit + Pazar Legacy Inventory** ✅ COMPLETE

**Status:** Completed 2026-01-19

**Purpose:** Determine exact current state, align SPEC + WP_CLOSEOUTS + CHANGELOG with actual implementation, confirm routes modularization status, produce legacy inventory.

**Deliverables:**
- `docs/PROOFS/wp_next_governance_sync_pass.md` - Reality snapshot and audit results
- `docs/LEGACY_PAZAR_INVENTORY.md` - Legacy file inventory (none found)
- Updated `docs/SPEC.md`, `docs/WP_CLOSEOUTS.md`, `CHANGELOG.md`

**Findings:**
- Routes already modularized (no refactoring needed)
- Core contract checks mostly PASS (3/4)
- No legacy files found in work/pazar/
- Governance docs updated with completed WPs and invariants

**Proof:** `docs/PROOFS/wp_next_governance_sync_pass.md`

### Alternative Next Steps

1. **Security Audit Violations:** ✅ COMPLETE (WP-29) - All 10 POST routes now have `auth.any` middleware
2. **Observability Gaps:** Implement Pazar /metrics endpoint and Prometheus setup (currently 404)
3. **Test Environment Setup:** Fix Reservation Contract Check bootstrap (H-OS admin API configuration)

---

## §27. WP-29: Security Audit Violations Fix

**Status:** ✅ COMPLETE  
**Completed:** 2026-01-19

**Purpose:** Eliminate Security Audit FAIL: "10 violations - POST routes missing auth.any". Zero refactor. Minimal diff. No behavior change except: unauthenticated POST write routes MUST now require auth (expected).

**Deliverables:**
- Added `auth.any` middleware to 10 POST routes across 5 route modules
- Updated security audit script to recognize both alias and class name
- All route guardrails budgets still met

**Proof:** `docs/PROOFS/wp29_security_audit_fix_pass.md`

**Closeout:** See `docs/WP_CLOSEOUTS.md` §WP-29

---

**SPEC v1.4 - Canonical Specification**  
**Last Updated:** 2026-01-19  
**Status:** GENESIS
