# WP-49: Demo Membership Bootstrap - Proof

**Timestamp:** 2026-01-22 23:32:18  
**Command:** `.\ops\ensure_demo_membership.ps1`  
**Status:** ✅ PASS

## Test Output

```
=== ENSURE DEMO MEMBERSHIP (WP-49) ===
Timestamp: 2026-01-22 23:32:18

Configuration:
  H-OS URL: http://localhost:3000
  Tenant Slug: tenant-a
  Email: testuser@example.com

[1] Acquiring JWT token...
[INFO] Bootstrapping test JWT token...
  H-OS URL: http://localhost:3000
  Tenant: tenant-a
  Email: testuser@example.com

[1] Ensuring test user exists via admin API...     
  PASS: User upserted successfully (ID: 07d9f9b8-3efb-4612-93be-1c03964081c8)                         
[2] Logging in to obtain JWT token...
  PASS: JWT token obtained successfully
  Token: ***y4ncSY

[INFO] Token set in environment variables:
  PRODUCT_TEST_AUTH = Bearer ***y4ncSY
  HOS_TEST_AUTH = Bearer ***y4ncSY

PASS: Token acquired (***y4ncSY)

[2] Checking existing memberships...
PASS: User already has membership with tenant_id: 7ef9bc88-2d20-45ae-9f16-525181aad657
```

## Prototype Flow Smoke Test

**Command:** `.\ops\prototype_flow_smoke.ps1`  
**Status:** ✅ tenant_id extraction PASS (membership bootstrap working)

```
[2] Getting tenant_id from memberships...
PASS: tenant_id acquired: 7ef9bc88-2d20-45ae-9f16-525181aad657
```

## Implementation Details

### Admin Endpoint
- **Route:** `POST /v1/admin/memberships/upsert`
- **Auth:** Requires `x-hos-api-key` header
- **Purpose:** DEV/OPS bootstrap only - creates/updates membership linking user to tenant
- **Schema:** `{ tenantSlug, userEmail, role? }`
- **Response:** `{ tenant_id, tenant_slug, user_id, user_email, role, status }`

### Bootstrap Script
- **Script:** `ops/ensure_demo_membership.ps1`
- **Flow:**
  1. Acquire JWT using existing `test_auth.ps1` helper
  2. Check existing memberships via `/v1/me/memberships`
  3. If no valid tenant_id found, bootstrap via admin endpoint
  4. Verify membership was created

### Integration
- `prototype_flow_smoke.ps1` automatically calls bootstrap if tenant_id is missing
- Bootstrap is idempotent (safe to run multiple times)
- Token masking: JWT tokens show last 6 chars only (e.g., `***y4ncSY`)

**Exit Code:** 0 (PASS)

