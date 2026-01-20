# Küresel Ölçek Blueprint (TR) — “7 milyar insan” hedefi için gerçekçi yol

Bu doküman “7 milyar insan rahatça kullanabilsin” hedefini **hayal değil**, **mühendislik planı** olarak çerçeveler.

> Not: Hiçbir sistem “tek sunucu / tek DB” ile 7B kullanıcı taşımaz. Taşıyan şey: **doğru sınırlar + yatay ölçek + veri ayrımı + kademeli servisleşme**.

## 1) Kanonik ayrım (patlamayı engelleyen temel)
- **H-OS = Evren (Kimlik + Yetki + Kanıt + Sözleşme Kanunu)**
- **Pazar = Dünya (Ticaret sahnesi: ürün/sipariş/rezervasyon/ödeme)**
- **Yeni dünyalar** (video/mesajlaşma) kendi DB’sini taşır; Pazar DB’sine girmez.

## 2) “7B” için 3 büyük kural
- **Kural-1: Veri doğru yerde durur**
  - Video: object storage + CDN + metadata DB (ayrı)
  - Mesaj: event/queue + hızlı write/read store (ayrı)
  - Pazar: sipariş/rezervasyon tutarlılığı için transaction-heavy DB (ayrı)
- **Kural-2: Kanun tek yerde durur**
  - Policy / Contract / Proof H-OS’ta (veya en azından tek kanun katmanında)
- **Kural-3: Tenant izolasyonu first-class**
  - Tenant bazlı index/partition/shard stratejisi

## 3) Aşamalar (kademeli, kopmadan)

### Aşama A (Bugün): Monolith’i “patlamaz” yap
- Proof tek kapı ✅
- Contract/FSM tek kapı ✅
- Policy shadow/enforce ✅ (shadow aktif)
- Rate-limit, request-id, idempotency, terminal state ✅

### Aşama B: Kuyruk + Cache
- Queue: ödeme sonrası işlemler, bildirim, rapor, outbox event’leri
- Cache: ürün listeleme, vitrin sayfaları, kategori filtreleri
- Session/cache merkezi store: Redis (prod)

### Aşama C: Yatay ölçek
- 2+ PHP worker + load balancer
- DB read-replica (okuma yükü)
- CDN (statik) + image optimization

### Aşama D: Büyük tablo stratejileri (milyarlarca kayıt)
- Partitioning:
  - `payments`, `reservations`, `status_change_logs`
- Hot tenant ayrımı:
  - “çok büyük tenant” → ayrı DB/cluster (tenant sharding)
- Search engine:
  - ürün arama ayrı (OpenSearch/Meilisearch)

### Aşama E: H-OS servisleşmesi (ihtiyaç kanıtlanınca)
H-OS ayrı servis olur:
- `/v1/policy/can`
- `/v1/contract/transition`
- `/v1/proof/record`
Geçiş kuralı:
- shadow → enforce
- fallback: H-OS down olursa Pazar durmaz (hybrid mod)

## 4) SLO/Observability (7B için şart)
Ölçmeden ölçek olmaz.
- SLO: p95 latency, error rate, webhook ack time
- Metrics: request rate, queue lag, DB slow queries
- Logs: request-id ile korelasyon
- Alerts: “policy shadow denies spike”, “webhook failures”, “queue lag”

## 5) Güvenlik/KVKK (küresel kullanım için minimum)
- KVKK/Privacy: açık rıza, aydınlatma, silme/anonimleştirme süreçleri
- Audit/Proof: append-only, delil standardı
- Secrets: env/secrets standardı (H-OS ops)
- Rate limiting / abuse protection

## 6) Sonuç (gerçekçi taahhüt)
“7B kullanıcı” hedefi:
- **Tek ürün değil**, **platform + dünyalar** yaklaşımıyla mümkündür.
- Pazar “dünya” olarak şişmez; video/mesaj gibi büyük veriler kendi dünyasında taşınır.
- H-OS “evren kanunu” ile dünyaları birleştirir: tek hesap (SSO), tek rol kanunu, tek delil standardı.





