# 📱 Frontend Deployment Rehberi

**Amaç:** Telefondan ve başka bilgisayardan frontend'i test etmek

---

## 🚀 HIZLI BAŞLANGIÇ

### 1. Frontend'i Deploy Et

```powershell
# Değişiklikleri commit et
git add .
git commit -m "Frontend deployment hazır"
git push origin main
```

**GitHub Pages Settings:**
1. https://github.com/bekiryara/hos-stack/settings/pages
2. **Source:** "GitHub Actions" seç
3. **Workflow:** "Frontend GitHub Pages" seçilmiş olmalı
4. Deploy sonrası URL: `https://bekiryara.github.io/hos-stack/marketplace/`

---

### 2. Backend'i Public'e Aç (ngrok)

**ngrok Kurulumu:**
1. https://ngrok.com/download adresinden indir
2. PATH'e ekle veya `D:\stack\` klasörüne kopyala
3. https://ngrok.com/ adresinde ücretsiz hesap oluştur
4. Token'ı al: `ngrok authtoken <token>`

**Backend'i Aç:**
```powershell
.\ops\_legacy\legacy.ps1 ngrok-backend
```

**Çıktı:**
```
✅ BACKEND PUBLIC URL:
  https://abc123.ngrok.io
```

---

### 3. Frontend'de API URL'yi Güncelle

**Seçenek 1: Environment Variable (Önerilen)**

`.github/workflows/frontend-pages.yml` dosyasında:
```yaml
env:
  VITE_API_BASE_URL: ${{ secrets.VITE_API_BASE_URL || 'http://localhost:8080' }}
```

GitHub Secrets'a ekle:
1. https://github.com/bekiryara/hos-stack/settings/secrets/actions
2. **New repository secret**
3. **Name:** `VITE_API_BASE_URL`
4. **Value:** ngrok URL'si (örn: `https://abc123.ngrok.io`)

**Seçenek 2: Manuel Build (Local Test)**

```powershell
cd work/marketplace-web
$env:VITE_API_BASE_URL="https://abc123.ngrok.io"
npm run build
# dist/ klasörünü GitHub Pages'e manuel yükle
```

---

## 📋 TEST ADIMLARI

### 1. Frontend Test
- ✅ Telefondan: `https://bekiryara.github.io/hos-stack/marketplace/`
- ✅ Başka bilgisayardan: Aynı URL

### 2. Backend Test
- ✅ ngrok URL'si çalışıyor mu: `https://abc123.ngrok.io/api/ping`
- ✅ Frontend backend'e bağlanabiliyor mu

---

## ⚠️ ÖNEMLİ NOTLAR

### ngrok Limitleri
- **Ücretsiz plan:** 2 saat sonra timeout
- **URL değişir:** Her başlatmada farklı URL
- **Sadece test için:** Production için backend deploy et

### GitHub Pages Limitleri
- **Build süresi:** ~2-3 dakika
- **Otomatik güncelleme:** `work/marketplace-web/**` değişince
- **Base path:** `/marketplace/` (vite.config.js'de ayarlı)

---

## 🔧 SORUN GİDERME

### Frontend 404 Hatası
- GitHub Pages settings'te "GitHub Actions" seçili mi?
- Workflow başarıyla çalıştı mı? (Actions sekmesinde kontrol et)

### Backend Bağlanamıyor
- ngrok çalışıyor mu? (`http://localhost:4040` kontrol et)
- Frontend'deki API URL doğru mu?
- CORS hatası var mı? (Backend'de CORS ayarları kontrol et)

### API URL Değişmedi
- GitHub Secrets'a eklendi mi?
- Workflow yeniden çalıştırıldı mı?
- Build log'larında `VITE_API_BASE_URL` görünüyor mu?

---

## 🎯 PRODUCTION İÇİN

### Backend Deploy Seçenekleri

1. **Railway** (Önerilen - Ücretsiz)
   - https://railway.app/
   - Docker Compose desteği
   - Otomatik deploy

2. **Render** (Ücretsiz)
   - https://render.com/
   - Docker desteği
   - Otomatik deploy

3. **VPS** (Kendi sunucun)
   - DigitalOcean, AWS, vb.
   - Tam kontrol
   - Ücretli

---

**Son Güncelleme:** 2026-01-20

