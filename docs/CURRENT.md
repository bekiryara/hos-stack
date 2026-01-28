# CURRENT - Single Source of Truth

**Last Updated:** 2026-01-28  
**Baseline:** RELEASE-GRADE BASELINE RESET v1

## What is the Stack?

This repository runs **H-OS** (universe governance) and **Pazar** (first commerce world) services together.

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

### Pazar API (Port 8080)

- `GET /up` - Health check (nginx-level, no Laravel)
- `GET /api/world/status` - Marketplace world status (SPEC §24.4)
- `GET /api/v1/categories` - Category tree (WP-2, may return empty array if not seeded)
- `GET /api/v1/categories/{id}/filter-schema` - Filter schema for category (WP-2)
- `GET /api/v1/listings` - Single listing read/search engine (category + filters)

**Note:** Laravel routes in `routes/api.php` are automatically prefixed with `/api` by default.

## Green Checks (Working Definition)

Baseline is "working" when:

1. **H-OS Health**: `curl http://localhost:3000/v1/health` returns HTTP 200 with `{"ok":true}`
2. **Pazar Health**: `curl http://localhost:8080/up` returns HTTP 200 with `"ok"`
3. **Containers Running**: All required services show "Up" status in `docker compose ps`
4. **FS Posture**: Pazar storage/logs is writable (no permission errors)

## Verification Command

```powershell
.\ops\verify.ps1
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
.\ops\stack_up.ps1 -Profile core
```

**Note:** If `docker-compose.override.yml` exists, it will be automatically used by Docker Compose to override environment variables (e.g., `HOS_OIDC_ISSUER`, `HOS_OIDC_WORLD` for pazar-app). This is intentional for local development customization.

## Daily Commands

**Three essential commands for daily operations:**

1. **Start:** `docker compose up -d --build`
   - Starts all services in detached mode

2. **Verify:** `.\ops\verify.ps1`
   - Checks container status, health endpoints, filesystem posture
   - Exit code: 0=PASS, 1=FAIL

3. **Snapshot:** `.\ops\daily_snapshot.ps1`
   - Creates daily evidence snapshot in `_archive/daily/YYYYMMDD-HHmmss/`
   - Captures: git status, commit hash, container status, logs, health checks

## No PASS, No Next Step Rule

**CRITICAL:** Before starting new work:
- Run `.\ops\verify.ps1` → Must PASS (exit code 0)
- Run `.\ops\conformance.ps1` → Must PASS (exit code 0)
- If either fails, fix issues before proceeding

This ensures baseline remains stable and prevents breaking changes.

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

## Catalog / Search Final (Category → Catalog → Listing)

**Category (tree-only):**
- `GET /api/v1/categories` returns nodes with: `id`, `slug`, `parent_id` (plus optional nested `children`).

**Catalog (filter definitions):**
- `GET /api/v1/categories/{id}/filter-schema` returns `filters[]` describing allowed filter keys and types.
- Each filter includes canonical `key` and simplified `type` (select/number/range/boolean/text) for UI rendering (additive fields; existing fields remain).

**Listing read/search (single engine):**
- `GET /api/v1/listings` is the only listing read/search endpoint.
- Filter contract:
  - Primary: `filters[...]`
  - Legacy/backward compatible: `attrs[...]` (still supported; do not build new logic on this)
  - Priority: if `filters[...]` exists → use it; else if `attrs[...]` exists → use it.
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
- Do not add new logic that depends on `attrs[...]` (legacy only; kept for compatibility).

**Not Included in V1:**
- Payment processing
- Advanced search/filters
- Email notifications
- Multi-tenant switching UI
- Admin dashboard for firms

## Related Docs

- **Onboarding:** `docs/ONBOARDING.md` (quick start for newcomers)
- **Decisions:** `docs/DECISIONS.md` (baseline definition + frozen items)
- **Start Here:** `docs/START_HERE.md` (7 rule set)
- **Rules:** `docs/RULES.md` (fundamental rules)
