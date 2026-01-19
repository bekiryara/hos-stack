# Service Boundaries and Ownership (Source of Truth)

**Last Updated:** 2026-01-18  
**Purpose:** Document service boundaries, ownership, and API contracts to prevent cross-database access and maintain strict mode readiness.

---

## Service Ownership Table

| Domain | Owned By | Responsibilities | Database |
|--------|----------|------------------|----------|
| **Identity & Authentication** | H-OS/Core | User authentication (JWT), tenant management, membership enforcement | `hos-db` (PostgreSQL) |
| **World Directory** | H-OS/Core | World status management (`/v1/worlds`), service discovery | `hos-db` (PostgreSQL) |
| **Memberships** | H-OS/Core | User-tenant membership validation, role management | `hos-db` (PostgreSQL) |
| **Listings & Catalog** | Pazar | Product listings, categories, filter schemas | `pazar-db` (PostgreSQL) |
| **Transactions** | Pazar | Reservations, orders, rentals, offers | `pazar-db` (PostgreSQL) |
| **Idempotency** | Pazar | Idempotency key management for write operations | `pazar-db` (PostgreSQL) |
| **State Transitions** | Pazar | State machine validation (draft->published, requested->accepted, etc.) | `pazar-db` (PostgreSQL) |
| **Threads & Messages** | Messaging | Thread creation, message posting, participant management | `messaging-db` (PostgreSQL) |

---

## API Contract: Headers

### Required Headers by Scope

#### Store-Scope Endpoints (Write Operations)
- **X-Active-Tenant-Id** (required)
  - Format: Valid UUID (e.g., `951ba4eb-9062-40c4-9228-f8d2cfc2f426`)
  - Purpose: Identifies tenant context for store-scope operations
  - Validation: UUID format check (non-strict), HOS membership API (strict mode)
  - Error: `400 VALIDATION_ERROR` if missing, `403 FORBIDDEN_SCOPE` if invalid

#### Personal-Scope Endpoints (User Operations)
- **Authorization** (required)
  - Format: `Bearer <jwt-token>`
  - Purpose: JWT token for user authentication (via `auth.ctx` middleware)
  - Validation: JWT signature validation (H-OS JWT_SECRET)
  - Error: `401 AUTH_REQUIRED` if missing or invalid

#### Idempotent Write Operations
- **Idempotency-Key** (required for specific endpoints)
  - Format: UUID v4 (e.g., `550e8400-e29b-41d4-a716-446655440000`)
  - Purpose: Prevents duplicate requests (replay detection)
  - Scope: User or tenant-scoped (stored in `idempotency_keys` table)
  - Error: `400 VALIDATION_ERROR` if missing, `409 CONFLICT` on replay

---

## Error Semantics

### Standard Error Codes

| Status Code | Error Type | Description | Example |
|-------------|------------|-------------|---------|
| `400` | `VALIDATION_ERROR` | Missing required header or invalid format | Missing `X-Active-Tenant-Id` |
| `400` | `missing_header` | Required header missing | Missing `Idempotency-Key` |
| `401` | `AUTH_REQUIRED` | Authorization header missing or invalid JWT | No `Authorization` header |
| `403` | `FORBIDDEN_SCOPE` | Invalid tenant membership or scope violation | Invalid `X-Active-Tenant-Id` (strict mode) |
| `404` | `NOT_FOUND` | Resource not found | Listing ID not found |
| `409` | `CONFLICT` | Overlap conflict or idempotency replay | Date overlap for rental, duplicate `Idempotency-Key` |
| `422` | `VALIDATION_ERROR` | Business logic validation failed | Listing not published, invalid state transition |

---

## Strict Mode Story

### Non-Strict Mode (Default)

**Membership Validation:**
- Tenant UUID format validation only (regex check)
- No HOS API call required
- Backward compatible (GENESIS phase)

**Configuration:**
- `MARKETPLACE_MEMBERSHIP_STRICT=off` (default)

**Code Flow:**
```php
// MembershipClient::validateMembership()
// 1. Check strict mode flag (env('MARKETPLACE_MEMBERSHIP_STRICT') !== 'on')
// 2. Validate UUID format only
// 3. Return true if format is valid
```

### Strict Mode

**Membership Validation:**
- UUID format validation (first check)
- HOS API call: `GET /v1/tenants/{tenantId}/memberships/me`
- Enforces `allowed=true` from HOS response
- Blocks unauthorized tenant access

**Configuration:**
- `MARKETPLACE_MEMBERSHIP_STRICT=on`
- Requires `Authorization` header (JWT token)

**Code Flow:**
```php
// MembershipClient::validateMembership()
// 1. Check strict mode flag (env('MARKETPLACE_MEMBERSHIP_STRICT') === 'on')
// 2. Call checkMembershipViaHos($tenantId, $authToken)
// 3. Return result['allowed'] === true
```

**Error Handling:**
- HOS API timeout: Falls back to format validation (non-fatal)
- HOS API error: Logs warning, returns false (blocks request)

---

## Cross-Service Communication Rules

### Rule 1: No Cross-Database Access

**Enforcement:**
- Pazar code MUST NOT reference `messaging-db` connection strings
- Messaging service MUST NOT import Pazar DB migrations
- HOS code MUST NOT access `pazar-db` or `messaging-db`

