# WP-NEXT: Marketplace — api/client.js split (no behavior change) PASS

**Timestamp:** 2026-01-31  
**Summary:** `api/client.js` (567 satır) → request wrapper + 5 domain modülleri. Export yüzeyi ve davranış değişmedi.

## Changes

### New Files Created:
- `work/marketplace-web/src/api/request.js` (234 lines)
  - HTTP infrastructure: `apiRequest`, `hosApiRequest`, `messagingApiRequest`
  - Helpers: `PERSONA_MODES`, `buildPersonaHeaders`, `unwrapData`, `normalizeListResponse`, `generateIdempotencyKey`
  - Session integration: 401 handling, `clearSession`, `getBearerToken`

- `work/marketplace-web/src/api/domains/catalog.js` (24 lines)
  - Guest/public browsing: `getCategories`, `getFilterSchema`, `searchListings`, `getListing`

- `work/marketplace-web/src/api/domains/customer.js` (92 lines)
  - Personal scope: `getMyMemberships`, `getMe`, `getMyOrders`, `getMyRentals`, `getMyReservations`
  - Create operations: `createReservation`, `createRental`, `createOrder`

- `work/marketplace-web/src/api/domains/store.js` (136 lines)
  - Store scope: listings, orders, rentals, reservations (get/accept/reject/transition)
  - Write operations: `createListing`, `publishListing`

- `work/marketplace-web/src/api/domains/hos.js` (47 lines)
  - Tenant management: `hosCreateTenant`, `hosRegisterOwner`, `hosLogin`, `hosLogout`
  - Session wrappers: `getActiveTenantId`, `setActiveTenantId`

- `work/marketplace-web/src/api/domains/messaging.js` (40 lines)
  - Messaging operations: `messagingUpsertThread`, `messagingGetThreadByContext`, `messagingSendMessage`

### Modified Files:
- `work/marketplace-web/src/api/client.js` (567 → 117 lines, -78%)
  - Now acts as barrel export
  - Re-exports from `request.js` and domain modules
  - Keeps `login`/`register` with same logic
  - Composes `api` object from domain modules

## No Behavior Change Checklist

✅ **API_BASE_URL / MESSAGING_BASE_URL** — Same values, same env var logic  
✅ **401 handling** — `clearSession()` + `hos:session-expired` event unchanged  
✅ **Headers** — Authorization, X-Active-Tenant-Id, messaging-api-key logic identical  
✅ **Export surface** — All named exports present: `PERSONA_MODES`, `apiRequest`, `hosApiRequest`, `messagingApiRequest`, `unwrapData`, `normalizeListResponse`, `messagingUpsertThread`, `messagingGetThreadByContext`, `messagingSendMessage`, `login`, `register`, `api`  
✅ **api object** — 33 methods, same names, same signatures  
✅ **Idempotency** — `generateIdempotencyKey()` logic unchanged  
✅ **Session integration** — `getBearerToken`, `clearSession`, `setToken`, `saveSession` same

## Commands / Evidence

From repo root (D:\stack):

```text
.\ops\run_wp_next_local_gates.ps1   => WP-NEXT LOCAL GATES: PASS
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS (after commit)
```

## Before/After Line Count

```
client.js:  567 → 117 lines (-450, -78%)

New structure:
  request.js:    234 lines
  catalog.js:     24 lines
  customer.js:    92 lines
  store.js:      136 lines
  hos.js:         47 lines
  messaging.js:   40 lines
  -------------------------
  Total:         573 lines (net +6 for module boundaries)
```

## Engineering Rationale

- **Problem:** Single 567-line file → every feature change touches same file → merge conflicts + drift risk
- **Solution:** Domain boundaries → catalog/customer/store/hos/messaging isolated
- **Benefit:** New endpoints don't bloat client.js; easier to test/review/maintain per domain
- **Safety:** Zero behavior change; all existing imports work unchanged
