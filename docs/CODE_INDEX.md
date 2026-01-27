# Code Index - H-OS Stack

**Purpose:** Central index for quick file location in repository zip. All paths are relative to repo root.

---

## Quick Find (Zip Navigation)

**Frontend Pages:**
- Login: `work/marketplace-web/src/pages/LoginPage.vue`
- Register: `work/marketplace-web/src/pages/RegisterPage.vue`
- Account: `work/marketplace-web/src/pages/AccountPortalPage.vue`
- Create Listing: `work/marketplace-web/src/pages/CreateListingPage.vue`
- Router: `work/marketplace-web/src/router.js`

**Backend API Routes:**
- Main Routes: `work/pazar/routes/api.php`
- Listings: `work/pazar/routes/api/03a_listings_write.php`, `work/pazar/routes/api/03b_listings_read.php`
- Reservations: `work/pazar/routes/api/04_reservations.php`
- Orders: `work/pazar/routes/api/05_orders.php`
- Rentals: `work/pazar/routes/api/06_rentals.php`

**Ops Scripts:**
- Daily Ops: `ops/ops_run.ps1`
- Ship Main: `ops/ship_main.ps1`
- Dev Refresh: `ops/dev_refresh.ps1`
- Verify: `ops/verify.ps1`

**Documentation:**
- Discipline: `docs/DEV_DISCIPLINE.md`
- New Chat Protocol: `docs/NEW_CHAT_PROTOCOL.md`
- WP Closeouts: `docs/WP_CLOSEOUTS.md`
- Current State: `docs/CURRENT.md`

---

## Reading Strategy for AI

1. **Start here:** Read this file to understand the codebase structure
2. **Navigate by service:** Each service (H-OS, Pazar, Messaging) has its own section
3. **Follow repo structure:** Files are organized exactly like the repository structure
4. **Use Quick Find:** Above section lists most commonly accessed files

---

## H-OS Service (`work/hos/`)

**Description:** H-OS (universe governance) - Core authentication, authorization, and world management service.

### API Files (`work/hos/services/api/src/`)

- **Main Entry:** `work/hos/services/api/src/index.js`
- **Server:** `work/hos/services/api/src/server.js`
- **App:** `work/hos/services/api/src/app.js`
- **Config:** `work/hos/services/api/src/config.js`
- **Database:** `work/hos/services/api/src/db.js`
- **Auth:** `work/hos/services/api/src/auth.js`
- **Audit:** `work/hos/services/api/src/audit.js`
- **Migrations:** `work/hos/services/api/src/migrate.js`
- **Cleanup Idempotency:** `work/hos/services/api/src/cleanup_idempotency.js`
- **OpenTelemetry:** `work/hos/services/api/src/otel.js`

### Policy Files (`work/hos/services/api/src/policy/pazar/`)

- **Abilities:** `work/hos/services/api/src/policy/pazar/abilities.js`
- **Roles:** `work/hos/services/api/src/policy/pazar/roles.js`
- **Role Matrix:** `work/hos/services/api/src/policy/pazar/role_matrix.js`
- **Can:** `work/hos/services/api/src/policy/pazar/can.js`

#### Policy Actions (`work/hos/services/api/src/policy/pazar/actions/`)

- **Action Catalog:** `work/hos/services/api/src/policy/pazar/actions/action_catalog.js`
- **Action Keys:** `work/hos/services/api/src/policy/pazar/actions/action_keys.js`
- **Allowed Actions:** `work/hos/services/api/src/policy/pazar/actions/allowed_actions.js`
- **Reservation Contract:** `work/hos/services/api/src/policy/pazar/actions/reservation_contract.js`

#### Policy Contract (`work/hos/services/api/src/policy/pazar/contract/`)

- **Can Transition:** `work/hos/services/api/src/policy/pazar/contract/can_transition.js`

### Configuration

- **Docker Compose:** `work/hos/docker-compose.yml`
- **Dockerfile:** `work/hos/services/api/Dockerfile`

---

## Pazar Service (`work/pazar/`)

**Description:** Pazar (marketplace) - Laravel application for commerce world.

### Routes

