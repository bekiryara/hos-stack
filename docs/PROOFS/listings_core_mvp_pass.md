# Listings Core MVP PASS

**Date:** 2026-01-10

**Purpose:** Validate Listings Core MVP implementation - CRUD + publish + public search for enabled worlds, RC0-safe

## What Was Added

### 1. Database Migration

**Location:** `work/pazar/database/migrations/2026_01_10_000000_create_listings_table.php`

**Schema:**
- Table: `listings`
- Columns:
  - `id` (uuid, primary key)
  - `tenant_id` (uuid)
  - `world` (string 20: commerce|food|rentals)
  - `title` (string 120)
  - `description` (text, nullable)
  - `price_amount` (bigint, nullable)
  - `currency` (string 3, default TRY)
  - `status` (string 20, default draft: draft|published|archived)
  - `created_at`, `updated_at` (timestamps)
- Indexes:
  - `(tenant_id, world, status)`
  - `(tenant_id, status)`
  - `(world, status)`
  - `title`

### 2. Listing Model

**Location:** `work/pazar/app/Models/Listing.php`

**Functionality:**
- UUID primary key
- Mass assignable: tenant_id, world, title, description, price_amount, currency, status
- Scopes: `published()`, `draft()`, `forTenant($tenantId)`, `forWorld($world)`
- Status constants: STATUS_DRAFT, STATUS_PUBLISHED, STATUS_ARCHIVED

### 3. ListingController

**Location:** `work/pazar/app/Http/Controllers/ListingController.php`

**Endpoints:**

**Public (no auth):**
- `GET /api/{world}/listings/search?q=&status=published&page=1` - Public search (published only)
- `GET /api/{world}/listings/{id}` - Public show (published only)

**Panel (auth required: auth.any + tenant.user + resolve.tenant):**
- `GET /api/{world}/panel/listings` - List tenant's listings (any status)
- `POST /api/{world}/panel/listings` - Create listing
- `PATCH /api/{world}/panel/listings/{id}` - Update listing
- `POST /api/{world}/panel/listings/{id}/publish` - Publish listing (draft -> published)
- `POST /api/{world}/panel/listings/{id}/unpublish` - Unpublish listing (published -> draft)

**Validation:**
- `title`: required, string, min:3, max:120
- `description`: nullable, string, max:5000
- `price_amount`: nullable, integer, min:0
- `currency`: nullable, string, size:3, in:TRY,USD,EUR
- `status`: nullable, in:draft,published (for create)
- World mismatch: world in path must match ctx.world (400 WORLD_MISMATCH)

**Tenant Boundary:**
- All panel endpoints enforce tenant scope via `forTenant($tenantId)`
- Tenant ID obtained from request (request->tenant?->id, request->user()?->tenant_id, request->attributes->get('tenant_id'))

### 4. API Routes

**Location:** `work/pazar/routes/api.php`

**Routes:**
- Public routes: `/api/{world}/listings/search`, `/api/{world}/listings/{id}` (middleware: world.resolve)
- Panel routes: `/api/{world}/panel/listings/*` (middleware: world.resolve, auth.any, resolve.tenant, tenant.user)

**Bootstrap Integration:**
- `bootstrap/app.php`: Added `api: __DIR__.'/../routes/api.php'`
- `bootstrap/app.php`: Added `api/*` to `$isApiRequest` function

### 5. Feature Tests

**Location:** `work/pazar/tests/Feature/ListingCoreTest.php`

**Tests:**
1. `test_tenant_boundary_enforcement()` - Tenant A listings not accessible to tenant B
2. `test_publish_flow_visibility()` - Draft not visible in public search, published is visible
3. `test_world_mismatch_validation()` - World scope enforcement
4. `test_public_search_only_published()` - Public search returns only published listings
5. `test_panel_list_all_statuses()` - Panel returns all statuses for tenant

## Expected Behaviors

### Public Search

**Request:**
```bash
curl -i "http://localhost:8080/api/commerce/listings/search?q=laptop&status=published&page=1"
```

**Expected Response:**
- HTTP 200
- Header: `X-World: commerce`
- Header: `X-Request-Id: <uuid>`
- Body: JSON with listings array and pagination

```json
{
  "ok": true,
  "listings": [
    {
      "id": "...",
      "tenant_id": "...",
      "world": "commerce",
      "title": "...",
      "description": "...",
      "price_amount": 1000,
      "currency": "TRY",
      "status": "published",
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "pagination": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 20,
    "total": 1
  }
}
```

### Panel Create

**Request:**
```bash
curl -i -X POST "http://localhost:8080/api/commerce/panel/listings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "title": "Test Listing",
    "description": "Test description",
    "price_amount": 1000,
    "currency": "TRY",
    "status": "draft"
  }'
```

**Expected Response:**
- HTTP 201
- Header: `X-World: commerce`
- Header: `X-Request-Id: <uuid>`
- Body: JSON with created listing

```json
{
  "ok": true,
  "listing": {
    "id": "...",
    "tenant_id": "...",
    "world": "commerce",
    "title": "Test Listing",
    "description": "Test description",
    "price_amount": 1000,
    "currency": "TRY",
    "status": "draft",
    "created_at": "...",
    "updated_at": "..."
  }
}
```

### Panel Publish

