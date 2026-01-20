# H-OS Repo Haritası (TR) — “Yanlış müdahale olmasın”

Bu doküman `Desktop\\h-os` reposunun **ne nerede** olduğunu tek sayfada anlatır.
Amaç: H-OS’a müdahale eden (ajan/ekip) kim olursa olsun, **gereksiz/yanlış dokunuş yapmasın**.

## 1) Kök dosyalar (repo root)
- **`FOUNDING_CHARTER.md`**: kurucu sözleşme / kapsam
- **`KULLANIM_KILAVUZU.md`**: tek sayfa hızlı başlangıç
- **`RUNBOOK.md`**: teknik kurulum/troubleshooting
- **`ROADMAP.md`**: “tek kaynak” plan
- **`STATUS.md`**: repo’nun güncel durumu
- **`RISK_*`**: risk yönetimi
- **`SECURITY.md`**, **`SLO.md`**, **`NOTIFICATION_STANDARD.md`**: ops güvenlik/slo/alert standartları
- **`docker-compose*.yml`**: stack bileşenleri (api/web/proxy/obs/secrets/ports/prod/lockdown)

## 2) `services/` (çalışan sistem)

### 2.1) `services/api`
Platform çekirdeği (Fastify):
- Tenant + kullanıcı + auth temeli
- `/health`, `/ready`, `/metrics` gibi endpoint’ler
- DB migrasyonları: `services/api/migrations/*.sql`
- Kod: `services/api/src/*`
- Testler: `services/api/test/*`

**Dikkat**: Bu servis “evrensel kimlik/çekirdek” rolünde; Pazar gibi dünyalar buradan beslenecek şekilde tasarlanmalı.

### 2.2) `services/web`
Minimal admin UI (Vite+React, nginx):
- UI: `http://localhost:3002` (compose ile)
- `/api/*` reverse-proxy (CORS’suz)

### 2.3) `services/proxy`
Reverse proxy (Caddy):
- Prod-benzeri “tek giriş” yaklaşımı için

### 2.4) `services/observability`
Grafana/Prometheus/Loki/Tempo/Otel collector + Alertmanager:
- dashboard & alert standardı burada

## 3) `ops/` (operasyon)
PowerShell operasyon scriptleri:
- **`bootstrap.ps1`**: stack’i başlat (web/obs/proxy/secrets/prod varyantları)
- **`check.ps1`**, **`smoke.ps1`**: doğrulama
- **`proof.ps1`**: kanıt çıktısı üretir
- **backup/restore**, **alerts**, **harden_check** vb.

## 4) `docs/adr/` (mimari karar hafızası)
ADR’ler: versiyonlama, refresh token rotasyonu, secrets standardı, contract governance, role matrix, SLO/alerting.

## 5) `docs/pazar/` (Pazar entegrasyon paketi)
Pazar ile H-OS’un kopmaması için otomatik export edilen dokümanlar:
- manifesto (Pazar ilk dünya)
- sözleşme (beklentiler/sınırlar)
- entegrasyon playbook
- SSO standardı
- policy kanunu
- ölçek blueprint

## 6) “Dokunmadan önce” kuralları (kısa)
- H-OS’ta “evrensel” olmayan domain’i ekleme (dünya verisini H-OS’a taşıma).
- Her değişiklik: **küçük**, **geri alınabilir**, **proof/test** ile kanıtlı olmalı.
- Prod değişikliği: shadow→enforce geçişi ve rollback planı olmadan yapılmaz.





