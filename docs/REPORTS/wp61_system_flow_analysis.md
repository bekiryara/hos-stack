# WP-61: Sistem Çalışma Akışı Derin Analiz
**Date:** 2025-01-24  
**Scope:** Create Listing akışı ve sistem mimarisi analizi

---

## 1. PORT YAPISI VE SERVİSLER

### Port Dağılımı:
- **3002:** HOS Web (nginx) - Frontend serve ediyor
  - HOS Admin UI (`/`) - React
  - Marketplace UI (`/marketplace/*`) - Vue.js
  - Proxy: `/api/*` → `hos-api:3000` (HOS API)
  - Proxy: `/api/messaging/*` → `messaging-api:3000`

- **8080:** Pazar API (Laravel/PHP) - Marketplace backend
  - Endpoints: `/api/v1/listings`, `/api/v1/categories`, etc.
  - CORS middleware aktif
  - Middleware chain: PersonaScope → auth.any → tenant.scope

- **3000:** HOS API (Fastify/Node.js) - Auth/memberships
  - Endpoints: `/v1/auth/demo`, `/v1/me/memberships`
  - JWT token generation

---

## 2. TOKEN AKIŞI (Demo Authentication)

### Token Kaynağı:
1. **HOS Web UI:** Kullanıcı "Enter Demo" butonuna tıklar
2. **HOS API:** `POST /v1/auth/demo` isteği atılır
3. **JWT Token:** HOS API JWT token döner
4. **localStorage:** `localStorage.setItem('demo_auth_token', token)`

### Token Kullanımı:
- **getToken() helper:** `localStorage.getItem('demo_auth_token')`
- **getMyMemberships():** HOS API'ye Authorization header ile token gönderilir ✅
- **createListing():** Token kullanılmıyor ❌ (sorun burada)

### Token Akışı Eksik:
- `CreateListingPage.vue` → `handleSubmit()`: `getToken()` çağrılmıyor
- `api.createListing(payload, tenantId)`: `authToken` geçilmiyor
- `client.js` → `createListing()`: `authToken` parametresi yok
- `buildPersonaHeaders()`: `authToken` bekliyor ama `null` geçiliyor

---

## 3. FRONTEND AKIŞI (Create Listing)

### Form Submit Akışı:
1. **Kullanıcı formu doldurur:**
   - Category (dropdown)
   - Title (text input)
   - Description (textarea, optional)
   - Transaction Mode (checkboxes: sale, rental, reservation)

2. **handleSubmit() çalışır:**
   ```javascript
   // Validation
   if (!tenantId || !category_id || !title || transaction_modes.length === 0) {
     return; // Early exit
   }
   
   // Payload oluşturulur
   const payload = {
     category_id,
     title,
     description,
     transaction_modes,
     attributes
   };
   
   // API çağrısı
   const result = await api.createListing(payload, tenantId);
   ```

