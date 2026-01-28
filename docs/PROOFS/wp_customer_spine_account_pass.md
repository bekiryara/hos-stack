# WP-NEXT: Customer Spine v1 (My Account + My Records) — PASS

Timestamp: 2026-01-28

## Summary
- Verified real customer flow: register/login → browse listings → create ONE record (order) → see it under `/account` → logout.
- Reused existing “my records” read endpoints via HOS (`/v1/me/orders|rentals|reservations`) backed by Pazar account portal list endpoints (no new backend endpoints).
- Frontend account page supports per-section loading/empty/error states (reservations/rentals/orders) without blocking other panels if one fails.

## Commands + outputs (PASS)

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
Timestamp: 2026-01-28 19:18:27

[A] Running world status check...
=== WORLD STATUS CHECK (WP-1.2) ===
Timestamp: 2026-01-28 19:18:27

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

### `ops/prototype_v1.ps1`
```text
=== PROTOTYPE / DEMO VERIFICATION (WP-68C) ===
Timestamp: 2026-01-28 19:19:11

[1] Running frontend smoke test...
PASS: Frontend smoke test

[2] Checking world status...
PASS: World status check

=== PROTOTYPE VERIFICATION PASSED ===
Prototype/demo environment is ready.
  Tip: Use -CheckDemoSeed to verify demo listings exist
```

## Manual customer flow proof (network log)
This PowerShell run registers a new user, logs in, creates an order for a published listing, and confirms it appears in `GET /v1/me/orders`:

```text
email=wp_customer_spine_20260128-191827@example.com
register: OK
me.user_id=8668c89c-ab58-44e3-aeea-f2576964ea98
listing_id=983bb1ed-86cb-4d95-812b-26674b8fd9aa
order.id=59639612-14a4-4b6f-bc1e-bc0e9d85ac99
my_orders.contains_new_order=True
```

## Manual UI proof (URLs)
1. Register/login: `http://localhost:3002/marketplace/register` → `http://localhost:3002/marketplace/login`.
2. Browse/search: `http://localhost:3002/marketplace/search/{categoryId}` → open a listing.
3. Create ONE record (order) from listing page.
4. Open account: `http://localhost:3002/marketplace/account` → the record appears under **My Orders**.
5. Logout: user session clears and returns to login/home.

## Files changed
- `work/marketplace-web/src/pages/AccountPortalPage.vue`
- `docs/PROOFS/wp_customer_spine_account_pass.md`
