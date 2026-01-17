# WP-7 Rentals Thin Slice - Proof Document

**Date:** 2026-01-17 09:52:40  
**Package:** WP-7 RENTALS THIN SLICE (DETERMINISTIC PACK v1)  
**Reference:** `docs/SPEC.md` §§ 6.3, 6.7, 17.4

---

## Executive Summary

Successfully implemented Rentals endpoint for Marketplace Transactions spine. Rentals can be created with idempotency support, validated against published listings, checked for date overlaps, and accepted by provider tenants. All contract checks PASS. Marketplace Transactions spine now complete with Reservations, Orders, and Rentals.

---

## Deliverables

### A) Database Migration

**Files Created:**
- `work/pazar/database/migrations/2026_01_17_100006_create_rentals_table.php`

**Tables Created:**
- `rentals` table with fields:
  - `id` (uuid, primary key)
  - `listing_id` (uuid, foreign key to listings)
  - `renter_user_id` (uuid, not null)
  - `provider_tenant_id` (uuid, not null)
  - `start_at` (timestamp, not null)
  - `end_at` (timestamp, not null)
  - `status` (string, default='requested') - requested|accepted|active|completed|cancelled
  - `created_at`, `updated_at` (timestamps)

**Indexes:**
- `listing_id`
- `(renter_user_id, status)`
- `(provider_tenant_id, status)`
- `(listing_id, start_at, end_at)` - For overlap checks

**Foreign Keys:**
- `listing_id` -> `listings.id` (on delete cascade)

---

### B) API Endpoints

**Files Modified:**
- `work/pazar/routes/api.php` - Added rental endpoints (lines 858-1036)

**Endpoints:**
1. `POST /api/v1/rentals` - Create rental request
2. `POST /api/v1/rentals/{id}/accept` - Accept rental (provider)
3. `GET /api/v1/rentals/{id}` - Get rental details

**POST /api/v1/rentals:**
- **Input:**
  ```json
  {
    "listing_id": "uuid",
    "start_at": "2026-05-13T09:52:43Z",
    "end_at": "2026-05-16T09:52:43Z"
  }
  ```
- **Headers Required:**
  - `Idempotency-Key` (required)
  - `X-Requester-User-Id` (required)
- **Behavior:**
  - Validates listing exists and is published (422 VALIDATION_ERROR if not)
  - Validates start_at < end_at (422 VALIDATION_ERROR if not)
  - Checks date overlap with existing requested/accepted/active rentals (409 CONFLICT if overlap)
  - Creates rental with status='requested'
  - Returns 201 Created (new rental) or 200 OK (idempotency replay)
  - Idempotency enforced via idempotency_keys table

**POST /api/v1/rentals/{id}/accept:**
- **Headers Required:**
  - `X-Active-Tenant-Id` (required, must match provider_tenant_id)
- **Behavior:**
  - Validates rental exists (404 if not found)
  - Validates tenant ownership (403 FORBIDDEN_SCOPE if wrong tenant)
  - Validates status is 'requested' (422 INVALID_STATE if not)
  - Updates status to 'accepted' (atomic operation)
  - Returns 200 OK with updated rental

**GET /api/v1/rentals/{id}:**
- **Behavior:**
  - Returns rental details (404 if not found)

**Domain Invariants Enforced:**
- Listing must be published (VALIDATION_ERROR if not)
- start_at < end_at (VALIDATION_ERROR if not)
- No overlap for requested/accepted/active rentals (CONFLICT if overlap)
- Renter = userId (from X-Requester-User-Id header)
- Provider = listing.tenant_id
- Idempotency enforced via idempotency_keys table
- Tenant ownership enforced for accept (FORBIDDEN_SCOPE if wrong tenant)
- State transition validated (requested -> accepted only)

---

### C) Ops Contract Check

**Files Created:**
- `ops/rental_contract_check.ps1`

**Test Scenarios:**
1. Create rental -> PASS (201)
2. Idempotency replay -> SAME rental id
3. Overlap conflict -> 409 CONFLICT
4. Accept rental -> status=accepted
5. Negative scope (accept without X-Active-Tenant-Id) -> 400
6. GET rental -> PASS

**Files Modified:**
- `ops/pazar_spine_check.ps1` - Added Rental Contract Check as step 5 (WP-7)

---

## Verification Commands and Real Outputs

### 1. Run Migration

```powershell
docker compose exec pazar-app php artisan migrate
```

**Output:**
```
   INFO  Nothing to migrate.
```

(Note: Migration was already run in previous test runs)

### 2. Rental Contract Check

```powershell
.\ops\rental_contract_check.ps1
```

**Output:**
```
=== RENTAL CONTRACT CHECK (WP-7) ===
Timestamp: 2026-01-17 09:52:40


[0] Getting or creating published listing for testing...
PASS: Found existing published listing: 08b75991-f3ec-4e4b-abf2-2bda3af1c344                                                                        
  Title: Test Wedding Hall Listing

[1] Testing POST /api/v1/rentals (create rental)...
PASS: Rental created successfully
  Rental ID: 40c20958-1bf4-4b10-a846-c38093b3a972
  Status: requested
  Start: 2026-05-13T09:52:43Z
  End: 2026-05-16T09:52:43Z

[2] Testing idempotency replay (same Idempotency-Key)...
PASS: Idempotency replay returned same rental ID
  Rental ID: 40c20958-1bf4-4b10-a846-c38093b3a972

[3] Testing overlap conflict (overlapping rental period)...
PASS: Overlap conflict correctly returned 409 CONFLICT
  Status Code: 409

[4] Testing POST /api/v1/rentals/{id}/accept (accept rental)...
PASS: Rental accepted successfully
  Status: accepted

[5] Testing negative scope (accept without X-Active-Tenant-Id)...
PASS: Missing header correctly returned 400
  Status Code: 400

[6] Testing GET /api/v1/rentals/{id} (get rental)...
PASS: Get rental returned correct rental
  Rental ID: 40c20958-1bf4-4b10-a846-c38093b3a972
  Status: accepted

=== RENTAL CONTRACT CHECK: PASS ===
All rental contract checks passed.
```

