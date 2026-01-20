# GitHub Pages Kurulum Rehberi

## Adım Adım Talimatlar

### 1. GitHub Repository'ye Git
- Tarayıcıda şu URL'yi aç: https://github.com/bekiryara/hos-stack
- Giriş yap (eğer giriş yapmadıysan)

### 2. Settings Sayfasına Git
- Repository sayfasında üst menüden **"Settings"** sekmesine tıkla
- Veya direkt şu URL'yi aç: https://github.com/bekiryara/hos-stack/settings

### 3. Pages Ayarlarını Bul
- Sol menüde **"Pages"** seçeneğini bul (genelde en altta, "Code and automation" bölümünde)
- **"Pages"** seçeneğine tıkla

### 4. Source Seçimi
- **"Source"** dropdown menüsünü aç
- **"GitHub Actions"** seçeneğini seç
- (Eğer "Deploy from a branch" görüyorsan, önce "GitHub Actions" seçeneğinin görünür olduğundan emin ol)

### 5. Kaydet
- **"Save"** butonuna tıkla
- Yeşil bir onay mesajı göreceksin

### 6. İlk Deploy'u Bekle
- GitHub Actions otomatik olarak çalışmaya başlayacak
- Actions sekmesine git: https://github.com/bekiryara/hos-stack/actions
- "GitHub Pages" workflow'unun çalıştığını göreceksin
- İlk deploy 1-2 dakika sürebilir

### 7. Site Hazır!
- Deploy tamamlandığında site şurada olacak:
  - **Ana sayfa:** https://bekiryara.github.io/hos-stack/
  - **Code Index:** https://bekiryara.github.io/hos-stack/CODE_INDEX.html

## Sorun Giderme

### "GitHub Actions" seçeneği görünmüyor
- `.github/workflows/pages.yml` dosyasının main branch'inde olduğundan emin ol
- Veya PR merge edilmiş olmalı

### Deploy başarısız oluyor
- Actions sekmesinde hata detaylarını kontrol et
- Genelde Jekyll build hatası olabilir
- `docs/_config.yml` dosyasının doğru olduğundan emin ol

### Site açılmıyor
- İlk deploy 1-2 dakika sürebilir, bekle
- Tarayıcı cache'ini temizle (Ctrl+F5)
- URL'nin doğru olduğundan emin: `https://bekiryara.github.io/hos-stack/`

## Notlar

- Her `docs/` klasöründeki değişiklik otomatik deploy edilir
- Sadece main branch'deki değişiklikler deploy edilir
- GitHub Actions workflow'u otomatik çalışır


