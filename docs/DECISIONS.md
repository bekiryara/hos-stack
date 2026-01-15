# DECISIONS - Baseline Definition + Frozen Items

**Last Updated:** 2026-01-14  
**Baseline:** RELEASE-GRADE BASELINE RESET v1

## Baseline Definition

**Baseline** means the minimum working state that must be maintained:

1. **Core Services Running**: hos-db, hos-api, hos-web, pazar-db, pazar-app
2. **Health Checks Passing**: H-OS `/v1/health` returns 200, Pazar `/up` returns 200
3. **No Breaking Changes**: Existing functionality must continue to work
4. **Verification Passes**: `.\ops\verify.ps1` returns exit code 0

## What is Frozen

These items are **frozen** and must not be changed without explicit decision:

### Docker Compose Topology

- **Service names**: `hos-db`, `hos-api`, `hos-web`, `pazar-db`, `pazar-app`
- **Port mappings**: 3000 (hos-api), 3002 (hos-web), 8080 (pazar-app)
- **Dependencies**: hos-api depends on hos-db (healthy), pazar-app depends on pazar-db (healthy)
- **Health checks**: Must remain functional (pg_isready for DBs)

**Rationale:** Changing service names or ports breaks documentation, scripts, and CI/CD.

### Health Endpoints

- **H-OS**: `GET /v1/health` must return HTTP 200 with `{"ok":true}`
- **Pazar**: `GET /up` must return HTTP 200 with `"ok"`

**Rationale:** These endpoints are used by ops scripts, CI/CD, and monitoring.

### Verification Script

- **Path**: `ops/verify.ps1`
- **Exit codes**: 0=PASS, 1=FAIL (must not change)
- **Checks performed**: Must remain deterministic

**Rationale:** CI/CD and automation depend on exit codes.

## What Can Change

These items can be modified with proper documentation:

- **Business logic**: Application code, routes, controllers
- **Database schema**: Migrations (with proper migration scripts)
- **Optional services**: Observability stack, development tools
- **Documentation**: Always welcome improvements

## Quarantine Policy

**Rule:** When removing or deprecating code:
1. **Quarantine first**: Move to `_graveyard/` or `_archive/` (do NOT delete)
2. **Document reason**: Add README or NOTE file explaining why and how to restore
3. **Preserve history**: Git history must remain intact for restoration

**Rationale:** Avoids accidental loss of potentially useful code and allows safe restoration if needed.

## PR + Proof Requirement

**Rule:** Every change must include:
1. **PR description**: What changed, why, risk, rollback plan
2. **Proof doc**: Under `docs/PROOFS/` with verification commands and outputs
3. **Baseline check**: `.\ops\verify.ps1` and `.\ops\conformance.ps1` must PASS

**Rationale:** Ensures changes are validated and documented before merge.

## Decision Log

### 2026-01-14: Baseline Freeze

**Decision:** Established baseline definition with core services and health checks.  
**Impact:** All future changes must maintain baseline functionality.  
**Documented in:** `docs/PROOFS/baseline_pass.md`

### 2026-01-15: Quarantine Policy

**Decision:** Established "quarantine first" policy for code removal/deprecation.  
**Impact:** Dead code is preserved in `_graveyard/` or `_archive/` with documentation.  
**Documented in:** `_graveyard/POLICY.md`, `docs/DECISIONS.md`


