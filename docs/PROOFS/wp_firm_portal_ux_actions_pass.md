# WP-NEXT: Firm Portal — UX Standard + Actions PASS

Timestamp: 2026-01-30

## Summary
- Firm Portal panelleri (Listings/Orders/Rentals/Reservations) standart UX’e alındı: loading + error box + Retry butonu + empty state.
- Listings tablosuna Actions kolonu eklendi: View → /listing/{id}, Message → /listing/{id}/message, Edit → disabled (title: not implemented).
- Bir panel hata verince diğerleri etkilenmiyor (izole state).

## Commands + outputs (PASS)

### .\ops\run_wp_next_local_gates.ps1
- Son satır: `=== WP-NEXT LOCAL GATES: PASS ===`
- Exit code: 0

### .\ops\ops_run.ps1 -Profile Prototype
- Özet: Secret Scan PASS, Public Ready PASS, Conformance PASS, Prototype Verification PASS
- Son satır: `OVERALL STATUS: PASS` veya `All checks passed`
- Exit code: 0

## DoD
- [x] Her panel: loading "Loading …", error box + Retry (sadece o paneli tekrar çağırır), empty "No X yet", data tablo
- [x] Listings: Actions kolonu — View, Message, Edit (disabled, title "not implemented")
- [x] Paneller izole (bir hata diğerlerini bloklamaz)
