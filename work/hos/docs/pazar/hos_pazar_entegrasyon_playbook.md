# H-OS ↔ Pazar Entegrasyon Playbook (TR) — Kopmadan, Taş Gibi

Bu doküman “H-OS ayrı repo, Pazar ayrı repo” iken bile iki sistemin **kopmaması** için yazılmıştır.

Hedef: H-OS’a geri döndüğümüzde (yeni gelişiyor olsa bile) herkes aynı soruyu cevaplayabilsin:
- **Pazar bugün H-OS’tan ne bekliyor?**
- **H-OS Pazar’a ne sağlamak zorunda?**
- **Geçişi nasıl yaparız (shadow → enforce) ve sistem nasıl düşmez?**

## 1) 3 Entegrasyon Modu (Kafa karışmasını bitiren seçim)

### Mod-A (Bugün en güvenlisi): Embedded H-OS (Pazar içinde katman)
- Pazar monolith içinde `HosGate` ile **Proof + Contract/FSM** çalışır.
- H-OS ayrı repo **runtime dependency değildir**.
- Avantaj: XAMPP/tek deploy/az risk.
- Kural: Controller’lar **kural yazmaz**; `HosGate::contract()->transition()` kullanır.

### Mod-B (Hybrid): H-OS ayrı servis ama Pazar’da fallback var
- Pazar “remote H-OS”a HTTP ile yazar/okur.
- H-OS down olursa Pazar embedded modda devam eder (kontrollü).
- Avantaj: servise geçiş provası.
- Risk: iki kaynaklı doğruluk; shadow/enforce disiplin ister.

### Mod-C (Full): H-OS ayrı servis ve “kanun” orada
- Policy/Contract/Proof kararları H-OS’tan gelir.
- Pazar sahne kalır, kanun servisleşir.
- Bu moda **ihtiyaç kanıtlanınca** geçilir (erken geçilmez).

> **Kanon öneri:** Şu an Mod-A. Servisleşme için Mod-B ile kademeli geçiş.

## 2) Pazar’ın “H-OS’tan” Beklediği Minimum Sözleşme
Pazar H-OS’tan 3 primitive bekler:

1) **Policy (can)**
- `can(actor, ability, subject, context)` → `allowed / reason / policy_version`

2) **Contract/FSM (transition)**
- `transition(subject, to_status, meta, attrs?)` → `from/to/contract_version`
- Terminal state koruması + idempotency

3) **Proof/Audit (record)**
- `record(kind, payload, meta)` → `proof_id`
- Append-only delil mantığı (silme yok, düzeltme append ile)

Bugün Pazar içinde bu 3’ün “embedded” hali var:
- Proof ✅
- Contract/FSM ✅
- Policy ⏳ (sıradaki faz)

## 3) H-OS’un Pazar’dan Beklediği Minimumlar
H-OS sağlıklı çalışmak için Pazar’dan şunları “garanti” ister:
- Her olayda **tenant_id** zorunlu
- Actor varsa **user_id** zorunlu (webhook gibi yerlerde `null` olabilir)
- Her kritik işlemde **request_id** ve/veya **idempotency_key** önerilir
- Subject tanımı canonical olmalı:
  - `subject_type` (Order/Reservation/Payment)
  - `subject_id`
  - `from_status` / `to_status`
  - `occurred_at`

## 4) Servisleşme Yol Haritası (Kopmadan geçiş)

### Aşama 0 (Bugün): Kuralları Pazar’da kilitle
- Pazar: tüm status geçişleri Contract ile
- Pazar: tüm status proof kayıtları tek kapıdan
- H-OS: doküman/standartlar güncel (bu klasör)

### Aşama 1: Proof’u dışarı yaz (shadow)
- Pazar:
  - `hos.mode=hybrid`
  - “proof event”leri **async** H-OS’a gönder (outbox/job)
  - H-OS başarısızsa Pazar çalışmaya devam (retry)
- H-OS:
  - `POST /v1/proof/record` endpoint
  - idempotency: `idempotency_key` veya `(tenant_id, event_hash)` ile

### Aşama 2: Policy shadow → enforce
- Pazar:
  - kritik aksiyonlarda `policy.can` kararını “logla” (shadow)
  - karar farkı varsa alarm/rapor
  - sonra enforce’a geç
