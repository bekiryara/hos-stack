# Frontend Integration Plan (WP-13)

**Date:** 2026-01-17  
**Status:** READ-ONLY FREEZE ACTIVE

## Purpose

This document defines the integration contract between Frontend (marketplace-web) and Backend (Pazar API) for READ operations. This is a **READ-ONLY FREEZE** - no new READ endpoints can be added without updating the snapshot files and passing the gate check.

## Rule: UI Only Uses READ Endpoints

**CRITICAL:** Frontend UI components **MUST ONLY** use READ endpoints. Write operations (POST, PUT, PATCH, DELETE) are **FORBIDDEN** in UI code. Write operations are only allowed via:
- Ops scripts (contract checks, test scripts)
- Direct API testing tools (Postman, curl, etc.)

## Endpoint Usage Matrix

### Account Portal Endpoints (Personal Scope)

| Endpoint | Method | Scope | Required Headers | Query Params | Response Format |
|----------|--------|-------|------------------|--------------|-----------------|
| `/api/v1/orders` | GET | personal | `Authorization: Bearer {token}` | `buyer_user_id={uuid}` | `{data: [...], meta: {...}}` |
| `/api/v1/rentals` | GET | personal | `Authorization: Bearer {token}` | `renter_user_id={uuid}` | `{data: [...], meta: {...}}` |
| `/api/v1/reservations` | GET | personal | `Authorization: Bearer {token}` | `requester_user_id={uuid}` | `{data: [...], meta: {...}}` |

**Header Rules:**
- `Authorization: Bearer {jwt-token}` is **REQUIRED**
- Token must contain `sub` or `user_id` claim matching the query parameter
- Missing token → `401 AUTH_REQUIRED`
- Token user_id mismatch → `403 FORBIDDEN_SCOPE`

### Account Portal Endpoints (Store/Tenant Scope)

| Endpoint | Method | Scope | Required Headers | Query Params | Response Format |
|----------|--------|-------|------------------|--------------|-----------------|
| `/api/v1/listings` | GET | tenant | `X-Active-Tenant-Id: {uuid}` | `tenant_id={uuid}` | `{data: [...], meta: {...}}` |
| `/api/v1/orders` | GET | tenant | `X-Active-Tenant-Id: {uuid}` | `seller_tenant_id={uuid}` | `{data: [...], meta: {...}}` |
| `/api/v1/rentals` | GET | tenant | `X-Active-Tenant-Id: {uuid}` | `provider_tenant_id={uuid}` | `{data: [...], meta: {...}}` |
| `/api/v1/reservations` | GET | tenant | `X-Active-Tenant-Id: {uuid}` | `provider_tenant_id={uuid}` | `{data: [...], meta: {...}}` |

**Header Rules:**
- `X-Active-Tenant-Id: {uuid}` is **REQUIRED**
- Header UUID must match query parameter UUID
- Missing header → `400 VALIDATION_ERROR`
- Invalid UUID format → `403 FORBIDDEN_SCOPE`
- UUID mismatch → `403 FORBIDDEN_SCOPE`

### Marketplace Endpoints (Public Scope)

| Endpoint | Method | Scope | Required Headers | Query Params | Response Format |
|----------|--------|-------|------------------|--------------|-----------------|
| `/api/v1/categories` | GET | public | None | None | `[{...}, ...]` (tree) |
| `/api/v1/categories/{id}/filter-schema` | GET | public | None | None | `{...}` (schema) |
| `/api/v1/listings` | GET | public | None | `category_id`, `status`, `page`, `per_page` | `[{...}, ...]` or `{data, meta}` |
| `/api/v1/listings/{id}` | GET | public | None | None | `{...}` (single object) |
| `/api/v1/search` | GET | public | None | `category_id` (required), `city`, `date_from`, `date_to`, `capacity_min`, `transaction_mode`, `page`, `per_page` | `{data: [...], meta: {...}}` |
| `/api/v1/listings/{id}/offers` | GET | public | None | None | `[{...}, ...]` |
| `/api/v1/offers/{id}` | GET | public | None | None | `{...}` (single object) |

**Header Rules:**
- No headers required (public endpoints)
- Optional: `Authorization` header may be present but not required

## Response Format Standards

### Paginated Responses (`{data, meta}`)

All Account Portal list endpoints and Search endpoint return:

