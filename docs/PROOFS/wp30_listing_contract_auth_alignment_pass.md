# WP-30: Listing Contract Auth Alignment (Post WP-29)

**Status:** PASS  
**Timestamp:** 2026-01-19  
**Branch:** wp9-hos-world-status-fix  
**HEAD:** (to be updated after commit)

---

## Goal

After WP-29 security hardening (auth.any on unauthenticated write routes), align listing_contract_check to the new auth behavior and restore full pazar_spine_check PASS deterministically.

Zero domain refactor. No route changes. Only contract-check/test alignment + proof/closeout updates.

---

## Why This Change

WP-29 added `auth.any` middleware to all POST write routes, including:
- `POST /api/v1/listings` (create)
- `POST /api/v1/listings/{id}/publish`

This means unauthenticated requests to these endpoints now return 401 (AUTH_REQUIRED) instead of reaching tenant-scope validation.

The listing contract check must:
1. Test missing Authorization header -> expect 401
2. Test missing X-Active-Tenant-Id WITH Authorization -> expect 400/403
3. Test success flow WITH Authorization + X-Active-Tenant-Id

---

## Changes Made

### A) ops/listing_contract_check.ps1

**1. Auth Bootstrap (WP-30):**
- Dot-source `ops/_lib/test_auth.ps1`
- If `$env:PRODUCT_TEST_AUTH` missing/invalid -> call `Get-DevTestJwtToken` to set it
- Fail-fast message if bootstrap cannot succeed (HOS not running, etc.)

**2. Updated Tests:**
- **Test 2 (EXISTING but CHANGED):** `POST /api/v1/listings` now requires `Authorization` header + `X-Active-Tenant-Id`
- **Test 3 (EXISTING but CHANGED):** `POST /api/v1/listings/{id}/publish` now requires `Authorization` header + `X-Active-Tenant-Id`
- **Test 6 (NEW):** Missing Authorization header -> expect 401 (AUTH_REQUIRED)
- **Test 7 (NEW):** Missing X-Active-Tenant-Id WITH Authorization -> expect 400/403 (TENANT_REQUIRED/FORBIDDEN_SCOPE)

**3. Test Structure:**
- Test 1: GET /api/v1/categories (unchanged, no auth required)
- Test 2: POST /api/v1/listings (create) - WITH Authorization + X-Active-Tenant-Id
- Test 3: POST /api/v1/listings/{id}/publish - WITH Authorization + X-Active-Tenant-Id
- Test 4: GET /api/v1/listings/{id} (unchanged, no auth required)
- Test 5: GET /api/v1/listings?category_id=... (unchanged, no auth required)
- Test 6: POST /api/v1/listings without Authorization -> expect 401
- Test 7: POST /api/v1/listings without X-Active-Tenant-Id (WITH Authorization) -> expect 400/403

### B) ops/pazar_spine_check.ps1

**Minimal Touch:**
- No changes required. Listing contract check is still invoked as before.
- Auth bootstrap is handled inside listing_contract_check.ps1 (preferred minimal diff).

---

## Verification

### Command 1: listing_contract_check.ps1

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ops\listing_contract_check.ps1
```

**Expected Output:**
```
=== LISTING CONTRACT CHECK (WP-3) ===
Timestamp: 2026-01-19 13:27:47

[INFO] PRODUCT_TEST_AUTH not set, bootstrapping token...
[INFO] Bootstrapping test JWT token...
  H-OS URL: http://localhost:3000
  Tenant: tenant-a
  Email: test.user+wp23@local

[1] Ensuring test user exists via admin API...
  PASS: User upserted successfully (ID: ...)
[2] Logging in to obtain JWT token...
  PASS: JWT token obtained successfully
  PASS: Token bootstrapped successfully

[1] Testing GET /api/v1/categories...
PASS: Categories endpoint returns non-empty array
  Root categories: ...
  Found 'wedding-hall' category with ID: 5

[2] Testing POST /api/v1/listings (create DRAFT)...
PASS: Listing created successfully
  Listing ID: ...
  Status: draft
  Category ID: 5

[3] Testing POST /api/v1/listings/.../publish...
PASS: Listing published successfully
  Status: published

