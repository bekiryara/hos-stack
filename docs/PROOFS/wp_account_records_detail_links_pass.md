# WP-NEXT: Account Records — Detail Links PASS

**Timestamp:** 2026-02-01 (proof created with WP execution)

## Summary

- 3 panellerde (MyOrdersPanel, MyRentalsPanel, MyReservationsPanel) `detailLink(row)` eklendi; ID tıklayınca ilgili detail route'a gidiyor.
- Route üretimi `account_record_links.js` util ile merkezileştirildi; query standardı: `listing_id`, `status`, `created_at`, `updated_at` (null when absent).
- Davranış değişikliği yok: sadece "ID tıklayınca detail route'a doğru git" + query standard.

## Manual UI proof steps

1. `/account` aç.
2. **Orders** tab → bir ID'ye tıkla → `/account/orders/:id` açılıyor, header "Order {id}".
3. **Rentals** tab → ID'ye tıkla → `/account/rentals/:id`.
4. **Reservations** tab → ID'ye tıkla → `/account/reservations/:id`.
5. Detail sayfada `listing_id` / `status` / `created_at` alanları query'den dolu geliyor (varsa).

## Commands + outputs

- `.\ops\run_wp_next_local_gates.ps1` => PASS (see gate run)
- `.\ops\ops_run.ps1 -Profile Prototype` => OVERALL STATUS: PASS (see ops run)
