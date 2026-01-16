# Stack Kök Dizini A-Z Açıklamalı Rehber

**Tarih:** 2026-01-15  
**Amaç:** Kök dizindeki her dosya ve klasörün ne işe yaradığını açıklamak

## 📋 Nasıl Okunur?

- **📁 Klasör** → Alt klasörler ve dosyalar içerir
- **📄 Dosya** → Tek bir dosya
- **🔒 Frozen** → Değiştirilemez (baseline frozen)
- **⚠️ Önemli** → Mutlaka okunması gereken

---

## A-Z Sıralı Liste

### 📁 `.github/`
**Ne İşe Yarar?**
- GitHub yapılandırma dosyaları
- CI/CD workflow'ları (otomatik testler)
- Issue ve PR template'leri
- CODEOWNERS (dosya sahipliği)

**İçinde Ne Var?**
- `workflows/ci.yml` → Otomatik CI kontrolleri
- `ISSUE_TEMPLATE/` → Bug report ve feature request şablonları
- `pull_request_template.md` → PR şablonu
- `CODEOWNERS` → Dosya sahipliği kuralları

**Ne Zaman Kullanılır?**
- PR gönderildiğinde otomatik çalışır
- Issue açarken template gösterilir
- PR açarken checklist gösterilir

---

### 📁 `_archive/`
**Ne İşe Yarar?**
- Geçici arşiv dosyaları (günlük snapshot'lar, release bundle'lar)
- Git'te track edilmez (`.gitignore`'da)

**İçinde Ne Var?**
- `daily/` → Günlük durum kayıtları (ops/daily_snapshot.ps1 tarafından oluşturulur)
- `releases/` → Release bundle'lar
- `audits/` → Denetim kayıtları
- `incidents/` → Olay kayıtları

**Ne Zaman Kullanılır?**
- Günlük snapshot'lar otomatik buraya kaydedilir
- Release yaparken bundle'lar buraya kaydedilir
- Sorun çıktığında geçmişe bakmak için

**⚠️ ÖNEMLİ:** Bu klasördeki dosyalar git'te track edilmez, sadece lokal olarak saklanır.

---

### 📁 `_graveyard/`
**Ne İşe Yarar?**
- Kullanılmayan (ölü) kod için karantina alanı
- Kod silinmez, sadece buraya taşınır
- Git history korunur, geri alınabilir

**İçinde Ne Var?**
- `ops_candidates/` → Kullanılmayan ops script'leri
- `ops_rc0/` → RC0 release script'leri (artık kullanılmıyor)
- `POLICY.md` → Graveyard kuralları
- `README.md` → Graveyard açıklaması

**Ne Zaman Kullanılır?**
- Kullanılmayan kodu silmek yerine buraya taşı
- NOT dosyası eklemeyi unutma (CI kontrol eder)

**⚠️ ÖNEMLİ:** Buraya taşınan kod geri alınabilir ama NOT dosyası olmadan commit edersen CI başarısız olur.

---

### 📄 `CHANGELOG.md`
**Ne İşe Yarar?**
- Proje değişiklik geçmişi
- Keep a Changelog formatında
- Baseline-impacting değişiklikler için zorunlu

**Ne Zaman Güncellenir?**
- Baseline değiştiğinde (docker-compose.yml, ops/verify.ps1, vb.)
- Yeni özellik eklendiğinde
- Breaking change yapıldığında

**⚠️ ÖNEMLİ:** Sadece önemli değişiklikler için güncelle, her küçük değişiklik için değil.

---

### 📄 `docker-compose.override.yml`
**Ne İşe Yarar?**
- Docker Compose için lokal override dosyası
- Environment variable'ları override eder
- Git'te track edilmez (`.gitignore`'da)

**Ne Zaman Kullanılır?**
- Lokal geliştirme için özel ayarlar yapmak istediğinde
- Örnek: HOS_OIDC_ISSUER, HOS_OIDC_WORLD değerlerini değiştirmek

**⚠️ ÖNEMLİ:** Bu dosya otomatik olarak docker-compose.yml ile birleştirilir.

---

### 📄 `docker-compose.yml` 🔒
**Ne İşe Yarar?**
- Ana Docker Compose yapılandırması
- Tüm servisleri tanımlar (hos-db, hos-api, hos-web, pazar-db, pazar-app)
- Port mapping'leri (3000, 3002, 8080)

