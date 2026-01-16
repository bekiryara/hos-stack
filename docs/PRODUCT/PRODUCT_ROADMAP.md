# Product Roadmap

**Status:** Post-RC0 Planning

**Date:** 2026-01-10

## World Status

### Enabled Worlds (Active)

1. **commerce** - E-commerce (Satış/Alışveriş)
   - Status: enabled
   - Label (TR): Pazar (Satış/Alışveriş)
   - Example categories: Elektronik, Giyim, Ev & Yaşam, Anne & Bebek, Spor, Kitap & Hobi

2. **food** - Food delivery (Yemek)
   - Status: enabled
   - Label (TR): Yemek
   - Example categories: Pide & Lahmacun, Döner & Kebap, Pizza, Ev Yemekleri, Tatlı, Kahvaltı

3. **rentals** - Rental/Reservation (Kiralama)
   - Status: enabled
   - Label (TR): Kiralama (Rezervasyon)
   - Example categories: Tatil Konaklama, Araç Kiralama, Ekipman Kiralama, Etkinlik Mekânı, Depo/Ofis, Günlük Daire

### Disabled Worlds (Planned but Closed)

4. **services** - Services (Hizmetler)
   - Status: disabled
   - Label (TR): Hizmetler
   - Note: Planned but currently closed

5. **real_estate** - Real Estate (Emlak)
   - Status: disabled
   - Label (TR): Emlak
   - Note: Planned but currently closed

6. **vehicle** - Vehicles (Taşıtlar)
   - Status: disabled
   - Label (TR): Taşıtlar
   - Note: Planned but currently closed

**Canonical Source:** `work/pazar/WORLD_REGISTRY.md` and `work/pazar/config/worlds.php`

## MVP Plan (3 Phases)

### MVP-0: World Navigation + Tenant Context + Read-Only Home Pages

**Goal:** Enable users to navigate between worlds, see tenant context, and view read-only home pages (no DB write operations).

**Scope:**
- World navigation UI (world selector/dropdown)
- Tenant context display (current tenant info)
- Read-only home pages for all enabled worlds (commerce, food, rentals)
- No database write operations (read-only)
- Basic UI/UX for world switching

**Definition of Done:**
- [ ] World navigation component functional
- [ ] Tenant context visible in UI
- [ ] Home pages render for all enabled worlds (commerce, food, rentals)
- [ ] No database writes during MVP-0 (read-only operations only)
- [ ] `ops/verify.ps1` PASS (stack health, FS posture)
- [ ] `ops/conformance.ps1` PASS (world registry, disabled-world code policy)
- [ ] `ops/world_spine_check.ps1` PASS (world routes/controllers present)
- [ ] `ops/routes_snapshot.ps1` PASS (route contract stable)
- [ ] No UI 500 errors (storage/logs writable)
- [ ] Request tracing functional (request_id in logs)

**Ops Gates Required:**
- `ops/verify.ps1` - PASS (stack health, FS posture)
- `ops/conformance.ps1` - PASS (world registry, disabled-world code)
- `ops/world_spine_check.ps1` - PASS (world routes/controllers)
- `ops/routes_snapshot.ps1` - PASS or WARN (route contract)
- `ops/schema_snapshot.ps1` - PASS (schema contract, read-only = no changes)

**Non-Goals:**
- Listing creation/publishing
- User authentication (use existing H-OS OIDC)
- Payment processing
- Search functionality

### MVP-1: Listing Read Path (Index/Show)

**Goal:** Enable users to view listings (index/list view and detail view) for World 1: commerce.