3. **API Client (client.js):**
   - `API_BASE_URL = 'http://localhost:8080'` (direkt 8080'e gidiyor)
   - `createListing(data, tenantId)` fonksiyonu:
     - `Idempotency-Key` generate edilir
     - `activeTenantId = tenantId || api.getActiveTenantId()`
     - `buildPersonaHeaders(STORE, { tenantId })` → `X-Active-Tenant-Id` eklenir
     - **Authorization header EKSİK** (authToken geçilmiyor)
     - `POST http://localhost:8080/api/v1/listings`

---

## 4. CORS PREFLIGHT (Browser)

### Preflight Akışı:
1. **Browser:** `OPTIONS http://localhost:8080/api/v1/listings`
2. **Origin:** `http://localhost:3002`
3. **Request-Headers:** `content-type, x-active-tenant-id`

4. **Pazar CORS Middleware Kontrolü:**
   - `Access-Control-Allow-Origin: http://localhost:3002` ✅ (allowed)
   - `Access-Control-Allow-Headers: X-Active-Tenant-Id, Idempotency-Key` ✅ (WP-61 fix)
   - `Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS` ✅

5. **Preflight PASS** → POST isteği gönderilir

### CORS Yapılandırması:
- **DEV/LOCAL:** localhost variants allowed (3002, 8080, etc.)
- **PROD:** `CORS_ALLOWED_ORIGINS` env var'dan strict allowlist
- **Headers:** Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept, **X-Active-Tenant-Id**, **Idempotency-Key** (WP-61)

---

## 5. BACKEND MIDDLEWARE CHAIN (POST /v1/listings)

### Middleware Sırası:
```
Request → PersonaScope:store → auth.any → tenant.scope → Handler
```

### 1. PersonaScope:store Middleware:
- **Kontrol:** `X-Active-Tenant-Id` header varlığı
- **Durum:** ✅ Header varsa → PASS
- **Hata:** 400 `missing_header` (header yoksa)

### 2. auth.any Middleware:
- **Kontrol 1:** Session auth (`Auth::check()`) → ❌ YOK
- **Kontrol 2:** Bearer token (`request->bearerToken()`) → ❌ YOK
- **Kontrol 3:** HOS_OIDC_API_KEY match → ❌ YOK
- **Kontrol 4:** JWT validation (HOS_JWT_SECRET) → ❌ Token yok
- **Sonuç:** 401 `UNAUTHORIZED` döner

### 3. tenant.scope Middleware (çalışmaz, auth.any fail ediyor):
- **Kontrol:** `X-Active-Tenant-Id` format validation (UUID)
- **Kontrol:** Membership validation (HOS API)
- **Durum:** ❌ Çalışmıyor (auth.any önce fail ediyor)

---

## 6. SORUN ANALİZİ

### Ana Sorun: Authorization Header Eksik

**Frontend:**
- `createListing()` fonksiyonu `authToken` parametresi almıyor
- `getToken()` helper'ı var ama kullanılmıyor
- `buildPersonaHeaders()` `authToken` bekliyor ama `null` geçiliyor

**Backend:**
- `auth.any` middleware Authorization header bekliyor
- Session auth yok
- Bearer token yok
- Sonuç: 401 UNAUTHORIZED

### İkincil Sorun: Port Karmaşası

**Mevcut Durum:**
- Frontend: `API_BASE_URL = 'http://localhost:8080'` (direkt 8080'e gidiyor)
- Nginx proxy: `/api/*` → `hos-api:3000` (kullanılmıyor)
- Sonuç: CORS riski (ama çalışıyor, WP-61 fix ile)

**Olması Gereken:**
- Frontend: `API_BASE_URL = ''` (relative)
- İstekler: `/api/v1/listings` (3002 üzerinden)
- Nginx: `/api/*` → 8080'e proxy eder
- Avantaj: Same-origin, CORS yok

---

## 7. TAM AKIŞ ÖZETİ

### Create Listing Akışı (Mevcut):

```
1. Kullanıcı formu doldurur
   ↓
2. handleSubmit() → validation → payload oluşturulur
   ↓
3. api.createListing(payload, tenantId) çağrılır
   ↓
4. API_BASE_URL = 'http://localhost:8080' (direkt 8080)
   ↓
5. Headers:
   ✅ X-Active-Tenant-Id: <tenant_id>
   ✅ Idempotency-Key: <uuid>
   ❌ Authorization: Bearer <token> (EKSİK)
   ↓
6. Browser CORS preflight:
   ✅ OPTIONS → 204 (X-Active-Tenant-Id allowed)
   ↓
7. POST isteği gönderilir
   ↓
8. Backend middleware chain:
   ✅ PersonaScope:store → X-Active-Tenant-Id OK
   ❌ auth.any → Authorization YOK → 401
   ↓
9. Response: 401 UNAUTHORIZED
```

### GET Listings Akışı (Çalışıyor):

```
1. Frontend: api.searchListings(params)
   ↓
2. GET http://localhost:8080/api/v1/listings
   ↓
3. Backend: PersonaScope:guest → auth gerekmez
   ↓
4. Response: 200 OK (listings array)
```

---

## 8. ÇÖZÜM ÖNERİSİ

### createListing() Fonksiyonunu Güncelle:

**Mevcut:**
```javascript
createListing: (data, tenantId) => {
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId });
  // ...
}
```

**Önerilen:**
```javascript
createListing: (data, tenantId, authToken) => {
  const activeTenantId = tenantId || api.getActiveTenantId();
  const activeAuthToken = authToken || getToken(); // Auto-get token
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { 
    tenantId: activeTenantId,
    authToken: activeAuthToken 
  });
  // ...
}
```

### CreateListingPage.vue'da Token Geç:

**Mevcut:**
```javascript
const result = await api.createListing(payload, this.formData.tenantId || null);
```

**Önerilen:**
```javascript
const demoToken = getToken();
const result = await api.createListing(payload, this.formData.tenantId || null, demoToken);
```

---

## 9. SİSTEM MİMARİSİ ÖZETİ

### Katmanlar:
1. **Frontend (3002):** Vue.js SPA, nginx serve
2. **API Client:** `client.js` - HTTP istekleri, header yönetimi
3. **CORS Middleware:** Browser preflight kontrolü
4. **Backend Middleware Chain:** PersonaScope → auth.any → tenant.scope
5. **Route Handler:** Business logic, database INSERT

### Veri Akışı:
- **Token:** localStorage → getToken() → Authorization header
- **Tenant ID:** localStorage → getActiveTenantId() → X-Active-Tenant-Id header
- **Payload:** Form data → JSON → POST body

### Güvenlik:
- **CORS:** Origin kontrolü, header allowlist
- **Auth:** JWT token validation (auth.any middleware)
- **Tenant Scope:** Membership validation (tenant.scope middleware)
- **Persona:** Header requirements (PersonaScope middleware)

---

## 10. SORUN ÖZETİ

**Ana Sorun:** Authorization header eksik
- Frontend `createListing()` authToken geçmiyor
- Backend `auth.any` middleware Authorization bekliyor
- Sonuç: 401 UNAUTHORIZED

**İkincil Sorun:** Port karmaşası
- Frontend direkt 8080'e gidiyor (nginx proxy kullanılmıyor)
- CORS riski (ama WP-61 fix ile çalışıyor)

**Çözüm:** 
- `createListing()` fonksiyonuna `authToken` parametresi ekle
- `getToken()` helper'ından token al
- `buildPersonaHeaders()`'a `authToken` geç

