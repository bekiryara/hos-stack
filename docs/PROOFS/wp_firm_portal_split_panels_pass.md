# WP-NEXT: Firm Portal — Split panels (no behavior change) PASS

**Timestamp:** 2026-02-01  
**Summary:** FirmPortalPage.vue split into page orchestrator + 4 isolated panels (FirmListingsPanel, FirmOrdersPanel, FirmRentalsPanel, FirmReservationsPanel). Each panel owns loading/error/retry/empty/table; one panel FAIL does not block others. Routes, titles, table columns, buttons, API calls unchanged.

## Changes

### New Components
- `work/marketplace-web/src/components/portal/firm/FirmListingsPanel.vue`
  - Props: activeTenantId (required)
  - Own state: items, loading, error
  - api.getStoreListings(activeTenantId); table: ID, Başlık, Durum, Kategori ID, Actions (View, Message, Edit disabled); "İlan Ver" link

- `work/marketplace-web/src/components/portal/firm/FirmOrdersPanel.vue`
  - Props: activeTenantId (required)
  - Own state: items, loading, error, transitioning
  - api.getStoreOrders; Accept/Reject (canApprove/canReject: status === 'placed'); api.acceptStoreOrder, rejectStoreOrder; reload on action

- `work/marketplace-web/src/components/portal/firm/FirmRentalsPanel.vue`
  - Props: activeTenantId (required)
  - Own state: items, loading, error, transitioning
  - api.getStoreRentals; Accept/Reject (status === 'requested'); api.acceptStoreRental, rejectStoreRental; reload on action

- `work/marketplace-web/src/components/portal/firm/FirmReservationsPanel.vue`
  - Props: activeTenantId (required)
  - Own state: items, loading, error, transitioning
  - api.getStoreReservations; Accept/Reject (status === 'requested'); api.acceptStoreReservation, rejectStoreReservation; reload on action

### Modified
- `work/marketplace-web/src/pages/FirmPortalPage.vue`
  - Removed: listings/orders/rentals/reservations data, load* methods, formatDate, canApprove/canReject, accept/reject methods, all section markup
  - Kept: activeTenantId (getActiveTenantId), activeTenantName (loadMembershipsForName via api.getMyMemberships), no-tenant warning, firm info bar
  - Added: 4 panel components with :active-tenant-id="activeTenantId"
  - Line count: 577 → 120 (orchestrator only)

## No Behavior Change

- Same route, page title "Firma Paneli", same no-tenant message and /account link
- Same firm info bar (Aktif Firma ID, Firma Adı)
- Same API calls: getStoreListings, getStoreOrders, getStoreRentals, getStoreReservations; accept/reject store order/rental/reservation
- Same table columns, button labels (Accept, Reject), disable conditions (placed/requested + transitioning)
- Same empty texts: "No listings yet", "No orders yet", "No rentals yet", "No reservations yet"

## Panel Isolation

- Each panel has its own loading/error/data/retry; one panel failure does not affect others
- Transitioning map per panel for Accept/Reject; action failure shows error in that panel only

## Commands / Evidence

From repo root (e.g. D:\stack):

```text
.\ops\run_wp_next_local_gates.ps1   => WP-NEXT LOCAL GATES: PASS
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS (after commit; git clean required)
```

Commit: 27bd0dc

## Line Count

- FirmPortalPage.vue: 577 → 120 (at proof time).
