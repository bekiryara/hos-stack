# WP-61: Create Listing 401 Unauthorized - Teknik Veri
**Date:** 2025-01-24

---

## NETWORK REQUEST

```
Method: POST
URL: http://localhost:8080/api/v1/listings
Status: 401 Unauthorized
CORS Preflight: OPTIONS → 204 No Content
```

### Request Headers
```
Content-Type: application/json
X-Active-Tenant-Id: 7ef9bc88-2d20-45ae-9f16-525181aad657
Idempotency-Key: <uuid>
Authorization: Bearer <token> (kontrol edilmeli)
```

### Response Body
```json
{
  "ok": false,
  "error_code": "UNAUTHORIZED",
  "message": "Unauthenticated.",
  "request_id": "<uuid>"
}
```

---

## KOD

### work/marketplace-web/src/pages/CreateListingPage.vue
**Satır 308-316:**
```javascript
const demoToken = getToken();
if (!demoToken) {
  this.error = { message: 'Demo session yok. /demo sayfasından oturum başlat.', status: 401 };
  this.loading = false;
  return;
}
const result = await api.createListing(payload, this.formData.tenantId || null, demoToken);
```

### work/marketplace-web/src/api/client.js
**Satır 216-227:**
```javascript
createListing: (data, tenantId, authToken) => {
  const idempotencyKey = generateIdempotencyKey();
  const activeTenantId = tenantId || api.getActiveTenantId();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: activeTenantId, authToken });
  headers['Idempotency-Key'] = idempotencyKey;
  return apiRequest('/api/v1/listings', {
    method: 'POST',
    body: JSON.stringify(data),
    headers,
  });
}
```

**Satır 34-45:**
```javascript
} else if (personaMode === PERSONA_MODES.STORE) {
  if (config.tenantId) {
    headers['X-Active-Tenant-Id'] = config.tenantId;
  }
  if (config.authToken) {
    headers['Authorization'] = config.authToken.startsWith('Bearer ') 
      ? config.authToken 
      : `Bearer ${config.authToken}`;
  }
}
```

### work/pazar/routes/api/03a_listings_write.php
**Satır 14:**
```php
Route::middleware([
    \App\Http\Middleware\PersonaScope::class . ':store',
    'auth.any',
    'tenant.scope'
])->post('/v1/listings', function (\Illuminate\Http\Request $request) {
```

### work/pazar/app/Http/Middleware/AuthAny.php
**Satır 30-50:**
```php
$bearerToken = $request->bearerToken();
if ($bearerToken !== null) {
    $apiKey = env('HOS_OIDC_API_KEY');
    if ($apiKey !== null && $apiKey !== '' && $bearerToken === $apiKey) {
        return $next($request);
    }
    $jwtSecret = env('HOS_JWT_SECRET') ?: env('JWT_SECRET');
    if ($jwtSecret && strlen($jwtSecret) >= 32) {
        try {
            $payload = $this->verifyJWT($bearerToken, $jwtSecret);
            return $next($request);
        } catch (\Exception $e) {
        }
    }
}
return response()->json(['ok' => false, 'error_code' => 'UNAUTHORIZED', 'message' => 'Unauthenticated.'], 401);
```

---

## VERİ

### Form Durumu
```
Tenant ID: 7ef9bc88-2d20-45ae-9f16-525181aad657
Category: Services (service)
Title: "2121"
Transaction Mode: Seçilmiş
```

### Hata Mesajları
```
UI: Error (401): unknown - Unauthenticated.
Console: Failed to load resource: the server responded with a status of 401 (Unauthorized) :8080/api/v1/listings:1
```

### Browser Console Kontrolü
```javascript
localStorage.getItem('demo_auth_token')
localStorage.getItem('active_tenant_id')
```

### Backend Log
```bash
docker compose logs pazar-app | grep -i "unauthorized\|401\|jwt"
```

### Backend Env
```bash
docker compose exec pazar-app php artisan tinker
>>> env('HOS_JWT_SECRET')
>>> env('JWT_SECRET')
```

---

## KOD DEĞİŞİKLİKLERİ (WP-61)

### work/marketplace-web/src/api/client.js
**Satır 216:**
```javascript
createListing: (data, tenantId, authToken) => {
```

### work/marketplace-web/src/pages/CreateListingPage.vue
**Satır 308:**
```javascript
const demoToken = getToken();
```

**Satır 316:**
```javascript
const result = await api.createListing(payload, this.formData.tenantId || null, demoToken);
```

### work/marketplace-web/src/router.js
**Satır 21:**
```javascript
{ path: '/listing/create', component: CreateListingPage, meta: { requiresAuth: true } }
```
