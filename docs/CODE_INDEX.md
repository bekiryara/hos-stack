# Code Index - Complete System Overview

**Last Updated:** 2026-01-20  
**Purpose:** Single entry point for ChatGPT/AI to understand entire codebase structure  
**GitHub Pages:** https://bekiryara.github.io/hos-stack/CODE_INDEX.html

## 🎯 For ChatGPT/AI: Start Here!

This file contains **ALL** important code file links. Read this first, then follow the links to read actual code files.

## Quick Links to All Code Files

### Backend Routes (Pazar - Laravel)

**Main Route File:**
- `work/pazar/routes/api.php` - Route manifest (loads all modules)

**Route Modules (in order):**
1. `work/pazar/routes/api/00_metrics.php` - Metrics endpoint
2. `work/pazar/routes/api/00_ping.php` - Ping endpoint
3. `work/pazar/routes/api/01_world_status.php` - World status
4. `work/pazar/routes/api/02_catalog.php` - Category tree + filter schema
5. `work/pazar/routes/api/03a_listings_write.php` - Create/publish listings
6. `work/pazar/routes/api/03b_listings_read.php` - Read listings
7. `work/pazar/routes/api/03c_offers.php` - Offers management
8. `work/pazar/routes/api/04_reservations.php` - Reservations CRUD
9. `work/pazar/routes/api/05_orders.php` - Orders management
10. `work/pazar/routes/api/06_rentals.php` - Rentals management
11. `work/pazar/routes/api/account_portal.php` - Account Portal endpoints
12. `work/pazar/routes/api/messaging.php` - Messaging routes

### H-OS API (Node.js)

**Main Files:**
- `work/hos/services/api/src/app.js` - Main application file (all routes)
- `work/hos/services/api/src/routes/` - Route modules (if modularized)

### Frontend (Vue.js)

**Main Files:**
- `work/marketplace-web/src/pages/AccountPortalPage.vue` - Account Portal UI
- `work/marketplace-web/src/api/client.js` - API client
- `work/marketplace-web/vite.config.js` - Vite configuration

### Configuration

**Docker & Services:**
- `docker-compose.yml` - Main compose file (all services)
- `work/pazar/bootstrap/app.php` - Laravel bootstrap
- `work/hos/docker-compose.ports.yml` - H-OS ports config

### Middleware

**Pazar Middleware:**
- `work/pazar/app/Http/Middleware/PersonaScope.php` - Persona-based access
- `work/pazar/app/Http/Middleware/TenantScope.php` - Tenant isolation
- `work/pazar/app/Http/Middleware/Cors.php` - CORS handling

### Contracts & Snapshots

**API Contracts:**
- `contracts/api/marketplace.write.snapshot.json` - Write endpoints contract
- `contracts/api/marketplace.read.snapshot.json` - Read endpoints contract
- `contracts/api/account_portal.read.snapshot.json` - Account Portal contract

## System Architecture

### Services

1. **H-OS API** (Port 3000)
   - Universe governance
   - Auth/JWT management
   - World registry

2. **H-OS Web** (Port 3002)
   - Web UI for H-OS

3. **Pazar App** (Port 8080)
   - Laravel application
   - Marketplace API
   - Business logic

4. **Messaging API** (Port 8090)
   - Messaging service

### Database

- **hos-db**: PostgreSQL (H-OS data)
- **pazar-db**: PostgreSQL (Pazar data)
- **messaging-db**: PostgreSQL (Messaging data)

## Key Endpoints

### Catalog
- `GET /api/v1/categories` - Category tree
- `GET /api/v1/categories/{id}/filter-schema` - Filter schema

### Listings
- `POST /api/v1/listings` - Create listing (DRAFT)
- `POST /api/v1/listings/{id}/publish` - Publish listing
- `GET /api/v1/listings` - List listings
- `GET /api/v1/listings/{id}` - Get listing

### Reservations
- `POST /api/v1/reservations` - Create reservation
- `POST /api/v1/reservations/{id}/accept` - Accept reservation
- `GET /api/v1/reservations/{id}` - Get reservation

### Orders
- `POST /api/v1/orders` - Create order
- `GET /api/v1/orders` - List orders

