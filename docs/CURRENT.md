# CURRENT - Single Source of Truth

**Last Updated:** 2026-01-14  
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

## Related Docs

- **Onboarding:** `docs/ONBOARDING.md` (quick start for newcomers)
- **Decisions:** `docs/DECISIONS.md` (baseline definition + frozen items)
- **Start Here:** `docs/START_HERE.md` (7 rule set)
- **Rules:** `docs/RULES.md` (fundamental rules)