```json
{
  "data": [
    {
      "id": "...",
      // ... entity fields
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "meta": {
    "total": 0,
    "page": 1,
    "per_page": 20,
    "total_pages": 0
  }
}
```

**Pagination Parameters:**
- `page` (integer, default: 1)
- `per_page` (integer, default: 20, max: 50)

### Error Responses

All errors return consistent format:

```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable error message"
}
```

**Error Codes:**
- `AUTH_REQUIRED` (401): Authorization token missing or invalid
- `FORBIDDEN_SCOPE` (403): Scope violation (user_id mismatch, UUID mismatch, invalid format)
- `VALIDATION_ERROR` (422): Missing required parameter or invalid value
- `INTERNAL_ERROR` (500): Server error

## Frontend Implementation Guidelines

### 1. API Client Setup

```javascript
// Example: API client with header management
const apiClient = {
  baseURL: 'http://localhost:8080',
  
  // Personal scope requests
  personalRequest(path, params, token) {
    return fetch(`${this.baseURL}${path}?${new URLSearchParams(params)}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
  },
  
  // Tenant scope requests
  tenantRequest(path, params, tenantId) {
    return fetch(`${this.baseURL}${path}?${new URLSearchParams(params)}`, {
      headers: {
        'X-Active-Tenant-Id': tenantId,
        'Content-Type': 'application/json'
      }
    });
  },
  
  // Public requests
  publicRequest(path, params = {}) {
    const queryString = Object.keys(params).length > 0 
      ? `?${new URLSearchParams(params)}` 
      : '';
    return fetch(`${this.baseURL}${path}${queryString}`, {
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
};
```

### 2. Error Handling

```javascript
// Example: Error handling
async function handleApiResponse(response) {
  if (!response.ok) {
    const error = await response.json();
    switch (response.status) {
      case 401:
        // Redirect to login or show auth error
        throw new Error('AUTH_REQUIRED');
      case 403:
        // Show scope violation error
        throw new Error('FORBIDDEN_SCOPE');
      case 422:
        // Show validation error
        throw new Error('VALIDATION_ERROR');
      default:
        throw new Error('INTERNAL_ERROR');
    }
  }
  return response.json();
}
```

### 3. Pagination Handling

```javascript
// Example: Pagination component
function usePagination(apiCall, params) {
  const [data, setData] = useState([]);
  const [meta, setMeta] = useState({ total: 0, page: 1, per_page: 20, total_pages: 0 });
  
  const loadPage = async (page) => {
    const response = await apiCall({ ...params, page, per_page: 20 });
    setData(response.data);
    setMeta(response.meta);
  };
  
  return { data, meta, loadPage };
}
```

## Testing

### Manual Testing

1. **Personal Scope:**
   ```bash
   curl -H "Authorization: Bearer {token}" \
     "http://localhost:8080/api/v1/orders?buyer_user_id={uuid}"
   ```

2. **Tenant Scope:**
   ```bash
   curl -H "X-Active-Tenant-Id: {uuid}" \
     "http://localhost:8080/api/v1/listings?tenant_id={uuid}"
   ```

3. **Public Scope:**
   ```bash
   curl "http://localhost:8080/api/v1/categories"
   ```

### Contract Checks

Run contract check scripts:
```powershell
.\ops\read_snapshot_check.ps1
.\ops\pazar_spine_check.ps1
.\ops\account_portal_list_contract_check.ps1
```

## Governance

### READ-ONLY FREEZE Rules

1. **No new READ endpoints** without:
   - Updating `contracts/api/*.read.snapshot.json`
   - Passing `ops/read_snapshot_check.ps1`
   - Passing CI gate `.github/workflows/gate-read-snapshot.yml`

2. **No breaking changes** to existing READ endpoints:
   - Response format changes require snapshot update
   - Query parameter changes require snapshot update
   - Header requirement changes require snapshot update

3. **Allowed changes:**
   - Error message improvements (non-breaking)
   - Response envelope consistency (already standardized)
   - Logging/observability improvements

### SPEC References

- SPEC §20.1: Account Portal Ownership Map
- SPEC §15: Marketplace Catalog Spine
- SPEC §18: Search & Discovery

## Notes

- All endpoints are READ-ONLY (GET methods only)
- Write operations (POST, PUT, PATCH, DELETE) are FORBIDDEN in UI
- Frontend must handle pagination for all list endpoints
- Frontend must handle error responses consistently
- Frontend must respect scope restrictions (personal vs tenant vs public)


