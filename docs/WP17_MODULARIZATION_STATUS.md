# WP-17 Routes Modularization - Status

## Pre-Flight Report

**Current api.php line count:** 2121 lines

**Duplicate routes check:** No duplicates found (manual verification based on grep results)

## Completed Modules

1. ✅ `work/pazar/routes/_helpers.php` - Helper functions extracted
2. ✅ `work/pazar/routes/api/_meta.php` - Ping and world/status endpoints
3. ✅ `work/pazar/routes/api/catalog.php` - Categories and filter-schema endpoints
4. ✅ `work/pazar/routes/api/search.php` - Search endpoint

## Remaining Modules to Create

5. ⏳ `work/pazar/routes/api/listings.php` - Listings CRUD, offers, GET /v1/listings, GET /v1/listings/{id}
   - Lines 193-872: POST /v1/listings, POST /v1/listings/{id}/publish, offers endpoints, GET /v1/listings
   - Lines 1032-1056: GET /v1/listings/{id}

6. ⏳ `work/pazar/routes/api/reservations.php` - Reservations create/accept/get
   - Lines 1058-1351: POST /v1/reservations, POST /v1/reservations/{id}/accept
   - Lines 1834-1857: GET /v1/reservations/{id}

7. ⏳ `work/pazar/routes/api/account_portal.php` - Account portal read endpoints
   - Lines 1353-1705: GET /v1/orders, GET /v1/rentals, GET /v1/reservations (list endpoints)

8. ⏳ `work/pazar/routes/api/orders.php` - Orders create
   - Lines 1707-1832: POST /v1/orders

9. ⏳ `work/pazar/routes/api/rentals.php` - Rentals create/accept/get
   - Lines 1859-2114: POST /v1/rentals, POST /v1/rentals/{id}/accept, GET /v1/rentals/{id}

## Next Steps

1. Create remaining module files by extracting exact content from api.php
2. Refactor api.php to require all modules in deterministic order
3. Create ops/route_duplicate_guard.ps1 script
4. Run verification checks
5. Create proof document

## Module Load Order (Deterministic)

1. _helpers.php
2. api/_meta.php
3. api/catalog.php
4. api/listings.php
5. api/search.php
6. api/reservations.php
7. api/orders.php
8. api/rentals.php
9. api/account_portal.php