**İçinde Ne Var?**
- Service tanımları
- Volume tanımları
- Network yapılandırması
- Health check'ler

**⚠️ ÖNEMLİ:** Bu dosya FROZEN (dondurulmuş). Service isimleri, portlar değiştirilemez! 
Detaylar: `docs/DECISIONS.md`

---

### 📁 `docs/`
**Ne İşe Yarar?**
- Tüm dokümantasyon burada
- Tek kaynak dokümantasyon (single source of truth)

**İçinde Ne Var?**
- `CURRENT.md` → Stack'in ne olduğu (İLK OKUNMASI GEREKEN!)
- `ONBOARDING.md` → Yeni başlayanlar için rehber
- `DECISIONS.md` → Baseline kararları, frozen items
- `CONTRIBUTING.md` → Commit, PR kuralları
- `PROOFS/` → Proof dokümanları (değişiklik kanıtları)
- `runbooks/` → Operasyon runbook'ları
- `RELEASES/` → Release planları

**⚠️ ÖNEMLİ:** Yeni başlayanlar önce `docs/CURRENT.md` okumalı!

---

### 📄 `LICENSE`
**Ne İşe Yarar?**
- MIT License
- Projenin lisans bilgisi

**Ne Zaman Kullanılır?**
- Projeyi kullananlar lisans koşullarını görmek için

---

### 📁 `ops/`
**Ne İşe Yarar?**
- Operasyon script'leri (PowerShell)
- Sistem kontrolü, test, bakım script'leri

**İçinde Ne Var?**
- `verify.ps1` → Genel sağlık kontrolü (EN ÇOK KULLANILAN!)
- `baseline_status.ps1` → Baseline durum kontrolü
- `conformance.ps1` → Repository uyumluluk kontrolü
- `ci_guard.ps1` → CI drift koruma (yeni!)
- `daily_snapshot.ps1` → Günlük durum kaydı
- `triage.ps1` → Sorun tespit etme
- `_lib/` → Ortak kütüphane fonksiyonları

**Ne Zaman Kullanılır?**
- PR göndermeden önce: `verify.ps1`, `conformance.ps1`, `ci_guard.ps1`
- Günlük: `daily_snapshot.ps1`
- Sorun olduğunda: `triage.ps1`

**⚠️ ÖNEMLİ:** PR göndermeden önce mutlaka `verify.ps1` ve `conformance.ps1` çalıştır!

---

### 📄 `README.md` ⚠️
**Ne İşe Yarar?**
- Repository'nin ana giriş noktası
- "What is this repo?" açıklaması
- Quick start linkleri
- Baseline frozen uyarısı

**Ne Zaman Okunur?**
- Repository'yi ilk kez açtığında
- Yeni başlayanlar için ilk okuma

**⚠️ ÖNEMLİ:** Bu dosya repository'nin yüzü! Herkes önce bunu okur.

---

### 📄 `SECURITY.md`
**Ne İşe Yarar?**
- Güvenlik politikası
- Vulnerability disclosure süreci
- Secrets policy (secrets commit etme kuralları)

**Ne Zaman Okunur?**
- Güvenlik açığı bulduğunda
- Secrets ile çalışırken
- Security best practices öğrenmek için

**⚠️ ÖNEMLİ:** Secrets asla commit etme! Detaylar bu dosyada.

---

### 📄 `VERSION`
**Ne İşe Yarar?**
- Mevcut versiyon numarası
- Release versioning için

**Ne Zaman Güncellenir?**
- Yeni release yapıldığında

---

### 📁 `work/`
**Ne İşe Yarar?**
- Uygulama kodları
- H-OS ve Pazar servisleri

**İçinde Ne Var?**
- `hos/` → H-OS servisi (API, Web, database)
- `pazar/` → Pazar servisi (Laravel application)

**Ne Zaman Kullanılır?**
- Uygulama geliştirme yaparken
- Business logic değiştirirken

**⚠️ ÖNEMLİ:** Bu klasördeki kodlar değiştirilebilir (baseline frozen değil).

---

## 📊 Özet Tablo

