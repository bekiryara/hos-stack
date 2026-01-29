# Product API Spine

> **OpenAPI Specification**: The canonical API contract is defined in [openapi.yaml](openapi.yaml). This document provides additional context and implementation details.

**Status:** Read/Write-Path (v1) - All enabled worlds (commerce, food, rentals) GET endpoints return real data (tenant-scoped), write endpoints return 202 ACCEPTED (SPINE_READY, no business rules, no persistence)

**Date:** 2026-01-10 (Initial stub), 2026-01-10 (READ MVP), 2026-01-11 (Read-Path v1)

## Overview

Product API Spine establishes the canonical API contract for product endpoints across enabled worlds without implementing business logic. This contract-first approach ensures:

- Stable routes and error envelope contracts
- Zero architecture drift when business logic is added
- RC0 gates remain stable (security/tenant/session/env/ops_status)
- Consistent API surface across enabled worlds

## Enabled vs Disabled Worlds

**Enabled Worlds (spine implemented):**
- `commerce` - E-commerce (Satış/Alışveriş)
- `food` - Food delivery (Yemek)
- `rentals` - Rental/Reservation (Kiralama)

**Disabled Worlds (no code footprint):**
- `services` - Services (Hizmetler) - CLOSED
- `real_estate` - Real Estate (Emlak) - CLOSED
- `vehicle` - Vehicles (Taşıtlar) - CLOSED

**Constraint:** No code, routes, or controllers exist for disabled worlds. World governance gate must remain PASS.

## API Endpoints

### Canonical Product Core Spine

**Base Path:** `/api/v1/products`

**Status:** IMPLEMENTED (Read-Only v1) - Returns tenant-scoped, world-filtered products

**World Boundary:** Enforced via query parameter `?world=commerce` (required) or `X-World` header (fallback)

**All routes require:** `auth.any` + `resolve.tenant` + `tenant.user` middleware

#### List Products

- **Method:** `GET`
- **Path:** `/api/v1/products?world=commerce`
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Read-Only v1)

**Query Parameters:**
- `world` (required): World identifier (`commerce`, `food`, `rentals`)
- `limit` (optional, default 20, max 100): Number of items per page
- `after_id` (optional): Cursor-based pagination (product ID)

