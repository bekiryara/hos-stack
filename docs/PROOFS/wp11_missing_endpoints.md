# WP-11 Missing Read Endpoints Report

**Date:** 2026-01-17  
**WP:** WP-11 Account Portal Read Aggregation  
**Status:** BACKEND ENDPOINTS MISSING

## Summary

Account Portal read aggregation requires list GET endpoints with user_id/tenant_id filters. Current backend only provides single-item GET endpoints (`/v1/reservations/{id}`, `/v1/rentals/{id}`) and no orders endpoint. List endpoints with filters are required for Account Portal functionality.

## Missing Endpoints

### Personal (User) View:
1. **GET /v1/orders?buyer_user_id={userId}** - List user's orders
   - Status: MISSING (no GET /v1/orders endpoint exists)
   - Required for: "My Orders" personal view

2. **GET /v1/rentals?renter_user_id={userId}** - List user's rentals
   - Status: MISSING (only GET /v1/rentals/{id} exists)
   - Required for: "My Rentals" personal view

3. **GET /v1/reservations?requester_user_id={userId}** - List user's reservations
   - Status: MISSING (only GET /v1/reservations/{id} exists)
   - Required for: "My Reservations" personal view

### Store (Provider) View:
4. **GET /v1/listings?tenant_id={tenantId}** - List store's listings
   - Status: PARTIAL (GET /v1/listings exists but no tenant_id filter)
   - Required for: "My Listings" store view

5. **GET /v1/orders?seller_tenant_id={tenantId}** - List orders as provider
   - Status: MISSING (no GET /v1/orders endpoint exists)
   - Required for: "My Orders" store view

6. **GET /v1/rentals?provider_tenant_id={tenantId}** - List rentals as provider
   - Status: MISSING (only GET /v1/rentals/{id} exists)
   - Required for: "My Rentals" store view

7. **GET /v1/reservations?provider_tenant_id={tenantId}** - List reservations as provider
   - Status: MISSING (only GET /v1/reservations/{id} exists)
   - Required for: "My Reservations" store view

## Current Endpoints (Available)

- GET /v1/listings (category_id, status filters - NO tenant_id filter)
- GET /v1/listings/{id}
- GET /v1/reservations/{id}
- GET /v1/rentals/{id}

## Impact

Account Portal read aggregation cannot be fully implemented without these list endpoints. Frontend UI structure can be created but will show "Endpoint not available" messages until backend endpoints are added.

## Recommendation

Add list GET endpoints to `work/pazar/routes/api.php` with appropriate filters:
- Query parameters: `buyer_user_id`, `seller_tenant_id`, `renter_user_id`, `provider_tenant_id`, `requester_user_id`, `tenant_id`
- Return arrays of items (same format as single-item endpoints)
- No write operations required (read-only)

## Next Steps

1. Backend: Implement missing list endpoints (separate WP)
2. Frontend: Create Account Portal UI structure with placeholder messages (current WP-11)


