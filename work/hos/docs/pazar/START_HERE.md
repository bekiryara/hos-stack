# START HERE (TR) — Yeni Ajan Onboarding (Pazar + H-OS)

Bu dosya yeni katılan ajan/ekip için **tek giriş kapısıdır**. Amaç: sapmayı sıfıra yaklaştırmak.

## 0) Kanonik karar (1 cümle)
- **H-OS = evren hukuku**
- **Pazar = ilk ticaret dünyası**

## 0.1) Kanonik ödeme kararı (unutma)
- **Şu an test edilenler (demo)**: `stripe/mock` + **Kapıda ödeme** + **Havale/EFT**
- **Ürün oluştururken ödeme seçilmez**: ödeme yöntemi **checkout** ekranında seçilir
- **Sıradaki online provider**: **iyzico** (ilk entegrasyon)

## 1) 10 dakikada bağlam (okuma sırası)
1) **Altın hedefler**: `docs/tr/altin_hedefler.md`
2) **Pazar↔H-OS sözleşme**: `docs/tr/hos_pazar_sozlesmesi.md`
3) **Entegrasyon playbook**: `docs/tr/hos_pazar_entegrasyon_playbook.md`
4) **SSO standardı**: `docs/tr/hos_universal_identity_sso.md`
5) **Policy kanunu**: `docs/tr/hos_policy_yetki_kanunu.md`
6) **Değişiklik protokolü**: `docs/tr/pazar_hos_degisim_protokolu.md`

## 2) “Sapma olmasın” kilit kurallar
- Controller içine **kanun** yazma: (policy/contract/proof) → tek kapı.
- Breaking change **asla** direkt enforce değil: **shadow → enforce**.
- Dünya verisi H-OS’a taşınmaz (video/mesaj/ticaret kayıtları evrende tutulmaz).
- Kanıtsız merge yok: test + smoke + proof.

## 3) Pazar üzerinde çalışacaksan (en kısa yol)
- Test:
  - `cd C:\xampp\htdocs\pazar`
  - `php artisan test`

- Uçtan uca kanıt (Pazar + H-OS opsiyonel):

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\proof_bundle.ps1 -BaseUrl "http://localhost/pazar/index.php" -TenantSlug "demo" -IncludeHos -HosBootstrap
```

## 4) H-OS üzerinde çalışacaksan (en kısa yol)
- Stack:

```powershell
cd $env:USERPROFILE\Desktop\h-os
.\ops\bootstrap.ps1 -Obs -Web
.\ops\check.ps1 -SkipAuth
```

## 5) PR açmadan önce 5 soru
1) Bu iş **evrensel mi**? (çoklu dünya) → H-OS
2) Bu iş **dünya domain’i mi**? → Pazar (veya ilgili dünya)
3) State geçişi var mı? → Contract/FSM
4) Yetki kararı var mı? → Policy (shadow→enforce)
5) Kanıt gerekiyor mu? → Proof/Audit

## 6) Minimum “done” tanımı
- Testler yeşil (`php artisan test`)
- Smoke yeşil (`docs/smoke_test.ps1`)
- Policy değiştiyse: shadow log ve rollback planı var
- Doküman güncel (Altın hedef/sözleşme/playbook)

# START HERE (TR) — H-OS Evreni + Pazar İlk Dünya (Yeni ajan için)

Bu dosya, projeye yeni katılan **H-OS ajanı** veya **Pazar ajanı** için tek giriş noktasıdır.
Amaç: sapma olmasın, yanlış müdahale olmasın, sistem patlamasın.

## 1) Kanonik Tanım (değişmez)
- **H-OS = EVREN**: kimlik/SSO + policy + contract/FSM + proof/audit + ops standartları
- **Pazar = İLK DÜNYA**: ticaret sahnesi (ürün/sipariş/rezervasyon/ödeme + panel + vitrin)

## 2) Altın Hedefler (tek gerçek)
Önce bunu oku:
- `docs/tr/altin_hedefler.md`

## 3) Sınırlar (sapmayı engelleyen çizgi)
- Dünya verisi evrene taşınmaz (video/mesaj/ticaret kayıtları H-OS DB’ye dolmaz).
- Controller’da kanun yazılmaz:
  - Yetki → **Policy**
  - State geçişi → **Contract/FSM**
  - Kanıt → **Proof/Audit**

## 4) Değişiklik protokolü (her PR için şart)
Mutlaka oku:
- `docs/tr/pazar_hos_degisim_protokolu.md`

Kısa özet:
- Breaking change = **shadow → enforce**
- Proof/test olmadan merge yok
- Rollback planı yaz

## 5) “Kilitlenme” (PowerShell) notu
Daha önce `proof_bundle` H-OS bootstrap sırasında “Container ... Running” gibi stderr yüzünden PowerShell’de kırmızı hata verip akışı bozabiliyordu.
Bu düzeltildi:
- H-OS bootstrap/check/stop çağrıları artık **ayrı proses** + **stdout/stderr dosyaya redirect** ile çalışır.

## 5.1) H-OS bootstrap “port is already allocated” hatası (en sık sebep)
Eğer `.\ops\bootstrap.ps1 -Obs -Web` çıktısında şunu görürsen:
- `Bind for 127.0.0.1:3002 failed: port is already allocated`

Bu, **3002 portunu başka bir process/container kullanıyor** demektir. H-OS web UI bu yüzden kalkamaz (grafana/tempo çalışsa bile).

Teşhis (küçük adımlar):

```powershell
# 1) 3002'yi kim dinliyor?
netstat -ano | findstr :3002

