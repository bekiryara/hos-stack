# SPEC v1.4 - Canonical Specification

**Version:** 1.4.0  
**Last Updated:** 2026-01-16  
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

## §5. Error Codes (§17.5)

- **WORLD_DISABLED**: World is disabled in registry/config
- **VALIDATION_ERROR**: Validation failed (e.g., party_size > capacity_max) (§6.3)
- **CONFLICT**: Resource conflict (e.g., slot overlap) (§6.7)
- **missing_header**: Required header missing (X-Active-Tenant-Id, Idempotency-Key)
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

## §9. Workspace Packages (WP) Status

### §9.1. WP-0: Governance Lock (§25.2)

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

**SPEC v1.4 - Canonical Specification**  
**Last Updated:** 2026-01-16  
**Status:** GENESIS
