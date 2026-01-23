# Contract Check Report - Raw Command Outputs

**Date:** 2026-01-23  
**Purpose:** Raw command outputs from ops gate scripts for audit verification

---

## Note

This report contains the raw console output from running ops gate scripts.  
Full output was captured during state report generation.

## Summary

| Script | Exit Code | Status |
|--------|-----------|--------|
| world_status_check.ps1 | 0 | PASS |
| catalog_contract_check.ps1 | 0 | PASS |
| listing_contract_check.ps1 | 1 | FAIL |
| reservation_contract_check.ps1 | 0 | FAIL |
| messaging_contract_check.ps1 | 0 | PASS |
| frontend_smoke.ps1 | 1 | FAIL |
| prototype_smoke.ps1 | 0 | PASS |
| prototype_flow_smoke.ps1 | 0 | PASS |

---

## Full Outputs

### world_status_check.ps1

```
=== WORLD STATUS CHECK (WP-1.2) ===
Timestamp: 2026-01-23 16:43:55

[1] Testing HOS GET /v1/world/status...
PASS: HOS /v1/world/status returns valid response
  world_key: core
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

[2] Testing HOS GET /v1/worlds...
PASS: HOS /v1/worlds returns valid array with all worlds
  - core: ONLINE (GENESIS, v1.4.0)
  - marketplace: ONLINE (GENESIS, v1.4.0)
  - messaging: ONLINE (GENESIS, v1.4.0)
  - social: DISABLED (GENESIS, v1.4.0)

[3] Testing Pazar GET /api/world/status...
PASS: Pazar /api/world/status returns valid response
  world_key: marketplace
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

=== WORLD STATUS CHECK: PASS ===
```

---

### catalog_contract_check.ps1

```
=== CATALOG CONTRACT CHECK (WP-2) ===
Timestamp: 2026-01-23 16:44:01

[1] Testing GET /api/v1/categories...
PASS: Categories endpoint returns non-empty tree
  Root categories: 3
  Found wedding-hall category (id: 3)

[2] Testing GET /api/v1/categories/3/filter-schema...
PASS: Filter schema endpoint returns valid response
  Category ID: 3
  Category Slug: wedding-hall
  Active filters: 1
  PASS: wedding-hall has capacity_max filter with required=true
  Filter attributes:
    - capacity_max (number, required: True)

=== CATALOG CONTRACT CHECK: PASS ===
```

---

### listing_contract_check.ps1

```
=== LISTING CONTRACT CHECK (WP-3) ===
Timestamp: 2026-01-23 16:44:02

[1] Testing GET /api/v1/categories...
PASS: Categories endpoint returns non-empty array
  Root categories: 3
  Found 'wedding-hall' category with ID: 3

[2] Testing POST /api/v1/listings (create DRAFT)...
FAIL: Create listing request failed: Uzak sunucu hatası döndürdü: (401) Onaylanmadı.
  Status Code: 401

[3] SKIP: Cannot test publish (listing ID not available)
[4] SKIP: Cannot test get listing (listing ID not available)

[5] Testing GET /api/v1/listings?category_id=3...
PASS: Search listings returns results
  Results count: 20

[6] Testing POST /api/v1/listings without X-Active-Tenant-Id header...
PASS: Request without header correctly rejected (status: 400)

=== LISTING CONTRACT CHECK: FAIL ===
```

**Issue:** Missing JWT token bootstrap. Script needs to use `ops/_lib/test_auth.ps1` to acquire token and tenant_id.

---

### reservation_contract_check.ps1

```
=== RESERVATION CONTRACT CHECK (WP-4) ===
Timestamp: 2026-01-23 16:44:02

[PREP] Cleaning up old test reservations...

[0] Getting or creating published listing for testing...
PASS: Found existing published listing: 82b4a251-28...
  Title: Test Wedding Hall Listing
  Capacity Max: 500

[1] Testing POST /api/v1/reservations (party_size less than capacity_max)...
FAIL: Create reservation request failed: Uzak sunucu hatası döndürdü: (401) Onaylanmadı.
  Status Code: 401

[1b] Testing Messaging thread creation for reservation...
SKIP: Cannot verify messaging thread (reservation ID not available)

[2] SKIP: Cannot test idempotency (reservation ID not available)

[3] Testing POST /api/v1/reservations (conflict - slot overlap)...
FAIL: Expected 409 CONFLICT, got status: 401

[4] Testing POST /api/v1/reservations (party_size greater than capacity_max)...
FAIL: Expected 422 VALIDATION_ERROR, got status: 401

[5] Testing POST /api/v1/reservations/{id}/accept (tenant ownership)...
FAIL: Accept reservation request failed: Uzak sunucu hatası döndürdü: (401) Onaylanmadı.
  Status Code: 401

[6] Testing POST /api/v1/reservations/{id}/accept (reject unauthorized tenant)...
FAIL: Could not create reservation for reject test: (401) Onaylanmadı.

=== RESERVATION CONTRACT CHECK: FAIL ===
```

**Issue:** Missing JWT token bootstrap. Script needs to use `ops/_lib/test_auth.ps1` to acquire token.

