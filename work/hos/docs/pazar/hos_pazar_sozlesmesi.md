# H-OS ↔ Pazar Sözleşmesi (TR) — Tek Kaynak, Tek Gerçek

Bu doküman **Pazar** ile **H-OS** arasındaki sınırları ve beklentileri “tek gerçek sözleşme” olarak kilitler.

Amaç: İki proje ayrı da olsa, entegre de olsa **karışmadan**, **patlamadan**, **taş gibi** ilerlemek; ayrıca H-OS’u geliştiren ajan/ekiplerin “neden ne yaptığını” her an bilmesini sağlamak.

## 0) Kanonik Tanım
- **Pazar = Ticaret sahnesi** (ürün/sipariş/rezervasyon/ödeme/vitrin/panel)
- **H-OS = Evren hukuku** (kimlik/yetki/policy/sözleşme geçerliliği/kanıt/audit/güven/evrensel yasaklar)

Bu iki tanım **değiştirilemez**; değişirse sistem tekrar “site” olur ve büyüdükçe patlar.

## 1) Sınırlar (Nerede ne biter?)

### Pazar’ın sahibi olduğu domain
- Ürün, kategori, stok
- Sipariş, rezervasyon (günlük/saatlik)
- Ödeme niyeti (intent), ödeme kaydı (payment), checkout akışı
- Takvim görünümü / vitrin / müşteri ekranı / firma paneli
- Tenant (firma) vitrini ve tenant-scoped kurallar (stok, ürün görünürlüğü)

### H-OS’un sahibi olduğu “evrensel” domain
- **Identity**: tekil kişi/kurum kimliği, doğrulamalar
- **Canonical Role Law**: rol modeli, yetki kanunları (owner/staff/superadmin vs)
- **Policy Engine**: “bu kişi bunu yapabilir mi?”
- **Contract Engine (FSM)**: “bu sözleşme bu statüye geçebilir mi?”
- **Proof/Audit**: kanıt üretimi (mahkemeye uygun delil ilkeleri)
- **Registry**: evrensel yasaklar / kara liste / güven kuralları
- **Dispute evidence**: uyuşmazlıkta delil paketleri (ileride)

## 2) Pazar’ın H-OS’tan Beklentileri
Pazar, H-OS’a şunu “sorar” ve “alır”:

- **Yetki kararı**
  - `can(actor, ability, subject)`
  - Örn: “staff ürün silebilir mi?”, “müşteri rezervasyon iptal edebilir mi?”

- **Sözleşme geçişi**
  - `contract(subject)->transition(to, meta, attrs?)`
  - Tek merkezden status kuralları + terminal state + idempotent davranış

- **Kanıt kaydı**
  - Her kritik olay tek deftere: status değişimleri, ödeme sonucu, iptal, webhook sonucu
  - Pazar controller’ı “kanıt formatı” üretmez; sadece H-OS’a “olayı” bildirir

- **Webhook gate**
  - İmza/timestamp doğrulama standardı, replay protection, idempotency

## 3) H-OS’un Pazar’dan Beklentileri
H-OS’un doğru çalışması için Pazar şunları sağlamalı:

- **Kanonik domain olayları**
  - H-OS’a “ne oldu?” net ve tek biçimde bildirilir (status değişimi, ödeme sonucu, iptal, onay)

- **Deterministik kimlik/tenant bilgisi**
  - Her işlemde `tenant_id` ve mümkünse `actor(user_id)` net olmalı

- **Değişmez audit kuralı**
  - Kritik state değişimi “kanıtsız” kalamaz
  - Kayıt silme yok; gerekiyorsa “düzeltme (append-only)” var

## 4) Entegrasyon Şekli (Bugün ve Yarın)

### Bugün (en güvenlisi)
Tek repo içinde “H-OS katmanı”:
- Proof + Contract/FSM Pazar içinde çalışır
- Tek deploy, tek DB, düşük risk
- Kurallar tek yerde kilitlenir

### Yarın (ihtiyaç kanıtlanınca)
H-OS ayrı servis olabilir:
- Pazar → H-OS API (policy/contract/proof)
- Event outbox + async proof ingestion (yük artınca)

**Kural:** Ayrı servise geçiş “performans ihtiyacı kanıtlanınca” yapılır, erken yapılmaz.

## 5) API / Event Sözleşmesi (taslak)
Bu bölüm H-OS ayrı servis olursa “bağlanma formatı”dır.

### 5.1 Policy API (taslak)
- `POST /v1/policy/can`
  - input: `{tenant_id, actor_id, ability, subject_type, subject_id, context}`
  - output: `{allowed: boolean, reason?: string, policy_version: string}`

### 5.2 Contract API (taslak)
- `POST /v1/contract/transition`
  - input: `{tenant_id, actor_id, source, subject_type, subject_id, to_status, attrs?, idempotency_key}`
  - output: `{ok: boolean, from_status, to_status, proof_id, contract_version}`

### 5.3 Proof API (taslak)
- `POST /v1/proof/record`
  - input: `{tenant_id, actor_id, source, kind, payload, occurred_at, hash_chain?}`
  - output: `{proof_id}`

## 6) Versiyonlama ve Değişiklik Yönetimi (Patlamayı engelleyen kural)
- **Sözleşme versiyonu**: `hos_contract_version` (örn. `2025-12-28`)
- **Policy versiyonu**: `hos_policy_version`
- **Breaking change kuralı**:
  - Yeni davranış önce **feature-flag** ile gelir
  - 2 aşama: “shadow mode” (yalnız ölç, karar verme) → “enforce mode”
  - Doküman güncellenmeden PR merge edilmez

## 7) Ajanlar için “Kilit Kurallar” (H-OS’a geçince herkes aynı dili konuşsun)
H-OS’u geliştiren ajan/ekip:
- **Controller kural yazmaz** hedefini bilir
- “Policy / Contract / Proof” üçlüsünü korur
- Her yeni iş için şu sorular cevaplanır:
  - **Neden H-OS?** (evrensel mi, yoksa Pazar domain mi?)
  - **Hangi sözleşmeyi etkiliyor?** (contract/policy/proof)
  - **Kanıt nasıl üretilecek?** (proof kind + payload)
  - **Geriye uyumluluk**: eski istemciler bozulur mu?

Pazar’ı geliştiren ajan/ekip:
- Kritik state değişimini **sadece** `contract()->transition()` ile yapar
- Yetki kararını **sadece** `policy()->can()` ile sorar (bir sonraki faz)
- Webhook doğrulamasını standarttan sapmadan uygular

## 8) “Done” Kriterleri (H-OS’a geçtik mi?)
Bir fazın “tamam” sayılması için:
- Status değişimleri tek kapı (Contract) ✅
- Kanıt tek kapı (Proof) ✅
- Yetki tek kanun (Policy) ⏳ (sonraki)
- Doküman güncel ✅
- Testler yeşil ✅