# 2) PID'yi bulduktan sonra process adını gör
tasklist /FI "PID eq <PID>"

# 3) Docker tarafında mı?
docker ps --format "table {{.Names}}\t{{.Ports}}" | findstr 3002
```

Çözüm (en güvenlisi):
- H-OS klasöründe **aynı compose dosyalarıyla** durdur:

```powershell
cd $env:USERPROFILE\Desktop\h-os
.\ops\stop.ps1
.\ops\bootstrap.ps1 -Obs -Web
```

Not:
- Sadece `docker compose down` (override dosyalarını vermeden) bazen tüm stack’i indirmez; bu da “Network ... resource is still in use” gibi uyarılar doğurur.
- Eğer daha önce Pazar içinden `proof_bundle.ps1 -IncludeHos` çalıştırıldıysa, eski sürümlerde farklı bir compose project adı ile (örn. `hos`) ayrı bir stack kalmış olabilir. Bunu görmek için:
  - `docker ps --format "table {{.Names}}\t{{.Ports}}" | findstr 3002`

İstersen hızlı teşhis için bu scripti de kullan:
- `.\docs\hos_port_diag.ps1 -Ports 3002,3001,3200`

## 6) Kanıt kapısı (teslim standardı)
Tek komutla “evren + ilk dünya” kanıtı:

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\proof_bundle.ps1 -BaseUrl "http://localhost/pazar/index.php" -TenantSlug "demo" -IncludeHos -HosBootstrap -HosStopAfter
```

Çıktı:
- `proofs/proof_YYYYMMDD-HHMMSS/`
  - `proof.log.txt` (Pazar)
  - `hos.bootstrap.txt`, `hos.check.txt`, `hos.stop.txt` (H-OS)

## 6.1) 10 dakikada doğrulama checklist’i (yeni ajan için)
Amaç: yeni gelen ajan **tek seferde** hem anlayıp hem kanıt üretsin.

### A) Ön koşul (2 dk)
- **Docker Desktop açık** (H-OS için)
- **XAMPP Apache + MySQL açık** (Pazar için)

### B) Pazar hızlı doğrulama (2 dk)
- **Health**: `http://localhost/pazar/index.php/up` → `OK`
- **Landing**: `http://localhost/pazar/index.php/` → marketplace sayfası
- **UI**: `http://localhost/pazar/index.php/ui/login` (demo kullanıcı ile giriş)
- **Demo shop**: `http://localhost/pazar/index.php/shop/demo`

### C) H-OS hızlı doğrulama (2 dk)
- **API health**: `http://localhost:3000/v1/health` → `{"ok":true}`
- **Web→API proxy**: `http://localhost:3002/api/v1/health` → `{"ok":true}`
- **H-OS Admin**: `http://localhost:3002` → Session ekranında **Status: ok**

### D) Kanıt üret (3 dk)

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\proof_bundle.ps1 -BaseUrl "http://localhost/pazar/index.php" -TenantSlug "demo" -IncludeHos -HosBootstrap
```

Beklenen:
- Exit code’lar 0
- `proofs/proof_*/` klasörü oluşur
- İçinde `proof.log.txt` + `hos.*.txt` dosyaları vardır

### E) Screenshot kanıtları (1 dk)
`proofs/proof_*/` içine koy:
- **Postman Runner**: `Local Quickstart` + `Hourly Quickstart` PASS ekran görüntüleri
- **H-OS Admin**: Session → **Status: ok** ekran görüntüsü

İsteğe bağlı teslim paketi (proof dahil):

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\package_delivery.ps1 -IncludeLatestProof -OpenFolder
```

### F) “Ben hata yapmak istemiyorum” modu (tek komut)
Yeni gelen ajan veya owner için en güvenli yol: tek komut, tek zip.

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\deliver.ps1 -IncludeHos -HosBootstrap -OpenFolder
```

Bu komut şunları otomatik yapar:
- `proof_bundle` çalıştırır (Pazar + opsiyonel H-OS)
- `package_delivery` üretir ve en güncel proof’u içine koyar
- delivery klasörünü `.zip` yapar

Manuel kalan tek şey: Postman + H-OS Admin screenshot’ları (yukarıdaki E maddesi).

Screenshot’ları ekledikten sonra zip’i güncelle (tek komut):

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\finalize_delivery.ps1 -OpenFolder
```

## 7) Entegrasyon rehberleri (okuma sırası)
1) `docs/tr/altin_hedefler.md`
2) `docs/tr/hos_pazar_sozlesmesi.md`
3) `docs/tr/hos_pazar_entegrasyon_playbook.md`
4) `docs/tr/hos_universal_identity_sso.md`
5) `docs/tr/hos_policy_yetki_kanunu.md`
6) `docs/tr/kuresel_olcek_blueprint.md`


