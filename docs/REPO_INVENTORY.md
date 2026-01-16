# REPO INVENTORY (2026-01-07)

Bu envanter, repo temizleme ve standartlaştırma çalışması için hazırlanmıştır.

## KEEP (Kod, Doküman, Ops)

### Kod
- `work/hos/` - H-OS servisi (Node.js API + Web)
- `work/pazar/` - Pazar servisi (Laravel PHP)

### Dokümanlar
- `work/hos/docs/` - H-OS dokümantasyonu
- `work/pazar/docs/` - Pazar dokümantasyonu
- `work/pazar/docs/runbooks/` - Operasyon runbook'ları
- `work/pazar/WORLD_REGISTRY.md` - Canonical world registry

### Ops
- `work/hos/ops/` - H-OS operasyon scriptleri
- `work/pazar/ops/` - Pazar operasyon scriptleri (varsa)

### Config
- `work/hos/config/` - H-OS config dosyaları
- `work/pazar/config/` - Pazar config dosyaları
- `work/hos/services/` - H-OS servis tanımları
- `work/pazar/docker/` - Pazar Docker config

### Canonical Entry Points
- `docker-compose.yml` (root) - **CANONICAL** compose (hos + pazar birlikte)
- `work/hos/docker-compose.yml` - H-OS standalone compose (ops için)

## ARCHIVE (Scratch, Eski Kopyalar, Runtime Çıktıları)

### Dış/Scratch Dosyalar
- `work dışındakler/` - **TÜM KLASÖR** (root dışı scratch dosyalar)
  - `_compose_rendered.yml`
  - `_dbscan_run.ps1`
  - `_test_form.html`
  - `check_cache.php`
  - `cookies.txt`
  - `docker-compose.override.yml`
  - `docker-compose.yml`
  - `docker-compose.yml.bak-20260105-122828`
  - `headers.txt`
  - `seed_demo.sql`
  - `test_control_center.sh`

### Root Scratch Dosyalar
- `_compose_rendered.yml` - Render çıktısı
- `_dbscan_run.ps1` - Scratch script
- `_test_form.html` - Test dosyası
- `check_cache.php` - Scratch script
- `cookies.txt` - Runtime çıktı
- `headers.txt` - Runtime çıktı
- `seed_demo.sql` - Scratch SQL
- `test_control_center.sh` - Scratch script
- `docker-compose.yml.bak-20260105-122828` - Eski compose backup

### Diag/Test Klasörleri
- `_diag/` - Diagnostic çıktıları
- `_ops/` - Scratch ops notları

### OIDC Runtime Artifacts
- `work/hos/oidc_*.txt` - OIDC test çıktıları (6 dosya)
- `work/hos/oidc_*.json` - OIDC JSON çıktıları (3 dosya)
- `work/hos/pazar_oidc_*.txt` - Pazar OIDC test çıktıları (5 dosya)
- `work/hos/pazar_oidc_discovery.json` - OIDC discovery çıktısı

### Proof Runtime Artifacts
- `work/hos/proof_*.txt` - Proof çıktıları (8 dosya)
- `work/hos/proofs/` - Proof klasörü (içindeki tüm dosyalar)
- `work/pazar/proofs/` - Pazar proof klasörü (içindeki tüm dosyalar)

### Compose Backup Dosyalar
- `docker-compose.yml.bak-20260105-122828` (root)
- `work dışındakler/docker-compose.yml.bak-20260105-122828`

### Backup Klasörü
- `_backup/` - Zaten arşiv klasörü (mevcut backup'lar)

## SENSITIVE (Secret, Token, Cookie, Headers)

### Secrets (Gerçek Değerler)
- `work/hos/secrets/*.txt` - **GERÇEK DEĞERLER** (repo'da kalmamalı)
  - `db_password.txt`
  - `jwt_secret.txt`
  - `database_url.txt`
  - `google_client_id.txt`
  - `google_client_secret.txt`
  - `google_redirect_uri.txt`

### Runtime Secrets
- `cookies.txt` - Cookie değerleri (archive'a gidecek)
- `headers.txt` - Header değerleri (archive'a gidecek)

### .env Dosyaları
- `work/pazar/.env` - Eğer varsa, gerçek değerler içeriyor (repo'da kalmamalı)
- `work/pazar/docs/env.example` - ✅ Zaten example (KEEP)

## Canonical Girişler

### Docker Compose
- **CANONICAL**: `docker-compose.yml` (root) - hos + pazar birlikte
- **H-OS Standalone**: `work/hos/docker-compose.yml` - sadece H-OS için (ops kullanımı)
- **Override**: `docker-compose.override.yml` (root) - local override (KEEP, ops için)

### Doküman Giriş Noktaları
- `work/pazar/docs/CURRENT.md` - Günlük entry point
- `work/pazar/docs/README.md` - Docs navigation
- `work/pazar/WORLD_REGISTRY.md` - Canonical world registry
- `work/hos/docs/pazar/START_HERE.md` - H-OS entry point (varsa)

## Taşıma Planı

### `/_archive/20260107/outside/`
- `work dışındakler/` (tüm klasör)

### `/_archive/20260107/runtime_artifacts/`
- Root: `cookies.txt`, `headers.txt`
- `work/hos/oidc_*.txt`, `work/hos/oidc_*.json`
- `work/hos/pazar_oidc_*.txt`, `work/hos/pazar_oidc_discovery.json`
- `work/hos/proof_*.txt`
- `work/hos/proofs/` (tüm klasör)
- `work/pazar/proofs/` (tüm klasör)

### `/_archive/20260107/compose_baks/`
- `docker-compose.yml.bak-20260105-122828` (root)
- `work dışındakler/docker-compose.yml.bak-20260105-122828`

### `/_archive/20260107/scratch/`
- Root scratch dosyalar: `_compose_rendered.yml`, `_dbscan_run.ps1`, `_test_form.html`, `check_cache.php`, `seed_demo.sql`, `test_control_center.sh`
- `_diag/` klasörü
- `_ops/` klasörü

## Secrets Temizleme Planı

### `work/hos/secrets/`
- Mevcut: `README.md` ✅ (KEEP)
- Gerçek `*.txt` dosyaları: **repo dışına taşınmalı** (local kullanım)
- Örnek dosyalar: `*.txt.example` pattern (opsiyonel, README yeterli)

### `work/pazar/`
- `docs/env.example` ✅ (KEEP)
- `.env` (varsa): **repo dışına** (local kullanım)

## Notlar

- `_backup/` klasörü zaten arşiv amaçlı, dokunulmayacak
- `work/hos/docker-compose.*.yml` dosyaları (email, lockdown, ports, prod, proxy, secrets) - **KEEP** (ops override'ları)
- Root `docker-compose.override.yml` - **KEEP** (local override)