- H-OS:
  - `POST /v1/policy/can`
  - role matrix (ADR/0005) + versiyonlama

### Aşama 3: Contract shadow → enforce
- Pazar:
  - `transition()` çağrılarını remote’a duplikasyonla gönder (shadow)
  - fark yoksa enforce
- H-OS:
  - `POST /v1/contract/transition`
  - terminal state + rollback + versioned contract governance

## 5) Pazar tarafında yapılacaklar (Servisleşmeye hazırlık checklist)
- **Config**: `HOS_BASE_URL`, `HOS_MODE=embedded|hybrid|remote`, `HOS_API_KEY`, timeouts
- **Client**: retry/backoff + circuit breaker (en azından timeout+retry)
- **Outbox**: `hos_outbox_events` tablosu + worker
- **Feature flags**: shadow/enforce
- **Metrics**: “remote hos latency/error rate” ölç

## 6) H-OS tarafında yapılacaklar (Pazar ile uyum checklist)
- **Auth**: API key/JWT ile servis auth (Pazar → H-OS)
- **Idempotency**: replay safe endpoint’ler
- **Proof store**: append-only audit + (opsiyonel) hash chain
- **Versioning**: `/v1` + `policy_version/contract_version/proof_version`
- **SLO**: /health /ready + error budget

## 7) Kopma olursa ne olur? (Fallback kuralı)
Bu bölümün kanonik detayları: `docs/tr/hos_remote_failover_politikasi.md`

Özet (en güvenli kanon):
- **Kritik mutation** (para/iptal/status geçişi): remote authoritative ise **fail-closed (503)**.
- **Read-only**: degrade (boş allowed-actions veya embedded kaynaklı görüntüleme).

Mod-B hedefi “Pazar hiç durmasın” olsa bile, kritik mutation’da doğruluk önceliklidir.

## 9) Hybrid → Remote “Hazır mıyız?” (ölçülebilir eşikler)
Bu bölüm “drift≈0” gibi soyut ifadeleri ölçülebilir hale getirir.

### 9.1 Zorunlu kanıtlar (merge gate)
- **Kritik endpoint coverage**: kritik mutation method’larında `checkEnforce()` var mı?
  - Test: `HosCriticalMutationEndpointsHavePolicyGateTest` (yeşil olmalı)
- **Failover kanonu**: `docs/tr/hos_remote_failover_politikasi.md` ile uyumlu
  - read-only degrade
  - kritik mutation fail-closed 503

### 9.2 Hybrid ölçüm eşikleri (remote canary açmadan önce)
Minimum eşikler (öneri):
- **Policy drift**: son 7 günde **0** (`hos.remote.shadow.policy_drift`)
- **Contract drift**: son 7 günde **0** (`hos.remote.shadow.contract_drift`)
- **Outbox backlog**:
  - pending+processing toplamı: **< 100**
  - en eski pending event yaşı: **< 5 dakika**
- **Outbox DLQ (failed)**: **0** (aksi halde idempotency/endpoint bug var)

### 9.3 Remote performans eşikleri (remote authoritative açmadan önce)
- **Health**: `/health` 200 ve sürekli erişilebilir (SLO hedefi: 99.9%)
- **Latency**: p95 < **300ms** (ilk hedef), p99 < **800ms**
- **Error rate**: < **0.1%** (5xx/timeouts)

### 9.4 Rollout (en güvenli sıra)
1) `HOS_MODE=hybrid` → sadece ölçüm (davranış embedded)
2) Remote “gate” canary:
   - policy decide (kritik mutation) + contract can-transition
3) Contract transition shadow + outbox retry (event delivery stabil)
4) `HOS_MODE=remote` (authoritative) → kademeli tenant/% canary + rollback hazır

## 8) “Done” (iki taraf da biliyor mu?)
- H-OS ekibi/ajanı bu dokümandaki checklist’leri okuyunca:
  - hangi endpoint’leri neden yapacağını bilir
  - Pazar’ın ne beklediğini bilir
- Pazar ekibi/ajanı:
  - servisleşmeye geçince hangi adımları atacağını bilir