### Rentals
- `POST /api/v1/rentals` - Create rental
- `GET /api/v1/rentals` - List rentals

## GitHub API Reading Strategy

**For ChatGPT/AI:**

1. **Start with this file** (`docs/CODE_INDEX.md`) - Read completely
2. Read `README.md` for overview
3. Read `docs/CURRENT.md` for current state
4. Read route files in order (00_metrics.php → 06_rentals.php)
5. Read middleware files for auth/access control
6. Read frontend files for UI structure

**GitHub API URLs (All files ready to read):**

**Documentation:**
- README: `https://api.github.com/repos/bekiryara/hos-stack/contents/README.md`
- CURRENT: `https://api.github.com/repos/bekiryara/hos-stack/contents/docs/CURRENT.md`
- This file: `https://api.github.com/repos/bekiryara/hos-stack/contents/docs/CODE_INDEX.md`

**Pazar Routes (read all):**
- Route manifest: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api.php`
- 00_metrics: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/00_metrics.php`
- 00_ping: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/00_ping.php`
- 01_world_status: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/01_world_status.php`
- 02_catalog: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/02_catalog.php`
- 03a_listings_write: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/03a_listings_write.php`
- 03b_listings_read: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/03b_listings_read.php`
- 03c_offers: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/03c_offers.php`
- 04_reservations: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/04_reservations.php`
- 05_orders: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/05_orders.php`
- 06_rentals: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/06_rentals.php`
- account_portal: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/routes/api/account_portal.php`

**Middleware:**
- PersonaScope: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/app/Http/Middleware/PersonaScope.php`
- TenantScope: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/app/Http/Middleware/TenantScope.php`
- Cors: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/app/Http/Middleware/Cors.php`

**Frontend:**
- API Client: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/marketplace-web/src/api/client.js`
- Account Portal: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/marketplace-web/src/pages/AccountPortalPage.vue`

**Configuration:**
- Docker Compose: `https://api.github.com/repos/bekiryara/hos-stack/contents/docker-compose.yml`
- Laravel Bootstrap: `https://api.github.com/repos/bekiryara/hos-stack/contents/work/pazar/bootstrap/app.php`

## Documentation Files

**Entry Points:**
- `docs/ONBOARDING.md` - Quick start
- `docs/CURRENT.md` - Single source of truth
- `docs/DECISIONS.md` - Baseline decisions
- `docs/ARCHITECTURE.md` - System architecture

**Runbooks:**
- `docs/runbooks/daily_ops.md` - Daily operations
- `docs/runbooks/repo_public_release.md` - Public release guide

**Proofs:**
- `docs/PROOFS/` - 177 proof documents (WP completions)

## Operations Scripts

**Key Scripts:**
- `ops/verify.ps1` - Full verification
- `ops/ops_status.ps1` - Unified ops dashboard
- `ops/daily_snapshot.ps1` - Daily evidence capture
- `ops/secret_scan.ps1` - Secret scanning
- `ops/public_ready_check.ps1` - Public readiness check

## How to Read This Repo (For AI)

**Step 1:** Read `README.md` (5 min)
**Step 2:** Read `docs/CURRENT.md` (10 min)
**Step 3:** Read `docs/CODE_INDEX.md` (this file) (5 min)
**Step 4:** Read route files in `work/pazar/routes/api/` (30 min)
**Step 5:** Read middleware files (10 min)
**Step 6:** Read frontend files (15 min)

**Total:** ~75 minutes to understand entire codebase

## File Count Summary

- **Route files:** 12 PHP files
- **Middleware:** 3 PHP files
- **Frontend:** 21 files (Vue + JS)
- **Ops scripts:** 109 PowerShell files
- **Documentation:** 177 proof files + runbooks
- **Total tracked files:** ~500+ files

## Technology Stack

- **Backend:** Laravel (PHP), Node.js (H-OS)
- **Frontend:** Vue.js 3, Vite
- **Database:** PostgreSQL 16
- **Container:** Docker Compose
- **Ops:** PowerShell 5.1+

## Important Notes

- All routes require authentication (auth.any middleware)
- Persona-based access: guest, personal, store
- Tenant isolation enforced via TenantScope middleware
- Idempotency required for write operations
- Error responses follow standardized format