**Verification:**
- Static code analysis (grep for DB connection strings)
- Migration file ownership (migrations only in owning service)
- Docker compose service isolation

### Rule 2: Context-Only Integration (Pazar ↔ Messaging)

**Pattern:**
- Pazar calls Messaging API (HTTP) with context links only
- No shared database tables
- No direct DB connections

**Example:**
```php
// Pazar creates reservation
$reservationId = createReservation(...);

// Pazar calls Messaging API (non-fatal)
$messagingClient = new MessagingClient();
$messagingClient->upsertThread('reservation', $reservationId, $participants);
```

**Context Link Fields:**
- `context_type`: Entity type (e.g., "reservation", "order", "rental")
- `context_id`: Entity ID (e.g., reservation UUID)
- `participants`: Array of user/tenant IDs (no DB foreign keys)

### Rule 3: Membership Validation via HOS API (Pazar ↔ HOS)

**Pattern:**
- Pazar calls HOS API for membership validation (strict mode)
- No direct access to `hos-db` from Pazar
- JWT token required for HOS API calls

**Example:**
```php
// Pazar validates membership (strict mode)
$membershipClient = new MembershipClient();
$isValid = $membershipClient->validateMembership($userId, $tenantId, $authToken);
```

**HOS API Endpoint:**
- `GET /v1/tenants/{tenantId}/memberships/me`
- Requires `Authorization: Bearer <jwt-token>`
- Returns: `{ allowed: bool, role: string, status: string }`

---

## Boundary Violation Examples (Anti-Patterns)

### ❌ Cross-Database Access
```php
// WRONG: Pazar accessing messaging-db
DB::connection('messaging')->table('threads')->where(...)->get();

// WRONG: Messaging importing Pazar migrations
// work/messaging/migrations/create_listings_table.php
```

### ❌ Direct DB Foreign Keys
```php
// WRONG: Foreign key to messaging thread
$reservation->thread_id  // Should use context_type + context_id instead
```

### ❌ Hardcoded Tenant Validation
```php
// WRONG: Bypassing MembershipClient
if ($tenantId === 'some-hardcoded-uuid') {
    return true;  // Should use MembershipClient::validateMembership()
}
```

---

## Integration Points

### Pazar → Messaging

**Client:** `App\Messaging\MessagingClient`
- Base URL: `MESSAGING_BASE_URL` (default: `http://messaging-api:3000`)
- API Key: `MESSAGING_API_KEY` (default: `dev-messaging-key`)
- Timeout: 1 second (non-fatal)
- Methods:
  - `upsertThread($contextType, $contextId, $participants)`
  - `postMessage($threadId, $senderType, $senderId, $body)`

**Usage:**
- Reservation creation → Thread upsert (context: "reservation", ID: reservation UUID)
- Order creation → Thread upsert (context: "order", ID: order UUID)
- Rental creation → Thread upsert (context: "rental", ID: rental UUID)

**Error Handling:**
- Network failures: Logged, non-fatal (reservation/order/rental still created)
- Timeout: 1 second, falls back gracefully

### Pazar → HOS

**Client:** `App\Core\MembershipClient`
- Base URL: `HOS_API_BASE_URL` (default: `http://hos-api:3000`)
- Timeout: 2 seconds (non-fatal in non-strict mode)
- Methods:
  - `validateMembership($userId, $tenantId, $authToken)`
  - `checkMembershipViaHos($tenantId, $authToken)`
  - `isValidTenantIdFormat($tenantId)`

**Usage:**
- Store-scope endpoints → Membership validation (strict mode)
- X-Active-Tenant-Id header → UUID format + membership check

**Error Handling:**
- HOS API timeout: Logged, falls back to format validation (non-strict)
- HOS API error: Logged, returns false (blocks request in strict mode)

### HOS → Pazar

**Usage:**
- World status ping: `GET /api/world/status`
- Service discovery: `/v1/worlds` includes marketplace status

**Error Handling:**
- Pazar unavailable: World status set to OFFLINE

### HOS → Messaging

**Usage:**
- World status ping: `GET /health` or `/api/v1/threads` (world status check)

**Error Handling:**
- Messaging unavailable: World status set to DISABLED

---

## Verification

### Boundary Contract Check

```powershell
.\ops\boundary_contract_check.ps1
```

**Validates:**
- No cross-database access (static checks)
- Required headers on store-scope endpoints
- Integration points follow context-only pattern

### Manual Review Checklist

- [ ] Pazar code does not reference `messaging-db` connection strings
- [ ] Messaging service does not import Pazar migrations
- [ ] HOS code does not access `pazar-db` or `messaging-db`
- [ ] All store-scope endpoints require `X-Active-Tenant-Id` header
- [ ] All personal-scope endpoints require `Authorization` header
- [ ] Idempotent write operations use `Idempotency-Key` header
- [ ] Membership validation uses `MembershipClient` (no hardcoded checks)
- [ ] Messaging integration uses `MessagingClient` (no direct DB access)

---

## References

- WP-5: Messaging context-only integration
- WP-8: Membership strict mode enforcement
- WP-24: Write-path lock (state transitions, idempotency)