- **Main Routes:** `work/pazar/routes/api.php`
- **00_metrics.php**: `work/pazar/routes/api/00_metrics.php`
- **00_ping.php**: `work/pazar/routes/api/00_ping.php`
- **01_world_status.php**: `work/pazar/routes/api/01_world_status.php`
- **02_catalog.php**: `work/pazar/routes/api/02_catalog.php`
- **03a_listings_write.php**: `work/pazar/routes/api/03a_listings_write.php`
- **03b_listings_read.php**: `work/pazar/routes/api/03b_listings_read.php`
- **03c_offers.php**: `work/pazar/routes/api/03c_offers.php`
- **04_reservations.php**: `work/pazar/routes/api/04_reservations.php`
- **05_orders.php**: `work/pazar/routes/api/05_orders.php`
- **06_rentals.php**: `work/pazar/routes/api/06_rentals.php`
- **account_portal.php**: `work/pazar/routes/api/account_portal.php`
- **messaging.php**: `work/pazar/routes/api/messaging.php`

**Key Endpoints:**
- `GET /api/world/status` - World availability and version info
- `GET /api/v1/categories` - Category tree
- `GET /api/v1/catalog/filters` - Filter schema
- `GET /api/v1/listings` - List listings (search, filter, paginate)
- `GET /api/v1/listings/{id}` - Get listing detail
- `POST /api/v1/listings` - Create listing
- `PUT /api/v1/listings/{id}` - Update listing
- `POST /api/v1/listings/{id}/publish` - Publish listing
- `GET /api/v1/reservations` - List reservations
- `POST /api/v1/reservations` - Create reservation
- `PUT /api/v1/reservations/{id}/accept` - Accept reservation
- `PUT /api/v1/reservations/{id}/reject` - Reject reservation

### Middleware (`work/pazar/app/Http/Middleware/`)

- **CORS:** `work/pazar/app/Http/Middleware/Cors.php`
- **Security Headers:** `work/pazar/app/Http/Middleware/SecurityHeaders.php`
- **Force JSON:** `work/pazar/app/Http/Middleware/ForceJsonForApi.php`
- **Request ID:** `work/pazar/app/Http/Middleware/RequestId.php`
- **Error Envelope:** `work/pazar/app/Http/Middleware/ErrorEnvelope.php`
- **Auth Any:** `work/pazar/app/Http/Middleware/AuthAny.php`
- **Auth Context:** `work/pazar/app/Http/Middleware/AuthContext.php`
- **Ensure Tenant User:** `work/pazar/app/Http/Middleware/EnsureTenantUser.php`
- **Persona Scope:** `work/pazar/app/Http/Middleware/PersonaScope.php`
- **Resolve Tenant:** `work/pazar/app/Http/Middleware/ResolveTenant.php`
- **Tenant Scope:** `work/pazar/app/Http/Middleware/TenantScope.php`
- **World Lock:** `work/pazar/app/Http/Middleware/WorldLock.php`
- **World Resolver:** `work/pazar/app/Http/Middleware/WorldResolver.php`

### Database Migrations (`work/pazar/database/migrations/`)

- **Listings Table:** `work/pazar/database/migrations/2026_01_10_000000_create_listings_table.php`
- **Products Table:** `work/pazar/database/migrations/2026_01_11_000000_create_products_table.php`
- **Categories Table:** `work/pazar/database/migrations/2026_01_15_100000_create_categories_table.php`
- **Attributes Table:** `work/pazar/database/migrations/2026_01_15_100001_create_attributes_table.php`
- **Category Filter Schema:** `work/pazar/database/migrations/2026_01_15_100002_create_category_filter_schema_table.php`
- **Update Category Filter Schema:** `work/pazar/database/migrations/2026_01_16_100000_update_category_filter_schema_add_fields.php`
- **Fix Categories Table:** `work/pazar/database/migrations/2026_01_16_100001_fix_categories_table_schema.php`
- **Update Listings Table WP3:** `work/pazar/database/migrations/2026_01_16_100002_update_listings_table_wp3.php`
- **Reservations Table:** `work/pazar/database/migrations/2026_01_16_100003_create_reservations_table.php`
- **Idempotency Keys:** `work/pazar/database/migrations/2026_01_16_100004_create_idempotency_keys_table.php`
- **Sessions Table:** `work/pazar/database/migrations/2026_01_16_141957_create_sessions_table.php`

### Configuration

- **Bootstrap:** `work/pazar/bootstrap/app.php`
- **World Registry:** `work/pazar/app/Worlds/WorldRegistry.php`
- **Worlds Config:** `work/pazar/config/worlds.php`

---

## Messaging Service (`work/messaging/`)

**Description:** Messaging service - Thread and message management.

### API Files (`work/messaging/services/api/src/`)

- **Main Entry:** `work/messaging/services/api/src/index.js`
- **App:** `work/messaging/services/api/src/app.js`
- **Config:** `work/messaging/services/api/src/config.js`
- **Database:** `work/messaging/services/api/src/db.js`

### Migrations (`work/messaging/services/api/migrations/`)

