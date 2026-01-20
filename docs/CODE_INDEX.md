# Code Index - H-OS Stack

**Purpose:** Central index for AI/ChatGPT to navigate and read the entire codebase efficiently.

**GitHub Repository:** [https://github.com/bekiryara/hos-stack](https://github.com/bekiryara/hos-stack)

**GitHub Pages:** [https://bekiryara.github.io/hos-stack/CODE_INDEX.html](https://bekiryara.github.io/hos-stack/CODE_INDEX.html)

---

## Reading Strategy for AI

1. **Start here:** Read this file to understand the codebase structure
2. **Navigate by service:** Each service (H-OS, Pazar, Messaging) has its own section
3. **Use raw URLs:** All raw URLs are listed for direct AI access
4. **Follow repo structure:** Files are organized exactly like the repository structure

---

## H-OS Service (`work/hos/`)

**Description:** H-OS (universe governance) - Core authentication, authorization, and world management service.

### API Files (`work/hos/services/api/src/`)

- **Main Entry:** [`work/hos/services/api/src/index.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/index.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/index.js)
- **Server:** [`work/hos/services/api/src/server.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/server.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/server.js)
- **App:** [`work/hos/services/api/src/app.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/app.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/app.js)
- **Config:** [`work/hos/services/api/src/config.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/config.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/config.js)
- **Database:** [`work/hos/services/api/src/db.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/db.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/db.js)
- **Auth:** [`work/hos/services/api/src/auth.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/auth.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/auth.js)
- **Audit:** [`work/hos/services/api/src/audit.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/audit.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/audit.js)
- **Migrations:** [`work/hos/services/api/src/migrate.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/migrate.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/migrate.js)

### Policy Files (`work/hos/services/api/src/policy/pazar/`)

- **Abilities:** [`work/hos/services/api/src/policy/pazar/abilities.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/policy/pazar/abilities.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/policy/pazar/abilities.js)
- **Roles:** [`work/hos/services/api/src/policy/pazar/roles.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/policy/pazar/roles.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/policy/pazar/roles.js)
- **Role Matrix:** [`work/hos/services/api/src/policy/pazar/role_matrix.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/policy/pazar/role_matrix.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/policy/pazar/role_matrix.js)
- **Can:** [`work/hos/services/api/src/policy/pazar/can.js`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/src/policy/pazar/can.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/policy/pazar/can.js)

### Configuration

- **Docker Compose:** [`work/hos/docker-compose.yml`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/docker-compose.yml) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/docker-compose.yml)
- **Dockerfile:** [`work/hos/services/api/Dockerfile`](https://github.com/bekiryara/hos-stack/blob/main/work/hos/services/api/Dockerfile) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/Dockerfile)

---

## Pazar Service (`work/pazar/`)

**Description:** Pazar (marketplace) - Laravel application for commerce world.

### Routes

- **Main Routes:** [`work/pazar/routes/api.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/routes/api.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/routes/api.php)

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

- **CORS:** [`work/pazar/app/Http/Middleware/Cors.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/Cors.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Http/Middleware/Cors.php)
- **Security Headers:** [`work/pazar/app/Http/Middleware/SecurityHeaders.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/SecurityHeaders.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Http/Middleware/SecurityHeaders.php)
- **Force JSON:** [`work/pazar/app/Http/Middleware/ForceJsonForApi.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/ForceJsonForApi.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Http/Middleware/ForceJsonForApi.php)
- **Request ID:** [`work/pazar/app/Http/Middleware/RequestId.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/RequestId.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Http/Middleware/RequestId.php)
- **Error Envelope:** [`work/pazar/app/Http/Middleware/ErrorEnvelope.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/ErrorEnvelope.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Http/Middleware/ErrorEnvelope.php)

### Configuration

- **Bootstrap:** [`work/pazar/bootstrap/app.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/bootstrap/app.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/bootstrap/app.php)
- **World Registry:** [`work/pazar/app/Worlds/WorldRegistry.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Worlds/WorldRegistry.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Worlds/WorldRegistry.php)
- **Worlds Config:** [`work/pazar/config/worlds.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/config/worlds.php) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/config/worlds.php)

---

## Messaging Service (`work/messaging/`)

**Description:** Messaging service - Thread and message management.

### API Files (`work/messaging/services/api/src/`)

- **Main Entry:** [`work/messaging/services/api/src/index.js`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/src/index.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/src/index.js)
- **App:** [`work/messaging/services/api/src/app.js`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/src/app.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/src/app.js)
- **Config:** [`work/messaging/services/api/src/config.js`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/src/config.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/src/config.js)
- **Database:** [`work/messaging/services/api/src/db.js`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/src/db.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/src/db.js)

### Migrations (`work/messaging/services/api/migrations/`)

- **Threads Table:** [`work/messaging/services/api/migrations/001_create_threads_table.sql`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/migrations/001_create_threads_table.sql) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/migrations/001_create_threads_table.sql)
- **Participants Table:** [`work/messaging/services/api/migrations/002_create_participants_table.sql`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/migrations/002_create_participants_table.sql) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/migrations/002_create_participants_table.sql)
- **Messages Table:** [`work/messaging/services/api/migrations/003_create_messages_table.sql`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/migrations/003_create_messages_table.sql) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/migrations/003_create_messages_table.sql)

