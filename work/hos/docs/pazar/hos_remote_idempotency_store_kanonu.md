# H-OS Remote Idempotency Store — Kanon (TR)

Amaç: Remote `/v1/contract/transition` gibi kritik mutation endpoint'lerinde **çift çağrı** (retry, network, outbox replay)
olduğunda **tek işlem** yapılmasını garanti etmek.

Bu doküman “in-memory idempotency”yi **kalıcı (DB/Redis)** hale getirmenin kanonik standardıdır.

## 1) Kural (Final)
- `idempotency_key` **zorunludur** (boş/null kabul edilmez).
- Aynı `idempotency_key` ile gelen ikinci istek:
  - aynı **response payload** döndürür
  - aynı **proof_id** döndürür
  - **yan etki üretmez** (status tekrar değişmez, proof tekrar yazılmaz).
- Servis **restart** olsa bile bu garanti bozulmaz.

## 2) Neden kritik?
Pazar tarafında outbox retry yapar. Bu şu demek:
- Remote endpoint aynı olayı 1'den fazla kez görebilir.
- Remote idempotent değilse: **double transition** + **double proof** ile sistem patlar.

## 3) Kanonik key formatı
Key üretimi dünyaya (Pazar) ait olabilir; H-OS sadece uygular.

Öneri (Pazar):
- `pazar:proof:status_change:{proof_id}`

Bu anahtarın avantajı:
- deterministik
- event id’si gibi davranır
- replay güvenli

## 4) Persist seçenekleri
### Seçenek A (önerilen): DB tabanlı idempotency (Postgres/MySQL)
Kalıcı ve basit.

#### Tablo: `hos_idempotency_keys`
Alanlar:
- `id` (pk)
- `key` (string, unique, not null)
- `scope` (string, opsiyonel; ör. `contract.transition`)
- `tenant_id` (int, opsiyonel ama önerilir)
- `status` (string: `completed|failed|processing`)
- `response_json` (json/text) → **dönen response** (proof_id dahil)
- `created_at`, `updated_at`
- `expires_at` (datetime, index) → TTL/cleanup

Unique index:
- `unique(key)`

TTL:
- Öneri: **7 gün**
- `expires_at = now()+7 days`

Cleanup:
- günlük job/cron: `DELETE FROM hos_idempotency_keys WHERE expires_at < now()`

#### Algoritma (atomik)
1) İstek gelir: `(key, tenant_id, scope, request_hash?)`
2) DB transaction başlat
3) `INSERT` dene:
   - başarılıysa: **ilk kez** görüldü → gerçek transition çalıştır
   - unique violation ise: **daha önce işlendi** → mevcut row’u oku ve `response_json` döndür
4) Transition başarılıysa:
   - row’u `status=completed`, `response_json=...` ile güncelle
5) Transition başarısızsa:
   - row’u `status=failed`, `response_json=...` (ok=false + reason) ile güncelle

Not:
- `processing` kilidi istersen: row’u önce `processing` kaydedip kısa bir süre lease ile yönetebilirsin.
- Minimum güvenli sürüm için “completed/failed cache” yeterlidir.

### Seçenek B: Redis tabanlı idempotency (cache+TTL)
Çok hızlıdır ama:
- Redis kalıcı değilse restart/flush riskine dikkat
- Üretimde persistence + replica şart

DB kadar net garantisi yoksa **Seçenek A** tercih edilir.

## 5) Endpoint davranışı (kanonik)
### `/v1/contract/transition`
Input:
- `idempotency_key` zorunlu

Output (örnek):
- `{ ok:true, from:"pending", to:"cancelled", contract_version:"...", proof_id: 123 }`

Idempotency:
- Aynı `idempotency_key` tekrar gelirse **aynen** bu output döner.

## 6) Kanıt testleri (zorunlu)
Minimum test paketi:
1) **Idempotency replay**:
   - aynı key ile 2 çağrı → aynı response/proof_id, tek transition
2) **Restart dayanıklılığı**:
   - “in-memory” değil: DB’de key saklanıyor mu?
   - test: aynı key ile çağrı, sonra yeni process/instance simülasyonu, tekrar çağrı → aynı response
3) **TTL cleanup**:
   - expires_at geçen kayıt siliniyor mu? (unit/job test)

## 7) Riskler
- In-memory idempotency = **yanlış güven** (restart'ta bozulur) → prod’da kabul edilmez.
- TTL çok kısa olursa outbox retry penceresiyle çakışır → event tekrar işlenebilir.

## 8) Done (H-OS hizası)
Bu doküman uygulanınca H-OS “remote contract transition” için Pazar’la tam hizalı sayılır:
- outbox retry güvenli
- double transition yok
- proof tekil