- **Threads Table:** `work/messaging/services/api/migrations/001_create_threads_table.sql`
- **Participants Table:** `work/messaging/services/api/migrations/002_create_participants_table.sql`
- **Messages Table:** `work/messaging/services/api/migrations/003_create_messages_table.sql`

### Configuration

- **Dockerfile:** `work/messaging/services/api/Dockerfile`
- **Package.json:** `work/messaging/services/api/package.json`

---

## Marketplace Web Frontend (`work/marketplace-web/`)

**Description:** Vue.js frontend for marketplace.

### Main Entry Point

- **Main:** `work/marketplace-web/src/main.js`
- **Router:** `work/marketplace-web/src/router.js`

### Pages (`work/marketplace-web/src/pages/`)

- **Listings Search:** `work/marketplace-web/src/pages/ListingsSearchPage.vue`
- **Listing Detail:** `work/marketplace-web/src/pages/ListingDetailPage.vue`
- **Create Listing:** `work/marketplace-web/src/pages/CreateListingPage.vue`
- **Account Portal:** `work/marketplace-web/src/pages/AccountPortalPage.vue`
- **Categories:** `work/marketplace-web/src/pages/CategoriesPage.vue`
- **Login:** `work/marketplace-web/src/pages/LoginPage.vue`
- **Register:** `work/marketplace-web/src/pages/RegisterPage.vue`
- **Firm Register:** `work/marketplace-web/src/pages/FirmRegisterPage.vue`
- **Messaging:** `work/marketplace-web/src/pages/MessagingPage.vue`
- **Create Order:** `work/marketplace-web/src/pages/CreateOrderPage.vue`
- **Create Rental:** `work/marketplace-web/src/pages/CreateRentalPage.vue`
- **Create Reservation:** `work/marketplace-web/src/pages/CreateReservationPage.vue`

### Components (`work/marketplace-web/src/components/`)

- **Category Tree:** `work/marketplace-web/src/components/CategoryTree.vue`
- **Filters Panel:** `work/marketplace-web/src/components/FiltersPanel.vue`
- **Listings Grid:** `work/marketplace-web/src/components/ListingsGrid.vue`
- **Publish Listing Action:** `work/marketplace-web/src/components/PublishListingAction.vue`

### API Client

- **Pazar API:** `work/marketplace-web/src/lib/pazarApi.js`
- **API Wrapper:** `work/marketplace-web/src/lib/api.js`
- **Session Management:** `work/marketplace-web/src/lib/demoSession.js`
- **API Client:** `work/marketplace-web/src/api/client.js`

---

## Operations Scripts (`ops/`)

**Description:** PowerShell scripts for operations and maintenance.

### Core Scripts (Most Important)

- **Ops Run:** `ops/ops_run.ps1` - Daily ops entrypoint (Prototype/Full profiles)
- **Ship Main:** `ops/ship_main.ps1` - Publish to main (gates + push)
- **Ops Status:** `ops/ops_status.ps1` - Unified ops dashboard
- **Verify:** `ops/verify.ps1` - Full health check
- **Baseline Status:** `ops/baseline_status.ps1` - Baseline status check
- **Conformance:** `ops/conformance.ps1` - Conformance checks
- **Daily Snapshot:** `ops/daily_snapshot.ps1` - Daily evidence capture
- **Dev Refresh:** `ops/dev_refresh.ps1` - Frontend refresh helper (FrontendOnly/All modes)
- **Frontend Refresh:** `ops/frontend_refresh.ps1` - Frontend refresh (restart/rebuild)
- **Prototype V1:** `ops/prototype_v1.ps1` - Prototype/demo verification
- **Demo Seed V1:** `ops/demo_seed_v1.ps1` - Idempotent demo seed for E2E tests

### Security & Governance

- **Public Ready Check:** `ops/public_ready_check.ps1` - Pre-release checks
- **Secret Scan:** `ops/secret_scan.ps1` - Security scan for secrets
- **Security Audit:** `ops/security_audit.ps1` - Security audit
- **Auth Security Check:** `ops/auth_security_check.ps1` - Auth security check
- **Repo Payload Guard:** `ops/repo_payload_guard.ps1` - Repository payload guard (gate)
- **Closeouts Size Gate:** `ops/closeouts_size_gate.ps1` - Closeouts size gate (gate)

### GitHub & Sync

- **Update Code Index:** `ops/update_code_index.ps1` - Auto-update CODE_INDEX.md with commit and push (`-AutoCommit -AutoPush`)
- **GitHub Sync Safe:** `ops/github_sync_safe.ps1` - PR-based sync enforcement
- **CI Guard:** `ops/ci_guard.ps1` - CI drift guard
- **Repo Integrity:** `ops/repo_integrity.ps1` - Repository integrity check

