# WP-NEXT: Marketplace — Account Portal split panels PASS

**Timestamp:** 2026-01-31  
**Summary:** AccountPortalPage.vue split into layout orchestrator + SectionShell + 3 isolated panels (MyOrdersPanel, MyRentalsPanel, MyReservationsPanel). Panel UX standard: loading + error box + Retry + empty state + basic table. Panel isolation: one panel FAIL does not block others.

## Changes

### New Components
- `work/marketplace-web/src/components/portal/SectionShell.vue`
  - Props: title, status ("loading" | "error" | "ready"), errorMessage, empty, emptyText
  - Emit: retry
  - UI: loading text, error box + Retry button, empty state, default slot for content

- `work/marketplace-web/src/components/portal/MyOrdersPanel.vue`
  - Own state: loading, error, items
  - api.getMyOrders(userId), extractItems, formatDate
  - Table: id, listing_id, status, quantity, created_at

- `work/marketplace-web/src/components/portal/MyRentalsPanel.vue`
  - Own state: loading, error, items
  - api.getMyRentals(userId), extractItems, formatDate
  - Table: id, listing_id, start_at, end_at, status

- `work/marketplace-web/src/components/portal/MyReservationsPanel.vue`
  - Own state: loading, error, items
  - api.getMyReservations(userId), extractItems, formatDate
  - Table: id, listing_id, slot_start, slot_end, party_size, status

### Modified
- `work/marketplace-web/src/pages/AccountPortalPage.vue`
  - Removed: inline orders/rentals/reservations data, panelErrors, loadOrders/loadRentals/loadReservations, extractItems, formatDate, inline result-section markup
  - Kept: logged-out view, user summary card, firm status card, tenant selection, refresh button
  - Added: MyReservationsPanel, MyRentalsPanel, MyOrdersPanel (refs for refreshAll)
  - refreshAll() calls load() on each panel ref
  - Line count: 657 → 377 (-43%)

## No Behavior Change

- Same data shown (orders, rentals, reservations)
- Same API calls: api.getMyOrders, getMyRentals, getMyReservations (imzaları aynı)
- Same 401 handling: clearSession + redirect to /login?reason=expired
- Same empty/error/loading UX (standardized via SectionShell)

## Panel Isolation

- Each panel has its own loading/error/data; one panel failure does not affect others
- Retry is per-panel via SectionShell emit

## Commands / Evidence

From repo root (D:\stack):

```text
.\ops\run_wp_next_local_gates.ps1   => WP-NEXT LOCAL GATES: PASS
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS (after commit)
```

## Line Count

- AccountPortalPage.vue: 657 → 377 (-280, -43%)
- New: SectionShell.vue (~95), MyOrdersPanel.vue (~115), MyRentalsPanel.vue (~115), MyReservationsPanel.vue (~120)
