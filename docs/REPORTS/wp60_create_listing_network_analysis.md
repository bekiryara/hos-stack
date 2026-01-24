# WP-60: Create Listing Network Analysis
**Date:** 2025-01-23  
**Scope:** Network tab analysis for POST /api/v1/listings request

---

## Test Senaryosu

1. Browser'da Network tab açıldı
2. Create Listing formu dolduruldu
3. POST isteği yakalanmaya çalışıldı

---

## Network Request Analizi

### 1. URL Kontrolü

**Frontend:**
- `POST /api/v1/listings`
- API_BASE_URL: `http://localhost:8080`
- Full URL: `http://localhost:8080/api/v1/listings`

**Backend Route:**
- File: `work/pazar/routes/api/03a_listings_write.php`
- Route: `POST /v1/listings`
- Middleware: `PersonaScope:store`, `auth.any`, `tenant.scope`

**Sonuç:** ✅ **URL DOĞRU**
- Frontend `/api/v1/listings` → Backend `/v1/listings` (nginx proxy `/api` prefix'i kaldırıyor)

---

### 2. Headers Kontrolü

#### Backend Gereksinimleri:

**PersonaScope:store middleware:**
- `X-Active-Tenant-Id` header: **REQUIRED** (store persona için)

**auth.any middleware:**
- `Authorization` header: **REQUIRED** (401 döner yoksa)
- Middleware logic:
  ```php
  // Session auth varsa geçer
  if (Auth::check()) return $next($request);
  
  // Bearer token varsa validate eder (HOS_OIDC_API_KEY veya JWT)
  $bearerToken = $request->bearerToken();
  if ($bearerToken !== null) {
    // Validate...
    return $next($request);
  }
  
  // Hiçbiri yoksa 401
  return response()->json(['error_code' => 'UNAUTHORIZED'], 401);
  ```

**tenant.scope middleware:**
- `X-Active-Tenant-Id` header: **REQUIRED** (400 döner yoksa)

#### Frontend Implementation:

**api.createListing() fonksiyonu:**
```javascript
createListing: (data, tenantId) => {
  const idempotencyKey = generateIdempotencyKey();
  const activeTenantId = tenantId || api.getActiveTenantId();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: activeTenantId });
  headers['Idempotency-Key'] = idempotencyKey;
  return apiRequest('/api/v1/listings', {
    method: 'POST',
    body: JSON.stringify(data),
    headers,
  });
}
```

**buildPersonaHeaders() STORE mode:**
```javascript
else if (personaMode === PERSONA_MODES.STORE) {
  // STORE: X-Active-Tenant-Id header required
  if (config.tenantId) {
    headers['X-Active-Tenant-Id'] = config.tenantId;
  }
  // Optional: Authorization header for store scope (GENESIS phase)
  if (config.authToken) {
    headers['Authorization'] = config.authToken.startsWith('Bearer ') 
      ? config.authToken 
      : `Bearer ${config.authToken}`;
  }
}
```

**Sonuç:** ❌ **AUTHORIZATION HEADER EKSİK**
- `X-Active-Tenant-Id`: ✅ Ekleniyor (tenantId varsa)
- `Authorization`: ❌ **EKLENMİYOR** (authToken geçilmiyor)
- `Idempotency-Key`: ✅ Ekleniyor

**Sorun:**
- `createListing()` fonksiyonu `authToken` parametresi almıyor
- `buildPersonaHeaders()`'a `authToken` geçilmiyor
- Backend `auth.any` middleware Authorization header bekliyor → **401 döner**

---

### 3. Response Kontrolü

**Network Tab Sonucu:**
- ❌ POST `/api/v1/listings` isteği **GÖRÜNMÜYOR**
- Sadece GET `/api/v1/categories` isteği görünüyor

**Olası Nedenler:**
1. **Form validation başarısız:** `handleSubmit()` erken return ediyor
2. **JavaScript hatası:** `api.createListing()` çağrılmadan önce hata oluyor
3. **Tenant ID eksik:** `formData.tenantId` boş, validation fail ediyor
4. **Category ID eksik:** `formData.category_id` boş, validation fail ediyor

**handleSubmit() validation:**
```javascript
if (!this.formData.tenantId || !this.formData.category_id || !this.formData.title || this.formData.transaction_modes.length === 0) {
  this.error = { message: 'Please fill all required fields', status: 400 };
  return; // Early return - API çağrılmıyor
}
```

---

## Backend Route Detayları

**Route:** `POST /v1/listings`
**File:** `work/pazar/routes/api/03a_listings_write.php:14`

**Middleware Chain:**
1. `PersonaScope:store` → X-Active-Tenant-Id header kontrolü
2. `auth.any` → Authorization header kontrolü (401 döner yoksa)
3. `tenant.scope` → X-Active-Tenant-Id validation + membership check

**Required Headers:**
- `X-Active-Tenant-Id`: UUID format, tenant.scope middleware
- `Authorization`: Bearer token, auth.any middleware (JWT veya HOS_OIDC_API_KEY)

**Request Body:**
```json
{
  "category_id": 1,
  "title": "Test Listing",
  "description": "Optional",
  "transaction_modes": ["reservation"],
  "attributes": {}
}
```

**Response (Success):**
```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "category_id": 1,
  "title": "Test Listing",
  "status": "draft",
  "created_at": "ISO timestamp"
}
```

**Response (Error):**
- 400: Missing X-Active-Tenant-Id header
- 401: Unauthenticated (auth.any middleware)
- 403: FORBIDDEN_SCOPE (tenant membership check failed)
- 422: Validation error

---

## Sorun Özeti

### Sorun 1: Authorization Header Eksik
**Semptom:**
- Network'te POST request görünmüyor
- Form submit sonrası sayfa değişmiyor

**Kök Neden:**
- `createListing()` fonksiyonu `authToken` parametresi almıyor
- `buildPersonaHeaders()`'a `authToken` geçilmiyor
- Backend `auth.any` middleware Authorization header bekliyor → **401 döner**

**Çözüm:**
- `createListing()` fonksiyonuna `authToken` parametresi ekle
- `getToken()` helper'ından token al
- `buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken })` şeklinde geç

### Sorun 2: Form Validation
**Semptom:**
- Network'te POST request görünmüyor
- Muhtemelen form validation erken return ediyor

**Kök Neden:**
- `handleSubmit()` validation'da erken return
- `formData.tenantId` boş olabilir
- `formData.category_id` boş olabilir

**Çözüm:**
- Form validation'ı kontrol et
- Tenant ID ve Category ID'nin dolu olduğundan emin ol

---

## Önerilen Düzeltmeler

### 1. createListing() Fonksiyonunu Güncelle

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
  const activeAuthToken = authToken || getToken(); // WP-62: Auto-get token
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { 
    tenantId: activeTenantId,
    authToken: activeAuthToken 
  });
  // ...
}
```

### 2. CreateListingPage.vue'da Token Geç

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

## Test Sonuçları

| Kontrol | Durum | Notlar |
|---------|-------|--------|
| URL | ✅ DOĞRU | POST /api/v1/listings → POST /v1/listings |
| X-Active-Tenant-Id Header | ✅ EKLENİYOR | tenantId varsa ekleniyor |
| Authorization Header | ❌ EKSİK | authToken geçilmiyor |
| Idempotency-Key Header | ✅ EKLENİYOR | Otomatik generate ediliyor |
| POST Request Network'te | ❌ GÖRÜNMÜYOR | Form validation veya JS hatası |

## Browser Test (Demo Girişi ile)

**Test Senaryosu:**
1. H-OS Admin'den demo girişi yapıldı
2. Create Listing sayfasına gidildi (`/marketplace/listing/create`)
3. Form dolduruldu:
   - Category: Service (seçildi)
   - Title: "Network Test Listing" (yazıldı)
   - Transaction Mode: Reservation (checkbox işaretlendi)
4. "Create Listing (DRAFT)" butonuna tıklandı

**Sonuç:**
- ❌ Network'te POST `/api/v1/listings` isteği **GÖRÜNMÜYOR**
- Sadece GET `/api/v1/categories` isteği görünüyor (sayfa yüklenirken)
- Form hala görünüyor (success state'e geçmemiş)
- Hata mesajı görünmüyor
- Console'da hata mesajı yok

**Olası Nedenler:**
1. **Form validation fail:** `handleSubmit()` erken return ediyor
   - Tenant ID eksik olabilir (demo girişi yapıldı ama tenant ID localStorage'a yazılmamış olabilir)
   - Category ID seçilmemiş olabilir (dropdown seçimi çalışmamış olabilir)
   - Transaction mode seçilmemiş olabilir (checkbox işaretlenmemiş olabilir)
2. **JavaScript hatası:** Form submit event handler çalışmıyor
3. **Demo token eksik:** Authorization header için token localStorage'da yok

---

## Sonuç

**Ana Sorun:** Authorization header eksik
- Backend `auth.any` middleware Authorization header bekliyor
- Frontend `createListing()` authToken geçmiyor
- Sonuç: 401 Unauthorized (ama network'te görünmüyor çünkü form validation fail ediyor olabilir)

**İkincil Sorun:** Form validation
- Network'te POST request görünmüyor
- Muhtemelen form validation erken return ediyor

**Öncelik:** Authorization header ekle, form validation kontrol et.

