# CURRENT - Single Source of Truth

**Last Updated:** 2026-03-06  
**Baseline:** RELEASE-GRADE BASELINE RESET v1

## Authoritative Completion Index

- Commit-certified completed works are tracked at:
  - `docs/RELEASES/COMPLETED_WORKS_2026_03_06.md`
- WP closeout addendum for latest layer:
  - `docs/WP_CLOSEOUTS_2026_03_06.md`

## Recent Updates (2026-03-05 to 2026-03-06)

- Primitive matrix governance locked (2026-03-06):
  - New runbook: `docs/runbooks/primitive_matrix_v1.md` (canonical behavior families table).
  - `ops/_checks/policy_variant_matrix_check.ps1` expanded to assert all active rule/variant rows,
    including `pricing_strategy` and `billing_model`.
  - Validation:
    - `ops/_checks/policy_variant_matrix_check.ps1` -> PASS
- Create/Edit parity gate (2026-03-06):
  - New check: `ops/_checks/create_edit_parity_check.ps1`.
  - Ensures Edit reuses Create form behavior surface and policy billing/time primitives are covered.
  - Wired into ops command surface:
    - `ops.ps1 create-edit-parity`
    - `ops_status` check registry (`create_edit_parity`, blocking)
  - Validation:
    - `ops/_checks/create_edit_parity_check.ps1` -> PASS
    - `ops.ps1 create-edit-parity` -> PASS
- Phase-2 hourly variant slice (2026-03-06):
  - `events` rule gained `reservation_hourly` offer variant (`billing_model=per_hour`, `service_time_model=slot`).
  - Matrix and gate updated accordingly:
    - `docs/runbooks/primitive_matrix_v1.md`
    - `ops/_checks/policy_variant_matrix_check.ps1`
  - Validation:
    - `npm run build` -> PASS
    - `ops/_checks/policy_variant_matrix_check.ps1` -> PASS
    - `ops/_checks/create_edit_parity_check.ps1` -> PASS
- Phase-2 session variant slice (2026-03-06):
  - `events` rule gained `reservation_session` offer variant (`billing_model=per_session`, `service_time_model=session`).
  - Matrix and gate updated accordingly:
    - `docs/runbooks/primitive_matrix_v1.md`
    - `ops/_checks/policy_variant_matrix_check.ps1`
  - Validation:
    - `npm run build` -> PASS
    - `ops/_checks/policy_variant_matrix_check.ps1` -> PASS
    - `ops/_checks/create_edit_parity_check.ps1` -> PASS
- Reservation per_session functional slice (2026-03-06):
  - `POST /v1/reservations` now accepts `session_count` and feeds `quantity=session_count` into pricing resolve when `billing_model=per_session`.
  - Reservation `totals_json`/response include `session_count` for deterministic read-back.
  - `CreateReservationPage` dynamically shows `Seans Sayisi` input only for `per_session` listings and submits `session_count`.
  - Validation:
    - `npm run build` -> PASS
    - `ops/_checks/reservation_contract_check.ps1` -> PASS
 - Rental create billing-time UX alignment (2026-03-06):
  - `CreateRentalPage` now reads listing `billing_model` and renders time labels/guidance deterministically (`per_hour` vs `per_day`).
  - Listing UUID input watch added to preload policy context without ad-hoc category patches.
  - Validation:
    - `npm run build` -> PASS
    - `ops/_checks/rental_contract_check.ps1` -> PASS
 - Order create pricing-label alignment (2026-03-06):
  - `CreateOrderPage` now derives multiplier input/summary label from listing `billing_model` (instead of fixed `Adet`).
  - Success and pre-submit pricing cards consume policy-derived billing model for deterministic multiplier label rendering.
  - Validation:
    - `npm run build` -> PASS
    - `ops/_checks/order_contract_check.ps1` -> PASS
    - `ops/_checks/create_edit_parity_check.ps1` -> PASS
 - Order detail pricing parity alignment (2026-03-06):
  - `OrderDetailPage` now uses shared `PricingSummary` (same renderer as create/rental/reservation).
  - Manual fixed `Adet`/price rows removed; multiplier/label derives from `totals.billing_model`.
  - Validation:
    - `npm run build` -> PASS
    - `ops/_checks/order_contract_check.ps1` -> PASS
    - `ops/_checks/account_portal_read_check.ps1` -> PASS
 - Transaction detail billing labels normalized (2026-03-06):
  - Billing model labels in technical info are now user-friendly via shared mapping (`displayLabels.getBillingModelLabel`).
  - Updated screens:
    - `OrderDetailPage`
    - `RentalDetailPage`
    - `ReservationDetailPage`
  - Validation:
    - `npm run build` -> PASS
    - `ops/_checks/order_contract_check.ps1` -> PASS
    - `ops/_checks/reservation_contract_check.ps1` -> PASS
    - `ops/_checks/rental_contract_check.ps1` -> FAIL (409 overlap on selected test listing; known data-state conflict, not UI/runtime regression)

