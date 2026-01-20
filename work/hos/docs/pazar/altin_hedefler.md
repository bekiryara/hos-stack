# Altın Hedefler (Golden Goals) — H-OS Evreni + Pazar İlk Dünya (TR)

Bu doküman **nihai hedefi** kilitler. Hem H-OS hem Pazar ekibi/ajanı “neye göre doğru ilerliyoruz?” sorusunu burada cevaplar.

## 0) Kanonik cümle
- **H-OS = evren hukuku**
- **Pazar = ilk ticaret dünyası**
- Sonraki dünyalar: Yemek / Araç / Gayrimenkul / Hizmet vb.

## 1) Altın Hedefler (değişmez)

### 1.1 H-OS (Evren) Altın Hedefleri
- **Tek kimlik (SSO)**: kullanıcı yeniden kayıt olmaz; dünyalar “onboard” eder.
- **Tek yetki kanunu (Policy)**: kim neyi yapabilir tek yerden ve versiyonlu.
- **Tek sözleşme kanunu (Contract/FSM)**: state geçişleri tek yerden, terminal state korunur.
- **Tek kanıt standardı (Proof/Audit)**: append-only, delil standardı, korelasyon (request-id) ile izlenebilir.
- **Kademeli geçiş**: breaking change = shadow → enforce → rollback planı.
- **Multi-tenant birinci sınıf**: tenant izolasyonu, büyük tenant için shard planı.
- **Operasyonel ergonomi**: health/ready/metrics, log redaction, secrets standardı.

### 1.2 Pazar (İlk attaching dünya) Altın Hedefleri
- **Satış + Rezervasyon çekirdeği tek**: ürün/sipariş/rezervasyon/ödeme aynı platform.
- **Günlük + saatlik kiralama**: çakışma koruması, doğru fiyat/total hesaplama.
- **Ödeme/webhook güvenliği**: imza doğrulama (opsiyonel), idempotency, terminal state.
- **Basit ve teslim edilebilir UX**: admin + firma panel + müşteri vitrin uçtan uca çalışır.
- **TR hazırlığı**: KVKK ve temel metinler şablonları + teslim kanıtları.

## 2) Anti-Goals (özellikle yapılmayacaklar)
- **Erken mikroservis**: ihtiyaç kanıtlanmadan dünyaları servisleştirmeyiz.
- **Dünya verisini evrene taşıma**: video/mesaj/ticaret kayıtları H-OS DB’ye dolmaz.
- **Controller’da kanun yazma**: if-else kuralı controller’a gömülmez.
- **Breaking change’ı direkt enforce etmek**: shadow olmadan “kanun” devreye alınmaz.
- **Kanıtsız teslim**: proof bundle + postman + test olmadan “teslim” sayılmaz.

## 3) “Devam mı?” karar mekanizması (tüm olasılıklar için)
Her yeni özellikte sor:
1) **Bu evrensel mi?** (birden çok dünyada kullanılacak mı?) → H-OS
2) **Bu dünya domain’i mi?** (ticaret/video/mesaj domain’i mi?) → ilgili dünya (Pazar vb.)
3) **Kanıt gerektiriyor mu?** (status/ödeme/iptal/webhook) → Proof zorunlu
4) **State geçişi var mı?** → Contract zorunlu
5) **Yetki kararı var mı?** → Policy zorunlu (shadow→enforce)

## 4) Ölçülebilir Kabul Kriterleri (kanıt)

### 4.1 Pazar kanıtları
- `php artisan test` → PASS
- `docs/smoke_test.ps1` → PASS
- Postman Runner:
  - Local Quickstart → Errors 0
  - Hourly Quickstart → Errors 0
- `docs/proof_bundle.ps1` → proof klasörü üretir

### 4.2 H-OS kanıtları (opsiyonel ama hedef)
- `ops/bootstrap.ps1 -Obs -Web` → stack ayakta
- `ops/check.ps1 -SkipAuth` → health/ready/metrics OK
- Pazar proof bundle içinden:
  - `docs/proof_bundle.ps1 -IncludeHos -HosBootstrap` → `hos.check.txt` ve `exit code: 0`

## 5) Versiyonlar
- `HOS_POLICY_VERSION`
- `HOS_CONTRACT_VERSION` (hedef; Pazar embedded katmanda versiyonlanır)
- `HOS_PROOF_VERSION` (hedef)
- `HOS_SSO_VERSION` (hedef)