### Contract & Spine Checks

- **Pazar Spine Check:** `ops/pazar_spine_check.ps1` - Pazar spine verification
- **Product Spine Check:** `ops/product_spine_check.ps1` - Product spine check
- **World Spine Check:** `ops/world_spine_check.ps1` - World spine check
- **Listing Contract Check:** `ops/listing_contract_check.ps1` - Listing contract verification
- **Reservation Contract Check:** `ops/reservation_contract_check.ps1` - Reservation contract check
- **Catalog Contract Check:** `ops/catalog_contract_check.ps1` - Catalog contract check
- **Product Contract Check:** `ops/product_contract_check.ps1` - Product contract check
- **Messaging Contract Check:** `ops/messaging_contract_check.ps1` - Messaging contract check
- **Order Contract Check:** `ops/order_contract_check.ps1` - Order contract check
- **Rental Contract Check:** `ops/rental_contract_check.ps1` - Rental contract check
- **Offer Contract Check:** `ops/offer_contract_check.ps1` - Offer contract check
- **Account Portal Contract Check:** `ops/account_portal_contract_check.ps1` - Account portal contract check
- **Catalog Integrity Check:** `ops/catalog_integrity_check.ps1` - Catalog integrity check
- **World Status Check:** `ops/world_status_check.ps1` - World status check

### Observability & Monitoring

- **Observability Status:** `ops/observability_status.ps1` - Observability status
- **Routes Snapshot:** `ops/routes_snapshot.ps1` - Routes snapshot
- **Schema Snapshot:** `ops/schema_snapshot.ps1` - Database schema snapshot
- **Triage:** `ops/triage.ps1` - System triage and diagnostics
- **Doctor:** `ops/doctor.ps1` - Comprehensive system diagnostics

### Smoke Tests

- **Frontend Smoke:** `ops/frontend_smoke.ps1` - Frontend smoke test (gate)
- **Prototype Smoke:** `ops/prototype_smoke.ps1` - Prototype smoke test (gate)
- **Prototype Flow Smoke:** `ops/prototype_flow_smoke.ps1` - Prototype flow smoke test (gate)
- **Pazar UI Smoke:** `ops/pazar_ui_smoke.ps1` - Pazar UI smoke test
- **Messaging Proxy Smoke:** `ops/messaging_proxy_smoke.ps1` - Messaging proxy smoke test
- **Product API Smoke:** `ops/product_api_smoke.ps1` - Product API smoke test
- **Product Spine Smoke:** `ops/product_spine_smoke.ps1` - Product spine smoke test
- **Smoke Surface:** `ops/smoke_surface.ps1` - Smoke surface test
- **Smoke:** `ops/smoke.ps1` - General smoke test

### Ops Library (`ops/_lib/`)

- **core_availability.ps1**: `ops/_lib/core_availability.ps1` - Core availability helper
- **ops_env.ps1**: `ops/_lib/ops_env.ps1` - Ops environment helper
- **ops_exit.ps1**: `ops/_lib/ops_exit.ps1` - Ops exit helper
- **ops_output.ps1**: `ops/_lib/ops_output.ps1` - Ops output helper
- **routes_json.ps1**: `ops/_lib/routes_json.ps1` - Routes JSON helper
- **test_auth.ps1**: `ops/_lib/test_auth.ps1` - Test auth helper
- **worlds_config.ps1**: `ops/_lib/worlds_config.ps1` - Worlds config helper
### Release & Bundle

- **Release Check:** `ops/release_check.ps1` - Release check
- **RC0 Gate:** `ops/rc0_gate.ps1` - RC0 gate
- **RC0 Check:** `ops/rc0_check.ps1` - RC0 check
- **RC0 Release Bundle:** `ops/rc0_release_bundle.ps1` - RC0 release bundle
- **Release Bundle:** `ops/release_bundle.ps1` - Release bundle generation
- **Release Note:** `ops/release_note.ps1` - Release note generation
- **Incident Bundle:** `ops/incident_bundle.ps1` - Incident bundle generation
- **Self Audit:** `ops/self_audit.ps1` - Self audit bundle generation

---

## Infrastructure

### Docker Compose

- **Main Compose:** `docker-compose.yml`

**Services:**
- `hos-api` - H-OS API (Node.js) on port 3000
- `hos-db` - PostgreSQL database for H-OS
- `pazar-app` - Pazar API (Laravel) on port 8080
- `pazar-db` - PostgreSQL database for Pazar
- `pazar-web` - Marketplace frontend (Vue.js/Vite) on port 5173
- `messaging-api` - Messaging service (Node.js)