### Configuration

- **Dockerfile:** [`work/messaging/services/api/Dockerfile`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/Dockerfile) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/Dockerfile)
- **Package.json:** [`work/messaging/services/api/package.json`](https://github.com/bekiryara/hos-stack/blob/main/work/messaging/services/api/package.json) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/package.json)

---

## Marketplace Web Frontend (`work/marketplace-web/`)

**Description:** Vue.js frontend for marketplace.

### Main Entry Point

- **Main:** [`work/marketplace-web/src/main.js`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/main.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/main.js)
- **Router:** [`work/marketplace-web/src/router.js`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/router.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/router.js)

### Pages (`work/marketplace-web/src/pages/`)

- **Listings Search:** [`work/marketplace-web/src/pages/ListingsSearchPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/ListingsSearchPage.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/pages/ListingsSearchPage.vue)
- **Listing Detail:** [`work/marketplace-web/src/pages/ListingDetailPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/ListingDetailPage.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/pages/ListingDetailPage.vue)
- **Create Listing:** [`work/marketplace-web/src/pages/CreateListingPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/CreateListingPage.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/pages/CreateListingPage.vue)
- **Account Portal:** [`work/marketplace-web/src/pages/AccountPortalPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/AccountPortalPage.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/pages/AccountPortalPage.vue)
- **Categories:** [`work/marketplace-web/src/pages/CategoriesPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/CategoriesPage.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/pages/CategoriesPage.vue)

### Components (`work/marketplace-web/src/components/`)

- **Category Tree:** [`work/marketplace-web/src/components/CategoryTree.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/components/CategoryTree.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/components/CategoryTree.vue)
- **Filters Panel:** [`work/marketplace-web/src/components/FiltersPanel.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/components/FiltersPanel.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/components/FiltersPanel.vue)
- **Listings Grid:** [`work/marketplace-web/src/components/ListingsGrid.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/components/ListingsGrid.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/components/ListingsGrid.vue)
- **Publish Listing Action:** [`work/marketplace-web/src/components/PublishListingAction.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/components/PublishListingAction.vue) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/components/PublishListingAction.vue)

### API Client

- **Pazar API:** [`work/marketplace-web/src/lib/pazarApi.js`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/lib/pazarApi.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/lib/pazarApi.js)
- **API Client:** [`work/marketplace-web/src/api/client.js`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/api/client.js) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/api/client.js)

---

## Operations Scripts (`ops/`)

**Description:** PowerShell scripts for operations and maintenance.

### Key Scripts

- **Ops Status:** [`ops/ops_status.ps1`](https://github.com/bekiryara/hos-stack/blob/main/ops/ops_status.ps1) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/ops_status.ps1) - Unified ops dashboard
- **Public Ready Check:** [`ops/public_ready_check.ps1`](https://github.com/bekiryara/hos-stack/blob/main/ops/public_ready_check.ps1) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/public_ready_check.ps1) - Pre-release checks
- **Secret Scan:** [`ops/secret_scan.ps1`](https://github.com/bekiryara/hos-stack/blob/main/ops/secret_scan.ps1) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/secret_scan.ps1) - Security scan for secrets
- **GitHub Sync Safe:** [`ops/github_sync_safe.ps1`](https://github.com/bekiryara/hos-stack/blob/main/ops/github_sync_safe.ps1) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/github_sync_safe.ps1) - PR-based sync enforcement
- **Verify:** [`ops/verify.ps1`](https://github.com/bekiryara/hos-stack/blob/main/ops/verify.ps1) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/verify.ps1) - Full health check
- **Baseline Status:** [`ops/baseline_status.ps1`](https://github.com/bekiryara/hos-stack/blob/main/ops/baseline_status.ps1) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/baseline_status.ps1) - Baseline status check
- **Conformance:** [`ops/conformance.ps1`](https://github.com/bekiryara/hos-stack/blob/main/ops/conformance.ps1) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/conformance.ps1) - Conformance checks

---

## Infrastructure

### Docker Compose

- **Main Compose:** [`docker-compose.yml`](https://github.com/bekiryara/hos-stack/blob/main/docker-compose.yml) | [Raw](https://raw.githubusercontent.com/bekiryara/hos-stack/main/docker-compose.yml)

**Services:**
- `hos-api` - H-OS API (Node.js) on port 3000
- `hos-db` - PostgreSQL database for H-OS
- `pazar-app` - Pazar API (Laravel) on port 8080
- `pazar-db` - MySQL database for Pazar
- `pazar-web` - Marketplace frontend (Vue.js/Vite) on port 5173
- `messaging-api` - Messaging service (Node.js)

### Environment Configuration

- **Example:** `.env.example` (not tracked, use as template)
- **Local:** `.env` (not tracked, local configuration)

---

## Documentation

### Architecture

- **Architecture Overview:** [docs/ARCHITECTURE.md](https://bekiryara.github.io/hos-stack/ARCHITECTURE.html)
- **Specification:** [docs/SPEC.md](https://bekiryara.github.io/hos-stack/SPEC.html)
- **Product Roadmap:** [docs/PRODUCT/PRODUCT_ROADMAP.md](https://bekiryara.github.io/hos-stack/PRODUCT/PRODUCT_ROADMAP.html)

### Runbooks

- **Ops Status:** [docs/runbooks/ops_status.md](https://bekiryara.github.io/hos-stack/runbooks/ops_status.html)
- **Security:** [docs/runbooks/security.md](https://bekiryara.github.io/hos-stack/runbooks/security.html)
- **Incident Response:** [docs/runbooks/incident.md](https://bekiryara.github.io/hos-stack/runbooks/incident.html)

### Proofs

- **All Proofs:** [docs/PROOFS/](https://github.com/bekiryara/hos-stack/tree/main/docs/PROOFS/) directory
- **Work Package Closeouts:** [docs/WP_CLOSEOUTS.md](https://bekiryara.github.io/hos-stack/WP_CLOSEOUTS.html)

---

## Quick Links - All Raw URLs (AI Direct Access)

**H-OS Service:**
- [H-OS API Index](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/index.js)
- [H-OS API App](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/app.js)
- [H-OS API Config](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/config.js)
- [H-OS API DB](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/db.js)
- [H-OS API Auth](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/hos/services/api/src/auth.js)

**Pazar Service:**
- [Pazar API Routes](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/routes/api.php)
- [Pazar Bootstrap](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/bootstrap/app.php)
- [Pazar CORS Middleware](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Http/Middleware/Cors.php)
- [Pazar Security Headers](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Http/Middleware/SecurityHeaders.php)
- [Pazar World Registry](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/app/Worlds/WorldRegistry.php)

**Messaging Service:**
- [Messaging API Index](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/src/index.js)
- [Messaging API App](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/src/app.js)
- [Messaging API Config](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/src/config.js)
- [Messaging API DB](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/messaging/services/api/src/db.js)

**Frontend:**
- [Frontend Main](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/main.js)
- [Frontend Router](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/router.js)
- [Pazar API Client](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/lib/pazarApi.js)

**Infrastructure:**
- [Docker Compose](https://raw.githubusercontent.com/bekiryara/hos-stack/main/docker-compose.yml)

**Ops Scripts:**
- [Ops Status](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/ops_status.ps1)
- [Verify](https://raw.githubusercontent.com/bekiryara/hos-stack/main/ops/verify.ps1)

### GitHub Pages (for documentation)

- [Home](https://bekiryara.github.io/hos-stack/)
- [This Index](https://bekiryara.github.io/hos-stack/CODE_INDEX.html)
- [Architecture](https://bekiryara.github.io/hos-stack/ARCHITECTURE.html)
- [Spec](https://bekiryara.github.io/hos-stack/SPEC.html)

---

## Notes for AI

- **All code is public** - No secrets in tracked files
- **Use environment variables** - Check `.env.example` for required vars
- **PR-based workflow** - All changes go through PRs, never direct push to main
- **Documentation first** - Read `docs/` before diving into code
- **Ops scripts** - Run `ops/ops_status.ps1` to check system health

### How to Read Code Files

**IMPORTANT:** AI can read raw GitHub URLs directly. Use the "Quick Links - All Raw URLs" section above to access files.

**Example:**
1. Read this CODE_INDEX.md file first
2. Find the service you need (H-OS, Pazar, Messaging, Frontend)
3. Use the raw URL from the "Quick Links" section
4. AI can read raw URLs directly without clicking links

**Why?** AI web tools can only open URLs from search results or user messages, not from clicking links on pages. So all raw URLs are listed above for direct access.

**Repository Structure:**
- `work/hos/` - H-OS service files
- `work/pazar/` - Pazar service files
- `work/messaging/` - Messaging service files
- `work/marketplace-web/` - Frontend files
- `ops/` - Operations scripts
- `docs/` - Documentation

---

**Last Updated:** 2026-01-20
