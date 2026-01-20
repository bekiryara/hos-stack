# NEXT DECISIONS (TR) — Pazar + H-OS “kilitlenmeden ilerleme”

Amaç: Dokümanların hepsini aynı anda okuyup kilitlenmeden, **tek sayfada** karar noktalarına gelmek.

## 0) Okuma yöntemi (kilitlenmeyi engeller)
Kural: Bir seferde **en fazla 2–3 doküman** okunur.

Her doküman için sadece şunlar çıkarılır:
- **Ne kilitliyor?** (hangi kural / sınır / garanti)
- **Hangi kararı doğuruyor?** (evet/hayır veya seçenek A/B)
- **Kanıtı ne?** (tek komut / tek ekran)

Sonra bu dosyada “Karar Gündemi” güncellenir. Hepsi bu.

## 1) Kanonik çerçeve (değişmez)
- **H-OS = evren hukuku** (SSO/Policy/Contract/FSM/Proof/Ops)
- **Pazar = ilk ticaret dünyası** (ürün/sipariş/rezervasyon/ödeme + panel/vitrin)

Kaynak:
- `docs/tr/altin_hedefler.md`
- `docs/tr/hos_pazar_sozlesmesi.md`

## 2) Karar Gündemi (şu an)

## 2.0) DURUM ÖZETİ (Bugün) — Yeni ajan için tek bakış
**Aşama**: Embedded H‑OS (Mod‑A) üstünde “remote’a taşınabilir kanun” kilitleme + canary remote gate’ler.

### Neler kilitlendi? (drift/patlama riskini düşüren çekirdek)
- **Policy Gate (tek kapı)**: kritik mutation endpoint’ler `HosGate::policyEnforcer()->checkEnforce(...)` ile korunur.
- **Contract/FSM (tek mutation kapısı)**: status geçişleri `HosGate::contract($subject)->transition(...)` ile yapılır (+ proof otomatik).
- **Allowed-actions (UI kanonu)**: UI butonları role/status if’leriyle değil, server’ın döndürdüğü `allowedActions` listesinden çizilir.
- **ActionCatalog (tek sözlük)**: action→ability→toStatus mapping tek yerde (`app/Hos/Actions/ActionCatalog.php`).

### Remote’a hazırlık (kanon + config + skeleton)
- **Remote failover kanonu**: `docs/tr/hos_remote_failover_politikasi.md`
  - read-only: **degrade**
  - kritik mutation: **fail‑closed (503)**
- **Config**: `config/hos.php`
  - `HOS_MODE=embedded|hybrid|remote`
  - `HOS_BASE_URL`, `HOS_API_KEY`, `HOS_TIMEOUT_MS`, `HOS_RETRIES`
  - `HOS_POLICY_VERSION`, `HOS_CONTRACT_VERSION`
- **Remote client skeleton** (henüz runtime’a tam bağlanmış authoritative değil):
  - `app/Hos/Remote/RemoteHosHttpClient.php`
  - `app/Hos/Remote/RemoteHosService.php`
- **Read-only switch noktası**: `app/Hos/Runtime/HosRouter.php` (allowed-actions için embedded/hybrid/remote)

### Canary remote gate’ler (kanıtlı)
- **Policy (kritik mutation)**: `PolicyEnforcer::checkEnforce()` → `HOS_MODE=remote` iken remote `/v1/policy/decide`
  - remote down/unconfigured → **503**
- **Contract gate**: `BaseContract::assertCanTransition()` → `HOS_MODE=remote` iken remote `/v1/contract/can-transition`
  - remote down/unconfigured → **503**
  - remote deny → ValidationException (422)
  - `HOS_MODE=hybrid` iken drift log: `hos.remote.shadow.contract_drift`
 - **Contract transition shadow**: `BaseContract::transition()` → `HOS_MODE=hybrid` iken local transition sonrası remote `/v1/contract/transition` **best-effort** gönderilir (remote down bozmaz).
   - idempotency_key: `pazar:proof:status_change:{proof_id}`
 - **Outbox (retry garantisi)**: Hybrid transition artık request içinde HTTP yapmaz; `hos_outbox_events` tablosuna yazar.
   - Dispatch komutu: `php artisan hos:outbox-dispatch`