| Dosya/Klasör | Tip | Önem | Frozen | Ne Zaman Kullanılır |
|--------------|-----|------|--------|---------------------|
| `.github/` | 📁 | Yüksek | Hayır | PR/Issue açarken otomatik |
| `_archive/` | 📁 | Orta | Hayır | Günlük snapshot'lar, release bundle'lar |
| `_graveyard/` | 📁 | Orta | Hayır | Kullanılmayan kodu taşırken |
| `CHANGELOG.md` | 📄 | Yüksek | Hayır | Baseline değiştiğinde güncelle |
| `docker-compose.yml` | 📄 | 🔒 Kritik | **EVET** | Servisleri başlatmak için |
| `docs/` | 📁 | ⚠️ Çok Yüksek | Hayır | Her zaman (dokümantasyon) |
| `LICENSE` | 📄 | Düşük | Hayır | Lisans bilgisi için |
| `ops/` | 📁 | ⚠️ Çok Yüksek | Hayır | PR öncesi, günlük kontroller |
| `README.md` | 📄 | ⚠️ Çok Yüksek | Hayır | İlk okuma (giriş noktası) |
| `SECURITY.md` | 📄 | Yüksek | Hayır | Güvenlik konularında |
| `VERSION` | 📄 | Düşük | Hayır | Release yaparken |
| `work/` | 📁 | Yüksek | Hayır | Uygulama geliştirme |

---

## 🎯 Yeni Başlayanlar İçin Okuma Sırası

1. **README.md** → Repository'nin ne olduğunu anla
2. **docs/CURRENT.md** → Stack detaylarını öğren
3. **docs/ONBOARDING.md** → Hızlı başlangıç yap
4. **docs/DECISIONS.md** → Nelerin değiştirilemez olduğunu öğren
5. **ops/verify.ps1** → Sistem kontrolünü öğren

---

## ⚠️ Önemli Notlar

1. **docker-compose.yml FROZEN** → Service isimleri, portlar değiştirilemez!
2. **_archive/ ve _graveyard/ track edilmez** → Git'te görünmez
3. **Secrets asla commit etme** → SECURITY.md'yi oku
4. **PR öncesi mutlaka kontrol et** → verify.ps1, conformance.ps1, ci_guard.ps1
5. **docs/CURRENT.md tek kaynak** → Stack bilgileri için buraya bak

---

## 🔍 Hızlı Arama

**Sistem kontrolü için:**
- `ops/verify.ps1` → Tam kontrol
- `ops/baseline_status.ps1` → Hızlı kontrol
- `ops/triage.ps1` → Sorun tespit

**Dokümantasyon için:**
- `README.md` → Giriş
- `docs/CURRENT.md` → Stack detayları
- `docs/ONBOARDING.md` → Başlangıç rehberi

**PR için:**
- `ops/verify.ps1` → PASS olmalı
- `ops/conformance.ps1` → PASS olmalı
- `ops/ci_guard.ps1` → PASS olmalı

---

## 📁 Gerçek Kök Dizin Yapısı (Tree View)

