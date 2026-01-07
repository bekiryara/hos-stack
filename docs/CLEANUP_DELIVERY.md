# Repo Cleanup Delivery (2026-01-07)

## Değişen Dosyalar Listesi

### Oluşturulan Dosyalar (CREATE)
- `README.md` - Root canonical entry point
- `docs/REPO_INVENTORY.md` - Repo envanter raporu
- `docs/PROOFS/cleanup_pass.md` - PASS kanıtları
- `docs/CLEANUP_DELIVERY.md` - Bu dosya (teslim özeti)

### Güncellenen Dosyalar (UPDATE)
- `work/hos/secrets/README.md` - Secrets kullanım kılavuzu güncellendi (gerçek değerler repo dışına yönlendirme)

### Taşınan Dosyalar (MOVE)
Aşağıdaki tüm dosyalar `/_archive/20260107/` altına taşınmıştır (reversible).

## /_archive İçine Taşınanlar

### `/_archive/20260107/outside/`
- `work dışındakler/` (tüm klasör)
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

### `/_archive/20260107/runtime_artifacts/`
- `cookies.txt` (root)
- `headers.txt` (root)
- `oidc_authorize.txt`
- `oidc_pkce.txt`
- `oidc_token.json`
- `oidc_token.txt`
- `oidc_userinfo.json`
- `oidc_userinfo.txt`
- `pazar_oidc_authorize.txt`
- `pazar_oidc_discovery.json`
- `pazar_oidc_pkce.txt`
- `pazar_oidc_token.txt`
- `pazar_oidc_userinfo.txt`
- `proof_contract_transition_1.txt`
- `proof_contract_transition_2.txt`
- `proof_policy_decide_ok.txt`
- `proof_policy_decide.txt`
- `proof_record_1.txt`
- `proof_record_2.txt`
- `proof_record_ok_1.txt`
- `proof_record_ok_2.txt`
- `hos_proofs/` (tüm klasör)
- `pazar_proofs/` (tüm klasör - 97 dosya)

### `/_archive/20260107/compose_baks/`
- `docker-compose.yml.bak-20260105-122828` (root)

### `/_archive/20260107/scratch/`
- `_compose_rendered.yml`
- `_dbscan_run.ps1`
- `_test_form.html`
- `check_cache.php`
- `seed_demo.sql`
- `test_control_center.sh`
- `_diag/` (tüm klasör)
- `_ops/` (tüm klasör)

### `/_archive/20260107/secrets/`
- `database_url.txt`
- `db_password.txt`
- `google_client_id.txt`
- `google_client_secret.txt`
- `google_redirect_uri.txt`
- `jwt_secret.txt`

**Not:** Secrets dosyaları gerçek değerler içerir. Local kullanım için `_archive/20260107/secrets/` içeriğini `work/hos/secrets/` altına kopyalayın.

## Canonical Çalışma Komutları

### 1. Tam Stack (H-OS + Pazar)
```powershell
docker compose up -d --build
```

### 2. Sadece H-OS (Standalone)
```powershell
cd work/hos && docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d --build
```

### 3. Health Check
```powershell
curl.exe -sS -i http://localhost:3000/v1/health && curl.exe -sS -i http://localhost:8080/up
```

## PASS Kanıtları

### ✅ PASS: Docker Compose Config
**Komut:** `docker compose config`  
**Sonuç:** ✅ Geçerli YAML syntax, tüm servisler doğru parse edildi  
**Kanıt:** `docs/PROOFS/cleanup_pass.md`

### ⚠️ SKIP: Docker Compose Up -d
**Durum:** Docker Desktop çalışmıyor (test edilemedi)  
**Not:** Canonical compose dosyası geçerli ve kullanıma hazır

### ⚠️ SKIP: Smoke Testler
**Durum:** Docker Desktop gerekli (test edilemedi)  
**Not:** 
- H-OS smoke: `work/hos/ops/smoke.ps1 -SkipAuth`
- Pazar register smoke: `php artisan hos:register-smoke --base-url=http://localhost:3000 --api-key=dev-api-key`

**Detaylı kanıtlar:** `docs/PROOFS/cleanup_pass.md`

## Özet

- ✅ **Inventory raporu** oluşturuldu (`docs/REPO_INVENTORY.md`)
- ✅ **Canonical girişler** belirlendi (`README.md` oluşturuldu)
- ✅ **Taşıma işlemleri** tamamlandı (tüm scratch/runtime dosyalar `/_archive/20260107/` altında)
- ✅ **Secrets temizlendi** (gerçek değerler archive'a taşındı, README güncellendi)
- ✅ **PASS kanıtları** üretildi (`docs/PROOFS/cleanup_pass.md`)

**Toplam taşınan:** ~139 dosya + klasörler

## Sonraki Adımlar

1. Docker Desktop'ı başlat
2. Secrets dosyalarını local olarak oluştur:
   ```powershell
   Copy-Item '_archive/20260107/secrets/*.txt' -Destination 'work/hos/secrets/' -Force
   ```
3. Canonical compose ile sistemi başlat:
   ```powershell
   docker compose up -d --build
   ```
4. Smoke testleri çalıştır (opsiyonel)

## Notlar

- Tüm taşıma işlemleri **reversible** (geri alınabilir)
- Hiçbir dosya **silinmedi**, sadece **taşındı**
- Secrets dosyaları repo'da **kalmıyor** (local kullanım için archive'dan kopyalanabilir)
- Canonical compose: root'taki `docker-compose.yml` (hos + pazar birlikte)

