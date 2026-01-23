# Contract Check Scripts Index

**Date:** 2026-01-23  
**Purpose:** Complete list of all contract check PowerShell scripts

---

## Marketplace Spine (Pazar)

### 1. catalog_contract_check.ps1 (WP-2)
**SPEC:** §6.2 (Catalog Spine)  
**Tests:**
- GET /api/v1/categories (hierarchical tree)
- GET /api/v1/categories/{id}/filter-schema
- Validates root categories: vehicle, real-estate, service
- Validates wedding-hall capacity_max filter (required=true)

**Run:**
```powershell
.\ops\catalog_contract_check.ps1
```

---

### 2. listing_contract_check.ps1 (WP-3)
**SPEC:** §6.3 (Supply Spine)  
**Tests:**
- GET /api/v1/categories
- POST /api/v1/listings (create DRAFT)
- POST /api/v1/listings/{id}/publish
- GET /api/v1/listings/{id}
- GET /api/v1/listings?category_id={id}
- Negative test: Missing X-Active-Tenant-Id header

**Run:**
```powershell
.\ops\listing_contract_check.ps1
```

**Note:** Currently requires JWT token fix (uses hardcoded tenant-demo string)

---

### 3. reservation_contract_check.ps1 (WP-4)
**SPEC:** §6.3, §6.7, §17.4 (Reservation Spine)  
**Tests:**
- POST /api/v1/reservations (with idempotency)
- POST /api/v1/reservations/{id}/accept
- GET /api/v1/reservations/{id}
- Capacity constraint validation
- Slot overlap detection (409 CONFLICT)

**Run:**
```powershell
.\ops\reservation_contract_check.ps1
```

---

### 4. order_contract_check.ps1 (WP-6)
**SPEC:** §6.3 (Order Spine)  
**Tests:**
- POST /api/v1/orders
- GET /api/v1/orders/{id}
- Order status transitions

**Run:**
```powershell
.\ops\order_contract_check.ps1
```

---

### 5. rental_contract_check.ps1 (WP-7)
**SPEC:** §6.3 (Rental Spine)  
**Tests:**
- POST /api/v1/rentals
- GET /api/v1/rentals/{id}
- POST /api/v1/rentals/{id}/accept

**Run:**
```powershell
.\ops\rental_contract_check.ps1
```

---

### 6. offer_contract_check.ps1 (WP-9)
**SPEC:** §6.3 (Offer Spine)  
**Tests:**
- POST /api/v1/offers
- GET /api/v1/offers/{id}
- Offer status transitions

**Run:**
```powershell
.\ops\offer_contract_check.ps1
```

---

### 7. pazar_spine_check.ps1 (WP-4.2)
**Purpose:** Runs all Marketplace spine contract checks in order (fail-fast)  
**Checks:**
1. World Status Check (WP-1.2)
2. Catalog Contract Check (WP-2)
3. Listing Contract Check (WP-3)
4. Reservation Contract Check (WP-4)

**Run:**
```powershell
.\ops\pazar_spine_check.ps1
```

**Note:** Stops on first failure (fail-fast behavior)

---

## Messaging

### 8. messaging_contract_check.ps1 (WP-5)
**SPEC:** §6.3 (Messaging Read)  
**Tests:**
- GET /api/v1/threads/{id}
- GET /api/v1/threads/{id}/messages
- Thread ownership validation

**Run:**
```powershell
.\ops\messaging_contract_check.ps1
```

---

### 9. messaging_write_contract_check.ps1 (WP-16)
**SPEC:** §6.3 (Messaging Write)  
**Tests:**
- POST /api/v1/threads/upsert (idempotent)
- POST /api/v1/threads/{id}/messages
- Authorization validation
- Thread ownership enforcement

**Run:**
```powershell
.\ops\messaging_write_contract_check.ps1
```

---

## Auth & Persona

### 10. core_persona_contract_check.ps1 (WP-8)
**SPEC:** §5.1-§5.3 (Persona & Scope Lock)  
**Tests:**
- GUEST persona (no headers)
- PERSONAL persona (Authorization header)
- STORE persona (X-Active-Tenant-Id header)
- Error codes: AUTH_REQUIRED, missing_header, FORBIDDEN_SCOPE

