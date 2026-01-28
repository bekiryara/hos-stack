# WP-NEXT — Catalog Spine Hardening (Categories + Listings = single engine, zero drift)

Timestamp: 2026-01-28

## Summary
- Backend: hardened `filter-schema` response to be deterministic (always emits schema keys; normalized select options).
- Frontend: single cached catalog module, canonical `/search/:categoryId?` with shareable query (`q/filters/sort/page`), schema-driven FiltersPanel maintained.
- Integrity: reused existing `ops/catalog_integrity_check.ps1` and extended with allowed renderer/type checks (no new ops scripts).
- No new pages/routes; single entrypoint remains `/search/:categoryId?`.

## Commands + outputs (PASS)

### `ops/catalog_contract_check.ps1`
```text
=== CATALOG CONTRACT CHECK (WP-2) ===
Timestamp: 2026-01-28 18:04:17

[1] Testing GET /api/v1/categories...
Response: [{"id":4,"parent_id":null,"slug":"vehicle","name":"Vehicle","vertical":"vehicle","status":"active","children":[{"id":10,"parent_id":4,"slug":"car","name":"Car","vertical":"vehicle","status":"active","children":""},{"id":14,"parent_id":4,"slug":"boat","name":"Boat","vertical":"vehicle","status":"active","children":""}]},{"id":5,"parent_id":null,"slug":"real-estate","name":"Real Estate","vertical":"real_estate","status":"active","children":[{"id":20,"parent_id":5,"slug":"for-sale","name":"For Sale","vertical":"real_estate","status":"active","children":""}]},{"id":1,"parent_id":null,"slug":"service","name":"Services","vertical":"service","status":"active","children":[{"id":2,"parent_id":1,"slug":"events","name":"Events","vertical":"service","status":"active","children":""},{"id":8,"parent_id":1,"slug":"food","name":"Food","vertical":"service","status":"active","children":""},{"id":12,"parent_id":1,"slug":"products","name":"Products","vertical":"product","status":"active","children":""},{"id":13,"parent_id":1,"slug":"accommodation","name":"Accommodation","vertical":"accommodation","status":"active","children":""}]}]
PASS: Categories endpoint returns non-empty tree
  Root categories: 3
  Found wedding-hall category (id: 3)
  PASS: All required root categories present (vehicle, real-estate, service)

[2] Testing GET /api/v1/categories/3/filter-schema...
Response: {"category_id":3,"category_slug":"wedding-hall","filters":[{"attribute_key":"capacity_max","value_type":"number","unit":"person","description":"Maximum capacity (number of people)","status":"active","sort_order":10,"ui_component":"number","required":true,"filter_mode":"range","rules":{"min":1,"max":1000}}]}
PASS: Filter schema endpoint returns valid response
  Category ID: 3
  Category Slug: wedding-hall
  Active filters: 1
  PASS: wedding-hall has capacity_max filter with required=true
  Filter attributes:
    - capacity_max (number, required: True)

=== CATALOG CONTRACT CHECK: PASS ===
```

### `ops/conformance.ps1`
```text
=== Architecture Conformance Gate ===

[A] World registry drift check...
[PASS] [A] A - World registry matches config (enabled: 2, disabled: 1)

[B] Forbidden artifacts check...
[PASS] [B] B - No forbidden artifacts (*.bak, *.tmp, *.orig, *.swp, *~)

[C] Disabled-world code policy check...
[PASS] [C] C - No code in disabled worlds (0 disabled)

[D] Canonical docs single-source check...
[PASS] [D] D - No duplicate CURRENT*.md or FOUNDING_SPEC*.md files (checked 1 unique files)

[E] Secrets safety check...
[PASS] [E] E - No secrets tracked in git

[F] Docs truth drift: DB engine alignment check...
[PASS] [F] F - Docs match docker-compose.yml: Pazar DB is PostgreSQL

[G] Forbidden endpoint check...
[PASS] [G] G - No /v1/search endpoint in Pazar routes

[INFO] === Summary ===
[PASS] CONFORMANCE PASSED - All architecture rules validated
```

