# WP-65 Sorun Analizi — localhost:3002'de Neden Yansımıyor?

**Date:** 2026-01-24  
**Sorun:** Kod dosyada var, build yapıldı, container rebuild edildi ama tarayıcıda hala eski versiyon görünüyor.

---

## SORUN ANALİZİ

### 1. localhost:3002'de Hangi Sayfalar Var?

**Nginx Config (`work/hos/services/web/nginx.conf`):**
- `/` → `/usr/share/nginx/html/` (HOS Web SPA)
- `/marketplace/` → `/usr/share/nginx/html/marketplace/` (Marketplace SPA)
- `/api/*` → `hos-api:3000` (HOS API proxy)
- `/api/marketplace/*` → `pazar-app:80` (Marketplace API proxy)

**Container İçi:**
```
/usr/share/nginx/html/
  ├── index.html (HOS Web)
  ├── assets/ (HOS Web assets)
  └── marketplace/
      ├── index.html (Marketplace)
      └── assets/ (Marketplace assets)
```

**Sayfalar:**
1. **HOS Web** (`/`): Ana sayfa, demo control panel
2. **Marketplace** (`/marketplace/*`): Marketplace SPA (Vue.js)

---

### 2. Neden Yansımıyor?

**Sorun:** Docker container içinde eski build var.

**Akış:**
1. ✅ Kod yazıldı (`work/marketplace-web/src/pages/CreateReservationPage.vue`)
2. ✅ Local build yapıldı (`npm run build` → `work/marketplace-web/dist/`)
3. ❌ **Container içinde eski build var** (`/usr/share/nginx/html/marketplace/`)

**Dockerfile (`work/hos/services/web/Dockerfile`):**
```dockerfile
FROM node:20-alpine AS build-marketplace
WORKDIR /app
COPY marketplace-web/package.json marketplace-web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY marketplace-web/vite.config.js ./vite.config.js
COPY marketplace-web/index.html ./index.html
COPY marketplace-web/src ./src
RUN npm run build  # ← Container içinde build yapılıyor

FROM nginx:1.27-alpine
COPY --from=build-marketplace /app/dist/ /usr/share/nginx/html/marketplace/
```

**Sorun:** Dockerfile container içinde build yapıyor, local `dist/` klasörünü kullanmıyor!

---

### 3. Çözüm

**Seçenek 1: Docker Container Rebuild (YAPILDI)**
```powershell
docker compose build hos-web
docker compose up -d hos-web
```

**Seçenek 2: Volume Mount (Önerilen)**
Dockerfile'ı değiştir, local `dist/` klasörünü kullan:
```dockerfile
# Local build kullan
COPY marketplace-web/dist/ /usr/share/nginx/html/marketplace/
```

**Seçenek 3: Dev Mode**
Vite dev server kullan (HMR ile otomatik güncelleme).

---

## SONUÇ

**Sorun:** Docker container içinde build yapılıyor, local build kullanılmıyor.

**Çözüm:** Container rebuild edildi ama hala eski versiyon görünüyor → Browser cache veya build cache sorunu olabilir.

**Sonraki Adım:** Container içindeki dosyaları kontrol et, browser cache temizle.

---

**Test Tarihi:** 2026-01-24  
**Durum:** ❌ Hala eski versiyon görünüyor

