# WP-4.3 Governance & Stabilization Lock v1 - Proof Document

**Date:** 2026-01-16  
**Task:** WP-0 + WP-4.3 GOVERNANCE & STABILIZATION LOCK (SPEC + CI + TRACKED MIGRATIONS)  
**Status:** COMPLETE

## Summary

Made the repo governance-first and spine-stable by:
1. Verifying SPEC.md and WP_CLOSEOUTS.md as single source of truth
2. Creating and tracking sessions table migration
3. Hardening catalog contract check to fail on missing roots/capacity_max
4. Adding CI gate for spine reliability

## Changes Made

### 1. Sessions Table Migration (Tracked)

**Problem:**
- Pazar root endpoint (GET http://localhost:8080/) returned 500 error
- Error: "sessions table missing" (Laravel SESSION_DRIVER=database requires sessions table)
- Migration was applied but file was not tracked in git

**Solution:**
- Created migration file: `work/pazar/database/migrations/2026_01_16_141957_create_sessions_table.php`
- Migration includes standard Laravel sessions table schema (id, user_id, ip_address, user_agent, payload, last_activity)
- Applied migration: `docker compose exec pazar-app php artisan migrate --force`
- Root endpoint now works without sessions error

**Verification:**
```powershell
# Migration status
docker compose exec -T pazar-app php artisan migrate:status | Select-String -Pattern "sessions"
# Output: 2026_01_16_141957_create_sessions_table ............................ [2] Ran

# Root endpoint
curl http://localhost:8080/
# Output: HTTP 200 OK (no 500 error)
```

### 2. Catalog Contract Check Hardening

**Problem:**
- Script only warned about missing root categories (vehicle, real-estate, service)
- Script did not fail if wedding-hall exists but capacity_max filter is missing or required!=true

**Solution:**
- Updated `ops/catalog_contract_check.ps1` to FAIL (exit 1) if:
  - Root categories are not exactly: vehicle, real-estate, service
  - wedding-hall exists but capacity_max filter is missing
  - wedding-hall capacity_max filter has required!=true
- Changed from WARN to FAIL for missing root categories
- Added validation for capacity_max filter with required=true for wedding-hall
- Changed exit code from Invoke-OpsExit to hard exit (exit 0/1) for proper propagation

**Verification:**
```powershell
# Before seeding (should FAIL)
.\ops\catalog_contract_check.ps1
# Output: FAIL: Missing required root categories (exit 1)

# After seeding (should PASS if all roots present)
docker compose exec -T pazar-app php artisan db:seed --class=CatalogSpineSeeder --force
.\ops\catalog_contract_check.ps1
# Output: PASS (exit 0) - All required root categories present
```

### 3. CI Gate for Spine Reliability

**Problem:**
- No automated CI gate to verify Marketplace spine checks pass
- No check for SPEC.md existence in CI

**Solution:**
- Created `.github/workflows/gate-pazar-spine.yml`:
  - Checks SPEC.md exists (fails if missing)
  - Brings up services with docker compose
  - Runs migrations
  - Seeds required data (CatalogSpineSeeder)
  - Runs `ops/pazar_spine_check.ps1`
  - Fails job on non-zero exit
- Updated `.github/workflows/gate-spec.yml` to also check WP_CLOSEOUTS.md (WARN if missing, not FAIL)

**Verification:**
- CI workflow exists and triggers on PR/push for Pazar-related changes
- Workflow includes SPEC.md check
- Workflow runs spine check after migrations and seeding

### 4. SPEC and WP_CLOSEOUTS Verification

**Status:**
- `docs/SPEC.md` exists and is canonical (verified)
- `docs/WP_CLOSEOUTS.md` exists with WP summaries (verified)
- `docs/PROOFS/` contains existing proof docs for WP-1..WP-4.2 (verified)

## Commands Executed

```powershell
# 1. Verify sessions migration
docker compose exec -T pazar-app php artisan migrate:status | Select-String -Pattern "sessions"
# Output: 2026_01_16_141957_create_sessions_table ............................ [2] Ran

# 2. Verify root endpoint
curl http://localhost:8080/
# Output: HTTP 200 OK

# 3. Seed categories
docker compose exec -T pazar-app php artisan db:seed --class=CatalogSpineSeeder --force
# Output: Inserted attributes, categories, filter schemas

# 4. Run catalog check (should PASS after seeding)
.\ops\catalog_contract_check.ps1
# Output: PASS (exit 0) - All required root categories present

# 5. Run spine check
.\ops\pazar_spine_check.ps1
# Output: PASS (exit 0) - All 4 checks pass
```

## Acceptance Criteria

- [x] SPEC.md exists and is canonical
- [x] WP_CLOSEOUTS.md exists with WP summaries
- [x] Sessions migration file exists and is tracked in git
- [x] Root endpoint returns 200 OK (no sessions error)
- [x] Catalog check fails on missing roots/capacity_max
- [x] CI gate exists and checks SPEC.md + runs spine check
- [x] All proof docs exist for WP-1..WP-4.2

## Files Changed

1. `work/pazar/database/migrations/2026_01_16_141957_create_sessions_table.php` (NEW)
2. `ops/catalog_contract_check.ps1` (MODIFIED - hardened validation)
3. `.github/workflows/gate-pazar-spine.yml` (NEW)
4. `.github/workflows/gate-spec.yml` (MODIFIED - added WP_CLOSEOUTS.md check)
5. `docs/WP_CLOSEOUTS.md` (MODIFIED - added WP-4.3 entry)
6. `docs/PROOFS/wp4_3_governance_stabilization_pass.md` (NEW - this file)

## Notes

- Catalog check will FAIL until all three root categories (vehicle, real-estate, service) are seeded
- CI workflow requires PowerShell to be installed (uses microsoft/setup-powershell@v1)
- Sessions migration is idempotent (safe to run multiple times)







