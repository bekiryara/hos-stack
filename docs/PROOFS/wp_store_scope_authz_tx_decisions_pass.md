# WP-NEXT: Store Scope AuthZ v2 — Transaction Decisions PASS

**Timestamp:** 2026-02-01

## Summary

- **accept/reject** uçları (orders, rentals, reservations) **tenant.membership_strict** middleware ile HOS membership zorunlu hale geldi.
- **tenant.scope** GENESIS davranışı değiştirilmedi (esnek kalıyor); sadece karar uçlarına strict gate eklendi.
- Yeni middleware: `TenantMembershipStrict` — tenant_id attr yoksa 400, Authorization yoksa 401, membership allowed=false ise 403, HOS hata/timeout ise 503.

## Manual checks

Base: Pazar `http://localhost:8080`, path prefix `/api/v1`. Replace `$TOKEN`, `$TENANT_ID`, `$ORDER_ID` as needed.

### A) Authorization YOK → 401

**Request:** POST accept endpoint; X-Active-Tenant-Id var, Authorization yok.

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/v1/orders/$ORDER_ID/accept" -Method POST -Headers @{"X-Active-Tenant-Id"="$TENANT_ID"; "Content-Type"="application/json"} -UseBasicParsing
```

**Expected:** Status **401**, body contains `"error":"UNAUTHORIZED"` and message "Authorization required".

**Example output:**
- **StatusCode:** 401
- **Content:** `{"error":"UNAUTHORIZED","message":"Authorization required"}` (or envelope with error_code/message)

### B) Geçerli Authorization + üyelik YOK → 403

**Request:** Valid Bearer token, but X-Active-Tenant-Id set to a tenant the user is **not** a member of (or invalid tenant).

**Expected:** Status **403**, body contains `"error":"FORBIDDEN"` and message "tenant membership required".

**Example output:**
- **StatusCode:** 403
- **Content:** `{"error":"FORBIDDEN","message":"tenant membership required"}`

### C) Geçerli Authorization + üyelik VAR → 200 (veya endpoint success response)

**Request:** Valid Bearer token + X-Active-Tenant-Id = tenant where user has membership; POST accept/reject on a pending record.

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/v1/orders/$ORDER_ID/accept" -Method POST -Headers @{"Authorization"="Bearer $TOKEN"; "X-Active-Tenant-Id"=$TENANT_ID; "Content-Type"="application/json"} -UseBasicParsing
```

**Expected:** Status **200**, body has order/rental/reservation fields (id, status, updated_at, …).

**Example output:**
- **StatusCode:** 200
- **Content:** `{"id":"...","seller_tenant_id":"...","listing_id":"...","status":"accepted","updated_at":"..."}` (or envelope per API contract)

## Gates

- `.\ops\run_wp_next_local_gates.ps1` => PASS
- `.\ops\ops_run.ps1 -Profile Prototype` => PASS
