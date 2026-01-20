# Ölçeklenebilirlik Planı (TR) — “Pazar patlamasın”

Bu doküman “sistem çalışacak mı, gerçekten büyüyebilir mi?” sorusunu pratik ve kanıtlanabilir adımlarla yanıtlar.

## 1) Gerçek: “Sınırsız” diye bir şey yok
Hiçbir ürün **sonsuz** büyümez. Ama doğru mimariyle şu yapılır:
- **Büyüme tavanını** sürekli yukarı taşırız (DB, cache, kuyruk, yatay ölçek, bölme).
- “Patlama” riskini azaltırız (kural tek yerde, kanıt tek yerde, terminal state, idempotency, guard).

## 2) Pazar tek başına ne kadar taşır?
Pazar (tek repo/monolith) şu koşullarda **çok büyük** hacimlere kadar gider:
- DB indeksleri doğru
- yazma işlemleri kuyruklanıyor (queues)
- cache var (read-heavy endpoint’lerde)
- ödeme/webhook idempotent + terminal state korumalı
- observability var (metric/log/trace)

Bu “microservice şart” demek değildir. Microservice **son çaredir**.

## 3) Patlama sebepleri ve kilitler
Patlama sebepleri:
- Kurallar controller’lara dağılır
- Status geçişleri her yerde farklı uygulanır
- Kanıt/audit parçalanır
- Webhook/ödeme akışları “resurrect” eder

Kilitler:
- **H-OS Proof**: tüm kritik olaylar tek deftere akar
- **H-OS Contract/FSM**: tüm status geçişleri tek merkezde kurallıdır
- **H-OS Policy**: “kim neyi yapabilir” tek kanundur (bir sonraki faz)

## 4) Aşamalar (en mantıklı ilerleme)
### Aşama A — Monolith’i güçlendir (şimdi)
- Proof ve Contract/FSM tekleştir (yapıldı)
- Policy kanunu ekle (owner/staff/superadmin + müşteri yetkileri)
- Kuyruk: mail/notification/webhook işleme/rapor üretimi background
- Cache: ürün listeleme / vitrin sayfaları / kategori filtreleri

### Aşama B — Yatay ölçek (prod)
- 1’den fazla PHP worker + load balancer
- DB için read-replica (okuma yükünü ayır)
- file/session için merkezi store (Redis)

### Aşama C — Büyük hacim teknikleri
- Partitioning (özellikle `reservations`, `payments`, `status_change_logs`)
- Tenant bazlı bölme (çok büyük tenant’lar için ayrı DB/cluster)
- Search (ürün arama) için ayrı arama motoru (OpenSearch/Meilisearch)

### Aşama D — H-OS servisleşmesi (sadece gerekirse)
Ne zaman? Kanıtlanmış ihtiyaç:
- Audit/Proof tek başına devasa büyür
- Identity/Policy çok sayıda dünya tarafından tüketilir
O zaman H-OS ayrı servis olabilir, Pazar sahne olarak kalır.

## 5) Kanıt (Proof) ile ilerleme standardı
“Hata yapmadan ilerleme” için her adım:
- Test: `php artisan test`
- Smoke: `docs/smoke_test.ps1`
- Postman Runner: Local + Hourly Quickstart
- Proof bundle: `docs/proof_bundle.ps1`

## 6) Docker / Kubernetes şimdi gerekli mi?
Local XAMPP teslim hedefinde:
- Docker **şart değil**
- Kubernetes **şimdilik açma** (karmaşıklık ve risk)
Ölçek ihtiyacı doğunca prod için değerlendiririz.





