# FOUNDING CHARTER — H-OS

Bu doküman H-OS’un “kurucu sözleşmesi”dir: **neden varız**, **ne inşa ediyoruz**, **ne inşa etmiyoruz**, ve **başarıyı nasıl ölçeceğiz**.

## Document Control (Kurumsal kontrol)
- **Belge sahibi**: Maintainers / Core Team
- **Durum**: Active
- **Versiyon**: v0
- **Son güncelleme**: 2025-12-25
- **Gözden geçirme periyodu**: her major milestone veya ayda 1
- **Onay**: Maintainers (repo owner)

### Versiyon geçmişi
| Versiyon | Tarih | Değişiklik | Onay |
|---|---|---|---|
| v0 | 2025-12-25 | İlk kurumsal charter şablonu + repo gerçekleriyle hizalama | Maintainers |

### Sponsor / Sahiplik (placeholder)
> Kurumsal kullanımda aşağıdaki alanları kurumunuza göre doldurun.
- **Sponsor (Executive Sponsor)**: TBD
- **Ürün sahibi (Product Owner)**: TBD
- **Teknik lider (Tech Lead)**: TBD
- **Operasyon sahibi (Ops/On-call)**: TBD

## 1) Problem Tanımı / Bağlam
Platform kuran ekipler, her projede tekrar eden çekirdek ihtiyaçlar için zaman kaybeder:
- Kimlik & oturum (auth)
- Tenant izolasyonu (multi-tenant)
- Audit / güvenlik izi
- Gözlemlenebilirlik (metrics/tracing/alerts)
- Operasyonel ergonomi (start/stop/check/backup/restore)

## 2) Amaç (Mission)
H-OS, internette ürün/servis inşa eden ekiplerin tekrar tekrar çözdüğü “platform çekirdeği” problemlerini standardize eder.

## 3) Vizyon
H-OS, farklı internet projeleri için tekrar kullanılabilir “platform-işletim sistemi çekirdeği” sağlar: güvenli, gözlemlenebilir, operasyonu kolay, tenant izolasyonu net.

## 4) Kapsam (In / Out)

### In-scope (şu an)
- **Çekirdek**: `services/api` + Postgres
- **Çalıştırma**: Docker Compose + ops PowerShell script’leri
- **Gözlemlenebilirlik (opsiyonel)**: Prometheus + Grafana + Alertmanager + Tempo + Otel Collector

### Out-of-scope (şimdilik)
- UI/Frontend (ayrı servis/milestone)
- Multi-region HA, autoscaling, K8s gibi ileri orchestration
- Fine-grained ABAC/policy engine

## 5) Deliverables (Somut çıktılar)
- Versiyonlu API (`/v1/...`) ve geriye uyumluluk (deprecation yaklaşımı)
- Tenant + kullanıcı + oturum (auth) temeli
- RBAC (owner/admin/member) temeli
- Tenant-scope audit log
- Prometheus metrics endpoint’i + Grafana dashboard provisioning
- Alerting/observability stack (opt-in profile)
- Ops script’leri: `bootstrap`, `check`, `smoke`, `stop`, `backup`, `restore`
- Release checklist: `RELEASE.md`

## 6) İlk MVP / “İlk Bitiş” (BIFK) — Success Criteria
Bu milestone “tamamlandı” demek için:
- `.\ops\bootstrap.ps1 -Obs` çalışır (tek komutla start)
- `.\ops\check.ps1 -SkipAuth` **OK** döner (tek komutla doğrulama)
- CI içinde `compose-smoke` (env + secrets) başarılıdır

## 7) Paydaşlar, Roller, Sorumluluklar (özet)
- **Maintainers / Core Team**: tasarım kararları, merge, release, güvenlik triage
- **Operators (self-host)**: `.env`/secrets yönetimi, deploy, backup/restore, monitoring
- **Contributors**: feature/bugfix + test/doküman katkısı

## 8) Yönetişim (Governance) & Karar Mekanizması
- Tasarım kararları: PR + review + gerekirse `WORKLOG.md` notu
- Breaking değişiklik: `/v1` sözleşmesi ve migration gate ile kontrollü
- Risk takibi: `RISK_REGISTER.md` güncel tutulur

