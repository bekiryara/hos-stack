# WP-NEXT: Firm Portal — Transaction Decisions UI PASS

**Timestamp:** 2026-02-01

## Summary

- **Firm panel** order/rental/reservation rows expose **Accept** and **Reject** actions; action-level loading (“Working…”) and panel error box on failure; **post-action refresh** (no optimistic update); backend unchanged.
- **Orders:** Accept/Reject enabled when status = `placed`; success → list refetched, status updated (e.g. accepted/rejected).
- **Rentals / Reservations:** Accept/Reject enabled when status = `requested`; same pattern.
- **Isolation:** One panel’s action failure does not affect other panels’ state.

## Manual UX check

- **/firm → Orders tab:** Click Accept on a `placed` order → button shows “Working…”, request 2xx → list refreshes → row status becomes `accepted`. Same for Reject → `rejected`.
- **/firm → Rentals tab:** Same pattern for `requested` rentals (Accept → accepted, Reject → rejected).
- **/firm → Reservations tab:** Same pattern for `requested` reservations.
- **Pending kayıt yoksa:** Demo seed ile 1 adet pending sipariş/kiralama/rezervasyon oluşturup (müşteri tarafından create order/rental/reservation) firm panelden Accept/Reject deneyebilirsiniz; mevcut kullanıcı akışı değiştirilmedi.

## Gates evidence

- `.\ops\run_wp_next_local_gates.ps1` → **=== WP-NEXT LOCAL GATES: PASS ===**
- `.\ops\ops_run.ps1 -Profile Prototype` → **OVERALL STATUS: PASS**
