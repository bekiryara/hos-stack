# WP-NEXT: Portal records panels base — PASS

**Timestamp:** 2026-02-01

## Summary

6 panel (Firm Orders/Rentals/Reservations + Account My Orders/Rentals/Reservations) tek bir RecordsPanelBase bileşenine indirgendi; davranış değişmedi (aynı API çağrıları, loading/empty/error/retry semantiği). Wrapper’lar scope + kind ile base’i kullanıyor; parent load() / refresh mekanizması korunuyor.

## Manual checks

- **A) Firm:** /firm → Gelen Siparişler / Kiralama Talepleri / Rezervasyonlar listeleri yükleniyor; Accept/Reject çalışıyor.
- **B) Customer:** /account → Orders / Rentals / Reservations tab’ları listeleri yükleniyor; ID’ye tıklayınca detail sayfasına gidiyor.
- **C) API fail:** Token yok veya API hata verince error kutusu + Retry çalışıyor.
- **D) Empty state:** Veri yokken “No orders yet” / “No rentals yet” / “No reservations yet” doğru gösteriliyor.

## Gates evidence

- `.\ops\run_wp_next_local_gates.ps1` → **=== WP-NEXT LOCAL GATES: PASS ===**
- `.\ops\ops_run.ps1 -Profile Prototype` → **OVERALL STATUS: PASS**