---

### messaging_contract_check.ps1

```
=== MESSAGING CONTRACT CHECK (WP-5) ===
Timestamp: 2026-01-23 16:44:03

[1] Testing GET /api/world/status...
PASS: World status returns valid response
  world_key: messaging
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

[2] Testing POST /api/v1/threads/upsert...
PASS: Thread upserted successfully
  Thread ID: 9235c8fa-12f2-4e86-8ac6-37078d8b0569
  Context: reservation / test-20260123164403

[3] Testing POST /api/v1/threads/9235c8fa-12f2-4e86-8ac6-37078d8b0569/messages...
PASS: Message posted successfully
  Message ID: 57a47981-1824-4b71-9a73-fca6f7802e87
  Body: Test message from contract check

[4] Testing GET /api/v1/threads/by-context?context_type=reservation&context_id=test-20260123164403...
PASS: Thread by-context lookup successful
  Thread ID: 9235c8fa-12f2-4e86-8ac6-37078d8b0569
  Participants: 2
  Messages: 1

=== MESSAGING CONTRACT CHECK: PASS ===
```

---

### frontend_smoke.ps1

```
=== FRONTEND SMOKE TEST (WP-40) ===
Timestamp: 2026-01-23 16:44:06

[A] Running world status check...
PASS: world_status_check.ps1 returned exit code 0

[B] Checking HOS Web (http://localhost:3002)...
PASS: HOS Web returned status code 200
PASS: HOS Web contains hos-home marker
PASS: HOS Web contains prototype-launcher marker

[C] Checking marketplace demo page...
PASS: Marketplace demo page returned status code 200
PASS: Marketplace demo page contains Vue app mount

[D] Checking marketplace search page...
PASS: Marketplace search page returned status code 200
PASS: Marketplace search page contains Vue app mount

[E] Checking messaging proxy endpoint...
FAIL: Messaging proxy unreachable: Uzak sunucu hatası döndürdü: (404) Bulunamadı.
  Check if HOS Web is running and nginx config includes /api/messaging/ location

[F] Checking marketplace need-demo page...
PASS: Marketplace need-demo page returned status code 200
PASS: Marketplace need-demo page contains Vue app mount

[G] Checking marketplace-web build...
PASS: Build successful

=== FRONTEND SMOKE TEST: FAIL ===
```

**Issue:** Messaging proxy returns 404. Verify nginx configuration and messaging-api service accessibility.

---

### prototype_smoke.ps1

```
=== PROTOTYPE SMOKE (WP-44) ===
Timestamp: 2026-01-23 16:44:12

[1] Checking Docker services...
PASS: docker compose ps executed successfully
  Services: hos-api, hos-db, hos-web, messaging-api, pazar-app, pazar-db

[2] Checking HTTP endpoints...
  [2.1] HOS core status: PASS (world_key: core, availability: ONLINE)
  [2.2] HOS worlds: PASS (core, marketplace, messaging, social)
  [2.3] Pazar status: PASS (world_key: marketplace, availability: ONLINE)
  [2.4] Messaging status: PASS (world_key: messaging, availability: ONLINE)

[3] Checking HOS Web UI marker...
PASS: HOS Web UI contains prototype-launcher marker

=== PROTOTYPE SMOKE: PASS ===
```

---

### prototype_flow_smoke.ps1

```
=== PROTOTYPE FLOW SMOKE (WP-45) ===
Timestamp: 2026-01-23 16:44:14

[1] Acquiring JWT token...
PASS: Token acquired (***fbaFR4)

[2] Getting tenant_id from memberships...
PASS: tenant_id acquired: 7ef9bc88-2d20-45ae-9f16-525181aad657

[3] Ensuring Pazar has a usable listing...
PASS: Listing created: 51deef7e-0685-485d-9702-9b6c52649838
PASS: Listing published: 51deef7e-0685-485d-9702-9b6c52649838

[4] Testing Messaging flow...
  [4.1] Upserting thread by listing context...
PASS: Thread upserted: de4af210-8b29-49f7-abf0-d63b46f61d9a
  [4.2] Fetching thread by context...
PASS: Thread fetched by context: de4af210-8b29-49f7-abf0-d63b46f61d9a
  [4.3] Posting smoke ping message...
PASS: Message posted: 82c729ac-da6e-44bc-8427-39ce9a37d415
  [4.4] Re-fetching thread to assert message...
PASS: Message found in thread

=== PROTOTYPE FLOW SMOKE: PASS ===
RESULT: tenant_id=7ef9bc88-2d20-45ae-9f16-525181aad657 listing_id=51deef7e-0685-485d-9702-9b6c52649838 thread_id=de4af210-8b29-49f7-abf0-d63b46f61d9a
```

---

## Conclusion

5/8 ops gates PASS, 3/8 FAIL:
- `listing_contract_check.ps1`: Missing JWT token bootstrap
- `reservation_contract_check.ps1`: Missing JWT token bootstrap
- `frontend_smoke.ps1`: Messaging proxy 404

See `docs/PROOFS/state_report_20260123.md` for detailed analysis and remediation steps.
