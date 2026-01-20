# Pazar + H-OS Değişiklik Protokolü (TR) — “Koparmadan ilerleme”

Bu protokol, “evren (H-OS) + ilk dünya (Pazar)” birlikte gelişirken yanlış yönlere sapmayı engeller.

## 1) Altın Kurallar
- **Kural-1:** Pazar domain’i H-OS’a taşınmaz (dünya verisi dünyada kalır).
- **Kural-2:** H-OS kanunu Pazar controller’larına gömülmez (policy/contract/proof tek kapı).
- **Kural-3:** Her değişiklik kanıtlanır (test + smoke + proof bundle).
- **Kural-4:** Breaking change = önce **shadow**, sonra **enforce**.

## 2) Değişiklik Akışı (her PR için)
1) **Sözleşme güncelle** (doküman):
   - etkilenen: Policy/Contract/Proof/SSO
   - versiyon: `HOS_*_VERSION`
2) **Küçük değişiklik uygula**
3) **Kanıt üret**
   - Pazar: `php artisan test`, Postman Quickstart, `docs/proof_bundle.ps1`
   - H-OS: `ops/check.ps1`, `ops/smoke.ps1`, gerekiyorsa `ops/proof.ps1`
4) **Rollback planı**
   - git revert + (varsa) docker image rollback

## 3) Shadow → Enforce kuralı (kopmayı engeller)
- Shadow: karar hesaplanır, log/metric çıkar, davranış değişmez
- Enforce: karar bloklar (403 vb.)

Policy için env:
- `HOS_POLICY_MODE=shadow|enforce|off`
- `HOS_POLICY_LOG=true|false`

## 4) “Dokunma listesi” (riskli bölgeler)
Bu alanlara müdahale ederken ekstra proof şart:
- Auth/refresh token akışları
- Webhook doğrulama / idempotency
- DB migrasyonları
- Role matrix / policy kuralları
- Observability/alerting config

## 5) Ne zaman H-OS’a kod müdahalesi yapılır?
Sadece şu koşullarda:
- Pazar tarafında “embedded” katmanda kanun netleşti
- Remote servisleşme ihtiyacı kanıtlandı (yük/çoklu dünya)
- API/event sözleşmesi dokümanda kilitlendi





