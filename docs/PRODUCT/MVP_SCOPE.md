# MVP Scope: Marketplace (Commerce Vertical) Slice

**World:** marketplace (commerce vertical)

**Phase:** MVP-1 + MVP-2 (Vertical Slice)

**Date:** 2026-01-10

## Kullanıcı Senaryosu

**User Journey:**
1. Tenant içinde marketplace (commerce vertical) home sayfasına giriş
2. Marketplace listing listesi görüntüleme (commerce vertical, index/list view)
3. Marketplace listing detay sayfası görüntüleme (commerce vertical, detail/show view)
4. Marketplace listing oluşturma (commerce vertical, create form)
5. Marketplace listing yayınlama (commerce vertical, publish action)

**Tenant Context:**
- User is authenticated via H-OS OIDC (existing auth)
- User belongs to a tenant (tenant context from session/token)
- User can only see/create listings for their tenant
- World context: `world=marketplace`, `vertical=commerce`

## Scope (Included)

### MVP-1: Read Path

1. **Marketplace Home Page (Commerce Vertical)**
   - World navigation (world selector)
   - Vertical selector (commerce/food/rentals)
   - Tenant context display (current tenant info)
   - Links to listing index

2. **Listing Index/List View**
   - Route: `/marketplace/listings?vertical=commerce` or `/world/marketplace/listings?vertical=commerce`
   - Display: List of listings for current tenant (marketplace world, commerce vertical)
   - Fields: Title, description, price, images, status (published/draft)
   - Pagination: Basic (limit 20-50 items per page)
   - Sorting: By created_at (descending, newest first)

3. **Listing Detail/Show View**
   - Route: `/marketplace/listings/{id}?vertical=commerce` or `/world/marketplace/listings/{id}?vertical=commerce`
   - Display: Single listing detail
   - Fields: All listing fields (title, description, price, images, status, created_at, updated_at)
   - Tenant-scoped: Only tenant's listings accessible (403 if other tenant)

### MVP-2: Write Path + Audit/Event + Ops Hooks

4. **Listing Create Form**
   - Route: `/marketplace/listings/create?vertical=commerce` (GET: form, POST: create action)
   - Form fields: Title, description, price, images (basic upload), category (basic)
   - Validation: Required fields, price format, image size/type
   - Tenant-scoped: Created listing belongs to current tenant
   - World-scoped: Listing world=marketplace, vertical=commerce

5. **Listing Publish/Unpublish**
   - Route: `/marketplace/listings/{id}/publish?vertical=commerce` (POST)
   - Route: `/marketplace/listings/{id}/unpublish?vertical=commerce` (POST)
   - Status: published/draft toggle
   - Tenant-scoped: Only tenant can publish/unpublish their listings
   - Authorization: tenant.user or tenant.admin middleware

6. **Audit Trail**
   - Fields: created_by, updated_by, created_at, updated_at
   - Track: Who created/modified listing, when
   - Database: Audit fields in listings table

7. **Event Logging**
   - Events: `listing.created`, `listing.updated`, `listing.published`, `listing.unpublished`
   - Storage: Events table or outbox pattern (H-OS compatible)
   - Fields: event_type, listing_id, tenant_id, user_id, world, timestamp, payload (JSON)

8. **Ops Hooks**
   - Metrics: Listing creation count, publish count, error count (/metrics endpoint)
   - Alerts: Critical errors alert (via observability baseline)
   - Request traces: request_id in logs, events, metrics
   - Logging: Structured logging (request_id, tenant_id, user_id, world, listing_id)

## Non-Goals (Out of Scope)

### Payment Processing
- No payment integration
- No checkout flow
- No order management
- Price display only (no transactions)

### Advanced Search
- No full-text search
- No filtering by category (basic category only)
- No sorting options (default sorting only)
- No search autocomplete

### Complex Business Logic
- No listing approval workflow (direct publish)
- No listing expiration (manual unpublish only)
- No listing versioning (simple update/replace)
- No listing templates

### Other Verticals
- No food vertical features (focus on commerce vertical only)
- No rentals vertical features (focus on commerce vertical only)
- Vertical navigation present but only commerce functional

### Advanced UI/UX
- No drag-and-drop image upload (basic file input)
- No rich text editor (plain text/textarea)
- No image cropping/resizing (basic upload only)
- No advanced form validation (basic validation only)

## Ölçüm (Metrics)

### Basic Metrics (/metrics endpoint)

**Listing Metrics:**
- `pazar_listings_total` - Total listings created (counter)
- `pazar_listings_published` - Published listings (gauge)
- `pazar_listings_draft` - Draft listings (gauge)
- `pazar_listing_creation_duration_seconds` - Listing creation duration (histogram)
- `pazar_listing_publish_duration_seconds` - Listing publish duration (histogram)

**Error Metrics:**
- `pazar_listing_errors_total` - Listing errors (counter, labels: type=validation|permission|internal)

**Request Metrics:**
- `pazar_http_requests_total` - HTTP requests (counter, labels: method, route, status)
- `pazar_http_request_duration_seconds` - Request duration (histogram, labels: method, route)

### Alerting Baseline