```
stack/
│
├── 📁 .github/                          → GitHub yapılandırması
│   ├── CODEOWNERS                       → Dosya sahipliği kuralları
│   ├── pull_request_template.md         → PR şablonu
│   ├── 📁 ISSUE_TEMPLATE/               → Issue şablonları
│   │   ├── bug_report.md                → Bug report şablonu
│   │   └── feature_request.md           → Feature request şablonu
│   └── 📁 workflows/                     → CI/CD workflow'ları
│       ├── ci.yml                       → Ana CI workflow (KRİTİK!)
│       ├── conformance.yml              → Conformance check
│       ├── auth-security.yml            → Auth security check
│       ├── contracts.yml                → Contract check
│       ├── product-*.yml                → Product API testleri
│       └── ... (diğer workflow'lar)
│
├── 📁 _archive/                         → Arşiv (git'te track edilmez)
│   ├── 📁 daily/                        → Günlük snapshot'lar
│   │   └── YYYYMMDD-HHmmss/            → Her günlük snapshot
│   ├── 📁 releases/                     → Release bundle'lar
│   ├── 📁 audits/                       → Denetim kayıtları
│   └── 📁 incidents/                    → Olay kayıtları
│
├── 📁 _graveyard/                       → Karantina (kullanılmayan kod)
│   ├── README.md                        → Graveyard açıklaması
│   ├── POLICY.md                        → Graveyard kuralları
│   ├── 📁 ops_candidates/               → Eski ops script'leri
│   │   ├── restore_pazar_routes.ps1
│   │   └── STACK_E2E_CRITICAL_TESTS_v0.ps1
│   └── 📁 ops_rc0/                      → RC0 release script'leri
│       └── rc0_release_candidate.ps1
│
├── 📁 docs/                             → Dokümantasyon (TEK KAYNAK!)
│   ├── CURRENT.md                       → Stack detayları (İLK OKUNMASI GEREKEN!)
│   ├── ONBOARDING.md                    → Yeni başlayanlar rehberi
│   ├── DECISIONS.md                     → Baseline kararları, frozen items
│   ├── CONTRIBUTING.md                  → Commit, PR kuralları
│   ├── COMMIT_RULES.md                  → Commit mesajı kuralları
│   ├── NE_YAPTIK.md                     → Ne yaptık özeti
│   ├── REPO_LAYOUT_AZ.md                → Bu dosya (kök dizin rehberi)
│   ├── START_HERE.md                    → Başlangıç noktası
│   ├── RULES.md                         → Temel kurallar
│   ├── ARCHITECTURE.md                  → Sistem mimarisi
│   ├── 📁 ops/                          → Ops dokümantasyonu
│   │   ├── VERSIONING.md
│   │   ├── PERFORMANCE_BASELINE.md
│   │   └── ERROR_BUDGET.md
│   ├── 📁 PRODUCT/                      → Product dokümantasyonu
│   │   ├── MVP_SCOPE.md
│   │   ├── openapi.yaml                 → API contract
│   │   └── PRODUCT_API_SPINE.md
│   ├── 📁 PROOFS/                       → Proof dokümanları (72 dosya)
│   │   ├── baseline_pass.md
│   │   ├── repo_world_standards_v1_1.md
│   │   └── ... (diğer proof'lar)
│   ├── 📁 RELEASES/                     → Release planları
│   │   ├── BASELINE.md
│   │   └── PLAN.md
│   └── 📁 runbooks/                     → Operasyon runbook'ları (37 dosya)
│       ├── daily_ops.md
│       ├── repo_hygiene.md
│       └── ... (diğer runbook'lar)
│
├── 📁 ops/                              → Operasyon script'leri
│   ├── verify.ps1                       → Genel sağlık kontrolü (EN ÇOK KULLANILAN!)
│   ├── baseline_status.ps1              → Baseline durum kontrolü (CI'da kullanılır)
│   ├── conformance.ps1                  → Repository uyumluluk (CI'da kullanılır)
│   ├── ci_guard.ps1                    → CI drift koruma (YENİ!)
│   ├── daily_snapshot.ps1               → Günlük durum kaydı
│   ├── triage.ps1                       → Sorun tespit etme
│   ├── doctor.ps1                       → Repository sağlık kontrolü
│   ├── graveyard_check.ps1             → Graveyard policy kontrolü
│   ├── repo_inventory_report.ps1       → Repo envanter raporu (YENİ!)
│   ├── release_note.ps1                 → Release notu oluşturma
│   ├── routes_snapshot.ps1             → Route snapshot
│   ├── schema_snapshot.ps1             → Schema snapshot
│   ├── stack_up.ps1                     → Stack başlatma wrapper
│   ├── stack_down.ps1                   → Stack durdurma wrapper
│   ├── 📁 _lib/                         → Ortak kütüphane fonksiyonları
│   │   ├── ops_exit.ps1                 → Safe exit helper
│   │   ├── ops_output.ps1              → Output formatting
│   │   └── ... (diğer library'ler)
│   ├── 📁 snapshots/                    → Contract snapshot'ları
│   │   ├── routes.pazar.json           → Route contract (KRİTİK!)
│   │   └── schema.pazar.sql            → Schema contract (KRİTİK!)
│   └── ... (diğer ops script'leri)
│
├── 📁 work/                             → Uygulama kodları
│   ├── 📁 hos/                          → H-OS servisi (179 dosya)
│   │   ├── 📁 services/                 → H-OS servisleri
│   │   │   ├── 📁 api/                  → H-OS API
│   │   │   └── 📁 web/                  → H-OS Web UI
│   │   ├── 📁 ops/                      → H-OS ops script'leri
│   │   ├── 📁 docs/                     → H-OS dokümantasyonu
│   │   ├── 📁 secrets/                  → H-OS secrets (git'te track edilmez)
│   │   ├── docker-compose.yml           → H-OS standalone compose
│   │   └── ... (diğer H-OS dosyaları)
│   └── 📁 pazar/                        → Pazar servisi (8286 dosya)
│       ├── 📁 app/                      → Laravel application
│       ├── 📁 routes/                   → Route tanımları
│       ├── 📁 database/                 → Migrations, seeders
│       ├── 📁 docker/                   → Docker dosyaları
│       ├── 📁 vendor/                   → Composer dependencies (git'te track edilmez)
│       └── ... (diğer Pazar dosyaları)
│
├── 📄 docker-compose.yml                → Ana Docker yapılandırması (🔒 FROZEN!)
├── 📄 docker-compose.override.yml       → Lokal override (git'te track edilmez)
├── 📄 README.md                         → Repository giriş noktası (⚠️ İLK OKUMA!)
├── 📄 LICENSE                           → MIT License
├── 📄 SECURITY.md                       → Güvenlik politikası
├── 📄 CHANGELOG.md                      → Değişiklik geçmişi
├── 📄 VERSION                           → Versiyon numarası
├── 📄 .gitignore                        → Git ignore kuralları
├── 📄 .gitattributes                    → Git attributes
├── 📄 STACK_DOSYA_ENVANTERI.md         → Dosya envanteri
├── 📄 OPS_ENVANTERI.md                  → Ops script envanteri
└── 📄 OPS_SCRIPT_CORE_VS_KARANTINA.md  → Ops script kategorileri
```

