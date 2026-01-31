# WP-NEXT: Store Scope AuthZ Hardening PASS

**Timestamp:** 2026-02-01

## Summary

- Store-scope read endpoints in `account_portal.php` now require **Authorization: Bearer** and **HOS membership check** (GET /tenants/:id/memberships/me). X-Active-Tenant-Id alone is insufficient.
- Helper `requireStoreScopeAuthz(Request, MembershipClient, tenantIdParam)` enforces: missing header → 400, invalid UUID → 422, header ≠ param → 403, no auth → 401, membership not allowed or HOS fail → 403/503.
- Applied to: GET /v1/orders (seller_tenant_id), GET /v1/rentals (provider_tenant_id), GET /v1/reservations (provider_tenant_id), and by-id store-scope paths. Personal scope unchanged.

## Manual negative/positive checks

Base: Pazar `http://localhost:8080`, path prefix `/api/v1`. Replace `$PAZAR` and `$TOKEN` as needed.

### (a) Store-scope without Authorization → 401

Request: store-scope list **without** `Authorization` header.

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/v1/orders?seller_tenant_id=55555555-5555-5555-5555-555555555555" -Headers @{"X-Active-Tenant-Id"="55555555-5555-5555-5555-555555555555"} -Method GET -UseBasicParsing -ErrorAction SilentlyContinue
```

**Expected:** Status 401, body contains `"error":"UNAUTHORIZED"` and message about Bearer token required for store scope.

**Example output:**
- StatusCode: 401
- Content: `{"error":"UNAUTHORIZED","message":"Authorization: Bearer token is required for store scope"}`

### (b) Authorization present but X-Active-Tenant-Id ≠ tenant param → 403

Request: valid Bearer token, but header tenant differs from query param.

```powershell
# Assume $TOKEN is a valid JWT; tenant in query is A, header is B (different UUID)
Invoke-WebRequest -Uri "http://localhost:8080/api/v1/orders?seller_tenant_id=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -Headers @{"Authorization"="Bearer $TOKEN"; "X-Active-Tenant-Id"="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"} -Method GET -UseBasicParsing -ErrorAction SilentlyContinue
```

**Expected:** Status 403, body contains `"error":"FORBIDDEN"` and message that X-Active-Tenant-Id must match tenant parameter.

**Example output:**
- StatusCode: 403
- Content: `{"error":"FORBIDDEN","message":"X-Active-Tenant-Id header must match tenant parameter"}`

### (c) Valid membership → 200

Request: valid Bearer token, X-Active-Tenant-Id matches seller_tenant_id (or provider_tenant_id for /v1/rentals or /v1/reservations), and user is member of that tenant in HOS.

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/v1/orders?seller_tenant_id=$TENANT_ID" -Headers @{"Authorization"="Bearer $TOKEN"; "X-Active-Tenant-Id"=$TENANT_ID} -Method GET -UseBasicParsing
```

**Expected:** Status 200, body has `"data"` (array) and `"meta"` (total, page, per_page, total_pages).

**Example output:**
- StatusCode: 200
- Content: `{"data":[...],"meta":{"total":0,"page":1,"per_page":20,"total_pages":0}}` (or with rows if any)

## Gates

- `.\ops\run_wp_next_local_gates.ps1` => PASS
- `.\ops\ops_run.ps1 -Profile Prototype` => PASS