**Critical Alerts:**
- Listing creation errors > 5/min
- Listing publish errors > 3/min
- UI 500 errors > 10/min
- Storage/logs not writable (FS posture check FAIL)

**Warning Alerts:**
- Listing creation duration p95 > 2s
- Listing publish duration p95 > 1s
- High error rate (> 5% of requests)

**Alert Channels:**
- Email (via Alertmanager)
- Slack (optional, via Alertmanager)
- Webhook (via alert-webhook service)

### Request Tracing

**Request ID Usage:**
- All requests have `X-Request-Id` header
- Request ID logged in Laravel log: `storage/logs/laravel.log`
- Request ID in event payload: `listing.created`, `listing.published` events
- Request ID in metrics labels: `request_id` label (optional)

**Trace Tools:**
- `ops/request_trace.ps1 -RequestId <id>` - Correlate Pazar and H-OS logs
- Request ID visible in UI error pages (for debugging)

## Risk/Bağımlılık Matrisi

### Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Storage/logs permission errors | HIGH | Fixed in RC0 (user: "0:0", entrypoint chown) |
| Tenant isolation failures | HIGH | `ops/tenant_boundary_check.ps1` PASS required |
| Database schema drift | MEDIUM | `ops/schema_snapshot.ps1` PASS required |
| Route contract drift | MEDIUM | `ops/routes_snapshot.ps1` PASS required |
| Auth security failures | HIGH | `ops/auth_security_check.ps1` PASS required |
| Event logging failures | MEDIUM | Event table/outbox pattern, graceful degradation |

### Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| H-OS OIDC auth | Ready | Existing integration |
| H-OS API (tenant context) | Ready | Existing integration |
| PostgreSQL (pazar-db) | Ready | RC0 verified |
| Storage/logs writable | Ready | RC0 fixed (user: "0:0") |
| Observability (metrics/alerts) | Optional | WARN acceptable for RC0 |
| Request tracing | Ready | `ops/request_trace.ps1` functional |

### Operational Dependencies

| Ops Gate | Status | Required for MVP-1 | Required for MVP-2 |
|----------|--------|-------------------|-------------------|
| `ops/verify.ps1` | PASS | Yes | Yes |
| `ops/conformance.ps1` | PASS | Yes | Yes |
| `ops/world_spine_check.ps1` | PASS | Yes | Yes |
| `ops/routes_snapshot.ps1` | PASS/WARN | Yes | Yes (PASS) |
| `ops/schema_snapshot.ps1` | PASS | Yes | Yes |
| `ops/env_contract.ps1` | PASS | No | Yes |
| `ops/auth_security_check.ps1` | PASS | Yes | Yes |
| `ops/tenant_boundary_check.ps1` | PASS/WARN | Yes | Yes (PASS) |
| `ops/session_posture_check.ps1` | PASS/WARN | No | Yes (PASS/WARN) |
| `ops/error_contract_check.ps1` | PASS | No | Yes |
| `ops/observability_status` | PASS/WARN | No | Yes (WARN acceptable) |

## Success Criteria

### MVP-1 Success (Read Path)

- [ ] Commerce home page loads (no 500 errors)
- [ ] Listing index page loads (no 500 errors)
- [ ] Listing detail page loads (no 500 errors)
- [ ] Tenant isolation verified (403 for other tenant's listings)
- [ ] World context maintained (world=marketplace, vertical=commerce)
- [ ] All ops gates PASS (verify, conformance, world_spine, routes_snapshot, schema_snapshot, auth_security, tenant_boundary)

### MVP-2 Success (Write Path + Audit/Event + Ops Hooks)

- [ ] Listing create form loads (no 500 errors)
- [ ] Listing creation functional (validation, tenant-scoped, world-scoped)
- [ ] Listing publish/unpublish functional (authorization, tenant-scoped)
- [ ] Audit trail recorded (created_by, updated_by, timestamps)
- [ ] Event logging functional (listing.created, listing.published events)
- [ ] Metrics available (/metrics endpoint, listing metrics)
- [ ] Alerting baseline functional (critical errors alert)
- [ ] Request tracing functional (request_id in logs, events, metrics)
- [ ] All ops gates PASS (all gates from MVP-1 plus env_contract, session_posture, error_contract, observability_status)

## Post-MVP: Next Steps

After MVP-2 for marketplace (commerce vertical):
1. Expand to food vertical (reuse commerce patterns)
2. Expand to rentals vertical (reuse commerce/food patterns)
3. Add payment processing (future phase)
4. Add advanced search (future phase)
5. Enable other worlds (messaging, social) when ready

## Related Documents

- `docs/PRODUCT/PRODUCT_ROADMAP.md` - Overall product roadmap (MVP-0, MVP-1, MVP-2)
- `docs/RELEASES/RC0.md` - RC0 release definition and PASS criteria
- `work/pazar/WORLD_REGISTRY.md` - Canonical world registry
- `work/pazar/config/worlds.php` - World configuration
- `docs/PROOFS/rc0_pazar_storage_permissions_pass.md` - Storage permissions fix proof
- `ops/request_trace.ps1` - Request tracing tool
- `docs/RULES.md` - Development rules (scratch yok, proof zorunlu, etc.)