- Tenant Address Spine stabilized in Marketplace:
  - Firm register and firm settings use city/district/neighborhood select-cascade.
  - Options source is HOS (`/v1/options/*`) and tenant address persists in HOS `tenant_addresses`.
  - Create Listing tenant-address preload and "Firma adresini kullan" autofill fixes shipped.
- Firm UX boundary tightened:
  - Firm settings moved to `/firm/settings`.
  - Account portal kept focused on account-level information.
- Repo hygiene:
  - Temporary tracked root artifacts (`tmp_*`) removed in commit `88aa944`.
- Variant-level deterministic policy shipped (policy + resolver + create form):
  - Commit `73a335c`: primitive fields now resolve per `offer_variant`
    (`fulfillment_mode`, `location_scope`, `service_time_model`, `offer_requirement`, `pricing_strategy`, `billing_model`).
  - Commit `7e90a09`: intent resolver fix to preserve variant primitive fields.
  - UI contract confirmed on Konut variants:
    - `sale` -> `time_model=none`
    - `rental` -> `time_model=date_range`
    - `reservation` -> `time_model=slot`
- Validation status (2026-03-06):
  - `ops/_checks/category_flow_policy_check.ps1` -> PASS
  - `ops/_checks/listing_contract_check.ps1` -> PASS
  - Snapshot drift cleaned:
    - `ops/_checks/routes_snapshot.ps1` -> PASS
    - `ops/_checks/schema_snapshot.ps1` -> PASS
- Ops/policy governance hardening (2026-03-06):
  - New blocking gate: `ops/_checks/policy_variant_matrix_check.ps1` (Konut variant matrix lock).
  - `ops_run` has `Release` profile (deterministic pre-release path).
  - New policy and planning runbooks:
    - `docs/runbooks/policy_extension.md`
    - `docs/runbooks/service_area_phase2_plan.md`
- Transaction policy enforce hardening (2026-03-06):
  - Commit `cd8347d`: transaction offer/policy validation centralized in shared resolver helpers
    (`pricing_strategy`, `offer_requirement`, unsupported-flow guardrail).
  - Reservations/Orders/Rentals now consume same effective policy path before pricing resolve.
  - Re-validated with elevated docker access:
    - `ops/_checks/policy_variant_matrix_check.ps1` -> PASS
    - `ops/_checks/category_flow_policy_check.ps1` -> PASS
    - `ops/_checks/listing_contract_check.ps1` -> PASS
- Create V2 (phase-1) + parity cleanup (2026-03-06):
  - Canonical pricing field now binds to `pricing_strategy` + `billing_model` (dynamic label and offer-only disable path).
  - Time model guidance moved into explicit `Zaman ve Uygunluk` section.
  - Duplicate Pricing/Billing rows removed from service model summary to avoid UI repetition.
- Pricing Engine v1 (backend, 2026-03-06):
  - `pazar_resolve_transaction_pricing` now returns unit + multiplier + total snapshot deterministically from
    `pricing_strategy`, `billing_model`, and transaction context (quantity/party_size/duration).
  - Orders consume new snapshot fields in totals.
  - Reservations/Rentals now return additive `totals` object in create response (`unit_price`, `multiplier`, `subtotal`, `currency`).
  - Validation checks after change:
    - `ops/_checks/listing_contract_check.ps1` -> PASS
    - `ops/_checks/order_contract_check.ps1` -> PASS
    - `ops/_checks/reservation_contract_check.ps1` -> PASS
    - `ops/_checks/rental_contract_check.ps1` -> FAIL (existing date-overlap conflict on chosen test listing; non-regression signal, not syntax/runtime crash).
