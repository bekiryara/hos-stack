# WP-NEXT: Transactions getById + Full Detail PASS

**Timestamp:** 2026-02-01

## Summary

- Pazar: GET /v1/orders/{id}, /v1/rentals/{id}, /v1/reservations/{id} (read-only, personal or store scope, UUID validation, { data } response).
- HOS: GET /me/orders/:id, /me/rentals/:id, /me/reservations/:id proxy to Pazar with buyer_user_id / renter_user_id / requester_user_id.
- Frontend: getMyOrderById, getMyRentalById, getMyReservationById; detail pages primary = getById fetch, fallback = query snapshot; limited banner only when limitedMode (fallback).

## Manual proof

- /account?tab=orders → click an ID → detail opens, **limited banner YOK**, server data rendered.
- Same for rentals and reservations tabs.

## Commands

- `.\ops\run_wp_next_local_gates.ps1` => PASS
- `.\ops\ops_run.ps1 -Profile Prototype` => OVERALL STATUS: PASS