### `ops/frontend_smoke.ps1`
```text
=== FRONTEND SMOKE TEST (WP-40) ===
Timestamp: 2026-01-28 18:04:24

[A] Running world status check...
=== WORLD STATUS CHECK (WP-1.2) ===
Timestamp: 2026-01-28 18:04:24

[1] Testing HOS GET /v1/world/status...
Response: {"world_key":"core","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
PASS: HOS /v1/world/status returns valid response
  world_key: core
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

[2] Testing HOS GET /v1/worlds...
Response: [{"world_key":"core","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"marketplace","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"messaging","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"social","availability":"DISABLED","phase":"GENESIS","version":"1.4.0"}]
PASS: HOS /v1/worlds returns valid array with all worlds
  - core: ONLINE (GENESIS, v1.4.0)
  - marketplace: ONLINE (GENESIS, v1.4.0)
  - messaging: ONLINE (GENESIS, v1.4.0)
  - social: DISABLED (GENESIS, v1.4.0)
  [DEBUG] Marketplace status from HOS: ONLINE
  [DEBUG] HOS successfully pinged Pazar (marketplace ONLINE)
  [DEBUG] Messaging status from HOS: ONLINE
  [DEBUG] HOS successfully pinged Messaging API (messaging ONLINE)

[3] Testing Pazar GET /api/world/status...
Response: {"world_key":"marketplace","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
PASS: Pazar /api/world/status returns valid response
  world_key: marketplace
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

=== WORLD STATUS CHECK: PASS ===
PASS: world_status_check.ps1 returned exit code 0

[B] Checking HOS Web (http://localhost:3002)...
PASS: HOS Web returned status code 200
PASS: HOS Web contains hos-home marker
PASS: HOS Web contains prototype-launcher (enter-demo button will be rendered client-side)
PASS: HOS Web contains root div (demo-control-panel will be rendered client-side)

[C] Checking marketplace demo page (http://localhost:3002/marketplace/demo)...
PASS: Marketplace demo page returned status code 200
PASS: Marketplace demo page contains Vue app mount (marketplace-demo marker will be rendered client-side)

[D] Checking marketplace search page (http://localhost:3002/marketplace/search/1)...
PASS: Marketplace search page returned status code 200
PASS: Marketplace search page contains Vue app mount (marketplace-search marker will be rendered client-side)
INFO: Marketplace search page filters state (client-side rendered, will be checked in browser)

[E] Checking messaging proxy endpoint...
  Messaging world is ONLINE
PASS: Messaging proxy returned status code 200
  Messaging API world_key: messaging

[F] Checking marketplace need-demo page (http://localhost:3002/marketplace/need-demo)...
PASS: Marketplace need-demo page returned status code 200
PASS: Marketplace need-demo page contains Vue app mount (need-demo marker will be rendered client-side)

[G] Checking marketplace-web build...
  Node.js version: v24.12.0
  npm version: 11.6.2
  Found package-lock.json, running: npm ci
PASS: npm ci completed successfully
  Running: npm run build
PASS: npm run build completed successfully

=== FRONTEND SMOKE TEST: PASS ===
  - Worlds check: PASS
  - HOS Web: PASS (hos-home, enter-demo, demo-control-panel markers)
  - Marketplace demo page: PASS (marketplace-demo marker)
  - Marketplace search page: PASS (marketplace-search marker, filters-empty handling)
  - Messaging proxy: PASS (/api/messaging/api/world/status)
  - Marketplace need-demo page: PASS (need-demo marker)
  - marketplace-web build: PASS
```

### `ops/catalog_integrity_check.ps1` (reused guard; PASS)
```text
=== CATALOG INTEGRITY CHECK (WP-74) ===
Timestamp: 2026-01-28 18:05:03

Using Docker exec for database queries (container: stack-pazar-db-1)
[A] Testing cycle check (no loops in category parent chain)...
PASS: No cycles detected in category parent chain

[B] Testing orphan check (parent_id points to existing category)...
PASS: No orphan categories found

[C] Testing duplicate slug check (slug must be unique)...
PASS: No duplicate slugs found

[D] Testing schema integrity (filter schema attributes must exist)...
PASS: All filter schema attributes exist in attributes table

[E] Testing root invariants (required root categories exist)...
PASS: All required root categories present (vehicle, real-estate, service)
  Found roots: real-estate, service, vehicle

[F] Testing filter-schema reachability (active schema categories must be active)...
PASS: All active filter-schema rows belong to active categories

[G] Testing allowed schema renderer types (number|range|boolean|string|select)...
PASS: All active filter-schema rows map to allowed renderers

=== CATALOG INTEGRITY CHECK: PASS ===
```

## Manual UI proof (URLs)
1. Open categories page: `http://localhost:3002/marketplace/` → tree loads.
2. Click a category → `http://localhost:3002/marketplace/search/{id}`.
3. Filter panel renders from schema (including select).
4. Change filters → URL query updates using canonical params: `?q=&filters=...&sort=&page=...`.
5. Refresh → filters persist + results load.
6. Navigate between categories → no repeated API storms (category + schema caches).

## Files changed
- `work/pazar/routes/api/02_catalog.php`
- `work/marketplace-web/src/lib/catalogSpine.js`
- `work/marketplace-web/src/pages/CategoriesPage.vue`
- `work/marketplace-web/src/pages/ListingsSearchPage.vue`
- `work/marketplace-web/src/pages/CreateListingPage.vue`
- `ops/catalog_integrity_check.ps1`
- `docs/PROOFS/wp_catalog_spine_hardening_pass.md`

