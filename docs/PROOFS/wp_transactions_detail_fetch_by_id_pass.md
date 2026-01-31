# WP-NEXT: Transactions detail — fetch-by-id + safe fallback PASS

**Timestamp:** 2026-02-01

## Summary

Detail sayfaları artık ID ile API'den tam veri çekiyor; query fallback sadece fallback ve ilk paint için kullanılıyor. Direct URL (query yok) açıldığında da fetch-by-id ile full view gelir. API hata verirse limited view + banner'da net hata mesajı gösterilir.

## Manual UI steps

1. **/account?tab=orders** → bir kayda tıkla → detail açılır → önce limited (query’den) sonra full (fetch başarılı) görünür.
2. **Direct URL:** Detail URL’sini kopyala, yeni sekmede query olmadan aç → yine full view gelir (ID ile API’den çekilir).
3. **API fail:** Token yok/expired (logout) veya 404/403 → limited view + banner’da “Limited view — API fetch failed: …” görünür.

## Gates evidence

- `.\ops\run_wp_next_local_gates.ps1` → **=== WP-NEXT LOCAL GATES: PASS ===**
- `.\ops\ops_run.ps1 -Profile Prototype` → **OVERALL STATUS: PASS**
