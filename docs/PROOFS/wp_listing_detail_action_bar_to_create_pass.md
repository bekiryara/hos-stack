# WP-NEXT: Listing Detail Action Bar → Create entrypoints PASS

**Timestamp:** 2026-02-01

## Summary

Listing detail sayfasına 3 aksiyon butonu eklendi (Sipariş Ver, Kirala, Rezervasyon Yap); create sayfalarına listing_id query ile yönlendiriyor. listingId tek kaynaktan (listing?.id ?? route.params.id); boşsa butonlar disabled + "Listing id missing" notu. Tıklamada transitioning state ile butonlar kısa süre disabled. Create sayfaları zaten query'den listing_id okuyordu; ek patch yok.

## Manual checks

- **A)** /search üzerinden bir listing aç → "Sipariş Ver" tıkla → /order/create sayfası listing_id dolu → submit → toast + detail redirect çalışıyor.
- **B)** "Kirala" → /rental/create sayfası listing_id dolu.
- **C)** "Rezervasyon Yap" → /reservation/create sayfası listing_id dolu.

## Gates evidence

- `.\ops\run_wp_next_local_gates.ps1` → **=== WP-NEXT LOCAL GATES: PASS ===**
- `.\ops\ops_run.ps1 -Profile Prototype` → **OVERALL STATUS: PASS**
