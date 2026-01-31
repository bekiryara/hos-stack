# WP-NEXT: Transactions detail pages (read-only) PASS

**Timestamp:** 2026-01-31  
**Summary:** Account list rows link to detail pages (/account/orders/:id, /account/rentals/:id, /account/reservations/:id); read-only; no getById API — limited view with query snapshot fallback.

## Changes

- **Router:** /account/orders/:id → OrderDetailPage, /account/rentals/:id → RentalDetailPage, /account/reservations/:id → ReservationDetailPage (requiresAuth).
- **OrderDetailPage.vue, RentalDetailPage.vue, ReservationDetailPage.vue:** id param; item from route.query snapshot (listing_id, status, created_at); limitedMode banner; SectionShell; key list (id, listing_id, status, created_at, updated_at); back link to /account?tab=orders|rentals|reservations.
- **MyOrdersPanel, MyRentalsPanel, MyReservationsPanel:** ID column → router-link to detail with query (listing_id, status, created_at).

## Steps (kanıt)

- /account?tab=orders → click row id → Order detail renders (Limited view banner).
- Same for rentals, reservations.

## Gates evidence

```text
.\ops\run_wp_next_local_gates.ps1   => === WP-NEXT LOCAL GATES: PASS ===
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS
```

**Commit:** `1147018` — WP-NEXT: Transactions detail pages (read-only) — PASS
