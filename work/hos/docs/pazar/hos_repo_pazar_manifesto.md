# H-OS ↔ Pazar Manifestosu (H-OS Repo İçin) — “Pazar ilk dünya”

Bu dosya **H-OS** projesinin içine konmak için yazılmıştır.

Amaç: H-OS’u geliştiren herkesin (ajan/ekip) **Pazar’ın varlığını**, entegrasyon gerekliliklerini, H-OS’un amacını ve Pazar’ın amacını **tek bakışta** bilmesi. Böylece iki sistem **tertemiz kalıp gibi**, karışmadan, patlamadan ilerler.

---

## 1) Kanonik Karar (Kilit)
- **H-OS = Evren Hukuku (Platform Katmanı)**  
  “Bu evrende ne yapılabilir / kim neyi yapabilir / ne kanıttır / ne geçerlidir?” sorularının cevabı.
- **Pazar = Ticaret Sahnesi (İlk Dünya)**  
  Ürün satma + rezervasyon/kiralama + ödeme + vitrin + panel.

> **Kanon:** “H-OS sınırsız dünya taşır. Pazar, H-OS’un ilk dünyasıdır.”

---

## 2) Sınırlar (Karışmayı engelleyen net çizgi)

### Pazar’ın sahibi olduğu alanlar (Domain)
- Ürün, kategori, stok
- Sipariş (order)
- Rezervasyon/kiralama (reservation) — günlük/saatlik
- Ödeme akışı (payment intent / payment / checkout)
- Tenant (firma) vitrini + müşteri ekranı + firma paneli
- Takvim görünümü / rezervasyon uygunluk UX’i

### H-OS’un sahibi olduğu alanlar (Universal)
- **Identity**: kişi/kurum kimliği, doğrulamalar
- **Canonical Role Law**: rol/yetki kanunu (owner/staff/superadmin vb.)
- **Policy Engine**: `can(actor, ability, subject)`
- **Contract Engine (FSM)**: status geçişleri (geçerlilik/terminal state/idempotency)
- **Proof/Audit**: kanıt üretimi, delil standardı (append-only prensip)
- Registry: kara liste/evrensel yasaklar/güven kuralları
- Dispute Evidence: uyuşmazlık delil paketleri (ileride)

**Kural:** Pazar “ticaret yapar”, H-OS “ticareti denetler”.

---

## 3) Entegrasyon hedefi (teknik netlik)
Pazar, H-OS’a üç şey için bağlanır:

1) **Policy** (Yetki kararı)  
   “Bu kişi bunu yapabilir mi?”

2) **Contract/FSM** (Sözleşme/statü geçişi)  
   “Bu işlem geçerli mi? Bu statüye geçebilir mi?”

3) **Proof/Audit** (Kanıt üretimi)  
   “Bu olay delil midir? Tek deftere yaz.”

---

## 4) Bugün/Şimdi: En güvenli çalışma şekli
Local / ilk teslim / hızlı iterasyon için:
- Pazar monolith içinde **H-OS katmanı** (kütüphane gibi) çalışır.
- Tek deploy, tek DB, düşük risk.

Bu repo’da zaten bu yaklaşımın “Pazar tarafı” başlatılmıştır:
- Proof: status değişimleri tek kapıdan
- Contract/FSM: order/reservation/payment status geçişleri tek kapıdan

> Not: H-OS ayrı servisleşme “ihtiyaç kanıtlanınca” yapılır; erken yapılmaz.

---

## 5) H-OS servisleşirse (taslak API sözleşmesi)
Bu bölüm H-OS’u ayrı repo/servis olarak yürütürken Pazar’ın ne bekleyeceğini standartlar.

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

---

## 6) Versiyonlama / Breaking change kuralı (ajanlar için kilit)
- Her değişiklik **versiyon** taşır:
  - `hos_policy_version`
  - `hos_contract_version`
  - `hos_proof_version`
- Breaking change süreci:
  - önce **shadow mode** (ölç, karar verme)
  - sonra **enforce mode** (kural uygula)
  - bu dosya güncellenmeden “merge” olmaz

---

## 7) H-OS ajanı “ne yapmalı, neden yapmalı?”
Bir iş H-OS’a alınacaksa aşağıdaki testten geçmeli:

- **Evrensel mi?**  
  Birden fazla dünya (Pazar gibi) bunu kullanacak mı?
- **Kural mı?**  
  Yetki/kanıt/geçerlilik/terminal state gibi “kanun” mu?
- **Sözleşme etkisi var mı?**  
  Status geçişi / iptal / iade / ceza gibi “FSM” alanı mı?
- **Kanıt formatı net mi?**  
  Hangi proof kind? payload neleri içerir?

Eğer cevaplar “evet” ise H-OS; değilse Pazar domain’inde kalır.

---

## 8) Tek cümle özet
**Pazar sahnedir; H-OS kanundur.**  
Sahne değişir, kanun kalır. Kanun tek olursa dünya sınırsız büyür.