## 📊 Klasör İçerik Özeti

### `.github/` (GitHub Yapılandırması)
- **CODEOWNERS** → Dosya sahipliği
- **ISSUE_TEMPLATE/** → Bug report, feature request şablonları
- **workflows/** → CI/CD pipeline'ları (25+ workflow)

### `_archive/` (Arşiv - Git'te Track Edilmez)
- **daily/** → Günlük snapshot'lar (ops/daily_snapshot.ps1 tarafından oluşturulur)
- **releases/** → Release bundle'lar
- **audits/** → Denetim kayıtları
- **incidents/** → Olay kayıtları

### `_graveyard/` (Karantina)
- **ops_candidates/** → Kullanılmayan ops script'leri
- **ops_rc0/** → RC0 release script'leri (artık kullanılmıyor)

### `docs/` (Dokümantasyon - Tek Kaynak!)
- **CURRENT.md** → Stack detayları (İLK OKUNMASI GEREKEN!)
- **ONBOARDING.md** → Yeni başlayanlar rehberi
- **DECISIONS.md** → Baseline kararları
- **PROOFS/** → Proof dokümanları (72 dosya)
- **runbooks/** → Operasyon runbook'ları (37 dosya)
- **ops/** → Ops dokümantasyonu
- **PRODUCT/** → Product dokümantasyonu
- **RELEASES/** → Release planları

### `ops/` (Operasyon Script'leri)
- **verify.ps1** → Genel sağlık kontrolü (EN ÇOK KULLANILAN!)
- **baseline_status.ps1** → Baseline kontrolü (CI'da kullanılır)
- **conformance.ps1** → Repository uyumluluk (CI'da kullanılır)
- **ci_guard.ps1** → CI drift koruma (YENİ!)
- **_lib/** → Ortak kütüphane fonksiyonları
- **snapshots/** → Contract snapshot'ları (routes.pazar.json, schema.pazar.sql)

### `work/` (Uygulama Kodları)
- **hos/** → H-OS servisi (179 dosya)
  - services/api/ → H-OS API
  - services/web/ → H-OS Web UI
  - ops/ → H-OS ops script'leri
  - secrets/ → H-OS secrets (git'te track edilmez)
- **pazar/** → Pazar servisi (8286 dosya)
  - app/ → Laravel application
  - routes/ → Route tanımları
  - database/ → Migrations, seeders
  - vendor/ → Composer dependencies (git'te track edilmez)

## 🔍 Hızlı Erişim

**İlk okuma:**
- `README.md` → Repository giriş noktası
- `docs/CURRENT.md` → Stack detayları

**PR öncesi:**
- `ops/verify.ps1` → PASS olmalı
- `ops/conformance.ps1` → PASS olmalı
- `ops/ci_guard.ps1` → PASS olmalı

**Günlük:**
- `ops/daily_snapshot.ps1` → Günlük durum kaydı

**Sorun olduğunda:**
- `ops/triage.ps1` → Sorun tespit

---

**Son Güncelleme:** 2026-01-15  
**Baseline:** RELEASE-GRADE BASELINE CORE v1