- Pricing UI standardization (frontend, 2026-03-06):
  - New shared component: `work/marketplace-web/src/components/common/PricingSummary.vue`.
  - Create success screens aligned:
    - `CreateOrderPage.vue`
    - `CreateRentalPage.vue`
    - `CreateReservationPage.vue`
  - Rental/Reservation detail summary now uses the same pricing card for totals-first rendering.
  - Validation after UI refactor:
    - `npm run build` -> PASS
    - `ops/_checks/order_contract_check.ps1` -> PASS
    - `ops/_checks/rental_contract_check.ps1` -> PASS
    - `ops/_checks/reservation_contract_check.ps1` -> PASS
- Rental/Reservation pricing snapshot persistence (backend, 2026-03-06):
  - New migration: `2026_03_06_190000_add_totals_json_to_rentals_and_reservations.php`.
  - Create endpoints now persist deterministic totals snapshot into `totals_json`:
    - `routes/api/06_rentals.php`
    - `routes/api/04_reservations.php`
  - Account portal read endpoints now consume `totals_json` directly (no synthetic multiplier=1 fallback):
    - `routes/api/account_portal.php`
  - Legacy rows without `totals_json` cleaned from local DB:
    - `rentals`: 8 deleted
    - `reservations`: 54 deleted
  - Validation after persistence switch:
    - `ops/_checks/rental_contract_check.ps1` -> PASS
    - `ops/_checks/reservation_contract_check.ps1` -> PASS
    - `ops/_checks/account_portal_read_check.ps1` -> PASS
- Listing search filters-only contract (backend, 2026-03-06):
  - `GET /api/v1/listings` now accepts `filters[...]` only.
  - Legacy `attrs[...]` query path is retired and now returns 422.
  - Frontend query hydration now also uses canonical `filters` only (`f_*` legacy query fallback removed).
  - Listing contract check updated accordingly:
    - `ops/_checks/listing_contract_check.ps1` [12] now expects attrs retirement (422).
  - Validation:
    - `ops/_checks/listing_contract_check.ps1` -> PASS
- Error envelope cleanup (phase-3 step-1, 2026-03-06):
  - Removed dead legacy conversion branch from `ErrorEnvelope` middleware (`error: { ... }` -> `ok:false` mapping).
  - Middleware now focuses on request_id completion for already-standard `ok:false` envelopes.
  - Validation:
    - `php -l app/Http/Middleware/ErrorEnvelope.php` -> PASS
    - `ops/_checks/listing_contract_check.ps1` -> PASS
    - `ops/_checks/order_contract_check.ps1` -> PASS
  - Test data hygiene:
    - Removed contract-check generated order/idempotency leftovers after validation.

## What is the Stack?

This repository runs **H-OS** (universe governance) and **Pazar** (marketplace world) services together.

### Core Services (Required for Baseline)

**H-OS Core:**
- `hos-db`: PostgreSQL 16 database for H-OS (internal service, no exposed port)
- `hos-api`: H-OS API service on `http://localhost:3000`
- `hos-web`: H-OS Web UI on `http://localhost:3002` (ops/admin only, DEV ONLY)

**Pazar Core:**
- `pazar-db`: PostgreSQL 16 database for Pazar (internal service, no exposed port)
- `pazar-app`: Laravel application on `http://localhost:8080`

### Optional Services (Not Required for Baseline)

- Observability stack (Prometheus, Grafana, Loki, etc.) - optional
- Any service not listed above

## Ports