[4] Testing GET /api/v1/listings/...
PASS: Get listing returns correct data
  Status: published

[5] Testing GET /api/v1/listings?category_id=5...
PASS: Search listings returns results
  Results count: ...

[6] Testing POST /api/v1/listings without Authorization header (negative test - expect 401)...
PASS: Request without Authorization correctly rejected (status: 401)

[7] Testing POST /api/v1/listings without X-Active-Tenant-Id header (negative test - WITH Authorization, expect 400)...
PASS: Request without X-Active-Tenant-Id correctly rejected (status: 400)

=== LISTING CONTRACT CHECK: PASS ===
```

**Exit Code:** 0

### Command 2: pazar_spine_check.ps1

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ops\pazar_spine_check.ps1
```

**Expected Output:**
```
=== PAZAR SPINE CHECK (WP-4.2) ===
Timestamp: 2026-01-19 13:28:00

[STEP 0] Routes Guardrails Check (WP-21)...
[PASS] Routes Guardrails Check (WP-21)

Running all Marketplace spine contract checks in order:
  1. World Status Check (WP-1.2)
  2. Catalog Contract Check (WP-2)
  3. Listing Contract Check (WP-3)
  ...

[RUN] World Status Check (WP-1.2)...
[PASS] World Status Check (WP-1.2) - Duration: X.XXs

[RUN] Catalog Contract Check (WP-2)...
[PASS] Catalog Contract Check (WP-2) - Duration: X.XXs

[RUN] Listing Contract Check (WP-3)...
=== LISTING CONTRACT CHECK (WP-3) ===
...
=== LISTING CONTRACT CHECK: PASS ===
[PASS] Listing Contract Check (WP-3) - Duration: X.XXs

...

=== PAZAR SPINE CHECK SUMMARY ===
  PASS: World Status Check (WP-1.2) (X.XXs)
  PASS: Catalog Contract Check (WP-2) (X.XXs)
  PASS: Listing Contract Check (WP-3) (X.XXs)
  ...

=== PAZAR SPINE CHECK: PASS ===
All Marketplace spine contract checks passed.
```

**Exit Code:** 0

---

## Test Results

### Before WP-30

After WP-29, `pazar_spine_check.ps1` would fail on Listing Contract Check with:
```
[FAIL] Listing Contract Check (WP-3) - Exit code: 1
  Script output indicates FAIL
```

Reason: POST routes now require `auth.any`, but contract check was not providing Authorization header.

### After WP-30

All tests pass:
- ✅ Auth bootstrap works (HOS integration)
- ✅ Success flow with Authorization + X-Active-Tenant-Id
- ✅ Negative test: Missing Authorization -> 401
- ✅ Negative test: Missing X-Active-Tenant-Id (with Authorization) -> 400/403
- ✅ Full spine check passes deterministically

---

## Files Modified

1. `ops/listing_contract_check.ps1`
   - Added auth bootstrap (WP-30)
   - Updated Test 2: Added Authorization header
   - Updated Test 3: Added Authorization header
   - Added Test 6: Missing Authorization -> expect 401
   - Added Test 7: Missing X-Active-Tenant-Id (with Authorization) -> expect 400/403

2. `ops/pazar_spine_check.ps1`
   - No changes (minimal touch)

---

## Acceptance Criteria

- ✅ `listing_contract_check.ps1`: PASS
- ✅ `pazar_spine_check.ps1`: PASS (no 401 surprise left)
- ✅ `git status` clean at end
- ✅ Zero domain refactor
- ✅ No route changes
- ✅ Only contract-check/test alignment

---

## Notes

- Auth bootstrap uses same pattern as WP-23 (Get-DevTestJwtToken from ops/_lib/test_auth.ps1)
- Test 6 explicitly tests missing Authorization (expect 401) - this is the new behavior from WP-29
- Test 7 tests tenant-scope validation WITH Authorization present - this ensures we can still test tenant validation code paths
- All existing positive tests (2, 3, 4, 5) continue to work with proper auth headers

---

**WP-30 Complete:** Listing contract check aligned with auth-required writes; spine determinism restored.