**Run:**
```powershell
.\ops\core_persona_contract_check.ps1
```

---

### 11. tenant_scope_contract_check.ps1 (WP-8)
**SPEC:** §5.2 (Tenant Scope)  
**Tests:**
- X-Active-Tenant-Id header validation
- Tenant ownership enforcement
- Invalid tenant_id handling

**Run:**
```powershell
.\ops\tenant_scope_contract_check.ps1
```

---

### 12. persona_scope_check.ps1
**Purpose:** Combined persona + scope validation  
**Tests:**
- Persona definitions (GUEST, PERSONAL, STORE)
- Scope validation
- Header requirements

**Run:**
```powershell
.\ops\persona_scope_check.ps1
```

---

## Account Portal

### 13. account_portal_contract_check.ps1 (WP-9)
**SPEC:** §6.3 (Account Portal)  
**Tests:**
- GET /api/v1/account (user info)
- Personal scope endpoints
- Store scope endpoints

**Run:**
```powershell
.\ops\account_portal_contract_check.ps1
```

---

### 14. account_portal_list_contract_check.ps1 (WP-12.1)
**SPEC:** §6.3 (Account Portal Lists)  
**Tests:**
- GET /api/v1/orders?buyer_user_id={id}
- GET /api/v1/rentals?renter_user_id={id}
- GET /api/v1/reservations?requester_user_id={id}
- Store-scoped lists (tenant_id filters)

**Run:**
```powershell
.\ops\account_portal_list_contract_check.ps1
```

---

## Search

### 15. search_contract_check.ps1 (WP-8)
**SPEC:** §6.3 (Search Functionality)  
**Tests:**
- GET /api/v1/listings?category_id={id}
- GET /api/v1/listings?attrs[capacity_max_min]={value}
- Filter attribute validation
- Search result format

**Run:**
```powershell
.\ops\search_contract_check.ps1
```

---

## Boundary & Other

### 16. boundary_contract_check.ps1
**Purpose:** Boundary contract validation  
**Tests:**
- Request/response boundaries
- Error envelope format
- Request ID tracking

**Run:**
```powershell
.\ops\boundary_contract_check.ps1
```

---

### 17. product_contract_check.ps1
**Purpose:** Product contract validation  
**Tests:**
- Product API endpoints
- Product data structure

**Run:**
```powershell
.\ops\product_contract_check.ps1
```

---

### 18. openapi_contract.ps1
**Purpose:** OpenAPI contract validation  
**Tests:**
- OpenAPI schema compliance
- API documentation accuracy

**Run:**
```powershell
.\ops\openapi_contract.ps1
```

---

### 19. env_contract.ps1
**Purpose:** Environment contract validation  
**Tests:**
- Required environment variables
- Environment configuration
- Secret management

**Run:**
```powershell
.\ops\env_contract.ps1
```

---

## Quick Reference

### Run All Marketplace Spine Checks
```powershell
.\ops\pazar_spine_check.ps1
```

### Run Individual Checks
```powershell
# Catalog
.\ops\catalog_contract_check.ps1

# Listing
.\ops\listing_contract_check.ps1

# Reservation
.\ops\reservation_contract_check.ps1
```

### Run All Contract Checks (Manual)
```powershell
.\ops\catalog_contract_check.ps1
.\ops\listing_contract_check.ps1
.\ops\reservation_contract_check.ps1
.\ops\order_contract_check.ps1
.\ops\rental_contract_check.ps1
.\ops\messaging_contract_check.ps1
.\ops\core_persona_contract_check.ps1
```

---

## Notes

- All contract checks require services to be running (`docker compose up -d`)
- Pazar API must be accessible at `http://localhost:8080`
- H-OS API must be accessible at `http://localhost:3000`
- Most checks create test data (idempotent, can be cleaned up)
- Exit codes: 0 (PASS) or 1 (FAIL)

---

**Last Updated:** 2026-01-23  
**Total Contract Check Scripts:** 19