**Exit Code:** 0 (PASS)

### 3. Pazar Spine Check (Full)

```powershell
.\ops\pazar_spine_check.ps1
```

**Output:**
```
=== PAZAR SPINE CHECK (WP-4.2) ===
Timestamp: 2026-01-17 09:52:48

Running all Marketplace spine contract checks in order:
  1. World Status Check (WP-1.2)
  2. Catalog Contract Check (WP-2)
  3. Listing Contract Check (WP-3)
  4. Reservation Contract Check (WP-4)
  5. Rental Contract Check (WP-7)

[RUN] World Status Check (WP-1.2)...
=== WORLD STATUS CHECK: PASS ===

[PASS] World Status Check (WP-1.2) - Duration: 5,79s

[RUN] Catalog Contract Check (WP-2)...
=== CATALOG CONTRACT CHECK: PASS ===

[PASS] Catalog Contract Check (WP-2) - Duration: 3,52s

[RUN] Listing Contract Check (WP-3)...
=== LISTING CONTRACT CHECK: PASS ===

[PASS] Listing Contract Check (WP-3) - Duration: 3,50s

[RUN] Reservation Contract Check (WP-4)...
=== RESERVATION CONTRACT CHECK: PASS ===

[PASS] Reservation Contract Check (WP-4) - Duration: 6,83s

[RUN] Rental Contract Check (WP-7)...
=== RENTAL CONTRACT CHECK (WP-7) ===
Timestamp: 2026-01-17 09:53:09

[0] Getting or creating published listing for testing...
PASS: Found existing published listing: 99b118d0-5c43-4858-abcb-1d184c63b951                                                                        
  Title: Test Wedding Hall Listing

[1] Testing POST /api/v1/rentals (create rental)...
PASS: Rental created successfully
  Rental ID: 7a21b6cb-b05c-434a-a2ed-48d623dd5b9b
  Status: requested
  Start: 2026-03-10T09:53:11Z
  End: 2026-03-13T09:53:11Z

[2] Testing idempotency replay (same Idempotency-Key)...
PASS: Idempotency replay returned same rental ID
  Rental ID: 7a21b6cb-b05c-434a-a2ed-48d623dd5b9b

[3] Testing overlap conflict (overlapping rental period)...
PASS: Overlap conflict correctly returned 409 CONFLICT
  Status Code: 409

[4] Testing POST /api/v1/rentals/{id}/accept (accept rental)...
PASS: Rental accepted successfully
  Status: accepted

[5] Testing negative scope (accept without X-Active-Tenant-Id)...
PASS: Missing header correctly returned 400
  Status Code: 400

[6] Testing GET /api/v1/rentals/{id} (get rental)...
PASS: Get rental returned correct rental
  Rental ID: 7a21b6cb-b05c-434a-a2ed-48d623dd5b9b
  Status: accepted

=== RENTAL CONTRACT CHECK: PASS ===
All rental contract checks passed.

[PASS] Rental Contract Check (WP-7) - Duration: 3,86s

=== PAZAR SPINE CHECK SUMMARY ===
  PASS: World Status Check (WP-1.2) (5,79s)
  PASS: Catalog Contract Check (WP-2) (3,52s)
  PASS: Listing Contract Check (WP-3) (3,50s)
  PASS: Reservation Contract Check (WP-4) (6,83s)
  PASS: Rental Contract Check (WP-7) (3,86s)

=== PAZAR SPINE CHECK: PASS ===
All Marketplace spine contract checks passed.
```

**Exit Code:** 0 (PASS)

---

## Summary Statistics

- **Migration:** 1 table created (`rentals`)
- **Endpoints:** 3 endpoints added (POST /rentals, POST /rentals/{id}/accept, GET /rentals/{id})
- **Contract Tests:** 6 test scenarios (all PASS)
- **Spine Check:** WP-7 integrated as step 5, all checks PASS

---

## Files Changed

**Created:**
- `work/pazar/database/migrations/2026_01_17_100006_create_rentals_table.php`
- `ops/rental_contract_check.ps1`
- `docs/PROOFS/wp7_rentals_spine_pass.md`

**Modified:**
- `work/pazar/routes/api.php` - Added rental endpoints (lines 858-1036)
- `ops/pazar_spine_check.ps1` - Added WP-7 check as step 5

---

## Acceptance Criteria Verification

✅ Rentals migration exists and applied  
✅ Rental endpoints return correct status codes and error codes  
✅ `rental_contract_check.ps1` PASS with exit 0  
✅ `pazar_spine_check.ps1` PASS with exit 0 including WP-7  
✅ Proof doc contains real outputs and timestamps  
✅ ASCII-only outputs  

**Status:** ALL ACCEPTANCE CRITERIA MET ✅

---

## Next Steps

Marketplace Transactions spine is now complete with:
- WP-4: Reservations (time-based bookings)
- WP-6: Orders (immediate sales)
- WP-7: Rentals (date-range rentals)

All endpoints follow consistent patterns:
- Idempotency enforced
- Overlap/conflict detection
- Tenant ownership validation
- State machine transitions
- Integration-ready for Messaging (WP-5)

---

**End of Proof Document**

