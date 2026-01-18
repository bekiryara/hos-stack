# WP-8 Core Persona Switch + Membership Strict Mode - PASS Proof

**Date:** 2026-01-17  
**WP:** WP-8 Core  
**Status:** PASS

## Summary

WP-8 Core Persona Switch + Membership Strict Mode implementation completed successfully. All core persona contract checks pass.

## Evidence

### 1. Core Persona Contract Check (PASS)

```
=== CORE PERSONA CONTRACT CHECK (WP-8) ===
Timestamp: 2026-01-17 12:17:42

[0] Creating test tenant and user via admin API...
PASS: Test tenant and user created via admin API
  User ID: e93fb721-6012-41dc-8a50-a74b1eb6cc0d
  Tenant ID: 78786041-6df9-44e9-acf0-d319b1e77af7
  Tenant Slug: test-tenant-wp8-20260117121742
  Logging in to obtain auth token...
PASS: Auth token obtained


[1] Testing GET /v1/me...
  Response: {
    "user_id":  "e93fb721-6012-41dc-8a50-a74b1eb6cc0d",
    "email":  "test-wp8@example.com",
    "display_name":  "test-wp8",
    "memberships_count":  0
}
PASS: GET /v1/me returns user info
  User ID: e93fb721-6012-41dc-8a50-a74b1eb6cc0d
  Email: test-wp8@example.com
  Display Name: test-wp8
  Memberships Count: 0

[2] Testing GET /v1/me/memberships...
PASS: GET /v1/me/memberships returns array
  Memberships count: 0
  Note: No memberships found (empty array is valid)

[3] Testing POST /v1/tenants/v2 (create tenant)...
PASS: POST /v1/tenants/v2 created tenant
  Tenant ID: 7b160080-931e-486e-bd0e-3413997e1eb1
  Slug: test-tenant-20260117121744-6e93e489
  Status: active

[4] Testing GET /v1/tenants/{tenant_id}/memberships/me (allowed=true)...
PASS: GET /v1/tenants/{id}/memberships/me returns allowed=true
  Tenant ID: 7b160080-931e-486e-bd0e-3413997e1eb1
  User ID: e93fb721-6012-41dc-8a50-a74b1eb6cc0d
  Role: owner
  Status: active
  Allowed: True

[5] Testing negative: GET /v1/tenants/{wrong_tenant_id}/memberships/me (should return allowed=false)...
PASS: Wrong tenant ID correctly returned allowed=false
  Tenant ID: 00000000-0000-0000-0000-000000000000
  Allowed: False

=== CORE PERSONA CONTRACT CHECK: PASS ===
All core persona contract checks passed.
```

### 2. Migration Applied

```
docker compose exec hos-db psql -U hos -d hos -c "SELECT COUNT(*) FROM memberships;"
     2
(1 row)
```

Memberships table exists and has been backfilled from existing users.

### 3. HOS API Endpoints Verified

- GET /v1/me: Returns user info with memberships_count
- GET /v1/me/memberships: Returns array of active memberships
- POST /v1/tenants/v2: Creates tenant and auto-creates membership (role=owner)
- GET /v1/tenants/{id}/memberships/me: Returns membership status (allowed=true/false)

## Deliverables

- [x] HOS migrations + backfill done (015_wp8_memberships_table.sql)
- [x] HOS endpoints implemented: /v1/me, /v1/me/memberships, POST /v1/tenants/v2, GET /v1/tenants/{id}/memberships/me
- [x] Feature flags added (CORE_MEMBERSHIP_STRICT, MARKETPLACE_MEMBERSHIP_STRICT)
- [x] Pazar HOS membership adapter + strict flag enforcement
- [x] ops/core_persona_contract_check.ps1 (NEW)
- [x] ops/pazar_spine_check.ps1 WP-8 step added
- [x] docs/SPEC.md WP-8 added + rules
- [x] docs/WP_CLOSEOUTS.md updated
- [x] docs/PROOFS/wp8_core_persona_pass.md with real outputs
- [x] CHANGELOG.md updated

## Notes

- Strict mode is OFF by default (backward compatible)
- Membership table backfilled from existing users
- All tests PASS with deterministic outputs
- ASCII-only outputs maintained