### Kanıt (yüksek sinyal testler)
- UI allowed-actions:
  - `UiTenantReservationAllowedActionsShowTest`
  - `UiTenantPaymentAllowedActionsShowTest`
  - `UiTenantOrderAllowedActionsShowTest`
- Remote read-only degrade:
  - `HosRemoteDegradeAllowedActionsTest`
- Remote fail-closed (kritik):
  - `HosRemoteFailClosedMutationTest`
  - `HosRemoteFailClosedContractTest`
- Hybrid transition shadow (remote yokken bozulmaz):
  - `HosHybridContractTransitionShadowDoesNotBreakTest`

### D1) Online ödeme sağlayıcısı (ilk)
- **Karar**: **iyzico** (hosted checkout / redirect)
- **Durum**: demo modunda **iyzico paid kanıtı var** (redirect simülasyonu)
- **Sonraki adım**: gerçek hosted checkout + webhook mapping (sandbox) — **mikro adımlarla**
- **Kanıt**:
  - UI: sipariş detayında `provider=iyzico, status=paid` ekran görüntüsü
  - Test: `php artisan test`

#### D1’i kilitlenmeden bitirme (mikro plan)
Her adım 10–20 dk; her adım sonunda **dur**.

- **D1.1 — Sadece “protokol” (doküman)**
  - Çıktı:
    - Kanonik webhook formatı değişmez: `{event_id, status, provider_reference}`
    - iyzico’ya gönderilen `conversationId` (veya karşılığı) = **bizim** `payments.provider_reference`
    - event_id yoksa deterministik fallback: `evt_iyzico_{paymentId}` veya `evt_iyzico_{conversationId}_{status}`
  - Kanıt: `docs/tr/iyzico_hosted_checkout_plani.md` içindeki “Protokol kararı” bölümü ✅

- **D1.2 — Data model kararı (1 karar)**
  - Karar: `payments` içine `provider_payload` (json/text) gibi bir alan ekleyelim mi?
  - Alternatif: ayrı `payment_provider_events` tablosu
  - Kanıt: migration diff + `php artisan test` ✅

- **D1.3 — Hosted checkout “başlat” endpoint (stub)**
  - Anahtar yoksa: 200 + “configured değil” mesajı (patlamasın)
  - Anahtar varsa: pending `provider=iyzico` payment + `provider_payload.checkout_url` üretilir (stub sayfa)
  - Kanıt:
    - UI: checkout ekranında “iyzico Checkout Başlat (Stub)” + “Checkout Linkini Aç”
    - Test: `UiIyzicoHostedCheckoutStubTest` ✅

- **D1.4 — Return (kullanıcı dönüş) sayfası**
  - Sadece “durum” gösterir; karar webhook’tan gelir
  - Kanıt:
    - UI: `iyzico Return (Read-only)` ekranı
    - Test: `UiIyzicoReturnReadOnlyTest` ✅

- **D1.5 — Webhook mapping (gerçek ‘paid’)**
  - iyzico webhook → bizim `/payments/webhook/iyzico` standard payload’a map
  - Mikro adımlar:
    - **D1.5.1**: iyzico payload tolerant mapping (conversationId/paymentStatus) ✅
    - **D1.5.2**: iyzico signature doğrulama (opsiyonel) ✅
  - Kanıt (D1.5.1):
    - Test: `PaymentWebhookIyzicoMappingTest` ✅
    - Payment `provider_payload.last_webhook` kaydı ✅
  - Kanıt (D1.5.2):
    - Test: `PaymentWebhookIyzicoSignatureTest` ✅

### D2) “Policy mode” ne zaman shadow→enforce olacak?
- **Karar**: önce **shadow** (log/metric), sonra sadece kritik endpoint’lerde enforce
- **Durum**: Pazar tarafında policy/contract/proof “tek kapı” disiplini var; enforce takvimi netleştirilecek
- **Sonraki adım**: `HOS_POLICY_MODE` (off/shadow/enforce) gibi bir bayrak standardı + rollout adımı
- **Kanıt**: shadow log’ların proof klasöründe görünmesi
  - Not: Varsayılan güvenli olmalı → `HOS_POLICY_MODE=enforce` (shadow sadece kontrollü ölçüm)

