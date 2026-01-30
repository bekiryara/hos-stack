# WP-NEXT: Customer Account — Read-only Orders/Rentals/Reservations PASS

**Timestamp:** 2026-01-30 (local gate run)  
**Scope:** Frontend + docs only. No backend changes.

## Summary

- **Account portal:** `work/marketplace-web/src/pages/AccountPortalPage.vue` (route `/account`).
- **Panels:** Orders, Rentals, Reservations — each with loading, error, retry (Yeniden dene), empty state.
- **Panel isolation:** Per-panel loading (ordersLoading, rentalsLoading, reservationsLoading); one panel fail does not block others; retry per panel.
- **API:** getMyOrders, getMyRentals, getMyReservations (api/client.js); null-safe extractItems.

## Gate commands (PASS evidence)

```
.\ops\run_wp_next_local_gates.ps1
=== WP-NEXT LOCAL GATES: PASS ===

.\ops\ops_run.ps1 -Profile Prototype
OVERALL STATUS: PASS
All checks passed.
```

## Files changed

1. `work/marketplace-web/src/pages/AccountPortalPage.vue` — per-panel loading, retry, empty-safe
2. `docs/PROOFS/wp_customer_account_readonly_pass.md`
3. `docs/WP_CLOSEOUTS.md` — new entry
