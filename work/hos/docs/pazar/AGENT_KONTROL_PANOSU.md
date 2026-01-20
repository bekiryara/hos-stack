# Agent Kontrol Panosu (TR) — H-OS + Pazar aynı kulvar

Amaç: Yeni gelen **H-OS ajanı** ve **Pazar ajanı** aynı yerden aynı gerçeği görsün; sapma olmasın.

## 1) Tek giriş kapısı (okuma sırası)
1) `docs/tr/START_HERE.md` (en hızlı onboarding + 10 dk doğrulama)
2) `docs/tr/altin_hedefler.md` (neyi hedefliyoruz / neyi hedeflemiyoruz)
3) `docs/tr/hos_pazar_sozlesmesi.md` (sınırlar + sözleşme)
4) `docs/tr/pazar_hos_degisim_protokolu.md` (shadow→enforce + proof gate)
5) `docs/tr/NEXT_DECISIONS.md` (tek sayfa: sıradaki kararlar + kanıt)

Aktif mikro planlar:
- `docs/tr/NEXT_MICRO_STEPS_UI_OFFLINE_PAYMENT.md` (DONE/ARŞİV)
- `docs/tr/NEXT_MICRO_STEPS_TENANT_OPS_POLISH.md` (aktif)
- `docs/tr/NEXT_MICRO_STEPS_PHASE_2A_RENTALS.md` (aktif — kiralama/Airbnb)

Kanonik yol haritası (sapma engelleyici):
- `docs/tr/ROADMAP_AMAZON_AIRBNB.md`

## 2) “Şu an sistem ayakta mı?” (2 dakikalık doğrulama)
### Pazar
- Health: `http://localhost/pazar/index.php/up` → `OK`
- Landing: `http://localhost/pazar/index.php/`
- UI Login: `http://localhost/pazar/index.php/ui/login`
- Demo shop: `http://localhost/pazar/index.php/shop/demo`

### H-OS
- API health: `http://localhost:3000/v1/health` → `{"ok":true}`
- Web→API proxy: `http://localhost:3002/api/v1/health` → `{"ok":true}`
- H-OS Admin: `http://localhost:3002` → Session ekranında **Status: ok**

## 3) “Kanıt nerede?” (tek kaynak)
### Pazar proof klasörleri
- Konum: `C:\xampp\htdocs\pazar\proofs\proof_YYYYMMDD-HHMMSS\`
- Son proof’u bul:

```powershell
cd C:\xampp\htdocs\pazar
dir .\proofs\proof_* | sort LastWriteTime -desc | select -first 1
```

### Teslim zip (tek dosya)
- Konum: `C:\xampp\htdocs\pazar\dist\delivery_*.zip`
- Son zip’i bul:

```powershell
cd C:\xampp\htdocs\pazar
dir .\dist\delivery_*.zip | sort LastWriteTime -desc | select -first 1
```

## 4) “Hata yapmadan teslim al” (tek komut)

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\deliver.ps1 -IncludeHos -HosBootstrap -OpenFolder
```

Screenshot’ları proof klasörüne koyduktan sonra zip’i güncelle:

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\finalize_delivery.ps1 -OpenFolder
```

## 4.1) “Ben hata yapmak istemiyorum” — ajan hizalama kontrolü (tek komut)
Pazar ve H-OS tarafında kritik dokümanlar var mı, son proof/zip nerede, hepsini raporlar:

```powershell
cd C:\xampp\htdocs\pazar
powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\agent_check.ps1 -ExportToHos
```

## 5) Kulvar ayrımı (kısa)
- **H-OS ajanı**: evrensel kimlik/SSO + policy + contract/FSM + audit/proof + ops standartları
- **Pazar ajanı**: ürün/sipariş/rezervasyon/ödeme + panel/vitrin + UI akışları

Kural: Dünya verisi evrene taşınmaz. Controller’da kanun yazılmaz. Breaking change = shadow→enforce.

## 6) Offline ödeme (Kapıda + Havale/EFT) — demo kanıt
Checkout ekranlarında offline yöntemler de var:
- **Kapıda ödeme**: pending payment oluşur (`provider=cash_on_delivery`)
- **Havale/EFT**: pending payment + **IBAN + referans** gösterilir (`provider=bank_transfer`)

Kanıt için 1 ekran görüntüsü yeter:
- Checkout ekranında **Havale/EFT seçilmiş** ve IBAN+referans kutusu görünüyor.

Not (karışıklığı bitiren kural):
- **Firma ürün oluştururken ödeme yöntemi seçmez.** Ödeme yöntemi **checkout** ekranında müşteri tarafından seçilir.

## 7) Sıradaki kilit karar (unutma): Kart/Online ödeme sağlayıcısı
Şu an teslim paketi (kanıtlar dahil) tamam. Başa dönmemek için sıradaki tek karar:
- **Online kart sağlayıcısı**: **`iyzico` seçildi** (ilk entegrasyon)
- Offline yöntemler (Kapıda + Havale/EFT) zaten hazır ve teslimde var.

Önerilen ilerleme:
1) Offline yöntemleri canlıda kullan (hemen).
2) Seçilen tek online sağlayıcıyı (**iyzico**) entegre et.
3) Plan dokümanı: `docs/tr/iyzico_hosted_checkout_plani.md`

## 8) “Kim ne yapıyor?” (minimum hata modu)
- **Sen (owner)**:
  - Sadece şu 2 şeyi seç/kararlaştır: (a) online provider = **iyzico** (b) canlıya çıkış zamanı/öncelik listesi
  - Kanıt üretmek için: `docs/deliver.ps1` + screenshot’ları proof klasörüne koy (hepsi bu)
- **Ben (ajan)**:
  - iyzico entegrasyonunu “adapter” olarak eklerim (idempotency + webhook + iade/cancel guard)
  - Policy/FSM sınırlarına uyarım (shadow→enforce), test + proof olmadan ilerletmem


