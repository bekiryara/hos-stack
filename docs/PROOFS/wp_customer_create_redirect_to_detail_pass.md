# WP-NEXT: Customer Create → Detail Redirect + Toast PASS

**Timestamp:** 2026-02-01

## Summary

Customer create flows (Order, Rental, Reservation) artık başarı sonrası otomatik olarak detail sayfasına redirect yapıyor; toast ile "Created" bildirimi gösteriliyor. Detail endpoint fail olsa bile query'den limited view ile veri ekranda görünüyor (`from=create` marker ile). Hata durumlarında `notifyApiError` + `normalizeApiError` kullanılıyor; inline error state korunuyor.

## Manual Smoke

1. **Login** → /account'a git.
2. **Bir listing aç** (örn. /listing/:id) → Create Order linkine tıkla.
3. **Form doldur** (listing_id zaten dolu, quantity gir) → Submit.
4. **Success:**
   - "Order created" toast sağ üstte görünecek.
   - Otomatik olarak `/account/orders/:id` detail sayfasına düşeceksin.
   - Detail sayfasında listing_id, quantity, status vb. query'den okunarak limited view görünecek.
5. **Aynı akışı Rental ve Reservation için test et:**
   - Create Rental → "Rental created" toast + `/account/rentals/:id`
   - Create Reservation → "Reservation created" toast + `/account/reservations/:id`

## Gates evidence

- `.\ops\run_wp_next_local_gates.ps1` → **=== WP-NEXT LOCAL GATES: PASS ===**
- `.\ops\ops_run.ps1 -Profile Prototype` → **OVERALL STATUS: PASS**
