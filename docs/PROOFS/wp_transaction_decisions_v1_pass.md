# WP-NEXT: Transaction Decisions v1 — PASS

**Timestamp:** 2026-01-31 (local gate run)  
**Scope:** Backend (accept/reject endpoints) + frontend (Firm Portal Accept/Reject wiring) + docs.

## Summary

- **Backend:** POST `/v1/orders/{id}/accept`, `/v1/orders/{id}/reject`; POST `/v1/rentals/{id}/reject` (accept existed); POST `/v1/reservations/{id}/reject` (accept existed). Store scope; 404 not_found, 403 FORBIDDEN_SCOPE, 422 INVALID_STATE / VALIDATION_ERROR; atomic update (WHERE id AND status).
- **Frontend:** Firm Portal Orders/Rentals/Reservations — Accept and Reject buttons per row; status `placed` (orders) or `requested` (rentals/reservations) only; panel-isolated reload and error.
- **Contract:** See `docs/CURRENT.md` — Transaction Decisions v1.

## Commands/Outputs

```
.\ops\run_wp_next_local_gates.ps1
=== WP-NEXT LOCAL GATES: PASS ===

.\ops\ops_run.ps1 -Profile Prototype
OVERALL STATUS: PASS
All checks passed.
```

## Scenario proof (rental reject)

```powershell
# With valid store token and X-Active-Tenant-Id matching rental provider_tenant_id:
# POST /api/v1/rentals/{RENTAL_ID}/reject
# Expected: 200 with { id, listing_id, ..., status: "rejected", updated_at }
# If status was not 'requested': 422 INVALID_STATE
```

## Files changed

1. `work/pazar/routes/api/04_reservations.php` — POST /v1/reservations/{id}/reject
2. `work/pazar/routes/api/06_rentals.php` — POST /v1/rentals/{id}/reject
3. `work/pazar/routes/api/05_orders.php` — POST /v1/orders/{id}/accept, /v1/orders/{id}/reject
4. `work/marketplace-web/src/api/client.js` — acceptStoreOrder, rejectStoreOrder, acceptStoreRental, rejectStoreRental, acceptStoreReservation, rejectStoreReservation
5. `work/marketplace-web/src/pages/FirmPortalPage.vue` — Accept/Reject buttons wired to accept/reject API; panel-isolated
6. `docs/CURRENT.md` — Transaction Decisions v1 section
7. `docs/PROOFS/wp_transaction_decisions_v1_pass.md`
8. `docs/WP_CLOSEOUTS.md` — entry
