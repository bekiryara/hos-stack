# STACK DOSYA ENVANTERİ (GEREKLİ vs GEREKSİZ)

**Tarih:** 2026-01-15  
**Son Güncelleme:** 2026-01-15 (repo_professionalization_v1 sonrası)  
**Amaç:** Stack'teki tüm dosyaların gerekli/gereksiz durumunu kategorize etmek

---

## ✅ GEREKLİ DOSYALAR (CRITICAL - SİLİNMEZ)

### Kök Dizin (Root) - Temel Dosyalar
- ✅ `docker-compose.yml` → **KRİTİK** - Tüm servislerin tanımı
- ✅ `README.md` → **GEREKLİ** - Proje giriş noktası
- ✅ `CHANGELOG.md` → **GEREKLİ** - Değişiklik kaydı
- ✅ `VERSION` → **GEREKLİ** - Versiyon numarası
- ✅ `.gitignore` → **KRİTİK** - Git ignore kuralları
- ✅ `.github/workflows/ci.yml` → **KRİTİK** - CI/CD pipeline
- ✅ `.github/pull_request_template.md` → **GEREKLİ** - PR şablonu

### docs/ Klasörü - Dokümantasyon
- ✅ `docs/CURRENT.md` → **KRİTİK** - Tek kaynak gerçek (single source of truth)
- ✅ `docs/ONBOARDING.md` → **GEREKLİ** - Yeni başlayanlar için rehber
- ✅ `docs/DECISIONS.md` → **GEREKLİ** - Baseline tanımı, frozen items
- ✅ `docs/ARCHITECTURE.md` → **GEREKLİ** - Sistem mimarisi
- ✅ `docs/RULES.md` → **GEREKLİ** - Geliştirme kuralları
- ✅ `docs/START_HERE.md` → **GEREKLİ** - İlk okunması gereken dosya
- ✅ `docs/CONTRIBUTING.md` → **GEREKLİ** - Katkıda bulunma rehberi
- ✅ `docs/COMMIT_RULES.md` → **GEREKLİ** - Commit mesajı kuralları
- ✅ `docs/REPO_LAYOUT.md` → **GEREKLİ** - Repo yapısı tanımı
- ✅ `docs/RELEASES/BASELINE.md` → **GEREKLİ** - Baseline release tanımı
- ✅ `docs/RELEASES/PLAN.md` → **GEREKLİ** - Release planlama
- ✅ `docs/PROOFS/` → **GEREKLİ** - Proof dokümanları (72 dosya)
- ✅ `docs/runbooks/` → **GEREKLİ** - Operasyon runbook'ları (36 dosya)
- ✅ `docs/PRODUCT/MVP_SCOPE.md` → **GEREKLİ** - MVP kapsamı
- ✅ `docs/PRODUCT/openapi.yaml` → **GEREKLİ** - API contract

