# OPS KLASÖRÜ ENVANTERİ

**Tarih:** 2026-01-15  
**Amaç:** ops/ klasöründeki tüm scriptlerin gerekli/gereksiz durumunu kategorize etmek

---

## ✅ KRİTİK DOSYALAR (CRITICAL - SİLİNMEZ)

### Core Health & Verification Scripts
- ✅ `ops/verify.ps1` → **KRİTİK** - Genel sağlık kontrolü (CI'da kullanılır: `.github/workflows/ci.yml`)
- ✅ `ops/baseline_status.ps1` → **KRİTİK** - Baseline kontrolü (CI'da kullanılır: `.github/workflows/ci.yml`)
- ✅ `ops/conformance.ps1` → **KRİTİK** - Mimari uyumluluk (CI'da kullanılır: `.github/workflows/ci.yml`, `.github/workflows/conformance.yml`)
- ✅ `ops/doctor.ps1` → **KRİTİK** - Repository sağlık kontrolü (CI'da kullanılır: `.github/workflows/ci.yml`)
- ✅ `ops/triage.ps1` → **KRİTİK** - Sorun tespit (docs/ONBOARDING.md'de referans edilir)

### Daily Operations
- ✅ `ops/daily_snapshot.ps1` → **KRİTİK** - Günlük snapshot (docs/CURRENT.md, docs/ONBOARDING.md'de referans edilir)

### Governance & Policy
- ✅ `ops/graveyard_check.ps1` → **KRİTİK** - Graveyard policy kontrolü (CI'da kullanılır: `.github/workflows/ci.yml`)

### Contract & Snapshot Management
- ✅ `ops/routes_snapshot.ps1` → **KRİTİK** - Route snapshot oluşturma (CI'da kullanılır: `.github/workflows/contracts.yml`)
- ✅ `ops/schema_snapshot.ps1` → **KRİTİK** - Schema snapshot oluşturma (CI'da kullanılır: `.github/workflows/db-contracts.yml`)
- ✅ `ops/snapshots/routes.pazar.json` → **KRİTİK** - Route contract snapshot (contract enforcement için)
- ✅ `ops/snapshots/schema.pazar.sql` → **KRİTİK** - Schema contract snapshot (contract enforcement için)

### Library Files
- ✅ `ops/_lib/core_availability.ps1` → **KRİTİK** - Core availability helper
- ✅ `ops/_lib/ops_env.ps1` → **KRİTİK** - Ops environment helper
- ✅ `ops/_lib/ops_exit.ps1` → **KRİTİK** - Safe exit helper (tüm ops scriptleri kullanır)
- ✅ `ops/_lib/ops_output.ps1` → **KRİTİK** - Output formatting helper
- ✅ `ops/_lib/routes_json.ps1` → **KRİTİK** - Routes JSON helper
- ✅ `ops/_lib/worlds_config.ps1` → **KRİTİK** - Worlds config helper

### Stack Management
- ✅ `ops/stack_up.ps1` → **GEREKLİ** - Stack başlatma wrapper (docs/CURRENT.md'de referans edilir)
- ✅ `ops/stack_down.ps1` → **GEREKLİ** - Stack durdurma wrapper

### Request Tracing
- ✅ `ops/request_trace.ps1` → **GEREKLİ** - Request ID log korelasyonu (docs/ARCHITECTURE.md'de referans edilir)

### Release Management
- ✅ `ops/release_note.ps1` → **GEREKLİ** - Release notu oluşturma (docs/RELEASES/PLAN.md'de referans edilir)

---

## ⚠️ AKTİF KULLANIMDA (ACTIVE - KONTROL EDİLMELİ)

### CI/CD Workflows'da Kullanılan Scriptler
- ⚠️ `ops/ops_status.ps1` → **AKTİF** - Ops status dashboard (CI'da kullanılır: `.github/workflows/ops-status.yml`)
- ⚠️ `ops/run_ops_status.ps1` → **AKTİF** - Ops status wrapper (CI'da kullanılır: `.github/workflows/ops-status.yml`, docs/runbooks/ops_status.md'de referans edilir)
- ⚠️ `ops/ops_drift_guard.ps1` → **AKTİF** - Ops drift guard (CI'da kullanılır: `.github/workflows/ops-status.yml`)

### Security & Auth Checks
- ⚠️ `ops/auth_security_check.ps1` → **AKTİF** - Auth security check (CI'da kullanılır: `.github/workflows/auth-security.yml`)
- ⚠️ `ops/security_audit.ps1` → **AKTİF** - Security audit (CI'da kullanılır: `.github/workflows/security-gate.yml`)

### Contract Checks
- ⚠️ `ops/env_contract.ps1` → **AKTİF** - Environment contract check (CI'da kullanılır: `.github/workflows/env-contract.yml`)
- ⚠️ `ops/openapi_contract.ps1` → **AKTİF** - OpenAPI contract check (CI'da kullanılır: `.github/workflows/openapi-contract.yml`)

### Boundary & Posture Checks
- ⚠️ `ops/tenant_boundary_check.ps1` → **AKTİF** - Tenant boundary check (CI'da kullanılır: `.github/workflows/tenant-boundary.yml`)
- ⚠️ `ops/session_posture_check.ps1` → **AKTİF** - Session posture check (CI'da kullanılır: `.github/workflows/session-posture.yml`)
- ⚠️ `ops/storage_posture_check.ps1` → **AKTİF** - Storage posture check (docs/runbooks/storage_posture.md'de referans edilir)
- ⚠️ `ops/storage_permissions_check.ps1` → **AKTİF** - Storage permissions check
- ⚠️ `ops/storage_write_check.ps1` → **AKTİF** - Storage write check

### World & Spine Checks
- ⚠️ `ops/world_spine_check.ps1` → **AKTİF** - World spine check (CI'da kullanılır: `.github/workflows/world-spine.yml`)

### Incident & Observability
- ⚠️ `ops/incident_bundle.ps1` → **AKTİF** - Incident bundle creation (CI'da kullanılır: `.github/workflows/ops-status.yml`, docs/runbooks/incident_bundle.md'de referans edilir)
- ⚠️ `ops/observability_status.ps1` → **AKTİF** - Observability status (docs/runbooks/observability_status.md'de referans edilir)

### Performance & SLO
- ⚠️ `ops/perf_baseline.ps1` → **AKTİF** - Performance baseline check
- ⚠️ `ops/slo_check.ps1` → **AKTİF** - SLO check (docs/runbooks/slo_breach.md'de referans edilir)

### H-OS Database Operations
- ⚠️ `ops/hos_db_recovery.ps1` → **AKTİF** - H-OS DB recovery
- ⚠️ `ops/hos_db_recovery_commands.ps1` → **AKTİF** - H-OS DB recovery commands
- ⚠️ `ops/hos_db_reset_safe.ps1` → **AKTİF** - H-OS DB safe reset
- ⚠️ `ops/hos_db_verify.ps1` → **AKTİF** - H-OS DB verification

### Repository Integrity
- ⚠️ `ops/repo_integrity.ps1` → **AKTİF** - Repository integrity check (docs/runbooks/repo_integrity.md'de referans edilir, ops/doctor.ps1 tarafından çağrılır)

---

## ❌ ŞÜPHELİ/GEREKSİZ DOSYALAR (CLEANUP CANDIDATES)

### Product-Specific Scripts (Aktif mi kontrol edilmeli)
- ❌ `ops/product_api_crud_e2e.ps1` → **ŞÜPHELİ** - Product API E2E test (CI'da kullanılır: `.github/workflows/product-api-crud-gate.yml`)
- ❌ `ops/product_api_smoke.ps1` → **ŞÜPHELİ** - Product API smoke test
- ❌ `ops/product_contract_check.ps1` → **ŞÜPHELİ** - Product contract check (CI'da kullanılır: `.github/workflows/product-contract.yml`)
- ❌ `ops/product_contract.ps1` → **ŞÜPHELİ** - Product contract (CI'da kullanılır: `.github/workflows/product-contract.yml`)
- ❌ `ops/product_e2e.ps1` → **ŞÜPHELİ** - Product E2E test (CI'da kullanılır: `.github/workflows/product-e2e.yml`)
- ❌ `ops/product_e2e_contract.ps1` → **ŞÜPHELİ** - Product E2E contract (CI'da kullanılır: `.github/workflows/product-e2e.yml`)
- ❌ `ops/product_mvp_check.ps1` → **ŞÜPHELİ** - Product MVP check
- ❌ `ops/product_perf_guard.ps1` → **ŞÜPHELİ** - Product performance guard
- ❌ `ops/product_read_path_check.ps1` → **ŞÜPHELİ** - Product read path check
- ❌ `ops/product_spine_check.ps1` → **ŞÜPHELİ** - Product spine check (CI'da kullanılır: `.github/workflows/product-spine.yml`)
- ❌ `ops/product_spine_e2e_check.ps1` → **ŞÜPHELİ** - Product spine E2E check (CI'da kullanılır: `.github/workflows/product-spine.yml`)
- ❌ `ops/product_spine_governance.ps1` → **ŞÜPHELİ** - Product spine governance (CI'da kullanılır: `.github/workflows/product-spine.yml`)
- ❌ `ops/product_spine_smoke.ps1` → **ŞÜPHELİ** - Product spine smoke (CI'da kullanılır: `.github/workflows/product-spine.yml`)
- ❌ `ops/product_write_spine_check.ps1` → **ŞÜPHELİ** - Product write spine check
- ❌ `ops/policy/product_spine_allowlist.json` → **ŞÜPHELİ** - Product spine allowlist (product_spine_governance.ps1 tarafından kullanılır)

**Not:** Product scriptleri CI'da aktif kullanılıyor gibi görünüyor. Ancak product MVP tamamlandı mı, bu scriptler hala gerekli mi kontrol edilmeli.

### Smoke & Surface Tests
- ❌ `ops/smoke_surface.ps1` → **ŞÜPHELİ** - Smoke surface test (CI'da kullanılır: `.github/workflows/smoke-surface.yml`)
- ❌ `ops/pazar_route_surface_diag.ps1` → **ŞÜPHELİ** - Pazar route surface diagnostic (docs/PROOFS/pazar_route_surface_diag.md'de referans edilir)
- ❌ `ops/pazar_ui_smoke.ps1` → **ŞÜPHELİ** - Pazar UI smoke test (CI'da kullanılır: `.github/workflows/pazar-ui-smoke.yml`)
- ❌ `ops/pazar_storage_posture.ps1` → **ŞÜPHELİ** - Pazar storage posture (docs/PROOFS/pazar_storage_posture_pass.md'de referans edilir)

### E2E Tests
- ❌ `ops/STACK_E2E_CRITICAL_TESTS_v0.ps1` → **ESKİ** - Eski E2E test versiyonu (v1 varsa v0 silinebilir)
- ❌ `ops/STACK_E2E_CRITICAL_TESTS_v1.ps1` → **ŞÜPHELİ** - E2E test v1 (aktif mi?)

### Release Scripts
- ❌ `ops/release_bundle.ps1` → **ŞÜPHELİ** - Release bundle (release_note.ps1 var, duplicate mi?)
- ❌ `ops/release_check.ps1` → **ŞÜPHELİ** - Release check (CI'da kullanılır: `.github/workflows/release-check.yml`)

### Audit & Monitoring
- ❌ `ops/alert_pipeline_proof.ps1` → **ŞÜPHELİ** - Alert pipeline proof (docs/PROOFS/alert_pipeline_pass.md'de referans edilir)
- ❌ `ops/drift_monitor.ps1` → **ŞÜPHELİ** - Drift monitor (ops_drift_guard.ps1 var, duplicate mi?)
- ❌ `ops/self_audit.ps1` → **ŞÜPHELİ** - Self audit (docs/runbooks/self_audit.md'de referans edilir)

### One-Time Scripts
- ❌ `ops/restore_pazar_routes.ps1` → **TEK SEFERLİK** - Restore Pazar routes (tek seferlik script, _graveyard/'e taşınabilir)

### Geçici Diff Dosyaları
- ❌ `ops/diffs/routes.current.json` → **GEREKSİZ** - Geçici diff dosyası (`.gitignore`'da ama fiziksel olarak var, silinebilir)
- ❌ `ops/diffs/routes.diff` → **GEREKSİZ** - Geçici diff dosyası (silinebilir)
- ❌ `ops/diffs/schema.current.sql` → **GEREKSİZ** - Geçici diff dosyası (silinebilir)
- ❌ `ops/diffs/schema.diff` → **GEREKSİZ** - Geçici diff dosyası (silinebilir)

---

## 📊 ÖZET İSTATİSTİKLER

### Kritik Dosyalar
- **Kritik:** 18 dosya (verify, baseline_status, conformance, doctor, triage, daily_snapshot, graveyard_check, routes_snapshot, schema_snapshot, snapshots, _lib/ 6 dosya, stack_up, stack_down, request_trace, release_note)

### Aktif Kullanımda
- **Aktif:** ~25 dosya (CI workflows'da veya dokümantasyonda referans edilir)

### Şüpheli/Gereksiz
- **Şüpheli:** ~30+ dosya (product_* scriptleri, smoke tests, E2E tests, vb.)
- **Geçici:** 4 dosya (ops/diffs/ içinde)

---

## 🧹 TEMİZLİK ÖNERİLERİ

### 1. Hemen Silinebilir
```powershell
# Geçici diff dosyaları
Remove-Item ops/diffs/* -Recurse -Force

# Eski E2E test versiyonu (v1 varsa)
Remove-Item ops/STACK_E2E_CRITICAL_TESTS_v0.ps1 -Force
```

### 2. _graveyard/'e Taşınabilir
```powershell
# Tek seferlik script
Move-Item ops/restore_pazar_routes.ps1 _graveyard/ops/restore_pazar_routes.ps1
# + _graveyard/ops/restore_pazar_routes.NOTE.md oluştur
```

### 3. Kontrol Edilmeli (Aktif mi?)
- Product scriptleri → CI'da aktif kullanılıyor, product MVP tamamlandı mı?
- Smoke tests → CI'da aktif kullanılıyor, hala gerekli mi?
- Release scripts → release_note.ps1 var, release_bundle.ps1 duplicate mi?
- Drift scripts → ops_drift_guard.ps1 var, drift_monitor.ps1 duplicate mi?

### 4. Product Scriptleri İçin Karar
- Eğer product MVP tamamlandıysa ve bu scriptler artık kullanılmıyorsa → _graveyard/'e taşın
- Eğer hala aktif kullanılıyorsa → KEEP

---

## ✅ DOĞRULAMA KOMUTLARI

```powershell
# 1. Kritik dosyaların varlığını kontrol et
Test-Path ops/verify.ps1
Test-Path ops/baseline_status.ps1
Test-Path ops/conformance.ps1
Test-Path ops/doctor.ps1
Test-Path ops/triage.ps1
Test-Path ops/daily_snapshot.ps1

# 2. CI workflow'larda kullanılan scriptleri kontrol et
grep -r "ops/" .github/workflows/

# 3. Dokümantasyonda referans edilen scriptleri kontrol et
grep -r "ops/" docs/
```

---

## 📝 NOTLAR

- **Kritik dosyalar:** Asla silinmemeli, CI/CD ve daily operations için gerekli
- **Aktif scriptler:** CI workflows'da veya dokümantasyonda referans edilir, silinmemeli
- **Şüpheli scriptler:** Product MVP tamamlandı mı, hala gerekli mi kontrol edilmeli
- **Geçici dosyalar:** ops/diffs/ içindeki dosyalar silinebilir (`.gitignore`'da zaten)
- **Tek seferlik scriptler:** restore_pazar_routes.ps1 gibi scriptler _graveyard/'e taşınabilir

---

**Son Güncelleme:** 2026-01-15

