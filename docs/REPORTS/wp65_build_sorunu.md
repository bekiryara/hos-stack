# WP-65 Build Sorunu — YANSIMADI

**Date:** 2026-01-24  
**Durum:** ❌ Build yapıldı ama tarayıcıda hala eski versiyon görünüyor

---

## SORUN

**Dosya:** `work/marketplace-web/src/pages/CreateReservationPage.vue`

**Kod:** ✅ Dosyada yeni kod var
- Satır 38: `Authorization Token (Demo) (Auto-filled from demo session)`
- Satır 50: `User ID (Demo) (Auto-filled from demo session)`
- Satır 42, 54: `readonly` attribute

**Build:** ✅ Build yapıldı
```powershell
npm run build
# ✓ built in 7.30s
```

**Tarayıcı:** ❌ Hala eski versiyon görünüyor
- "Authorization Token (Bearer) *" (eski)
- "User ID (optional)" (eski)
- Input'lar editable (readonly değil)

---

## OLASI SEBEPLER

### 1. Docker Volume Mount Sorunu

**Sebep:** Docker container içindeki nginx eski dosyaları serve ediyor.

**Kontrol:**
```powershell
# Docker compose.yml'de volume mount kontrolü
docker compose config | Select-String -Pattern "marketplace|volume"
```

**Çözüm:**
```powershell
# Container'ı yeniden build et
docker compose build hos-web
docker compose up -d hos-web
```

---

### 2. Nginx Static File Serve Sorunu

**Sebep:** Nginx `dist` klasörünü doğru serve etmiyor.

**Kontrol:**
```powershell
# Nginx config kontrolü
docker compose exec hos-web cat /etc/nginx/nginx.conf | Select-String -Pattern "marketplace|root"
```

**Çözüm:**
- Nginx config'de `root` path doğru mu?
- Volume mount doğru mu?

---

### 3. Build Output Path Sorunu

**Sebep:** Build output yanlış yere yazılıyor.

**Kontrol:**
```powershell
# Build output kontrolü
cd work/marketplace-web
ls -la dist/
```

**Çözüm:**
- `vite.config.js` kontrol et
- `dist` path doğru mu?

---

## HIZLI ÇÖZÜM

### Adım 1: Docker Container Rebuild

```powershell
cd D:\stack
docker compose build hos-web
docker compose up -d hos-web
```

### Adım 2: Tarayıcı Hard Refresh

- `Ctrl+Shift+R`
- DevTools > Application > Clear Storage

### Adım 3: Build Output Kontrolü

```powershell
cd work/marketplace-web
npm run build
# dist/ klasöründe yeni dosyalar var mı?
ls -la dist/assets/
```

---

## SONUÇ

**Durum:** ❌ YANSIMADI

**Sebep:** Docker volume mount veya nginx config sorunu (muhtemelen)

**Çözüm:** Docker container rebuild gerekli.

---

**Test Tarihi:** 2026-01-24  
**Build:** ✅ Yapıldı  
**Tarayıcı:** ❌ Eski versiyon görünüyor