**Request:**
```bash
curl -i -X POST "http://localhost:8080/api/commerce/panel/listings/{id}/publish" \
  -H "Authorization: Bearer <token>"
```

**Expected Response:**
- HTTP 200
- Header: `X-World: commerce`
- Header: `X-Request-Id: <uuid>`
- Body: JSON with updated listing (status: published)

### Tenant Boundary

**Request (tenant A creates, tenant B tries to fetch):**
```bash
# Tenant A creates listing
curl -X POST "http://localhost:8080/api/commerce/panel/listings" \
  -H "Authorization: Bearer <tenant-a-token>" \
  -d '{"title": "Tenant A Listing", "status": "draft"}'

# Tenant B tries to fetch (should not see tenant A's listings)
curl "http://localhost:8080/api/commerce/panel/listings" \
  -H "Authorization: Bearer <tenant-b-token>"
```

**Expected:**
- Tenant B's panel list does not include Tenant A's listings
- Tenant boundary enforced via `forTenant($tenantId)` scope

### World Mismatch

**Request:**
```bash
# Request to /api/food/panel/listings while ctx.world=commerce (should fail)
curl "http://localhost:8080/api/food/panel/listings" \
  -H "Authorization: Bearer <token>" \
  -H "X-World: commerce"
```

**Expected Response:**
- HTTP 400
- Error code: WORLD_MISMATCH
- Message: "World in path does not match context"

## How to Verify

### Step 1: Run Migration

```powershell
docker compose exec -T pazar-app php artisan migrate
```

**Expected:**
- Migration runs successfully
- `listings` table created with indexes

### Step 2: Verify Schema Snapshot Gate

```powershell
.\ops\schema_snapshot.ps1
```

**Expected:**
- Schema snapshot PASS
- `listings` table included in snapshot

### Step 3: Test Public Search

```powershell
curl.exe -i "http://localhost:8080/api/commerce/listings/search?status=published"
```

**Expected:**
- HTTP 200
- Header: `X-World: commerce`
- JSON response with listings array (empty if no published listings)

### Step 4: Test Panel Create

```powershell
curl.exe -i -X POST "http://localhost:8080/api/commerce/panel/listings" `
  -H "Content-Type: application/json" `
  -d '{\"title\":\"Test Listing\",\"status\":\"draft\"}'
```

**Expected:**
- HTTP 201 (if authenticated)
- HTTP 401 (if not authenticated)
- JSON response with created listing

### Step 5: Test Publish Flow

```powershell
# Create draft listing
curl.exe -X POST "http://localhost:8080/api/commerce/panel/listings" `
  -H "Content-Type: application/json" `
  -d '{\"title\":\"Draft Listing\",\"status\":\"draft\"}'

# Get listing ID from response, then publish
curl.exe -X POST "http://localhost:8080/api/commerce/panel/listings/{id}/publish"

# Verify published listing appears in public search
curl.exe "http://localhost:8080/api/commerce/listings/search?status=published"
```

**Expected:**
- Draft listing not visible in public search
- Published listing visible in public search

### Step 6: Run Feature Tests

```powershell
docker compose exec -T pazar-app php artisan test --filter ListingCoreTest
```

**Expected:**
- All tests PASS (5 tests)
- No failures

### Step 7: Verify Routes Snapshot Gate

```powershell
.\ops\routes_snapshot.ps1
```

**Expected:**
- Routes snapshot PASS
- New API routes included in snapshot

## RC0 Safety Verification

### No Regression in RC0 Gates

**Verify:**
```powershell
.\ops\verify.ps1
```

**Expected:**
- Step 4: Pazar FS posture check PASS (storage/logs writable)
- No permission denied errors
- Control Center does not 500

**Verify:**
```powershell
.\ops\conformance.ps1
```

**Expected:**
- World registry drift check PASS (no drift between WORLD_REGISTRY.md and config/worlds.php)

**Verify:**
```powershell
.\ops\schema_snapshot.ps1
```

**Expected:**
- Schema snapshot PASS (listings table included)

**Verify:**
```powershell
.\ops\routes_snapshot.ps1
```

**Expected:**
- Routes snapshot PASS (new API routes included)

## Related Files

- `work/pazar/database/migrations/2026_01_10_000000_create_listings_table.php` - Listings table migration
- `work/pazar/app/Models/Listing.php` - Listing model
- `work/pazar/app/Http/Controllers/ListingController.php` - Listing controller
- `work/pazar/routes/api.php` - API routes
- `work/pazar/tests/Feature/ListingCoreTest.php` - Feature tests
- `work/pazar/bootstrap/app.php` - API routes registration
- `work/pazar/config/worlds.php` - World configuration (canonical source)

## Conclusion

Listings Core MVP is implemented:
- Database migration (listings table + indexes)
- Model (Listing with scopes and status constants)
- Controller (public + panel endpoints with validation)
- API routes (public search + panel CRUD + publish/unpublish)
- Tenant boundary enforcement (via forTenant scope)
- World scope enforcement (via forWorld scope)
- Status-based visibility (draft not visible in public search, published is visible)
- Feature tests (tenant boundary, publish flow, world mismatch, visibility)
- RC0 gates remain green (no regression in verify, conformance, schema snapshot, routes snapshot)
- All changes are minimal, localized, and RC0-safe

Product development can proceed with Listings Core MVP as foundation.





