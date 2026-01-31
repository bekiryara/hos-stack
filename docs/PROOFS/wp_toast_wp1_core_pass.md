# WP-NEXT: Toast WP-1 — Core notifier + 2 integrations PASS

**Timestamp:** 2026-02-01

## Summary

ToastHost + notify API (notifySuccess, notifyError, notifyInfo) eklendi; App seviyesinde tek noktadan render. Firm Portal accept/reject aksiyonlarında success/error toast ve Login/Register + auth redirect (expired) için auth error toast entegrasyonu yapıldı. Form field-level validation ve panel error box’lar aynen kaldı; harici UI library yok.

## Manual checks

- **A)** `/firm` → Orders (veya Rentals/Reservations) tab → Accept → “Accepted” toast sağ üstte görünür.
- **B)** `/firm` → Reject → “Rejected” toast görünür.
- **C)** Logout veya expired token ile korumalı sayfaya gir → `/login?reason=expired` yönlendirmesi + “Auth required” toast; login form hata ile de “Login failed” toast. Mevcut UI (error box, info-box) davranışı sürer.

## Gates evidence

- `.\ops\run_wp_next_local_gates.ps1` → **=== WP-NEXT LOCAL GATES: PASS ===**
- `.\ops\ops_run.ps1 -Profile Prototype` → **OVERALL STATUS: PASS**