## 9) Varsayımlar / Kısıtlar
- Windows 10/11 + Docker Desktop hedeflenir (ops scriptleri PowerShell).
- Postgres tek instance (local/dev öncelikli); prod için “prod-benzeri” ayarlar mevcut.
- Observability stack default kapalı (compose profile), istenince açılır.

## 10) Ana Riskler (kurumsal özet)
- Secret/env mod karışıklığı → DB auth mismatch (28P01) / restart loop
- Tenant izolasyonu hatası → veri sızıntısı (sev-1)
- Grafana default/anon açık kalması → prod risk
- Loglarda secret/PII sızıntısı riski → redact zorunlu

## 11) Güvenlik ve Operasyon Standardı (prod yaklaşımı)
- `docker-compose.prod.yml`: daha güvenli varsayılanlar (Grafana anonymous kapalı, `COOKIE_SECURE=true`).
- Secrets: `docker-compose.secrets.yml` + `secrets/*.txt` (gitignore).
- Deploy öncesi/sonrası: `RELEASE.md` checklist.

## 12) Prensipler
- **Güvenlik varsayılanı**: secret’lar mümkünse dosya/secrets, loglarda redaction, cookie güvenliği (`COOKIE_SECURE`).
- **Tenant izolasyonu**: tüm kritik okuma/yazmalar tenant-scope olmalı; cross-tenant sızıntı sev-1 bug.
- **Sözleşme disiplini**: versiyonlu API (`/v1/...`) + deprecation.
- **Operasyonel ergonomi**: reboot/bağlantı kopması durumunda bile tek komutla durum görülebilmeli (`ops/check.ps1`).
- **Gözlemlenebilirlik**: metrics/traces/alerts opt-in ama hazır.
- **Deterministik build**: lockfile + CI gate + migration gate.

## 13) Change Control (Değişiklik yönetimi)
- Bu charter değişirse:
  - PR açılır, neden/etki yazılır
  - Success criteria / scope değişiyorsa `STATUS.md` ve `RELEASE.md` güncellenir

## 14) Referans dokümanlar (tek kaynaklar)
- Başlangıç (non-technical): `KULLANIM_KILAVUZU.md`
- Teknik kurulum/troubleshooting: `RUNBOOK.md`
- Ops komutları: `ops/README.md`
- Release checklist: `RELEASE.md`
- Günlük/karar kaydı: `WORKLOG.md`
- Repo durumu: `STATUS.md`

## 15) Milestones (yüksek seviye)
- **M0 (şimdi)**: Local dev + obs + secrets + CI smoke gate (env+secrets)
- **M1 (sonraki)**: Üretim deploy rehberi + hardening (reverse-proxy, domain, TLS, cookie policy), ops otomasyonu
- **M2 (sonraki)**: API sözleşmesi genişleme + data model evrimi + daha kapsamlı RBAC/audit

## 16) RACI (kurumsal rol matrisi, özet)
| Aktivite | Responsible | Accountable | Consulted | Informed |
|---|---|---|---|---|
| Charter güncelleme | Maintainers | Sponsor/PO (TBD) | Operators | Contributors |
| Release (deploy) | Operators | Maintainers | Maintainers | Stakeholders |
| Incident triage | Operators | Ops/On-call (TBD) | Maintainers | Stakeholders |
| Güvenlik açığı yönetimi | Maintainers | Maintainers | Operators | Stakeholders |

## 17) İletişim Planı (minimum)
- **Değişiklik duyuruları**: PR açıklaması + `WORKLOG.md` (gerekirse `STATUS.md`)
- **Release notları**: `RELEASE.md` checklist + ilgili PR/commit referansı
- **Incident**: `RELEASE.md` “Incident hızlı akış” + (varsa) Alertmanager/Grafana uyarıları

## 18) Bağımlılıklar ve Entegrasyonlar
- **Docker / Docker Compose** (çalıştırma standardı)
- **Postgres** (primary datastore)
- **Prometheus/Grafana/Alertmanager/Tempo** (opsiyonel obs profili)
- **Google OAuth** (opsiyonel; yapılandırma yoksa API 501 döner)
