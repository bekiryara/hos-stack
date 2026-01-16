# OPS SCRIPT CORE vs KARANTINA LİSTESİ

**Tarih:** 2026-01-15  
**Kaynak:** .github/workflows/*.yml taraması

---

## ✅ KESİN CORE (CI'DA AKTİF KULLANIMDA - ASLA SİLİNMEZ)

### Baseline Governance (ci.yml)
- ✅ `ops/doctor.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/ci.yml` (repo_hygiene, baseline_checks)
- ✅ `ops/graveyard_check.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/ci.yml` (repo_hygiene)
- ✅ `ops/conformance.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/ci.yml` (baseline_checks), `.github/workflows/conformance.yml`
- ✅ `ops/baseline_status.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/ci.yml` (baseline_checks)
- ✅ `ops/verify.ps1` → **CORE** - CI'da referans edilir: `.github/workflows/ci.yml` (baseline-impacting check)

### Contract Management
- ✅ `ops/routes_snapshot.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/contracts.yml`
- ✅ `ops/schema_snapshot.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/db-contracts.yml`

### Security & Auth
- ✅ `ops/auth_security_check.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/auth-security.yml`
- ✅ `ops/security_audit.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/security-gate.yml`

### Contract Checks
- ✅ `ops/env_contract.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/env-contract.yml`
- ✅ `ops/openapi_contract.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/openapi-contract.yml`

### Boundary & Posture Checks
- ✅ `ops/tenant_boundary_check.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/tenant-boundary.yml`
- ✅ `ops/session_posture_check.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/session-posture.yml`
- ✅ `ops/world_spine_check.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/world-spine.yml`

### Ops Status Dashboard
- ✅ `ops/ops_drift_guard.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/ops-status.yml`
- ✅ `ops/run_ops_status.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/ops-status.yml`

### Incident Management
- ✅ `ops/incident_bundle.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/pazar-ui-smoke.yml`, `product-api-crud-gate.yml`, `product-e2e.yml`, `rc0-check.yml`

### Smoke Tests
- ✅ `ops/smoke_surface.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/smoke-surface.yml`
- ✅ `ops/pazar_ui_smoke.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/pazar-ui-smoke.yml`

### Product Tests (Aktif CI'da)
- ✅ `ops/product_api_crud_e2e.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/product-api-crud-gate.yml`
- ✅ `ops/product_e2e.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/product-e2e.yml`
- ✅ `ops/product_contract.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/product-contract.yml`
- ✅ `ops/product_contract_check.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/product-contract.yml`
- ✅ `ops/product_spine_e2e_check.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/product-spine.yml`

### Release Management
- ✅ `ops/release_check.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/release-check.yml`
- ✅ `ops/release_bundle.ps1` → **CORE** - CI'da kullanılır: `.github/workflows/release-check.yml`

---

## ⚠️ KARANTİNA ADAYLARI (CI'DA KULLANILMIYOR VEYA ESKİ)

### RC0 Scripts (CI'da kullanılıyor AMA _graveyard'de!)
- ⚠️ `ops/rc0_check.ps1` → **KARANTİNA** - CI'da kullanılır: `.github/workflows/rc0-check.yml` **AMA** `_graveyard/ops_rc0/`'de! **SORUN: CI başarısız olabilir!**
- ⚠️ `ops/rc0_gate.ps1` → **KARANTİNA** - CI'da kullanılır: `.github/workflows/rc0-gate.yml` **AMA** `_graveyard/ops_rc0/`'de! **SORUN: CI başarısız olabilir!**

**ÇÖZÜM:** Bu scriptler CI'da kullanılıyorsa _graveyard'den geri alınmalı VEYA CI workflow'ları güncellenmeli.

### Zaten Karantinada
- ✅ `_graveyard/ops_rc0/rc0_release_bundle.ps1` → **KARANTİNA** - CI'da kullanılmıyor
- ✅ `_graveyard/ops_rc0/rc0_release_candidate.ps1` → **KARANTİNA** - CI'da kullanılmıyor
- ✅ `_graveyard/ops_candidates/restore_pazar_routes.ps1` → **KARANTİNA** - Tek seferlik script
- ✅ `_graveyard/ops_candidates/STACK_E2E_CRITICAL_TESTS_v0.ps1` → **KARANTİNA** - Eski versiyon

### CI'da Kullanılmayan Scripts (Karantina Adayları)
- ❌ `ops/product_api_smoke.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/product_mvp_check.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/product_perf_guard.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/product_read_path_check.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/product_spine_check.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/product_spine_governance.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/product_spine_smoke.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/product_write_spine_check.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/product_e2e_contract.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/STACK_E2E_CRITICAL_TESTS_v1.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/pazar_route_surface_diag.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/alert_pipeline_proof.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/drift_monitor.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor (ops_drift_guard.ps1 var)
- ❌ `ops/self_audit.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor
- ❌ `ops/repo_integrity.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor (doctor.ps1 tarafından çağrılıyor ama direkt CI'da yok)
- ❌ `ops/release_note.ps1` → **KARANTİNA ADAYI** - CI'da kullanılmıyor (release_bundle.ps1 var)

### Daily Operations (CI'da değil ama günlük kullanımda)
- ✅ `ops/daily_snapshot.ps1` → **CORE** - Günlük kullanım (docs/CURRENT.md, docs/ONBOARDING.md'de referans edilir)
- ✅ `ops/triage.ps1` → **CORE** - Sorun tespit (docs/ONBOARDING.md'de referans edilir)
- ✅ `ops/request_trace.ps1` → **CORE** - Request ID log korelasyonu (docs/ARCHITECTURE.md'de referans edilir)
- ✅ `ops/stack_up.ps1` → **CORE** - Stack başlatma (docs/CURRENT.md'de referans edilir)
- ✅ `ops/stack_down.ps1` → **CORE** - Stack durdurma

### H-OS Database Operations (CI'da değil ama ops için gerekli)
- ⚠️ `ops/hos_db_recovery.ps1` → **OPS GEREKLİ** - H-OS DB recovery (CI'da değil ama ops için gerekli)
- ⚠️ `ops/hos_db_recovery_commands.ps1` → **OPS GEREKLİ** - H-OS DB recovery commands
- ⚠️ `ops/hos_db_reset_safe.ps1` → **OPS GEREKLİ** - H-OS DB safe reset
- ⚠️ `ops/hos_db_verify.ps1` → **OPS GEREKLİ** - H-OS DB verification

### Storage & Posture Checks (CI'da değil ama ops için gerekli)
- ⚠️ `ops/storage_posture_check.ps1` → **OPS GEREKLİ** - Storage posture check (docs/runbooks/storage_posture.md'de referans edilir)
- ⚠️ `ops/storage_permissions_check.ps1` → **OPS GEREKLİ** - Storage permissions check
- ⚠️ `ops/storage_write_check.ps1` → **OPS GEREKLİ** - Storage write check
- ⚠️ `ops/pazar_storage_posture.ps1` → **OPS GEREKLİ** - Pazar storage posture

### Performance & SLO (CI'da değil ama ops için gerekli)
- ⚠️ `ops/perf_baseline.ps1` → **OPS GEREKLİ** - Performance baseline check
- ⚠️ `ops/slo_check.ps1` → **OPS GEREKLİ** - SLO check (docs/runbooks/slo_breach.md'de referans edilir)

### Observability (CI'da değil ama ops için gerekli)
- ⚠️ `ops/observability_status.ps1` → **OPS GEREKLİ** - Observability status (docs/runbooks/observability_status.md'de referans edilir)

### Library Files (Tüm ops scriptleri tarafından kullanılır)
- ✅ `ops/_lib/core_availability.ps1` → **CORE** - Core availability helper
- ✅ `ops/_lib/ops_env.ps1` → **CORE** - Ops environment helper
- ✅ `ops/_lib/ops_exit.ps1` → **CORE** - Safe exit helper (tüm ops scriptleri kullanır)
- ✅ `ops/_lib/ops_output.ps1` → **CORE** - Output formatting helper
- ✅ `ops/_lib/routes_json.ps1` → **CORE** - Routes JSON helper
- ✅ `ops/_lib/worlds_config.ps1` → **CORE** - Worlds config helper

### Snapshots (Contract enforcement için kritik)
- ✅ `ops/snapshots/routes.pazar.json` → **CORE** - Route contract snapshot
- ✅ `ops/snapshots/schema.pazar.sql` → **CORE** - Schema contract snapshot

---

## 📊 ÖZET

### CORE (CI'da Aktif veya Günlük Kullanımda)
- **CI'da aktif:** 24 script
- **Günlük kullanımda:** 5 script (daily_snapshot, triage, request_trace, stack_up, stack_down)
- **Ops gerekli:** 10 script (hos_db_*, storage_*, perf_baseline, slo_check, observability_status)
- **Library:** 6 dosya
- **Snapshots:** 2 dosya
- **TOPLAM CORE:** ~47 dosya

### KARANTİNA ADAYLARI
- **Zaten karantinada:** 4 script (_graveyard/ops_rc0/, _graveyard/ops_candidates/)
- **CI'da kullanılmayan:** 15+ script (product_* smoke/check scriptleri, vb.)
- **TOPLAM KARANTİNA ADAYI:** ~20 script

### ⚠️ SORUN: RC0 Scripts
- `rc0_check.ps1` ve `rc0_gate.ps1` CI'da kullanılıyor AMA _graveyard'de!
- **ÇÖZÜM:** Bu scriptleri _graveyard'den geri al VEYA CI workflow'larını güncelle (rc0-check.yml, rc0-gate.yml)

---

## 🎯 KARAR MATRİSİ

| Script | CI'da Kullanılıyor? | Durum | Karar |
|--------|---------------------|-------|-------|
| doctor.ps1 | ✅ Evet | CORE | KEEP |
| conformance.ps1 | ✅ Evet | CORE | KEEP |
| baseline_status.ps1 | ✅ Evet | CORE | KEEP |
| verify.ps1 | ✅ Evet (referans) | CORE | KEEP |
| rc0_check.ps1 | ✅ Evet | **SORUN** | _graveyard'den geri al VEYA CI güncelle |
| rc0_gate.ps1 | ✅ Evet | **SORUN** | _graveyard'den geri al VEYA CI güncelle |
| product_api_crud_e2e.ps1 | ✅ Evet | CORE | KEEP |
| product_e2e.ps1 | ✅ Evet | CORE | KEEP |
| product_api_smoke.ps1 | ❌ Hayır | KARANTİNA | _graveyard/'e taşı |
| product_mvp_check.ps1 | ❌ Hayır | KARANTİNA | _graveyard/'e taşı |

---

**Son Güncelleme:** 2026-01-15