### Environment Configuration

- **Example:** `.env.example` (not tracked, use as template)
- **Local:** `.env` (not tracked, local configuration)

### Infrastructure & Stack Management

- **Stack Up:** `ops/stack_up.ps1` - Start stack
- **Stack Down:** `ops/stack_down.ps1` - Stop stack
- **HOS DB Recovery:** `ops/hos_db_recovery.ps1` - HOS database recovery
- **HOS DB Reset Safe:** `ops/hos_db_reset_safe.ps1` - HOS database safe reset
- **HOS DB Verify:** `ops/hos_db_verify.ps1` - HOS database verification

### Governance & Guards

- **Pazar Routes Guard:** `ops/pazar_routes_guard.ps1` - Pazar routes guardrails
- **Route Duplicate Guard:** `ops/route_duplicate_guard.ps1` - Route duplicate guard
- **State Transition Guard:** `ops/state_transition_guard.ps1` - State transition guard
- **Ops Drift Guard:** `ops/ops_drift_guard.ps1` - Ops drift guard
- **Repo Governance Freeze V1:** `ops/repo_governance_freeze_v1.ps1` - Repo governance freeze

---

## Documentation (`docs/`)

**Description:** All documentation files - architecture, specifications, runbooks, and proofs.

### Core Documentation (Most Important - Frequently Updated)

- **README:** `README.md` - Main entry point
- **Index:** `docs/index.md` - Documentation index
- **SPEC:** `docs/SPEC.md` - Canonical specification (single source of truth)
- **CURRENT:** `docs/CURRENT.md` - Current system state (single source of truth)
- **ARCHITECTURE:** `docs/ARCHITECTURE.md` - System architecture overview
- **DECISIONS:** `docs/DECISIONS.md` - Baseline decisions and frozen items
- **RULES:** `docs/RULES.md` - Repository rules and conventions
- **WP_CLOSEOUTS:** `docs/WP_CLOSEOUTS.md` - Work package closeouts and status (last 12 WP entries)
- **WP_CLOSEOUTS_ARCHIVE:** `docs/closeouts/WP_CLOSEOUTS_ARCHIVE_2026.md` - Archived WP closeouts (older entries)

### Getting Started

- **NEW_CHAT_PROTOCOL:** `docs/NEW_CHAT_PROTOCOL.md` - New chat/agent start protocol (MUST READ FIRST)
- **DEV_DISCIPLINE:** `docs/DEV_DISCIPLINE.md` - Development discipline (WP-based workflow)
- **CONTEXT_PACK:** `docs/CONTEXT_PACK.md` - Context pack for AI agents
- **ONBOARDING:** `docs/ONBOARDING.md` - Quick start guide for newcomers
- **START_HERE:** `docs/START_HERE.md` - First file to read
- **CONTRIBUTING:** `docs/CONTRIBUTING.md` - Contribution guidelines

### Product & Planning

- **Product Roadmap:** `docs/PRODUCT/PRODUCT_ROADMAP.md`
- **MVP Scope:** `docs/PRODUCT/MVP_SCOPE.md`
- **OpenAPI Spec:** `docs/PRODUCT/openapi.yaml`

### Runbooks (`docs/runbooks/`)

- **Ops Status:** `docs/runbooks/ops_status.md` - Unified ops dashboard
- **Security:** `docs/runbooks/security.md`
- **Incident Response:** `docs/runbooks/incident.md`
- **Daily Ops:** `docs/runbooks/daily_ops.md`

### Proofs (`docs/PROOFS/`)

- **All Proofs:** docs/PROOFS/ directory - Proof documents for all work packages

---

## Notes for AI

- **All code is public** - No secrets in tracked files
- **Use environment variables** - Check `.env.example` for required vars
- **PR-based workflow** - All changes go through PRs, never direct push to main
- **Documentation first** - Read `docs/` before diving into code
- **Ops scripts** - Run `ops/ops_status.ps1` to check system health

### How to Read Code Files

**IMPORTANT:** All file paths are relative to the repository root. Use the file paths listed in this document to navigate the codebase.

**Repository Structure:**
- `work/hos/` - H-OS service files
- `work/pazar/` - Pazar service files
- `work/messaging/` - Messaging service files
- `work/marketplace-web/` - Frontend files
- `ops/` - Operations scripts
- `docs/` - Documentation

---

**Last Updated:** 2026-01-27  
**Index Status:** Complete - Repository scanned and indexed for quick navigation
