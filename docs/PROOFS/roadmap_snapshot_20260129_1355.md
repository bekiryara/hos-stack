# Roadmap Snapshot (Evidence) — 2026-01-29 13:55

This proof captures the **current baseline gates** output used to ground the roadmap.

Timestamp (local): 2026-01-29 13:55

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ops/ops_run.ps1 -Profile Prototype
powershell -NoProfile -ExecutionPolicy Bypass -File ops/public_ready_check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File ops/conformance.ps1
```

---

## Output — `ops/ops_run.ps1 -Profile Prototype`

```text
=== OPS RUN (WP-68) ===
Profile: Prototype
Timestamp: 2026-01-29 13:55:27

Running Prototype profile (minimal daily checks)...

[1/4] Running secret scan...
=== SECRET SCAN ===
PASS: 0 hits
PASS: Secret scan

[2/4] Running public ready check...
=== PUBLIC READY CHECK ===
Timestamp: 2026-01-29 13:55:47

[1] Running secret scan...
PASS: Secret scan - no secrets detected

[2] Checking git status...
PASS: Git working directory is clean

[3] Checking .env files are not tracked...
PASS: No .env files are tracked

[4] Checking vendor/ is not tracked...
PASS: No vendor/ directories are tracked

[5] Checking node_modules/ is not tracked...
PASS: No node_modules/ directories are tracked

=== PUBLIC READY CHECK: PASS ===
Repository appears safe for public release.

Next steps:
1. Review REMEDIATION_SECRETS.md (if secrets were found)
2. Create GitHub repository (public)
3. Push: git push <remote> main
PASS: Public ready check

[3/4] Running conformance check...
=== Architecture Conformance Gate ===

[A] World registry drift check...
[PASS] [A] A - World registry matches config (enabled: 2, disabled: 1)

[B] Forbidden artifacts check...
[PASS] [B] B - No forbidden artifacts (*.bak, *.tmp, *.orig, *.swp, *~)

[C] Disabled-world code policy check...
[PASS] [C] C - No code in disabled worlds (0 disabled)

[D] Canonical docs single-source check...
[PASS] [D] D - No duplicate CURRENT*.md or FOUNDING_SPEC*.md files (checked 1 unique files)

[E] Secrets safety check...
[PASS] [E] E - No secrets tracked in git

[F] Docs truth drift: DB engine alignment check...
[PASS] [F] F - Docs match docker-compose.yml: Pazar DB is PostgreSQL

[G] Forbidden endpoint check...
[PASS] [G] G - No /v1/search endpoint in Pazar routes

[INFO] === Summary ===
[PASS] CONFORMANCE PASSED - All architecture rules validated
PASS: Conformance check

[4/4] Running prototype verification...
=== PROTOTYPE VERIFICATION (WP-68C) ===
Timestamp: 2026-01-29 13:56:03

[1] Running frontend smoke test...
=== FRONTEND SMOKE TEST (WP-40) ===
Timestamp: 2026-01-29 13:56:03

[A] Running world status check...
=== WORLD STATUS CHECK (WP-1.2) ===
Timestamp: 2026-01-29 13:56:03

