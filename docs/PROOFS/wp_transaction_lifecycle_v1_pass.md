# WP-NEXT: Transaction Lifecycle v1 — Status Transitions PASS

**Timestamp:** 2026-01-30 (local gate run)  
**Scope:** Backend (transition endpoints) + minimal frontend (Approve/Reject) + docs.

## Summary

- **Backend:** POST `/v1/orders/{id}/transition`, `/v1/rentals/{id}/transition`, `/v1/reservations/{id}/transition` with body `{ "action": "approve|reject|cancel|complete" }`. Store scope (X-Active-Tenant-Id); allowlist: created→approved→completed, created→rejected, created→cancelled. Illegal transition → 422 `{ "error": "INVALID_TRANSITION", "allowed": [...] }`; success → 200 `{ "id", "status", "updated_at" }`. Audit log per transition.
- **Frontend:** Firm Portal Orders/Rentals/Reservations tables: per-row "Onayla" (Approve) and "Reddet" (Reject) buttons; disabled when status not allowlist-eligible; on success list refreshes. Customer account lists show status (read-only; refresh on load).
- **Backward compat:** Existing accept endpoints and list/read endpoints unchanged.

## Added/changed endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/orders/{id}/transition` | Body: `{ "action": "approve" \| "reject" \| "cancel" \| "complete" }`. Store scope. |
| POST | `/v1/rentals/{id}/transition` | Same contract. |
| POST | `/v1/reservations/{id}/transition` | Same contract. |

## Ops curl proof (deterministic)

```bash
# 1) Create order/rental/reservation (existing endpoints). Then with valid store token + X-Active-Tenant-Id:

# Order transition (approve from placed)
curl -s -X POST "http://localhost:8080/api/v1/orders/{ORDER_ID}/transition" \
  -H "Content-Type: application/json" \
  -H "X-Active-Tenant-Id: {SELLER_TENANT_ID}" \
  -H "Authorization: Bearer {TOKEN}" \
  -d '{"action":"approve"}'
# Expected: 200 { "id", "status": "approved", "updated_at" }

# Illegal transition (e.g. approve again from approved)
curl -s -X POST "http://localhost:8080/api/v1/orders/{ORDER_ID}/transition" \
  -H "Content-Type: application/json" \
  -H "X-Active-Tenant-Id: {SELLER_TENANT_ID}" \
  -H "Authorization: Bearer {TOKEN}" \
  -d '{"action":"approve"}'
# Expected: 422 { "error": "INVALID_TRANSITION", "allowed": ["complete"] }
```

Rentals and reservations: same pattern with `/v1/rentals/{id}/transition` and `/v1/reservations/{id}/transition`; status `requested` → approve → `accepted`, reject → `rejected`.

## Gate commands (PASS evidence)

```
.\ops\run_wp_next_local_gates.ps1
=== WP-NEXT LOCAL GATES: PASS ===

.\ops\ops_run.ps1 -Profile Prototype -CheckDemoSeed
OVERALL STATUS: PASS
All checks passed.
```

## UI changes

- **Firm Portal:** Orders, Rentals, Reservations sections — new column "İşlem" with "Onayla" and "Reddet" buttons per row; disabled when current status does not allow that action; on success panel list reloads.
- **Customer account:** No UI change; list endpoints return `status` and `updated_at`; customer sees updated status on next load/refresh.

## Files changed

1. `work/pazar/routes/api/05_orders.php` — POST transition endpoint
2. `work/pazar/routes/api/06_rentals.php` — POST transition endpoint
3. `work/pazar/routes/api/04_reservations.php` — POST transition endpoint
4. `work/marketplace-web/src/api/client.js` — transitionOrder, transitionRental, transitionReservation
5. `work/marketplace-web/src/pages/FirmPortalPage.vue` — Approve/Reject buttons, canApprove/canReject, transition methods
6. `docs/PROOFS/wp_transaction_lifecycle_v1_pass.md`
7. `docs/WP_CLOSEOUTS.md` — closeout entry
