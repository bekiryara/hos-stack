# WP-NEXT: Listing ActionBar (modes-aware) + Detail Fallback merkezileştirme PASS

**Timestamp:** 2026-02-01

## Summary

Listing detail action bar artık transaction_modes'a göre render ediyor (config-driven: modes.js + TransactionActionBar). Detail sayfalarında limited view + banner tek merkez utility (limited_view.js) ve component (LimitedViewBanner) ile standardize edildi; reason classifyLimitedReason ile; mesaj limitedMessage ile; query buildLimitedFromQuery ile.

## Manual checks

- **A)** transaction_modes = ['sale'] olan bir listing'de sadece "Sipariş ver" görünür.
- **B)** transaction_modes boş/undefined olan listing'de buton görünmez (UI patlamaz).
- **C)** Create sonrası detail'e gidince FULL view geliyorsa banner yok.
- **D)** Token yok/expired iken detail aç: LIMITED banner reason "unauthorized" veya "forbidden" (endpoint yok demesin).

## Gates evidence

- `.\ops\run_wp_next_local_gates.ps1` → **=== WP-NEXT LOCAL GATES: PASS ===**
- `.\ops\ops_run.ps1 -Profile Prototype` → **OVERALL STATUS: PASS**