[1] Testing HOS GET /v1/world/status...
Response: {"world_key":"core","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
PASS: HOS /v1/world/status returns valid response
  world_key: core
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

[2] Testing HOS GET /v1/worlds...
Response: [{"world_key":"core","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"marketplace","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"messaging","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"social","availability":"DISABLED","phase":"GENESIS","version":"1.4.0"}]
PASS: HOS /v1/worlds returns valid array with all worlds
  - core: ONLINE (GENESIS, v1.4.0)
  - marketplace: ONLINE (GENESIS, v1.4.0)
  - messaging: ONLINE (GENESIS, v1.4.0)
  - social: DISABLED (GENESIS, v1.4.0)
  [DEBUG] Marketplace status from HOS: ONLINE
  [DEBUG] HOS successfully pinged Pazar (marketplace ONLINE)
  [DEBUG] Messaging status from HOS: ONLINE
  [DEBUG] HOS successfully pinged Messaging API (messaging ONLINE)

[3] Testing Pazar GET /api/world/status...
Response: {"world_key":"marketplace","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
PASS: Pazar /api/world/status returns valid response
  world_key: marketplace
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

=== WORLD STATUS CHECK: PASS ===
PASS: world_status_check.ps1 returned exit code 0

[B] Checking HOS Web (http://localhost:3002)...
PASS: HOS Web returned status code 200
PASS: HOS Web contains hos-home marker

[C] Marketplace demo route check skipped (V1: no demo routes)

[D] Checking marketplace search page (http://localhost:3002/marketplace/search/1)...
PASS: Marketplace search page returned status code 200
PASS: Marketplace search page contains Vue app mount (marketplace-search marker will be rendered client-side)
INFO: Marketplace search page filters state (client-side rendered, will be checked in browser)

[E] Checking messaging proxy endpoint...
  Messaging world is ONLINE
PASS: Messaging proxy returned status code 200
  Messaging API world_key: messaging

[F] Marketplace need-demo route check skipped (V1: no demo routes)

[G] Checking marketplace-web build...
  Node.js version: v24.12.0
  npm version: 11.6.2
  Found package-lock.json, running: npm ci
PASS: npm ci completed successfully
  Running: npm run build
PASS: npm run build completed successfully

=== FRONTEND SMOKE TEST: PASS ===
  - Worlds check: PASS
  - HOS Web: PASS (hos-home marker)
  - Marketplace demo route: SKIP (V1: removed)
  - Marketplace search page: PASS (marketplace-search marker, filters-empty handling)
  - Messaging proxy: PASS (/api/messaging/api/world/status)
  - Marketplace need-demo route: SKIP (V1: removed)
  - marketplace-web build: PASS
PASS: Frontend smoke test

[2] Checking world status...
=== WORLD STATUS CHECK (WP-1.2) ===
Timestamp: 2026-01-29 13:56:31

[1] Testing HOS GET /v1/world/status...
Response: {"world_key":"core","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
PASS: HOS /v1/world/status returns valid response
  world_key: core
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

[2] Testing HOS GET /v1/worlds...
Response: [{"world_key":"core","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"marketplace","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"messaging","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"},{"world_key":"social","availability":"DISABLED","phase":"GENESIS","version":"1.4.0"}]
PASS: HOS /v1/worlds returns valid array with all worlds
  - core: ONLINE (GENESIS, v1.4.0)
  - marketplace: ONLINE (GENESIS, v1.4.0)
  - messaging: ONLINE (GENESIS, v1.4.0)
  - social: DISABLED (GENESIS, v1.4.0)
  [DEBUG] Marketplace status from HOS: ONLINE
  [DEBUG] HOS successfully pinged Pazar (marketplace ONLINE)
  [DEBUG] Messaging status from HOS: ONLINE
  [DEBUG] HOS successfully pinged Messaging API (messaging ONLINE)

[3] Testing Pazar GET /api/world/status...
Response: {"world_key":"marketplace","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
PASS: Pazar /api/world/status returns valid response
  world_key: marketplace
  availability: ONLINE
  phase: GENESIS
  version: 1.4.0

=== WORLD STATUS CHECK: PASS ===
PASS: World status check

=== PROTOTYPE VERIFICATION PASSED ===
Prototype environment is ready.
  Tip: Use -CheckDemoSeed to verify seed listings exist
PASS: Prototype verification

=== SUMMARY ===

Check                  Status
-----                  ------
Secret Scan            PASS
Public Ready           PASS
Conformance            PASS
Prototype Verification PASS


OVERALL STATUS: PASS
All checks passed.
```

---

## Output — `ops/public_ready_check.ps1`

```text
=== PUBLIC READY CHECK ===
Timestamp: 2026-01-29 13:55:29

[1] Running secret scan...
PASS: Secret scan - no secrets detected

[2] Checking git status...
PASS: Git working directory is clean

[3] Checking .env files are not tracked...
PASS: No .env files are tracked

[4] Checking vendor/ is not tracked...
PASS: No vendor/ directories are tracked

[5] Checking node_modules/ is not tracked...
PASS: No node_modules/ directories are tracked

=== PUBLIC READY CHECK: PASS ===
Repository appears safe for public release.

Next steps:
1. Review REMEDIATION_SECRETS.md (if secrets were found)
2. Create GitHub repository (public)
3. Push: git push <remote> main
```

---

## Output — `ops/conformance.ps1`

```text
=== Architecture Conformance Gate ===

[A] World registry drift check...
[PASS] [A] A - World registry matches config (enabled: 2, disabled: 1)

[B] Forbidden artifacts check...
[PASS] [B] B - No forbidden artifacts (*.bak, *.tmp, *.orig, *.swp, *~)

[C] Disabled-world code policy check...
[PASS] [C] C - No code in disabled worlds (0 disabled)

[D] Canonical docs single-source check...
[PASS] [D] D - No duplicate CURRENT*.md or FOUNDING_SPEC*.md files (checked 1 unique files)

[E] Secrets safety check...
[PASS] [E] E - No secrets tracked in git

[F] Docs truth drift: DB engine alignment check...
[PASS] [F] F - Docs match docker-compose.yml: Pazar DB is PostgreSQL

[G] Forbidden endpoint check...
[PASS] [G] G - No /v1/search endpoint in Pazar routes

[INFO] === Summary ===
[PASS] CONFORMANCE PASSED - All architecture rules validated
```

---

## Roadmap Notes (Imported) — `liste2.txt`

Source: `\\NUR\Users\Public\Bekir\liste2.txt`

### Son durum kanıtı

- ✅ `docs/PROOFS/wp74_v1_demo_freeze_pass.md` → “V1 demo freeze” PASS (kritik akışlar kilitli)
- ✅ `docs/PROOFS/wp_category_catalog_listing_final_pass.md` → Category/Catalog/Listing final PASS (spine sabit)
- ✅ `docs/PROOFS/wp70_single_auth_v1_lock_pass.md` → Single-auth V1 lock PASS
- ✅ `docs/CURRENT.md` → “V1 STABLE” tanımı + çalışma komutları mevcut
- ⚠️ `docs/SRC.md` → **NOT FOUND** (repo kaynak haritası eksik; drift riski)
- ✅ `docs/SRC.md` → **CREATED** (repo source map eklendi; drift riski kapatıldı)

### Backlog (öncelik sırası)

- [✅] **STOP: Tek “auth/session” omurgasını kesinleştir (legacy demo anahtarları temizliği planı)**
  - Ne yapacağım? Demo/legacy session anahtarlarını *tamamen* tek auth omurgasına indirip yanlışlıkla geri dönmesini engelleyeceğim.
  - Nerede?
    - `work/marketplace-web/src/lib/session.js`
    - `docs/PROOFS/wp70_single_auth_v1_lock_pass.md`
    - `docs/CURRENT.md`
  - Nasıl?
    - `session.js` içindeki legacy anahtarları (örn. `demo_*`) için **kaldırma mı / tutma mı** kararını yazılı hale getir (kural: demo-only production path’e giremez).
    - Eğer kaldırılacaksa: önce “migration window” tanımı yap (1 sürüm boyunca migrate et, sonra kaldır).
    - `docs/CURRENT.md` içine “Session Keys Contract” maddesi ekle (hangi key’ler **tek doğru**).
    - UI’da demo moduna dair tüm referanslar varsa sadece `/demo` altında kalacak şekilde doğrula.
  - Kanıt:
    - `ops/STACK_E2E_CRITICAL_TESTS_v1.ps1` → PASS: login→account→reservation/rental akışlarında 401 yok; tek session ile devam ediyor.
    - `ops/contract_check_report.ps1` → PASS: catalog+listing contract raporu (tek rapor noktası)
  - Öncelik: **P0 (en yüksek ROI / en düşük risk)**

- [✅] **SRC.md oluştur: repo “source map” (drift/patlama riskini düşür)**
  - Ne yapacağım? Repo’nun “tek doğru kaynak haritası” dokümanını ekleyeceğim.
  - Nerede?
    - `docs/SRC.md` (**NOT FOUND → oluşturulacak**)
    - `docs/CODE_INDEX.md`
    - `docs/CURRENT.md`
  - Nasıl?
    - `docs/SRC.md` içinde: backend entrypoints, frontend entrypoints, ops entrypoints, proof/closeout entrypoints başlıklarını koy.
    - Her başlıkta **sadece** path + 1 cümle rol tanımı yaz (uzun açıklama yok).
    - `docs/CURRENT.md` içine SRC referansı ekle.
    - `ops/update_code_index.ps1` ile `docs/CODE_INDEX.md` güncelliğini doğrula.
  - Kanıt:
    - `ops/update_code_index.ps1` → PASS: CODE_INDEX güncel ve SRC.md listeleniyor.
  - Öncelik: **P0**

- [✅] **OPS kaosunu azalt: tek “runbook + entrypoint” standardı**
  - Ne yapacağım? Tekrarlayan/eski ops scriptlerini gruplayıp “hangisi güncel?” belirsizliğini bitireceğim.
  - Nerede?
    - `docs/ops/OPS_ENTRYPOINTS.md`
    - `ops/` (özellikle benzer amaçlı scriptler)
  - Nasıl?
    - `docs/ops/OPS_ENTRYPOINTS.md` içine “Supported / Deprecated” bölümü ekle.
    - `ops/` altında “deprecate edilecek” script listesini çıkar (silmek yerine önce **deprecated banner** yaklaşımı).
    - Güncel akış için **tek** önerilen zinciri yaz: `ops/ops_run.ps1` → `ops/STACK_E2E_CRITICAL_TESTS_v1.ps1` → `ops/contract_check_report.ps1`.
    - Eski tarama/scan scriptleri varsa sadece `ops/ops_run.ps1` içinden çağrılanlar “supported” olsun.
  - Kanıt:
    - `ops/ops_run.ps1` → PASS: tek komutla standart çıktılar alınabiliyor.
  - Öncelik: **P0**

- [✅] **CHANGELOG.md encoding standardı (UTF-8) + yazım disiplini**
  - Ne yapacağım? CHANGELOG’un encoding/formatını standardize edip tooling ve diff gürültüsünü azaltacağım.
  - Nerede?
    - `CHANGELOG.md` (artık UTF-8, BOM’suz)
    - `docs/RULES.md` (varsa changelog kuralı)
  - Nasıl?
    - `CHANGELOG.md` dosyasını UTF-8’e çevir (içerik korunacak).
    - Üstte “Unreleased / YYYY-MM-DD” standardını sabitle.
    - Son 1–2 entry’nin WP referanslarını `docs/WP_CLOSEOUTS.md` ile tutarlı hale getir.
  - Kanıt:
    - `ops/verify.ps1` → PASS: repo guard/format kontrolleri geçiyor (encoding kaynaklı diff/parse sorunu yok).
  - Öncelik: **P1**

- [✅] **CODE_INDEX güncellik kilidi (her WP sonrası zorunlu)**
  - Ne yapacağım? CODE_INDEX’in “geri kalma” riskini sıfıra indireceğim.
  - Nerede?
    - `docs/CODE_INDEX.md`
    - `ops/update_code_index.ps1`
    - `ops/ship_main.ps1`
  - Nasıl?
    - `ops/ship_main.ps1` akışında (varsa) CODE_INDEX güncellik kontrolünün “gated” olduğundan emin ol.
    - `docs/CODE_INDEX.md` içinde son güncelleme timestamp/kanıt satırı varsa standardize et.
    - WP kapanışlarında CODE_INDEX güncellemesinin zorunlu kanıt satırı olmasını `docs/WP_CLOSEOUTS.md` kuralına ekle.
  - Kanıt:
    - `ops/ship_main.ps1` → PASS: CODE_INDEX güncel değilse FAIL, güncelse PASS.
  - Öncelik: **P1**

- [✅] **Firm register ekranı “boş sayfa” riskini kapat (tek sebep: auth/guard/route)**
  - Ne yapacağım? `/firm/register`’ın boş render olmasına neden olan şartları netleştirip deterministik hale getireceğim.
  - Nerede?
    - `work/marketplace-web/src/router.js`
    - `work/marketplace-web/src/pages/FirmRegisterPage.vue` (veya ilgili firm sayfaları)
    - `docs/PROOFS/wp67_user_to_firm_binding.md`
  - Nasıl?
    - Route meta/guard’larda `requiresAuth` / `requiresFirm` kuralını kontrol et (firm register **auth gerekir**, firm sahibi olma **gerekmez**).
    - Sayfa mount’unda membership/firm check hatası varsa ekranda deterministik “please login / firm exists → redirect” mesajı üret (sessiz boş ekran olmasın).
    - `docs/PROOFS/wp67...` ile davranış uyuşmazlığı varsa sadece minimal düzelt.
  - Kanıt:
    - `ops/STACK_E2E_CRITICAL_TESTS_v1.ps1` → PASS: login → /firm/register render → firm create → redirect çalışıyor.
  - Öncelik: **P1**

- [✅] **Demo-only UI elementlerinin nav’dan tamamen ayrılması**
  - Ne yapacağım? Demo buton/linklerinin production header/nav’da görünme riskini sıfırlayacağım.
  - Nerede?
    - `work/marketplace-web/src/components/*` (header/nav bileşeni)
    - `docs/PROOFS/wp74_v1_demo_freeze_pass.md`
  - Nasıl?
    - Nav’da “demo” ile ilgili link/buton varsa yalnızca `/demo` içinde görünür hale getir (ya da tamamen kaldır).
    - “Tek kullanıcı girişi” hedefiyle uyumlu olarak: header’da sadece `Categories / Search / Account / Firm` gibi temel linkler kalsın.
    - Bu değişiklik V1’i bozmayacak şekilde minimal UI düzeni olsun.
  - Kanıt:
    - `ops/STACK_E2E_CRITICAL_TESTS_v1.ps1` → PASS: header minimal, kritik sayfalar erişilebilir.
  - Öncelik: **P1**

- [✅] **Catalog/Listings sözleşmesi için “spec-alignment” tek rapor noktası**
  - Ne yapacağım? Category/Catalog/Listing alignment’ı tek raporda sabitleyip tekrar sapmayı engelleyeceğim.
  - Nerede?
    - `docs/SPEC.md`
    - `docs/PROOFS/wp_category_catalog_listing_final_pass.md`
    - `ops/contract_check_report.ps1` (tek rapor noktası)
  - Nasıl?
    - SPEC içinde “Catalog → Listings surface” bölümünü referanslı hale getir (hangi endpoint’ler, hangi filtre sözleşmesi).
    - `contract_check_report.ps1` çıktısında bu sözleşmeyi doğrulayan madde varsa adı/formatı sabitle.
    - “Yeni endpoint yok” kuralını SPEC içine net bir hatırlatma olarak ekle.
  - Kanıt:
    - `ops/contract_check_report.ps1` → PASS: catalog/listing sözleşmesi uyumlu.
  - Öncelik: **P2**

- [✅] **Frontend rebuild/refresh karmaşasını bitir: tek komut, tek açıklama**
  - Ne yapacağım? Tarayıcıya yansımayan değişiklikler için “ne zaman rebuild, ne zaman hard refresh” standardını tek yerde sabitleyeceğim.
  - Nerede?
    - `ops/dev_refresh.ps1`
    - `docs/FRONTEND_DEPLOY.md` (veya ilgili frontend dokümanı)
    - `docs/CURRENT.md`
  - Nasıl?
    - `ops/dev_refresh.ps1` gerçek kullanım senaryosunu dokümante et: “code change → dev server / build / cache clear” karar ağacı.
    - `docs/CURRENT.md` içine 5 satırlık “Frontend Refresh SOP” ekle (ne zaman `Ctrl+F5`, ne zaman rebuild).
    - Eğer birden fazla frontend refresh scripti varsa **supported** olanı tekilleştir (doc seviyesinde).
  - Kanıt:
    - `ops/dev_refresh.ps1` → PASS: script çıktısı net, aynı sonuçlar tekrar alınabiliyor.
  - Öncelik: **P2**

- [✅] **WP_CLOSEOUTS disiplinini toparla: hatalı/çakışan WP numaraları için düzeltme kuralı**
  - Ne yapacağım? “Hatalı WP’leri düzeltirsek WP yapısı bozulur mu?” kaygısını kural ile bitireceğim.
  - Nerede?
    - `docs/WP_CLOSEOUTS.md`
    - `docs/PROOFS/*`
  - Nasıl?
    - Closeout içinde “errata” bölümü aç: yanlış WP numarası/başlığı olursa *silmeden* düzeltme kaydı ekle.
    - Proof dosyalarının adlandırma standardını (wpXX_*.md) netleştir.
    - Eski isimli proof’lar varsa sadece indeks/doküman referanslarını düzelt (dosya taşıma yoksa daha düşük risk).
  - Kanıt:
    - `ops/verify.ps1` → PASS: doküman bütünlüğü korunuyor, referanslar kırılmıyor.
  - Öncelik: **P2**