**Response (200 OK):**
```json
{
  "ok": true,
  "data": {
    "items": [
      {
        "id": 1,
        "world": "commerce",
        "type": "listing",
        "title": "Product Title",
        "status": "draft",
        "currency": "TRY",
        "price_amount": 10000,
        "payload_json": null,
        "created_at": "2026-01-11T12:00:00Z",
        "updated_at": "2026-01-11T12:00:00Z"
      }
    ],
    "cursor": {
      "next": 123
    },
    "meta": {
      "count": 1,
      "limit": 20
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**
- `422 VALIDATION_ERROR`: World parameter missing
- `400 WORLD_NOT_ENABLED`: World not in enabled list
- `500 TENANT_CONTEXT_MISSING`: Tenant context not resolved

#### Show Product

- **Method:** `GET`
- **Path:** `/api/v1/products/{id}?world=commerce`
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Read-Only v1)

**Query Parameters:**
- `world` (required): World identifier (`commerce`, `food`, `rentals`)

**Response (200 OK):**
```json
{
  "ok": true,
  "data": {
    "item": {
      "id": 1,
      "world": "commerce",
      "type": "listing",
      "title": "Product Title",
      "status": "draft",
      "currency": "TRY",
      "price_amount": 10000,
      "payload_json": null,
      "created_at": "2026-01-11T12:00:00Z",
      "updated_at": "2026-01-11T12:00:00Z"
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**
- `404 NOT_FOUND`: Product not found (cross-tenant or cross-world access prevented)
- `422 VALIDATION_ERROR`: World parameter missing
- `400 WORLD_NOT_ENABLED`: World not in enabled list

#### Create Product

- **Method:** `POST`
- **Path:** `/api/v1/products`
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Write-Seed v1) - Creates tenant-scoped, world-locked product

**Request Headers:**
- `X-World` (required, alternative to body.world): World identifier (`commerce`, `food`, `rentals`)

**Request Body Schema:**
```json
{
  "world": "commerce",  // Optional if X-World header provided
  "title": "string (required, min 3, max 255)",
  "type": "string (required, max 64)",
  "status": "string (optional, draft|published|archived, default draft)",
  "price_amount": "integer (optional, min 0)",
  "currency": "string (optional, max 8)",
  "payload_json": "object (optional, world-specific data)"
}
```

**Response (201 CREATED):**
```json
{
  "ok": true,
  "data": {
    "id": 1,
    "item": {
      "id": 1,
      "world": "commerce",
      "type": "listing",
      "title": "Product Title",
      "status": "draft",
      "currency": "TRY",
      "price_amount": 10000,
      "payload_json": null,
      "created_at": "2026-01-11T12:00:00Z",
      "updated_at": "2026-01-11T12:00:00Z"
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**
- `422 VALIDATION_ERROR`: Missing/invalid fields (title, type, etc.)
- `422 WORLD_CONTEXT_INVALID`: World not in enabled list
- `500 TENANT_CONTEXT_MISSING`: Tenant context not resolved
- `500 INTERNAL_ERROR`: Database error

**Tenant Boundary:** Product is created with `tenant_id` from resolved tenant context (NOT from request body). Client-provided `tenant_id` is ignored.

**World Boundary:** Product is created with `world` from `X-World` header or `body.world` parameter. World must be enabled (`commerce`, `food`, `rentals`).

#### Create Product

- **Method:** `POST`
- **Path:** `/api/v1/products`
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Write-Seed v1) - Creates tenant-scoped, world-locked product

**Request Headers:**
- `X-World` (optional, fallback to body.world): World identifier (`commerce`, `food`, `rentals`)

**Request Body:**
```json
{
  "world": "commerce",
  "type": "listing",
  "title": "Product Title",
  "status": "draft",
  "currency": "TRY",
  "price_amount": 10000,
  "payload_json": null
}
```

**Validation Rules:**
- `title` (required, string, min 3, max 255)
- `type` (required, string, max 64)
- `status` (optional, string, max 32, in: draft|published|archived, default: draft)
- `price_amount` (optional, integer, min 0)
- `currency` (optional, string, max 8)
- `payload_json` (optional, array)

**Response (201 CREATED):**
```json
{
  "ok": true,
  "data": {
    "id": 1,
    "item": {
      "id": 1,
      "world": "commerce",
      "type": "listing",
      "title": "Product Title",
      "status": "draft",
      "currency": "TRY",
      "price_amount": 10000,
      "payload_json": null,
      "created_at": "2026-01-11T12:00:00Z",
      "updated_at": "2026-01-11T12:00:00Z"
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**
- `422 VALIDATION_ERROR`: Missing/invalid fields (includes `errors` object with field-level details)
- `422 WORLD_CONTEXT_INVALID`: World not in enabled list
- `500 TENANT_CONTEXT_MISSING`: Tenant context not resolved
- `500 INTERNAL_ERROR`: Database/exception error

**Tenant Boundary:** Product is created with `tenant_id` from resolved tenant context (NOT from request body). `tenant_id` is guarded in model (cannot be mass-assigned).

**World Boundary:** World must be provided via `X-World` header or `body.world` parameter. Must be in enabled worlds list (`commerce`, `food`, `rentals`).

#### Disable Product (Soft Delete)

- **Method:** `PATCH`
- **Path:** `/api/v1/products/{id}/disable?world=commerce`
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (MVP Loop v1) - Soft disables product (sets status to 'archived')

**Query Parameters:**
- `world` (required): World identifier (`commerce`, `food`, `rentals`)

**Request Headers:**
- `X-World` (optional, fallback to query param): World identifier

**Response (200 OK):**
```json
{
  "ok": true,
  "data": {
    "item": {
      "id": 1,
      "world": "commerce",
      "type": "listing",
      "title": "Product Title",
      "status": "archived",
      "currency": "TRY",
      "price_amount": 10000,
      "payload_json": null,
      "created_at": "2026-01-11T12:00:00Z",
      "updated_at": "2026-01-11T12:00:00Z"
    }
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**
- `404 NOT_FOUND`: Product not found (cross-tenant or cross-world access prevented)
- `422 VALIDATION_ERROR`: World parameter missing
- `422 WORLD_CONTEXT_INVALID`: World not in enabled list
- `500 TENANT_CONTEXT_MISSING`: Tenant context not resolved
- `500 INTERNAL_ERROR`: Database/exception error

**Tenant Boundary:** Product must belong to the authenticated tenant (404 NOT_FOUND if not found within tenant scope, preventing cross-tenant leakage).

**World Boundary:** World must be provided via query param `?world=commerce` or `X-World` header. Must be in enabled worlds list (`commerce`, `food`, `rentals`).

**Idempotent:** If product is already archived, returns 200 OK with current state (no error).

**Lifecycle States:**
- `draft`: Product created but not published
- `published`: Product is active and visible
- `archived`: Product is disabled (soft delete)

**Note:** Hard delete (DELETE) endpoint is not implemented yet (501 NOT_IMPLEMENTED). Soft disable (PATCH /disable) is the canonical way to remove products.

---

### World-Specific Listings Spine

**Base Path:** `/api/v1/{world}/listings`

**Enabled worlds:** `commerce`, `food`, `rentals`

**All routes follow identical pattern per world:**

### List Listings

- **Method:** `GET`
- **Path:** `/api/v1/{world}/listings` (enabled worlds: commerce, food, rentals - IMPLEMENTED)
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Read-Path v1.1 - Filter + Cursor Pagination + Perf Guardrails) - Returns tenant-scoped listings with deterministic filters, signed cursor pagination, and stable ordering

**Query Parameters:**
- `q` (optional, max 80 chars): Full-text search on title and description fields (LIKE match)
- `status` (optional): Filter by status (`draft`, `published`)
- `min_price` (optional, integer): Minimum price filter (price_amount >= min_price)
- `max_price` (optional, integer): Maximum price filter (price_amount <= max_price)
- `updated_after` (optional, ISO8601 datetime): Filter by updated_at (updated_at >= updated_after)
- `limit` (optional, default 20, min 1, max 100): Number of items per page
- `cursor` (optional): Signed cursor for seek pagination (base64url-encoded JSON + HMAC signature: `payload.signature`)

**Ordering:**
- Default: `id DESC` (stable cursor pagination)
- Cursor pagination uses seek-based approach (no offset, deterministic, tamper-safe)
- Cursor format: base64url-encoded JSON payload `{last_id, tenant_id, world, ts}` + HMAC signature using APP_KEY
- Invalid cursor returns `400 BAD_REQUEST` with `INVALID_CURSOR` error code

**Response (200 OK):**
```json
{
  "ok": true,
  "items": [
    {
      "id": "uuid",
      "tenant_id": "uuid",
      "world": "commerce",
      "title": "string",
      "description": "string|null",
      "price_amount": "integer|null",
      "currency": "string|null",
      "status": "string",
      "created_at": "ISO8601",
      "updated_at": "ISO8601"
    }
  ],
  "page": {
    "limit": 20,
    "next_cursor": "base64url-payload.signature|null",
    "has_more": true
  },
  "request_id": "uuid"
}
```

**Example (with filters):**
```bash
# Search for listings with "pizza" in title
GET /api/v1/food/listings?q=pizza&limit=10

# Filter by status and date range
GET /api/v1/commerce/listings?status=published&from=2026-01-01&to=2026-01-31

# Cursor pagination (next page)
GET /api/v1/rentals/listings?cursor=eyJzb3J0IjoiY3JlYXRlZF9hdCIsImRpciI6ImRlc2MiLCJhZnRlciI6IjIwMjYtMDEtMTVUMTI6MDA6MDBaIzEyMzQ1In0=
```

**Errors:**
- 400 INVALID_CURSOR: `{ "ok": false, "error_code": "INVALID_CURSOR", "message": "Invalid cursor value", "request_id": "uuid" }`
- 401 UNAUTHORIZED: `{ "ok": false, "error_code": "UNAUTHORIZED", "message": "...", "request_id": "uuid" }`
- 403 FORBIDDEN: `{ "ok": false, "error_code": "FORBIDDEN", "message": "...", "request_id": "uuid" }`
- 404 NOT_FOUND: `{ "ok": false, "error_code": "NOT_FOUND", "message": "Listing not found.", "request_id": "uuid" }`
- 400 WORLD_CONTEXT_INVALID: `{ "ok": false, "error_code": "WORLD_CONTEXT_INVALID", "message": "...", "request_id": "uuid" }`
- 500 TENANT_CONTEXT_MISSING: `{ "ok": false, "error_code": "TENANT_CONTEXT_MISSING", "message": "...", "request_id": "uuid" }`

**Required Headers:**
- `X-Tenant-Id` (or session): Tenant ID for tenant-scoped queries
- `Authorization` (Bearer token or session): Authentication required

**World Defaults:** Routes have world defaults set (e.g., `/api/v1/commerce/*` defaults to `world=commerce`), so WorldResolver can set `ctx.world` correctly.

**Tenant Boundary:** Only listings for the authenticated tenant are returned (no cross-tenant leakage).

**World Boundary:** Only listings for the specified world are returned (world context enforced via route defaults).

**Note:** All enabled worlds (commerce, food, rentals) GET endpoints are IMPLEMENTED (Read-Path v3, tenant-scoped). All enabled worlds (commerce, food, rentals) write endpoints (POST/PATCH/DELETE) are IMPLEMENTED (Write-Path v1, full CRUD with persistence).

### Show Listing

- **Method:** `GET`
- **Path:** `/api/v1/{world}/listings/{id}` (enabled worlds: commerce, food, rentals - IMPLEMENTED)
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Read-Path v3 - Unified DTO) - Returns tenant-scoped listing with unified DTO format

**Response (200 OK):**
```json
{
  "ok": true,
  "item": {
    "id": "uuid",
    "tenant_id": "uuid",
    "world": "commerce",
    "title": "string",
    "description": "string|null",
    "price_amount": "integer|null",
    "currency": "string|null",
    "status": "string",
    "created_at": "ISO8601",
    "updated_at": "ISO8601"
  },
  "request_id": "uuid"
}
```

**Errors:**
- 404 NOT_FOUND: `{ "ok": false, "error_code": "NOT_FOUND", "message": "Listing not found.", "request_id": "uuid" }`
- 401 UNAUTHORIZED: `{ "ok": false, "error_code": "UNAUTHORIZED", "message": "...", "request_id": "uuid" }`
- 403 FORBIDDEN: `{ "ok": false, "error_code": "FORBIDDEN", "message": "...", "request_id": "uuid" }`
- 500 TENANT_CONTEXT_MISSING: `{ "ok": false, "error_code": "TENANT_CONTEXT_MISSING", "message": "...", "request_id": "uuid" }`

**Tenant Boundary:** Listing must belong to the authenticated tenant (404 NOT_FOUND if not found within tenant scope, preventing cross-tenant leakage).

**World Boundary:** Only listings for the specified world are returned (world context enforced: commerce, food, or rentals).

**Note:** All enabled worlds (commerce, food, rentals) have identical read-path implementation with tenant-scoped queries and world enforcement.

### Create Listing

- **Method:** `POST`
- **Path:** `/api/v1/{world}/listings` (enabled worlds: commerce, food, rentals - IMPLEMENTED)
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Write-Path v1) - Creates listing with persistence, default status 'draft'

**Request Body Schema:**
```json
{
  "title": "string (required, max 255)",
  "description": "string (optional)",
  "price_amount": "integer (optional, min 0)",
  "currency": "string (optional, size 3)",
  "status": "string (optional, in: draft|published, default: draft)"
}
```

**Response (201 CREATED):**
```json
{
  "ok": true,
  "item": {
    "id": "uuid",
    "tenant_id": "uuid",
    "world": "commerce",
    "title": "string",
    "description": "string|null",
    "price_amount": "integer|null",
    "currency": "string|null",
    "status": "draft",
    "created_at": "ISO8601",
    "updated_at": "ISO8601"
  },
  "request_id": "uuid"
}
```

**Errors:**
- 422 VALIDATION_ERROR: `{ "ok": false, "error_code": "VALIDATION_ERROR", "message": "The given data was invalid.", "errors": { "field": ["error message"] }, "request_id": "uuid" }`
- 401 UNAUTHORIZED: `{ "ok": false, "error_code": "UNAUTHORIZED", "message": "...", "request_id": "uuid" }`
- 403 FORBIDDEN: `{ "ok": false, "error_code": "FORBIDDEN", "message": "...", "request_id": "uuid" }`
- 500 TENANT_CONTEXT_MISSING: `{ "ok": false, "error_code": "TENANT_CONTEXT_MISSING", "message": "...", "request_id": "uuid" }`
- 400 WORLD_CONTEXT_INVALID: `{ "ok": false, "error_code": "WORLD_CONTEXT_INVALID", "message": "...", "request_id": "uuid" }`

**Tenant Boundary:** Tenant context is validated (NOT from request body). Listing is created with `tenant_id` from resolved tenant context. Cross-tenant write attempts are prevented by middleware (`tenant.user` returns 403 if tenant missing).

**World Boundary:** World context is enforced (from route defaults). World context must match enabled world or returns 400 WORLD_CONTEXT_INVALID. Listing is created with `world` from resolved context.

### Update Listing

- **Method:** `PATCH`
- **Path:** `/api/v1/{world}/listings/{id}` (enabled worlds: commerce, food, rentals - IMPLEMENTED)
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Write-Path v1) - Partial update with persistence

**Request Body Schema (partial update):**
```json
{
  "title": "string (optional, max 255)",
  "description": "string (optional, nullable)",
  "price_amount": "integer (optional, nullable, min 0)",
  "currency": "string (optional, nullable, size 3)",
  "status": "string (optional, in: draft|published)"
}
```

**Response (200 OK):**
```json
{
  "ok": true,
  "item": {
    "id": "uuid",
    "tenant_id": "uuid",
    "world": "commerce",
    "title": "string",
    "description": "string|null",
    "price_amount": "integer|null",
    "currency": "string|null",
    "status": "draft",
    "created_at": "ISO8601",
    "updated_at": "ISO8601"
  },
  "request_id": "uuid"
}
```

**Errors:**
- 422 VALIDATION_ERROR: `{ "ok": false, "error_code": "VALIDATION_ERROR", "message": "The given data was invalid.", "errors": { "field": ["error message"] }, "request_id": "uuid" }`
- 404 NOT_FOUND: `{ "ok": false, "error_code": "NOT_FOUND", "message": "Listing not found.", "request_id": "uuid" }` (listing not found in tenant scope, prevents cross-tenant leakage)
- 401 UNAUTHORIZED: `{ "ok": false, "error_code": "UNAUTHORIZED", "message": "...", "request_id": "uuid" }`
- 403 FORBIDDEN: `{ "ok": false, "error_code": "FORBIDDEN", "message": "...", "request_id": "uuid" }`
- 500 TENANT_CONTEXT_MISSING: `{ "ok": false, "error_code": "TENANT_CONTEXT_MISSING", "message": "...", "request_id": "uuid" }`
- 400 WORLD_CONTEXT_INVALID: `{ "ok": false, "error_code": "WORLD_CONTEXT_INVALID", "message": "...", "request_id": "uuid" }`

**Tenant Boundary:** Listing must exist in tenant scope (404 NOT_FOUND if not found, prevents cross-tenant leakage). Only provided fields are updated (partial update).

**World Boundary:** World context is enforced (from route defaults). World context must match enabled world or returns 400 WORLD_CONTEXT_INVALID.

### Delete Listing

- **Method:** `DELETE`
- **Path:** `/api/v1/{world}/listings/{id}` (enabled worlds: commerce, food, rentals - IMPLEMENTED)
- **Auth:** Required (`auth.any` + `resolve.tenant` + `tenant.user` middleware)
- **Status:** IMPLEMENTED (Write-Path v1) - Hard delete with persistence

**Response (204 NO CONTENT):**
```json
{
  "ok": true,
  "deleted": true,
  "id": "uuid",
  "request_id": "uuid"
}
```

**Errors:**
- 404 NOT_FOUND: `{ "ok": false, "error_code": "NOT_FOUND", "message": "Listing not found.", "request_id": "uuid" }` (listing not found in tenant scope, prevents cross-tenant leakage)
- 401 UNAUTHORIZED: `{ "ok": false, "error_code": "UNAUTHORIZED", "message": "...", "request_id": "uuid" }`
- 403 FORBIDDEN: `{ "ok": false, "error_code": "FORBIDDEN", "message": "...", "request_id": "uuid" }`
- 500 TENANT_CONTEXT_MISSING: `{ "ok": false, "error_code": "TENANT_CONTEXT_MISSING", "message": "...", "request_id": "uuid" }`
- 400 WORLD_CONTEXT_INVALID: `{ "ok": false, "error_code": "WORLD_CONTEXT_INVALID", "message": "...", "request_id": "uuid" }`

**Tenant Boundary:** Listing must exist in tenant scope (404 NOT_FOUND if not found, prevents cross-tenant leakage). Hard delete removes listing from database.

**World Boundary:** World context is enforced (from route defaults). World context must match enabled world or returns 400 WORLD_CONTEXT_INVALID.

**Note:** All enabled worlds (commerce, food, rentals) write endpoints (POST/PATCH/DELETE) are IMPLEMENTED (Write-Path v1, centralized via ListingWriteModel, full CRUD with persistence). DELETE returns 204 NO CONTENT (consistent across all worlds).

**Note:** All enabled worlds (commerce, food, rentals) write endpoints are SPINE_READY (202 ACCEPTED, no persistence). Persistence is intentionally deferred (no schema changes, no business rules).

## Authentication

**Commerce GET endpoints (IMPLEMENTED):**
- Authentication required via `auth.any` middleware (session or bearer token)
- Tenant context required via `resolve.tenant` middleware (X-Tenant-Id header or session)
- Tenant user validation via `tenant.user` middleware (403 if tenant missing)
- Unauthorized requests return 401 UNAUTHORIZED (standard envelope)
- Tenant missing returns 403 FORBIDDEN or 500 TENANT_CONTEXT_MISSING (standard envelope)
- Authorized requests return real data (tenant-scoped listings)

**Food/Rentals GET endpoints (IMPLEMENTED):**
- Authentication required via `auth.any` middleware (session or bearer token)
- Tenant context required via `resolve.tenant` middleware (X-Tenant-Id header or session)
- Tenant user validation via `tenant.user` middleware (403 if tenant missing)
- Unauthorized requests return 401 UNAUTHORIZED (standard envelope)
- Tenant missing returns 403 FORBIDDEN or 500 TENANT_CONTEXT_MISSING (standard envelope)
- Authorized requests return real data (tenant-scoped listings, world-enforced)

**Protected endpoints (POST/PATCH/DELETE - all enabled worlds):**
- Authentication required via `auth.any` middleware
- Tenant context required via `resolve.tenant` middleware
- Tenant user validation via `tenant.user` middleware
- Unauthorized requests return 401/403 (standard envelope)
- Authorized requests return 202 ACCEPTED (SPINE_READY, no persistence, no business rules)

## Error Envelope Contract

All error responses follow the standard error envelope format:

```json
{
  "ok": false,
  "error_code": "<ERROR_CODE>",
  "message": "<optional message>",
  "request_id": "<uuid>"
}
```

**Required fields:**
- `ok`: boolean (always `false` for errors)
- `error_code`: string (error code identifier)
- `request_id`: string (UUID, non-empty, must match `X-Request-Id` header)

**Headers:**
- `X-Request-Id`: string (UUID, matches body request_id)
- `Content-Type`: `application/json`

## Write Spine Behavior (SPINE_READY)

During the write spine phase, all write endpoints (POST/PATCH/DELETE) return:

- **Status Code:** 202 (Accepted)
- **Response Envelope:**
  ```json
  {
    "ok": true,
    "status": "PENDING",
    "request_id": "<uuid>",
    "operation": {
      "type": "CREATE_LISTING|UPDATE_LISTING|DELETE_LISTING",
      "world": "<world>"
    }
  }
  ```
- **Headers:** `X-Request-Id: <uuid>`, `Content-Type: application/json`
- **Validation:** Required fields (e.g., `title` for POST) are validated (422 VALIDATION_ERROR if missing)
- **Audit Logging:** All write operations are logged with request_id, tenant_id, world, operation type

**Example (POST /api/v1/commerce/listings):**
```json
{
  "ok": true,
  "status": "PENDING",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "operation": {
    "type": "CREATE_LISTING",
    "world": "commerce"
  }
}
```

**Note:** Persistence is intentionally deferred (no schema changes, no business rules). This establishes the write contract without implementing domain logic.

## Stub Phase Rationale

The stub phase establishes:

1. **Route contracts:** All routes are defined and protected (GET public, writes protected)
2. **Error envelope compliance:** Standard error format is enforced via shared helper
3. **Request ID propagation:** Request ID is always present in responses
4. **Security gates:** Write endpoints are protected by `auth.any` (security audit PASS)
5. **Zero drift:** When business logic is added, routes and contracts remain stable
6. **World governance:** Only enabled worlds have code footprint (governance gate PASS)

## Business Logic Status

**Commerce/Food/Rentals read-path is implemented in v2 (tenant-scoped queries, world-enforced).**
- All enabled worlds have identical read-path implementation
- GET `/api/v1/{world}/listings` returns tenant-scoped listings with pagination
- GET `/api/v1/{world}/listings/{id}` returns tenant-scoped listing detail
- Cross-tenant access returns 404 NOT_FOUND (no leakage)
- World mismatch returns 400 WORLD_CONTEXT_INVALID

**All enabled worlds write-path (POST/PATCH/DELETE) is SPINE_READY (Write-Spine v1, tenant-scoped, world-locked).**
- All enabled worlds (commerce, food, rentals) write endpoints return 202 ACCEPTED (no persistence, no business rules)
- Cross-tenant access returns 404 NOT_FOUND (no leakage, consistent with read behavior)
- Required field validation enforced (422 VALIDATION_ERROR if missing)
- Audit logging for all write operations (request_id, tenant_id, world, operation type)
- Persistence is intentionally deferred (no schema changes, no business rules)

**Database schema:**
- Uses existing `listings` table (no schema changes in this pack)
- Listing model with scopes: `forTenant()`, `forWorld()`, `published()`, `draft()`

**Service layer:**
- No complex service layer (direct model queries in controller)
- Business rules will be added in subsequent packs

## Shared Helper

**Location:** `app/Support/ApiSpine/NotImplemented.php`

**Usage:**
```php
use App\Support\ApiSpine\NotImplemented;

return NotImplemented::response($request, 'Custom message');
```

**Responsibility:**
- Returns 501 NOT_IMPLEMENTED with standard error envelope
- Ensures request_id is present (from request attributes or generated)
- Consistent response format across all stub endpoints

## Related Files

- `work/pazar/routes/api.php` - API route definitions
- `work/pazar/app/Http/Controllers/Api/Commerce/ListingController.php` - Commerce controller (GET/POST/PATCH/DELETE implemented)
- `work/pazar/app/Http/Middleware/AuthAny.php` - Auth middleware (session or bearer token)
- `work/pazar/app/Http/Middleware/ResolveTenant.php` - Tenant context resolver (header or session)
- `work/pazar/app/Http/Middleware/EnsureTenantUser.php` - Tenant user enforcer (403 if missing)
- `work/pazar/app/Http/Controllers/Api/Food/FoodListingController.php` - Food controller (GET/POST/PATCH/DELETE implemented)
- `work/pazar/app/Http/Controllers/Api/Rentals/RentalsListingController.php` - Rentals controller (GET/POST/PATCH/DELETE implemented)
- `work/pazar/app/Support/ApiSpine/NotImplemented.php` - Shared stub helper
- `docs/PROOFS/cleanup_pass.md` - Proof documentation