### D3) Contract/FSM versiyonlama (minimum)
- **Karar**: breaking change = **shadow → enforce** + rollback planı
- **Durum**: doküman/protokol var
- **Sonraki adım**: versiyon alanları (örn. `HOS_*_VERSION`) için tek yerden okunan config
- **Kanıt**: `docs/proof_bundle.ps1` çıktısında versiyonların raporlanması

### D4) Prod tenant çözümleme standardı
- **Karar**: prod’da **subdomain** (örn. `{tenant}.domain.com`) önerilir; localde `Host: demo.localhost` ile devam
- **Durum**: local çalışıyor
- **Sonraki adım**: prod runbook’a “subdomain setup” bölümü eklenebilir (Nginx/Apache)
- **Kanıt**: resolve tenant testleri + prod smoke

### D5) Operasyon dağıtım stratejisi (XAMPP vs Docker)
- **Karar**: demo/dev: XAMPP; staging/prod: Docker Compose (kademeli)
- **Durum**: Pazar tarafında teslim/kanıt akışı oturdu; H-OS tarafında ops toolbelt güçlü
- **Sonraki adım**: Pazar için “ops iskeleti” (compose + check + smoke) opsiyonel eklenir (XAMPP bozulmaz)
- **Kanıt**: tek komut bootstrap + check + smoke

### D6) “Kategori / Üst sınıf / Akış” (patlamayı engelleyen model)
- **Karar**:
  - Akış sadece **2**: `sale` (Satış/Order) ve `booking` (Rezervasyon/Reservation)
  - Üst sınıf (form): Ürün/Araç/Gayrimenkul/Konaklama/Hizmet/Yemek
  - Kategori: sadece vitrin/SEO/filtre (**akış ve formu belirlemez**)
- **Durum**: kilitlendi (kanonik sayfa eklendi).
- **Kanonik**:
  - `docs/tr/KANONIK_MODEL_FLOW_UST_SINIF_KATEGORI.md`

### D7) “Policy Gate = tek kapı” standardı (Pazar embedded H-OS)
- **Karar**: Kritik mutation endpoint’lerinde subject resolve sonrası ilk business satırı Policy Gate olur (shadow→enforce).
- **Durum**: kanonik doküman eklendi.
- **Kanonik**:
  - `docs/tr/HOS_POLICY_GATE_KANONU.md`

### D8) Allowed-actions (UI kanonu) + ActionCatalog (tek sözlük)
- **Karar**: UI butonları “role/status” ile karar vermez; server `allowedActions` listesi verir.
- **Durum**: tenant show ekranları kilitlendi:
  - Reservation show ✅
  - Payment show ✅
  - Order show ✅
- **Kanonik**:
  - `app/Hos/Actions/ActionCatalog.php`
  - `app/Hos/Actions/ActionResolver.php`

### D9) Remote failover politikası (en kritik karar)
- **Karar**: Remote down olursa:
  - read-only: degrade (actions boş / safe)
  - kritik mutation: fail‑closed 503
- **Durum**: doküman kilitli + export var ✅
- **Kanonik**: `docs/tr/hos_remote_failover_politikasi.md`

## 3) “Sıradaki 3 adım” (net)
1) **Remote contract transition** (micro-canary): `/v1/contract/transition` shadow → enforce planı + Pazar adapter
2) **Hybrid ölçüm raporu**: embedded vs remote drift’i tek raporda görmek (log/metric)
3) **iyzico hosted checkout gerçek akış** (sandbox): checkout url + return + webhook doğrulama

## 5) Kanonik ürün vizyonu (sapma engelleyici)
- “Amazon seviyesi satış” + “Airbnb seviyesi kiralama” hedefi için tek sayfa roadmap:
  - `docs/tr/ROADMAP_AMAZON_AIRBNB.md`

## 4) Kanıt komutları (tek satır)
- Pazar (tek komut): `powershell -NoProfile -ExecutionPolicy Bypass -File .\\docs\\deliver.ps1 -OpenFolder`
- Zip güncelle (tek komut): `powershell -NoProfile -ExecutionPolicy Bypass -File .\\docs\\finalize_delivery.ps1 -OpenFolder`


