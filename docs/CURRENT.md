# CURRENT - Single Source of Truth (Runtime Truth)

**Last Updated:** 2026-01-17  
**Baseline:** RELEASE-GRADE BASELINE RESET v1

## What is the Stack?

This repository runs **H-OS** (universe governance) and **Pazar** (first commerce world) services together.

### Core Services (Required for Baseline)

**H-OS Core:**
- `hos-db`: PostgreSQL 16 database for H-OS (internal service, no exposed port)
- `hos-api`: H-OS API service on `http://localhost:3000`
- `hos-web`: H-OS Web UI on `http://localhost:3002`

**Pazar Core:**
- `pazar-db`: PostgreSQL 16 database for Pazar (internal service, no exposed port)
- `pazar-app`: Laravel application on `http://localhost:8080`

### Optional Services (Not Required for Baseline)

- Observability stack (Prometheus, Grafana, Loki, etc.) - optional
- Any service not listed above

## Ports

- **3000**: H-OS API (`http://localhost:3000`)
- **3002**: H-OS Web (`http://localhost:3002`)
- **8080**: Pazar App (`http://localhost:8080`)
- **5173**: Frontend Dev Server (`http://localhost:5173`) - Optional, only if frontend dev server is running


## API Endpoints

### H-OS API (Port 3000)

- `GET /v1/health` - Health check
- `GET /v1/worlds` - World directory (returns array of worlds: core, marketplace, etc.)

### Pazar API (Port 8080)

- `GET /up` - Health check (nginx-level, no Laravel)
- `GET /api/world/status` - Marketplace world status (SPEC §24.4)
- `GET /api/v1/categories` - Category tree (WP-2, may return empty array if not seeded)
- `GET /api/v1/categories/{id}/filter-schema` - Filter schema for category (WP-2)

**Note:** Laravel routes in `routes/api.php` are automatically prefixed with `/api` by default.

## Health Checks

### Quick Health Checks (curl commands)

```powershell
# H-OS World Status
curl http://localhost:3000/v1/world/status

# H-OS Worlds Directory
curl http://localhost:3000/v1/worlds

# Pazar World Status
curl http://localhost:8080/api/world/status

# Pazar Health (nginx-level)
curl http://localhost:8080/up
```

### Health Check Criteria

Baseline is "working" when:

1. **H-OS Health**: `curl http://localhost:3000/v1/health` returns HTTP 200 with `{"ok":true}`
2. **Pazar Health**: `curl http://localhost:8080/up` returns HTTP 200 with `"ok"`
3. **World Status**: Both H-OS and Pazar world status endpoints return valid responses
4. **Containers Running**: All required services show "Up" status in `docker compose ps`
5. **FS Posture**: Pazar storage/logs is writable (no permission errors)

## Verification Commands

### Basic Verification

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

### Contract Checks

```powershell
# Marketplace Spine Check (all contract checks)
.\ops\pazar_spine_check.ps1

# Individual contract checks (if needed)
.\ops\order_contract_check.ps1
.\ops\messaging_contract_check.ps1
```

**Note:** These scripts verify that backend READ endpoints match their contracts (snapshot files).

### Frontend Readiness Check (WP-15)

```powershell
.\ops\wp15_frontend_readiness.ps1
```

This command verifies that the stack is ready for frontend integration:
- Repo root sanity
- World status check
- Marketplace spine check
- Optional contract checks
- Frontend presence check

**Exit Codes:**
- `0` = READY FOR FRONTEND INTEGRATION
- `1` = NOT READY (see output for specific failure)

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

## Account Portal READ Endpoints (WP-12.1)

If Account Portal READ endpoints are implemented, they are available at:

**Personal Scope** (Authorization header required):
- `GET /api/v1/orders?buyer_user_id={uuid}`
- `GET /api/v1/rentals?renter_user_id={uuid}`
- `GET /api/v1/reservations?requester_user_id={uuid}`

**Store Scope** (X-Active-Tenant-Id header required):
- `GET /api/v1/listings?tenant_id={uuid}`
- `GET /api/v1/orders?seller_tenant_id={uuid}`
- `GET /api/v1/rentals?provider_tenant_id={uuid}`
- `GET /api/v1/reservations?provider_tenant_id={uuid}`

**Expected Response Format:**
```json
{
  "data": [...],
  "meta": {
    "total": 0,
    "page": 1,
    "per_page": 20,
    "total_pages": 0
  }
}
```

## Front-end Readiness Conditions (WP-15)

The stack is ready for frontend integration when:

1. **World Status Check PASS**: H-OS and Pazar world endpoints return valid responses
2. **Marketplace Spine Check PASS**: All contract checks pass (`.\ops\pazar_spine_check.ps1`)
3. **Optional Contract Checks**: Order and messaging contract checks (if scripts exist) do not fail
4. **Frontend Presence**: Frontend folder exists (`work/marketplace-web`) with `package.json`
5. **Frontend Dev Server** (optional): Port 5173 is LISTENING if frontend dev server is running

**Deterministic Check:**
```powershell
.\ops\wp15_frontend_readiness.ps1
```

**Expected Output:**
- `PASS: READY FOR FRONTEND INTEGRATION` (exit code 0)
- OR `FAIL: NOT READY` with specific failure details (exit code 1)

## Related Docs

- **Onboarding:** `docs/ONBOARDING.md` (quick start for newcomers)
- **Decisions:** `docs/DECISIONS.md` (baseline definition + frozen items)
- **Start Here:** `docs/START_HERE.md` (7 rule set)
- **Rules:** `docs/RULES.md` (fundamental rules)
