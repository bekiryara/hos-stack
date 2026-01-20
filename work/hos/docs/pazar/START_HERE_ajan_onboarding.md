# START HERE (Ajan Onboarding) — H-OS Evreni + Pazar İlk Dünya (TR)

Bu dosya yeni katılan **H-OS ajanı** veya **Pazar ajanı** için “ilk okunacak tek sayfa”dır.
Amaç: sapma olmasın, yanlış müdahale olmasın, herkes aynı hedefte buluşsun.

## 0) 2 dakikada kanonik tanım
- **H-OS = Evren hukuku** (Kimlik/SSO + Policy + Contract/FSM + Proof/Audit)
- **Pazar = İlk dünya** (ticaret sahnesi: ürün/sipariş/rezervasyon/ödeme + UI)

## 1) Altın hedefi oku (zorunlu)
- `docs/tr/altin_hedefler.md`

Bu doküman “doğru/yanlış” ölçütüdür.

## 2) Kısa çalışma kuralları (sapma önleyici)
- **Dünya verisi evrene taşınmaz** (video/mesaj/pazar kayıtları H-OS DB’ye dolmaz).
- **Controller kural yazmaz**:
  - state geçişleri → Contract/FSM
  - yetki → Policy
  - kanıt → Proof/Audit
- **Breaking change**: shadow → enforce → rollback.
- **Kanıtsız merge yok**: test + smoke + proof.

## 3) Ben neyi geliştiriyorum? (karar ağacı)
1) Bu özellik birden fazla dünya tarafından kullanılacak mı?
   - Evet → H-OS alanı
2) Bu özellik “kim neyi yapar / geçerlilik / kanıt” mı?
   - Evet → H-OS alanı
3) Bu özellik “ticaret domain’i” mi (ürün/sipariş/rezervasyon/ödeme UX)?
   - Evet → Pazar alanı

## 4) Pazar ajanı için küçük adımlar
Her PR şu min. adımlarla ilerler:
1) **Doküman**: etki ettiği sözleşmeyi güncelle (Policy/Contract/Proof/SSO).
2) **Kod**: küçük değişiklik (tek konu).
3) **Kanıt**:
   - `php artisan test`
   - `docs/smoke_test.ps1`
   - Postman: Local + Hourly Quickstart (Errors 0)
4) **Proof paket**:
   - `docs/proof_bundle.ps1 -IncludeHos -HosBootstrap -HosStopAfter` (opsiyonel ama önerilir)

## 5) H-OS ajanı için küçük adımlar
1) **Repo haritası**: `docs/tr/hos_repo_haritasi.md`
2) **Runbook**: `RUNBOOK.md`
3) **Kanıt**:
   - `.\ops\check.ps1 -SkipAuth`
   - `.\ops\smoke.ps1` (gerekirse)
4) Pazar ile entegrasyon değişiyorsa:
   - `docs/pazar/` altındaki sözleşme dokümanlarını güncelle
   - shadow/enforce planını yaz

## 6) Referans dokümanlar (tek tık)
- Entegrasyon playbook: `docs/tr/hos_pazar_entegrasyon_playbook.md`
- SSO standardı: `docs/tr/hos_universal_identity_sso.md`
- Policy kanunu: `docs/tr/hos_policy_yetki_kanunu.md`
- Değişiklik protokolü: `docs/tr/pazar_hos_degisim_protokolu.md`

# START HERE — Ajan Onboarding (TR)

Bu sayfa, **Pazar** ve **H-OS** ekosistemine yeni katılan ajan/ekip için tek giriş noktasıdır.
Hedef: sapma olmasın, sistem davranışı bozulmasın, “evren + ilk dünya” aynı hedefte kalsın.

## 1) 60 saniyede kanon
- **H-OS = evren hukuku** (kimlik/SSO, policy, contract/FSM, proof/audit, versiyonlama)
- **Pazar = ilk dünya** (ticaret sahnesi: ürün/sipariş/rezervasyon/ödeme/vitrin/panel)
- Dünyalar çoğalır; **kanun tek kalır**.

## 2) Okunması zorunlu 5 doküman (sırayla)
1) `docs/tr/altin_hedefler.md`  → “neye göre doğruyuz?”
2) `docs/tr/hos_pazar_sozlesmesi.md` → sınırlar/beklentiler
3) `docs/tr/hos_pazar_entegrasyon_playbook.md` → modlar (embedded/hybrid/remote)
4) `docs/tr/hos_policy_yetki_kanunu.md` → yetki kanunu (shadow→enforce)
5) `docs/tr/pazar_hos_degisim_protokolu.md` → değişiklik protokolü (kanıt/rollback)

## 2.1) Pazar model kararı (sapma önleyici)
- `docs/tr/KANONIK_MODEL_FLOW_UST_SINIF_KATEGORI.md`
  - Akışlar (Satış/Rezervasyon) ayrımı
  - Üst sınıf (form) vs Kategori (vitrin) ayrımı

## 2.2) H-OS “tek kapı” standardı (Pazar içinde embedded)
- `docs/tr/HOS_POLICY_GATE_KANONU.md`
  - Policy Gate (shadow→enforce)
  - Contract = tek mutation kapısı
  - Proof = otomatik defter
  - Allowed-actions = UI drift’i önleme

