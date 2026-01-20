# Code Index - H-OS Stack

**Purpose:** Central index for AI/ChatGPT to navigate and read the entire codebase efficiently.

**GitHub Repository:** [https://github.com/bekiryara/hos-stack](https://github.com/bekiryara/hos-stack)

**GitHub Pages:** [https://bekiryara.github.io/hos-stack/CODE_INDEX.html](https://bekiryara.github.io/hos-stack/CODE_INDEX.html)

---

## Reading Strategy for AI

1. **Start here:** Read this file to understand the codebase structure
2. **Backend API:** Read `work/pazar/routes/api.php` for all API endpoints
3. **Frontend:** Read `work/marketplace-web/src/` for Vue.js components
4. **Configuration:** Read `docker-compose.yml` for service architecture
5. **Documentation:** Browse `docs/` for architecture, specs, and runbooks

---

## Backend API (Pazar - Laravel)

### Main Routes File
- **GitHub:** [work/pazar/routes/api.php](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/routes/api.php)
- **GitHub Pages:** [work/pazar/routes/api.php](https://bekiryara.github.io/hos-stack/work/pazar/routes/api.php)
- **Description:** Main API routes file containing all endpoints

### Key Endpoints

#### World Status
- `GET /api/world/status` - World availability and version info

#### Catalog
- `GET /api/v1/categories` - Category tree
- `GET /api/v1/catalog/filters` - Filter schema

#### Listings
- `GET /api/v1/listings` - List listings (search, filter, paginate)
- `GET /api/v1/listings/{id}` - Get listing detail
- `POST /api/v1/listings` - Create listing
- `PUT /api/v1/listings/{id}` - Update listing
- `POST /api/v1/listings/{id}/publish` - Publish listing

#### Reservations
- `GET /api/v1/reservations` - List reservations
- `POST /api/v1/reservations` - Create reservation
- `PUT /api/v1/reservations/{id}/accept` - Accept reservation
- `PUT /api/v1/reservations/{id}/reject` - Reject reservation

#### Messaging
- `GET /api/v1/messaging/threads` - List message threads
- `POST /api/v1/messaging/threads` - Create thread
- `GET /api/v1/messaging/threads/{id}/messages` - Get messages
- `POST /api/v1/messaging/threads/{id}/messages` - Send message

### Middleware
- **CORS:** [`work/pazar/app/Http/Middleware/Cors.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/Cors.php)
- **Security Headers:** [`work/pazar/app/Http/Middleware/SecurityHeaders.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/SecurityHeaders.php)
- **Force JSON:** [`work/pazar/app/Http/Middleware/ForceJsonForApi.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/ForceJsonForApi.php)
- **Request ID:** [`work/pazar/app/Http/Middleware/RequestId.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/RequestId.php)
- **Error Envelope:** [`work/pazar/app/Http/Middleware/ErrorEnvelope.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Http/Middleware/ErrorEnvelope.php)

### Configuration
- **Bootstrap:** [`work/pazar/bootstrap/app.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/bootstrap/app.php)
- **World Registry:** [`work/pazar/app/Worlds/WorldRegistry.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/app/Worlds/WorldRegistry.php)
- **Config:** [`work/pazar/config/worlds.php`](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/config/worlds.php)

---

## Frontend (Marketplace Web - Vue.js)

### Main Entry Point
- **GitHub:** [work/marketplace-web/src/main.js](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/main.js)
- **GitHub Pages:** [work/marketplace-web/src/main.js](https://bekiryara.github.io/hos-stack/work/marketplace-web/src/main.js)

### Pages
- **Listings Search:** [`work/marketplace-web/src/pages/ListingsSearchPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/ListingsSearchPage.vue)
- **Listing Detail:** [`work/marketplace-web/src/pages/ListingDetailPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/ListingDetailPage.vue)
- **Create Listing:** [`work/marketplace-web/src/pages/CreateListingPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/CreateListingPage.vue)
- **Account Portal:** [`work/marketplace-web/src/pages/AccountPortalPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/AccountPortalPage.vue)
- **Categories:** [`work/marketplace-web/src/pages/CategoriesPage.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/pages/CategoriesPage.vue)

### Components
- **Category Tree:** [`work/marketplace-web/src/components/CategoryTree.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/components/CategoryTree.vue)
- **Filters Panel:** [`work/marketplace-web/src/components/FiltersPanel.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/components/FiltersPanel.vue)
- **Listings Grid:** [`work/marketplace-web/src/components/ListingsGrid.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/components/ListingsGrid.vue)
- **Publish Listing Action:** [`work/marketplace-web/src/components/PublishListingAction.vue`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/components/PublishListingAction.vue)

### API Client
- **Pazar API:** [`work/marketplace-web/src/lib/pazarApi.js`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/lib/pazarApi.js)
- **API Client:** [`work/marketplace-web/src/api/client.js`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/api/client.js)

### Router
- **Routes:** [`work/marketplace-web/src/router.js`](https://github.com/bekiryara/hos-stack/blob/main/work/marketplace-web/src/router.js)

---

## Infrastructure

### Docker Compose
- **GitHub:** [docker-compose.yml](https://github.com/bekiryara/hos-stack/blob/main/docker-compose.yml)
- **GitHub Pages:** [docker-compose.yml](https://bekiryara.github.io/hos-stack/docker-compose.yml)
- **Services:**
  - `hos-api` - H-OS API (Node.js)
  - `hos-db` - PostgreSQL database
  - `pazar-app` - Pazar API (Laravel)
  - `pazar-db` - MySQL database
  - `pazar-web` - Marketplace frontend (Vue.js/Vite)

### Environment Configuration
- **Example:** `.env.example`
- **Local:** `.env` (not tracked, use `.env.example` as template)

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

## Operations Scripts

### Key Scripts
- **Ops Status:** `ops/ops_status.ps1` - Unified ops dashboard
- **Public Ready Check:** `ops/public_ready_check.ps1` - Pre-release checks
- **Secret Scan:** `ops/secret_scan.ps1` - Security scan for secrets
- **GitHub Sync Safe:** `ops/github_sync_safe.ps1` - PR-based sync enforcement

---

## Quick Links

### GitHub Raw URLs (for direct file access)
- [API Routes](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/pazar/routes/api.php)
- [Docker Compose](https://raw.githubusercontent.com/bekiryara/hos-stack/main/docker-compose.yml)
- [Frontend Main](https://raw.githubusercontent.com/bekiryara/hos-stack/main/work/marketplace-web/src/main.js)

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

---

**Last Updated:** 2026-01-19