### ops/ Klasörü - Operasyon Scriptleri (Core)
- ✅ `ops/verify.ps1` → **KRİTİK** - Genel sağlık kontrolü
- ✅ `ops/baseline_status.ps1` → **KRİTİK** - Baseline kontrolü (CI'da kullanılır)
- ✅ `ops/triage.ps1` → **GEREKLİ** - Sorun tespit
- ✅ `ops/doctor.ps1` → **GEREKLİ** - Repository sağlık kontrolü
- ✅ `ops/conformance.ps1` → **KRİTİK** - Mimari uyumluluk (CI'da kullanılır)
- ✅ `ops/daily_snapshot.ps1` → **GEREKLİ** - Günlük snapshot
- ✅ `ops/graveyard_check.ps1` → **GEREKLİ** - Graveyard policy kontrolü (CI'da kullanılır)
- ✅ `ops/release_note.ps1` → **GEREKLİ** - Release notu oluşturma
- ✅ `ops/routes_snapshot.ps1` → **GEREKLİ** - Route snapshot oluşturma
- ✅ `ops/schema_snapshot.ps1` → **GEREKLİ** - Schema snapshot oluşturma
- ✅ `ops/request_trace.ps1` → **GEREKLİ** - Request ID log korelasyonu
- ✅ `ops/snapshots/routes.pazar.json` → **KRİTİK** - Route contract snapshot
- ✅ `ops/snapshots/schema.pazar.sql` → **KRİTİK** - Schema contract snapshot
- ✅ `ops/_lib/` → **GEREKLİ** - Ops library dosyaları (6 dosya)

### work/ Klasörü - Uygulama Kodları
- ✅ `work/hos/` → **KRİTİK** - H-OS uygulama kodu (179 dosya)
- ✅ `work/pazar/` → **KRİTİK** - Pazar uygulama kodu (98 dosya)

---

## ⚠️ GEREKSİZ/SAÇMA DOSYALAR (CLEANUP CANDIDATES)

### Root Dizin - Geçici Dosyalar
- ✅ `_PR_DESCRIPTION.md` → **TAŞINDI** - `_archive/20260115/docs_misc/` klasörüne taşındı (2026-01-15)
- ✅ `BASELINE_GOVERNANCE_DELIVERABLES.md` → **TAŞINDI** - `_archive/20260115/docs_misc/` klasörüne taşındı (2026-01-15)
- ✅ `docker-compose.override.yml` → **KEEP** - Aktif kullanılıyor (Docker Compose otomatik override), docs/CURRENT.md'de dokümante edildi

### ops/ Klasörü - Kullanılmayan/Eski Scriptler
- ✅ `ops/rc0_check.ps1` → **TAŞINDI** - `_graveyard/ops_rc0/` klasörüne taşındı (2026-01-15)
- ✅ `ops/rc0_gate.ps1` → **TAŞINDI** - `_graveyard/ops_rc0/` klasörüne taşındı (2026-01-15)
- ✅ `ops/rc0_release_bundle.ps1` → **TAŞINDI** - `_graveyard/ops_rc0/` klasörüne taşındı (2026-01-15)
- ⚠️ `ops/rc0_release_candidate.ps1` → **KONTROL EDİLMELİ** - Dosya mevcut mu? Varsa _graveyard/ops_rc0/'e taşınmalı
- ❌ `ops/product_api_crud_e2e.ps1` → **ŞÜPHELİ** - Product API E2E test, aktif mi?
- ❌ `ops/product_api_smoke.ps1` → **ŞÜPHELİ** - Product API smoke test, aktif mi?
- ❌ `ops/product_contract_check.ps1` → **ŞÜPHELİ** - Product contract check, aktif mi?
- ❌ `ops/product_contract.ps1` → **ŞÜPHELİ** - Product contract, aktif mi?
- ❌ `ops/product_e2e.ps1` → **ŞÜPHELİ** - Product E2E test, aktif mi?
- ❌ `ops/product_e2e_contract.ps1` → **ŞÜPHELİ** - Product E2E contract, aktif mi?
- ❌ `ops/product_mvp_check.ps1` → **ŞÜPHELİ** - Product MVP check, aktif mi?
- ❌ `ops/product_perf_guard.ps1` → **ŞÜPHELİ** - Product performance guard, aktif mi?
- ❌ `ops/product_read_path_check.ps1` → **ŞÜPHELİ** - Product read path check, aktif mi?
- ❌ `ops/product_spine_check.ps1` → **ŞÜPHELİ** - Product spine check, aktif mi?
- ❌ `ops/product_spine_e2e_check.ps1` → **ŞÜPHELİ** - Product spine E2E check, aktif mi?
- ❌ `ops/product_spine_governance.ps1` → **ŞÜPHELİ** - Product spine governance, aktif mi?
- ❌ `ops/product_spine_smoke.ps1` → **ŞÜPHELİ** - Product spine smoke, aktif mi?
- ❌ `ops/product_write_spine_check.ps1` → **ŞÜPHELİ** - Product write spine check, aktif mi?
- ❌ `ops/STACK_E2E_CRITICAL_TESTS_v0.ps1` → **ESKİ** - Eski E2E test versiyonu, v1 varsa v0 silinebilir
- ❌ `ops/STACK_E2E_CRITICAL_TESTS_v1.ps1` → **ŞÜPHELİ** - E2E test v1, aktif mi?
- ❌ `ops/smoke_surface.ps1` → **ŞÜPHELİ** - Smoke surface test, aktif mi?
- ❌ `ops/pazar_route_surface_diag.ps1` → **ŞÜPHELİ** - Pazar route surface diagnostic, aktif mi?
- ❌ `ops/pazar_ui_smoke.ps1` → **ŞÜPHELİ** - Pazar UI smoke test, aktif mi?
- ❌ `ops/alert_pipeline_proof.ps1` → **ŞÜPHELİ** - Alert pipeline proof, aktif mi?
- ❌ `ops/drift_monitor.ps1` → **ŞÜPHELİ** - Drift monitor, aktif mi?
- ❌ `ops/ops_drift_guard.ps1` → **ŞÜPHELİ** - Ops drift guard, aktif mi?
- ❌ `ops/ops_status.ps1` → **ŞÜPHELİ** - Ops status, aktif mi? (run_ops_status.ps1 var mı?)
- ❌ `ops/run_ops_status.ps1` → **ŞÜPHELİ** - Run ops status wrapper, aktif mi?
- ❌ `ops/self_audit.ps1` → **ŞÜPHELİ** - Self audit, aktif mi?
- ❌ `ops/security_audit.ps1` → **ŞÜPHELİ** - Security audit, aktif mi?
- ❌ `ops/repo_integrity.ps1` → **ŞÜPHELİ** - Repo integrity check, aktif mi?
- ❌ `ops/release_bundle.ps1` → **ŞÜPHELİ** - Release bundle, aktif mi? (release_note.ps1 var)
- ❌ `ops/release_check.ps1` → **ŞÜPHELİ** - Release check, aktif mi?
- ❌ `ops/restore_pazar_routes.ps1` → **ŞÜPHELİ** - Restore Pazar routes, tek seferlik script mi?

### ops/diffs/ Klasörü - Geçici Diff Dosyaları
- ❌ `ops/diffs/routes.current.json` → **GEREKSİZ** - Geçici diff dosyası, `.gitignore`'da ama fiziksel olarak var
- ❌ `ops/diffs/routes.diff` → **GEREKSİZ** - Geçici diff dosyası
- ❌ `ops/diffs/schema.current.sql` → **GEREKSİZ** - Geçici diff dosyası
- ❌ `ops/diffs/schema.diff` → **GEREKSİZ** - Geçici diff dosyası

### docs/ Klasörü - Eski/Duplicate Dokümantasyon
- ⚠️ `docs/CLEANUP_AUDIT.md` → **ESKİ** - Eski cleanup audit, `_archive/`'e taşınabilir
- ⚠️ `docs/CLEANUP_DELIVERY.md` → **ESKİ** - Eski cleanup delivery, `_archive/`'e taşınabilir
- ⚠️ `docs/CLEANUP_HIGH_EVIDENCE.md` → **ESKİ** - Eski cleanup evidence, `_archive/`'e taşınabilir
- ⚠️ `docs/CLEANUP_MED_EVIDENCE.md` → **ESKİ** - Eski cleanup evidence, `_archive/`'e taşınabilir
- ⚠️ `docs/HANDOVER_RC0.md` → **ESKİ** - RC0 handover, `_archive/`'e taşınabilir
- ⚠️ `docs/CONTEXT_PACK.md` → **ŞÜPHELİ** - Context pack, aktif kullanılıyor mu?
- ⚠️ `docs/REPO_INVENTORY.md` → **ŞÜPHELİ** - Repo inventory, aktif kullanılıyor mu?
- ⚠️ `docs/RELEASE_CHECKLIST.md` → **ŞÜPHELİ** - Release checklist, aktif kullanılıyor mu?

### _archive/ Klasörü - Arşiv Dosyaları (Git'te tracked değil ama fiziksel olarak var)

**Amaç:** Geçici dosyalar, snapshot'lar, audit kayıtları. `.gitignore`'da, Git'te tracked değil.

**İçerik:**

**20260115/ (Güncel arşiv):**
- ✅ `_archive/20260115/docs_misc/` → **ARŞİV** - Geçici dokümantasyon dosyaları
  - `_PR_DESCRIPTION.md` → **TAŞINDI** - Geçici PR açıklaması (2026-01-15'te taşındı)
  - `BASELINE_GOVERNANCE_DELIVERABLES.md` → **TAŞINDI** - Geçici deliverable listesi (2026-01-15'te taşındı)
  - `README.md` → **GEREKLİ** - Arşiv index ve restore rehberi

**20260114/ (Eski arşiv):**
- ✅ `_archive/20260114/` → **SİLİNDİ** - Eski arşiv dosyaları temizlendi (2026-01-15)

**20260107/ (Eski arşiv):**
- ✅ `_archive/20260107/` → **SİLİNDİ** - Eski arşiv dosyaları temizlendi (2026-01-15)

**daily/ (Günlük snapshot'lar):**
- ⚠️ `_archive/daily/` → **SNAPSHOT** - Günlük snapshot'lar (`.gitignore`'da)
  - `20260115-012142/` → **SNAPSHOT** - Günlük snapshot (ops/daily_snapshot.ps1 tarafından oluşturulur)
  - `20260115-014435/` → **SNAPSHOT** - Günlük snapshot
  - `20260115-014435.zip` → **SNAPSHOT** - Snapshot zip dosyası
  - **Not:** Bu dosyalar otomatik oluşturulur, temizlenebilir (eski snapshot'lar)

**audits/ (Audit kayıtları):**
- ⚠️ `_archive/audits/` → **AUDIT** - Audit kayıtları (`.gitignore`'da)
  - `audit-20260111-*/` → **AUDIT** - Eski audit kayıtları (50+ klasör), temizlenebilir

**incidents/ (Incident kayıtları):**
- ⚠️ `_archive/incidents/` → **INCIDENT** - Incident kayıtları (`.gitignore`'da)
  - 990+ dosya (900 *.txt, 90 *.md), temizlenebilir (eski incident'ler)

**releases/ (Release snapshot'ları):**
- ⚠️ `_archive/releases/` → **RELEASE** - Release snapshot'ları (`.gitignore`'da)
  - `rc0-*/` → **RELEASE** - RC0 release snapshot'ları (6 klasör)
  - `release-*/` → **RELEASE** - Release snapshot'ları (20+ klasör)
  - **Not:** Eski release snapshot'ları, temizlenebilir

**diagnostics/ (Diagnostic dosyaları):**
- ✅ `_archive/diagnostics/` → **SİLİNDİ** - Diagnostic dosyaları temizlendi (2026-01-15)

**Temizlik Önerisi:**
- Eski arşivler (20260107, 20260114) → Silinebilir
- Eski daily snapshot'lar → Silinebilir (son 7 gün hariç)
- Eski audit kayıtları → Silinebilir (son 30 gün hariç)
- Eski incident kayıtları → Silinebilir (son 30 gün hariç)
- Eski release snapshot'ları → Silinebilir (son 3 release hariç)

### _graveyard/ Klasörü - Ölü Kod (Kasıtlı karantina)

**Amaç:** Ölü kod karantinası, silinmez ama kullanılmaz. Git history korunur.

**İçerik:**
- ✅ `_graveyard/README.md` → **GEREKLİ** - Graveyard açıklaması ve restore rehberi
- ✅ `_graveyard/POLICY.md` → **GEREKLİ** - Graveyard policy kuralları
- ✅ `_graveyard/ops_rc0/` → **KARANTİNA** - RC0 release scriptleri (4 dosya + README)
  - `rc0_check.ps1` → **ESKİ** - RC0 release check (2026-01-15'te taşındı)
  - `rc0_gate.ps1` → **ESKİ** - RC0 gate (2026-01-15'te taşındı)
  - `rc0_release_bundle.ps1` → **ESKİ** - RC0 release bundle (2026-01-15'te taşındı)
  - `rc0_release_candidate.ps1` → **ESKİ** - RC0 release candidate (zaten buradaydı)
  - `README.md` → **GEREKLİ** - RC0 scripts açıklaması
- ✅ `_graveyard/ops_candidates/` → **KARANTİNA** - One-off/legacy scriptler (2026-01-15'te oluşturuldu)
  - `restore_pazar_routes.ps1` → **TEK SEFERLİK** - Restore Pazar routes (tek seferlik script)
  - `restore_pazar_routes.ps1.NOTE.md` → **GEREKLİ** - Taşıma nedeni ve restore rehberi
  - `STACK_E2E_CRITICAL_TESTS_v0.ps1` → **ESKİ** - Eski E2E test versiyonu (v1 varsa v0 gereksiz)
  - `STACK_E2E_CRITICAL_TESTS_v0.ps1.NOTE.md` → **GEREKLİ** - Taşıma nedeni

**Not:** Tüm _graveyard/ içeriği `.gitignore`'da, Git'te tracked değil ama fiziksel olarak var.

---

## 📊 ÖZET İSTATİSTİKLER

### Gerekli Dosyalar
- **Kritik:** 10 dosya (docker-compose.yml, verify.ps1, baseline_status.ps1, vb.)
- **Gerekli:** ~150+ dosya (docs/, ops/ core scripts, work/)

### Gereksiz/Saçma Dosyalar
- **Root geçici:** 2 dosya (_PR_DESCRIPTION.md, BASELINE_GOVERNANCE_DELIVERABLES.md)
- **Eski ops scripts:** ~30+ dosya (rc0_*, product_*, vb.)
- **Geçici diff dosyaları:** 4 dosya (ops/diffs/)
- **Eski dokümantasyon:** 7 dosya (CLEANUP_*, HANDOVER_*, vb.)
- **Arşiv dosyaları:** ~100+ dosya (_archive/ içinde)

---

## 🧹 TEMİZLİK ÖNERİLERİ

### 1. Hemen Silinebilir
```powershell
# Root geçici dosyalar
Remove-Item _PR_DESCRIPTION.md -ErrorAction SilentlyContinue
Remove-Item BASELINE_GOVERNANCE_DELIVERABLES.md -ErrorAction SilentlyContinue

# Geçici diff dosyaları
Remove-Item ops/diffs/* -Recurse -ErrorAction SilentlyContinue
```

### 2. _archive/'e Taşınabilir
```powershell
# Eski dokümantasyon
Move-Item docs/CLEANUP_*.md _archive/20260115/docs/ -ErrorAction SilentlyContinue
Move-Item docs/HANDOVER_RC0.md _archive/20260115/docs/ -ErrorAction SilentlyContinue
```

### 3. Kontrol Edilmeli (Aktif mi?)
- `ops/rc0_*.ps1` scriptleri → CI'da kullanılıyor mu?
- `ops/product_*.ps1` scriptleri → Aktif testler mi?
- `ops/STACK_E2E_CRITICAL_TESTS_*.ps1` → Aktif mi?
- `docs/CONTEXT_PACK.md` → Aktif kullanılıyor mu?

### 4. _graveyard/'e Taşınabilir
```powershell
# Kullanılmayan ops scriptleri (NOT dosyası ile)
# Örnek: ops/rc0_check.ps1 → _graveyard/ops/rc0_check.ps1
# + _graveyard/ops/rc0_check.NOTE.md oluştur
```

---

## ✅ DOĞRULAMA KOMUTLARI

```powershell
# 1. Doctor check (repo sağlığı)
.\ops\doctor.ps1

# 2. Conformance check (mimari uyumluluk)
.\ops\conformance.ps1

# 3. Repo integrity check
.\ops\repo_integrity.ps1

# 4. Git status (temiz olmalı)
git status --short
```

---

## 📝 NOTLAR

- **work/** klasörü Git'te tracked olmamalı (`.gitignore`'da)
- **_archive/** klasörü Git'te tracked olmamalı (`.gitignore`'da)
- **_graveyard/** klasörü Git'te tracked olmamalı (`.gitignore`'da)
- **ops/diffs/** klasörü Git'te tracked olmamalı (`.gitignore`'da)
- Eski dosyalar silinmeden önce `_archive/`'e taşınmalı (geri dönüş için)

---

**Son Güncelleme:** 2026-01-15