## 2.3) H-OS ajanı görevi (Pazar ile hizalama) — OKU ve buna göre PR aç
Bu repo (Pazar) içinde H-OS şu an **embedded** çalışıyor. H-OS ajanı olarak amacın:
- Pazar’daki mevcut H-OS entegrasyonunu “remote H-OS servisi varmış gibi” kanonik hale getirmek
- Yetki/kanun drift’ini sıfırlamak (doküman ≡ kod ≡ UI)
- Controller/UI içine yeni hukuk kuralı sokmamak

Not (path/konum):
- **Pazar repo**: kanonik TR dokümanları `docs/tr/` altındadır.
- **H-OS repo**: Pazar’dan export edilen kopyalar `docs/pazar/` altındadır (Pazar: `docs/export_to_hos.ps1`).
  - H-OS ajanı olarak senin okuyacağın dosyalar **H-OS repo içindeki** `docs/pazar/` kopyalarıdır.

### Yapılacaklar (öncelik sırası)
- **1) Policy kanunu (tek kaynak)**:
  - `docs/pazar/hos_policy_yetki_kanunu.md` içindeki ability listesi + role matrix’i H-OS tarafında **aynen** kanun kabul et.
    - (Pazar repo karşılığı: `docs/tr/hos_policy_yetki_kanunu.md`)
  - Eğer H-OS repo’da ayrı bir “ability catalog” dosyası varsa, isimleri birebir eşle (ör: `tenant.payment.mark_paid`).
- **2) Policy Gate standardı**:
  - `docs/pazar/HOS_POLICY_GATE_KANONU.md` kanonunu referans al.
    - (Pazar repo karşılığı: `docs/tr/HOS_POLICY_GATE_KANONU.md`)
  - “kritik mutation endpoint” tanımı: para / iptal / status transition / owner transfer / tenant user yönetimi.
- **3) Granular abilities (ops vs kritik)**:
  - Rezervasyon için ayrım kilitli:
    - ops: `tenant.reservation.ops` (owner+staff)
    - kritik: `tenant.reservation.cancel`, `tenant.reservation.confirm` (owner-only)
  - Order/Payment kritik aksiyonları owner-only kilitli:
    - `tenant.order.cancel`
    - `tenant.payment.mark_paid`
    - `tenant.payment.cancel`
- **4) Drift kontrolü (kabul kriteri)**:
  - H-OS dokümanı “staff reservation manage ✅” derken kod “❌” yapamaz (ve tersi).
  - Ability ismi asla değişmez (breaking change). Yeni ihtiyaç varsa **yeni ability** eklenir.

### Yapılmayacaklar (kritik)
- **Pazar controller’larına “rol if” ekleme** (owner/staff kontrolü) → yasak. Yetki: Policy Gate.
- “manage” ability’lerini her şeye yeten süper güç gibi büyütme → drift üretir. Gerekirse aksiyon bazlı ability aç.
- UI’yı hukuk kaynağı gibi kabul etme → UI sadece server’ın söylediğini çizer.

### PR kapsamı önerisi (küçük ve kanıtlı)
- 1 PR = 1 konu (örn: “Policy role matrix sync + test”).
- Her PR’da en az 1 kanıt:
  - unit/feature test veya
  - açık bir smoke adımı + beklenen çıktı.

## 3) Sapmayı önleyen çalışma protokolü (kısa)
- **Küçük değişiklik**: 1 PR = 1 net amaç
- **Shadow → Enforce**: breaking change direkt enforce edilmez
- **Proof kapısı**: test/smoke/proof bundle olmadan “done” yok
- **Rollback**: her PR’da geri dönüş planı

## 4) “Ne H-OS’ta, ne Pazar’da?” hızlı testi
Bir iş için:
- **Evrensel mi?** (birden çok dünya kullanacak) → H-OS
- **Dünya domain’i mi?** (ticaret/video/mesaj) → ilgili dünya (Pazar vb.)
- **State geçişi mi?** → Contract/FSM
- **Yetki kararı mı?** → Policy
- **Kanıt gerekir mi?** → Proof/Audit

## 5) Kanıt komutları (en az)

### 5.1 Pazar (XAMPP)
```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\proof_bundle.ps1 -BaseUrl "http://localhost/pazar/index.php" -TenantSlug "demo" -IncludeHos -HosBootstrap -HosStopAfter
```

### 5.2 H-OS (Docker Desktop)
```powershell
cd $env:USERPROFILE\Desktop\h-os
.\ops\bootstrap.ps1 -Obs -Web
.\ops\check.ps1 -SkipAuth
```

## 6) “Dokunma listesi” (yüksek risk)
Bu alanlara dokunacaksan ekstra proof şart:
- Auth/refresh token
- Webhook doğrulama/idempotency/terminal state
- DB migrations
- Role matrix / policy rules
- Observability/alerting config

## 7) Yeni ajanın ilk görevi
- Bu dokümanları okudum ✅
- 1 küçük “shadow only” PR açtım ✅ (davranış değişmeden ölçüm/log)