- **3000**: H-OS API (`http://localhost:3000`)
- **3002**: H-OS Web (`http://localhost:3002`) - ops/admin only
- **3002/marketplace/**: Marketplace Web - customer login/register entry point
- **8080**: Pazar App (`http://localhost:8080`)

## API Endpoints

### H-OS API (Port 3000)

- `GET /v1/health` - Health check
- `GET /v1/worlds` - World directory (returns array of worlds: core, marketplace, etc.)
- **Admin SSOT (H-OS only)**:
  - UI (DEV): `http://localhost:3002/ui/admin/control-center`
  - API (role-guarded `owner|admin`): `GET /v1/admin/tenants`, `GET /v1/admin/users`, `GET /v1/admin/audit`
  - Persistent storage (hos-db): `tenants`, `users`, `memberships`, `audit_events`

### Pazar API (Port 8080)

- `GET /up` - Health check (nginx-level, no Laravel)
- `GET /api/world/status` - Marketplace world status (SPEC §24.4)
- `GET /api/v1/categories` - Category tree (WP-2, may return empty array if not seeded)
- `GET /api/v1/categories/{id}/filter-schema` - Filter schema for category (WP-2)
- `GET /api/v1/listings` - Single listing read/search engine (category + filters)

**Note:** Laravel routes in `routes/api.php` are automatically prefixed with `/api` by default.

## SSOT Boundary (locked)

- **Pazar has NO admin/panel/auth surface** (`/admin`, `/panel`, `/auth/login` are forbidden in Pazar).
- **Admin SSOT = H-OS** (`/v1/admin/*` + `/ui/admin/*`).

## Catalog SSOT (Data vs Runtime) (locked)

**Runtime truth (always):** Pazar serves catalog from the **database** (`categories`, `attributes`, `category_filter_schema`).

**Source-of-change SSOT (team rule):** Catalog data changes MUST be made in the external dataset:
- `D:\stack-data\catalog-dataset\csv\` (categories/attributes/schema/options)

**How it reaches the DB (artifact + sync):**
- Dataset generates a manifests artifact (`out/manifests_current/`).
- Pazar imports/syncs manifests into DB via `php artisan catalog:sync` (default is dry-run).

**Local binding (Docker):**
- `docker-compose.override.yml` mounts manifests into container path `/var/www/html/catalog/manifests`.
- Set host path override when you want to use external dataset artifact:
  - `CATALOG_MANIFESTS_HOST_PATH=D:\stack-data\catalog-dataset\out\manifests_current`

**Canonical daily flow (safe):**
```powershell
cd D:\stack-data\catalog-dataset
node .\tools\validate-csv.mjs
node .\tools\generate-manifests.mjs --out-dir .\out\manifests_current

cd D:\stack
$env:CATALOG_MANIFESTS_HOST_PATH="D:\stack-data\catalog-dataset\out\manifests_current"
docker compose up -d
docker compose exec -T pazar-app php artisan catalog:sync --dry-run
.\ops\ops.ps1 pazar-spine
```

## Transaction Decisions v1 (Orders/Rentals/Reservations)

- **Allowed transitions (v1):**
  - Order: `placed` → accepted | rejected
  - Rental: `requested` → accepted | rejected
  - Reservation: `requested` → accepted | rejected
- **Endpoints:** POST `/v1/orders/{id}/accept`, `/v1/orders/{id}/reject`; POST `/v1/rentals/{id}/accept`, `/v1/rentals/{id}/reject`; POST `/v1/reservations/{id}/accept`, `/v1/reservations/{id}/reject`.
- **Scope:** Store decision endpoints are tenant-locked (X-Active-Tenant-Id + PersonaScope:store).

## Green Checks (Working Definition)

Baseline is "working" when:

1. **H-OS Health**: `curl http://localhost:3000/v1/health` returns HTTP 200 with `{"ok":true}`
2. **Pazar Health**: `curl http://localhost:8080/up` returns HTTP 200 with `"ok"`
3. **Containers Running**: All required services show "Up" status in `docker compose ps`
4. **FS Posture**: Pazar storage/logs is writable (no permission errors)

## Verification Command

```powershell
.\ops\ops.ps1 verify
```

This command checks:
- Container status (docker compose ps)
- H-OS health endpoint
- Pazar health endpoint
- Pazar filesystem posture

**Exit Codes:**
- `0` = PASS (all checks pass)
- `1` = FAIL (required check failed)
- Optional services that are down are marked SKIP, not FAIL

## Compose Profiles

**No profiles defined** in the main `docker-compose.yml`. All services run by default.

**Note:** The `work/hos/docker-compose.yml` file defines profiles (`default`, `obs`, `mail`) for H-OS observability services, but these are not used by the main stack compose file.

## Canonical Boot Command

**Single Entry Point:**
```powershell
docker compose up -d --build
```

**Alternative (with wrapper):**
```powershell
.\ops\ops.ps1 up -StackProfile core
```

**Note:** If `docker-compose.override.yml` exists, it will be automatically used by Docker Compose to override environment variables (e.g., `HOS_OIDC_ISSUER`, `HOS_OIDC_WORLD` for pazar-app). This is intentional for local development customization.

## Daily Commands

**Three essential commands for daily operations:**

1. **Start:** `docker compose up -d --build`
   - Starts all services in detached mode

2. **Verify:** `.\ops\ops.ps1 verify`
   - Checks container status, health endpoints, filesystem posture
   - Exit code: 0=PASS, 1=FAIL

3. **Snapshot:** `.\ops\ops.ps1 daily-snapshot`
   - Creates daily evidence snapshot in `_archive/daily/YYYYMMDD-HHmmss/`
   - Captures: git status, commit hash, container status, logs, health checks

**Ops entrypoints (Golden 4):** See `docs/runbooks/OPS_ENTRYPOINTS.md` (single canonical runbook).

## Frontend Refresh SOP (Local Dev)

Use this when “I changed frontend code but browser still shows old UI”:

1. **Hard refresh first:** `Ctrl+Shift+R` (Windows/Linux) / `Cmd+Shift+R` (Mac). (`Ctrl+F5` is also ok.)
2. If still stale (Docker-served UI): run `.\ops\ops.ps1 refresh` (restart web containers).
3. If still stale or build/deps changed: run `.\ops\ops.ps1 refresh -Build` (rebuild web containers).
5. If you changed only docs/backend: do **not** rebuild frontend; rerun `.\ops\ops.ps1 verify` instead.
6. If you still can’t see changes: confirm you’re on the right URL (`/marketplace/`) and no browser extension is caching.

See: `ops/frontend_refresh.ps1` (canonical implementation).

## No PASS, No Next Step Rule

**CRITICAL:** Before starting new work:
- Run `.\ops\ops.ps1 verify` → Must PASS (exit code 0)
- Run `.\ops\ops.ps1 conformance` → Must PASS (exit code 0)
- If either fails, fix issues before proceeding

This ensures baseline remains stable and prevents breaking changes.

## Session Keys Contract (V1)

**Canonical localStorage keys (only keys we WRITE):**
- `auth_token` - raw JWT token (no `Bearer ` prefix)
- `auth_user` - JSON user object (best-effort cache; token payload is fallback)
- `tenant_slug` - active tenant slug (optional)
- `active_tenant_id` - active tenant id (optional)

**Legacy keys (READ for migration only, never write):**
- `demo_auth_token` → migrate to `auth_token`, then delete legacy key
- `demo_user` → migrate to `auth_user`, then delete legacy key

**Policy:** Legacy keys are supported for one release window (migration only) and should be removed after the window closes.

## V1 Demo User Flow

**Confirmed Working:**
1. Guest opens Marketplace Web (`http://localhost:3002/marketplace/`)
2. Guest registers (email + password) → logged in as CUSTOMER
3. Header shows logged-in state (email, "Hesabım", "Çıkış")
4. User can create:
   - Reservation (`/reservation/create`)
   - Rental (`/rental/create`)
   - Order (`/order/create`)
5. User opens "My Account" (`/account`) → sees created records (reservations, rentals, orders)
6. Logout works correctly
7. Optional: User can create firm (`/firm/register`) → gains FIRM_OWNER role (additive, CUSTOMER remains)
8. Firm Spine v1: User creates firm → selects active tenant on `/account` → opens Firm Portal (`/firm`) to see store listings, incoming orders, rentals, and reservations. No active tenant → guard redirects to `/account?reason=firm_required`.

**Yerel gate koşumu (önerilen):**
- Hızlı sağlık: `.\ops\ops.ps1 verify`
- Daha geniş paket: `.\ops\ops.ps1 full` (tek komut “full gates” paketi)
- Kanıt notu: `docs/PROOFS/PASS_LOG.md` içine koştuğun komut + sonuç satırı ekle.

## Catalog / Search Final (Category → Catalog → Listing)

**Terminology (locked):**
- **World (`world_key`)**: H-OS world directory key. Examples: `core`, `marketplace`, `messaging`, `social`.
- **Pazar enablement**: Pazar only controls its own world (`marketplace`) locally; other worlds are owned by H-OS.
- **Vertical**: marketplace-internal classification carried by the category tree roots (contract-locked): `vehicle`, `real-estate`, `service`.
- **Transaction mode**: `sale | rental | reservation` (cross-vertical intent; driven by schema + transaction spines).

**Category (tree-only):**
- `GET /api/v1/categories` returns nodes with: `id`, `slug`, `parent_id` (plus optional nested `children`).

**Catalog (filter definitions):**
- `GET /api/v1/categories/{id}/filter-schema` returns `filters[]` describing allowed filter keys and types.
- Each filter includes canonical `key` and simplified `type` (select/number/range/boolean/text) for UI rendering (additive fields; existing fields remain).

**Listing read/search (single engine):**
- `GET /api/v1/listings` is the only listing read/search endpoint.
- Filter contract:
  - Primary: `filters[...]`
  - `attrs[...]` is retired; requests using `attrs[...]` are rejected with `422 VALIDATION_ERROR`.
- Category-scoped validation:
  - If `category_id` is provided and invalid → 404.
  - If `category_id` is provided and filter keys are not defined by catalog schema for that category (or descendants) → 422.

**Rules: Adding Categories (no code change)**
- Add a new row to the `categories` table (set `parent_id` to attach it to the tree).
- No new frontend route/page is created; users navigate via the existing category tree and `/search/:categoryId?`.

**Rules: Adding Filters (catalog-only)**
- Add a new row to `attributes` (if the attribute key does not exist yet).
- Add a new row to `category_filter_schema` for the target category (and set status=active).
- No backend or frontend code changes are required for the filter to appear in UI and be accepted by listing search.

**DO NOT (locked rules)**
- Do not add new listing search endpoints (only `GET /api/v1/listings`).
- Do not add category-specific SQL or category-specific frontend pages.
- Do not hardcode filter keys/types in frontend; UI renders from catalog schema.
- Do not reintroduce `attrs[...]` compatibility path in backend or frontend query handling.

**Not Included in V1:**
- Payment processing
- Advanced search/filters
- Email notifications
- Multi-tenant switching UI
- Admin dashboard for firms

## Catalog Invariants (Drift Guard)

**Locked rules** live in `docs/SPEC.md` and this document (contract/behavior sections above).

## Related Docs

- **Source Map:** `docs/SRC.md` (repo entrypoints, minimal navigation map)
- **Onboarding:** `docs/ONBOARDING.md` (quick start for newcomers)
- **Start Here:** `docs/START_HERE.md` (7 rule set)
- **Rules:** `docs/RULES.md` (fundamental rules)
## Listing Detail Read/Projection Status

**Current state (confirmed):**
- Listing detail no longer relies on raw `attributes` dump as its primary read model.
- Marketplace frontend now uses a shared listing detail projection layer to separate:
  - listing base
  - category context
  - schema-backed attributes
  - policy / transaction info
  - technical meta
- Canonical category lookup is fixed for detail/edit surfaces: listing `category_id` must resolve against `canonical_category_id` in menu trees, not only menu node `id`.

**Confirmed frontend files involved:**
- `work/marketplace-web/src/lib/listingDetailProjection.js`
- `work/marketplace-web/src/lib/categoryTree.js`
- `work/marketplace-web/src/pages/ListingDetailPage.vue`
- `work/marketplace-web/src/pages/EditListingPage.vue`

**Behavior now expected on listing detail:**
- Hero reads as: `Transaction Type / Category Name`
- Product/listing features, listing context, transaction info, and technical info are separated into distinct sections.
- `published` is no longer treated as primary customer-facing hero context.

**Validation note:**
- This read/projection correction was validated on multiple families:
  - `vehicle`
  - `real-estate`
  - `service-product`
  - `events`

## Full Gate Status Note (2026-03-04)

- `verify`, `openapi_contract`, `conformance`, `v2_gate`, and `messaging_contract_check` pass.
- `pazar_spine_check` currently fails at `Trendyol Category Coverage` with `98.3%` coverage (`4747 / 4828`, `81` unreachable).
- That Trendyol coverage failure is currently a known/accepted open item, not a surprise regression.
- `ops.ps1 full` currently prints a final PASS even when `pazar_spine_check` fails; treat this as an ops wrapper reporting inconsistency, not as proof that all gates are green.