**Scope:**
- Listing index/list view (commerce world)
- Listing detail/show view (commerce world)
- Basic listing display (title, description, price, images, etc.)
- Tenant-scoped listing display (only tenant's listings)
- World context maintained (world=commerce)

**Definition of Done:**
- [ ] Listing index page functional (commerce world)
- [ ] Listing detail page functional (commerce world)
- [ ] Listings are tenant-scoped (only current tenant's listings visible)
- [ ] World context maintained (world=commerce parameter)
- [ ] Basic listing fields displayed (title, description, price, images, etc.)
- [ ] `ops/verify.ps1` PASS (stack health, FS posture)
- [ ] `ops/conformance.ps1` PASS (world registry, disabled-world code)
- [ ] `ops/world_spine_check.ps1` PASS (commerce world routes/controllers)
- [ ] `ops/routes_snapshot.ps1` PASS (route contract updated with listing routes)
- [ ] `ops/schema_snapshot.ps1` PASS (schema contract, listing tables/columns)
- [ ] `ops/env_contract.ps1` PASS (required env vars)
- [ ] `ops/auth_security_check.ps1` PASS (listing routes protected)
- [ ] `ops/tenant_boundary_check.ps1` PASS (tenant isolation verified)
- [ ] No UI 500 errors
- [ ] Request tracing functional
- [ ] Basic metrics available (/metrics endpoint)

**Ops Gates Required:**
- `ops/verify.ps1` - PASS
- `ops/conformance.ps1` - PASS
- `ops/world_spine_check.ps1` - PASS
- `ops/routes_snapshot.ps1` - PASS (route contract updated)
- `ops/schema_snapshot.ps1` - PASS (schema contract updated with listing tables)
- `ops/env_contract.ps1` - PASS
- `ops/auth_security_check.ps1` - PASS
- `ops/tenant_boundary_check.ps1` - PASS or WARN

**Non-Goals:**
- Listing creation/publishing (MVP-2)
- Payment processing
- Advanced search
- Other worlds (food, rentals) - focus on commerce first

### MVP-2: Listing Write Path (Create/Publish) + Audit/Event + Ops Hooks

**Goal:** Enable users to create and publish listings for World 1: commerce, with audit trail, event logging, and ops hooks.

**Scope:**
- Listing creation form (commerce world)
- Listing publish/unpublish functionality
- Audit trail (who created/modified, when)
- Event logging (listing created, published, etc.)
- Ops hooks (metrics, alerts, request traces)
- Tenant-scoped listing creation (only tenant can create listings)

**Definition of Done:**
- [ ] Listing creation form functional (commerce world)
- [ ] Listing publish/unpublish functional (commerce world)
- [ ] Audit trail recorded (created_by, updated_by, created_at, updated_at)
- [ ] Event logging functional (listing.created, listing.published events)
- [ ] Ops hooks integrated (metrics, alerts, request traces)
- [ ] Tenant-scoped creation (only tenant can create listings)
- [ ] World context maintained (world=commerce parameter)
- [ ] `ops/verify.ps1` PASS (stack health, FS posture)
- [ ] `ops/conformance.ps1` PASS (world registry, disabled-world code)
- [ ] `ops/world_spine_check.ps1` PASS (commerce world routes/controllers)
- [ ] `ops/routes_snapshot.ps1` PASS (route contract updated with create/publish routes)
- [ ] `ops/schema_snapshot.ps1` PASS (schema contract updated with audit fields, events table)
- [ ] `ops/env_contract.ps1` PASS (required env vars for audit/events)
- [ ] `ops/auth_security_check.ps1` PASS (create/publish routes protected, authorized)
- [ ] `ops/tenant_boundary_check.ps1` PASS (tenant isolation verified for write operations)
- [ ] `ops/session_posture_check.ps1` PASS or WARN (session security for write operations)
- [ ] `ops/error_contract_check.ps1` PASS (error envelopes for validation errors)
- [ ] No UI 500 errors
- [ ] Request tracing functional (request_id in logs, events)
- [ ] Metrics available (/metrics endpoint, listing creation/publish metrics)
- [ ] Alerting baseline functional (critical errors alert)

**Ops Gates Required:**
- `ops/verify.ps1` - PASS
- `ops/conformance.ps1` - PASS
- `ops/world_spine_check.ps1` - PASS
- `ops/routes_snapshot.ps1` - PASS (route contract updated)
- `ops/schema_snapshot.ps1` - PASS (schema contract updated with audit/events)
- `ops/env_contract.ps1` - PASS
- `ops/auth_security_check.ps1` - PASS
- `ops/tenant_boundary_check.ps1` - PASS
- `ops/session_posture_check.ps1` - PASS or WARN
- `ops/error_contract_check.ps1` - PASS
- `ops/observability_status` - PASS or WARN (metrics, alerts functional)

**Non-Goals:**
- Payment processing
- Advanced search
- Other worlds (food, rentals) - focus on commerce first
- Complex business logic (simplified create/publish flow)

## Development Sequence

1. **RC0 PASS** (infrastructure, ops gates, UI 500 errors eliminated)
2. **MVP-0** (world navigation, tenant context, read-only home pages)
3. **MVP-1** (commerce listing read path: index/show)
4. **MVP-2** (commerce listing write path: create/publish + audit/event + ops hooks)

After MVP-2 for commerce:
- Expand to other worlds (food, rentals) - reuse commerce patterns
- Add payment processing (future phase)
- Add advanced search (future phase)

## World Development Priority

1. **World 1: commerce** (MVP-1 and MVP-2 focus)
   - First vertical slice
   - Establish patterns for other worlds
   - Validate ops gates and monitoring

2. **World 2: food** (post-commerce MVP-2)
   - Reuse commerce patterns
   - Food-specific adaptations

3. **World 3: rentals** (post-food)
   - Reuse commerce/food patterns
   - Rental-specific adaptations

4. **Worlds 4-6: services, real_estate, vehicle** (future)
   - Currently disabled
   - Enable when ready

## Related Documents

- `docs/PRODUCT/MVP_SCOPE.md` - MVP scope for World 1 (commerce) vertical slice
- `docs/RELEASES/RC0.md` - RC0 release definition and PASS criteria
- `work/pazar/WORLD_REGISTRY.md` - Canonical world registry
- `work/pazar/config/worlds.php` - World configuration
- `docs/RULES.md` - Development rules (scratch yok, proof zorunlu, etc.)






