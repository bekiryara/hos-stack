# WP-61: Create Listing 401 - POST İsteği Akış Analizi
**Date:** 2025-01-24

---

## POST İSTEĞİ AKIŞI

### 1. Frontend: Form Submit
**File:** `work/marketplace-web/src/pages/CreateListingPage.vue`  
**Satır 272-316:**

```javascript
async handleSubmit() {
  // Validation
  if (!this.formData.tenantId || !this.formData.category_id || !this.formData.title || this.formData.transaction_modes.length === 0) {
    return;
  }
  
  // Payload
  const payload = {
    category_id: this.formData.category_id,
    title: this.formData.title,
    description: this.formData.description || null,
    transaction_modes: this.formData.transaction_modes,
    attributes: Object.keys(attributes).length > 0 ? attributes : null,
  };
  
  // Token
  const demoToken = getToken(); // localStorage.getItem('demo_auth_token')
  
  // API Call
  const result = await api.createListing(payload, this.formData.tenantId || null, demoToken);
}
```

**Veri:**
```
demoToken: <token_value> veya null
formData.tenantId: 7ef9bc88-2d20-45ae-9f16-525181aad657
payload: { category_id: 1, title: "2121", transaction_modes: ["reservation"], ... }
```

---

### 2. Frontend: API Client
**File:** `work/marketplace-web/src/api/client.js`  
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

**Veri:**
```
authToken: <demoToken_value> veya null
activeTenantId: 7ef9bc88-2d20-45ae-9f16-525181aad657
idempotencyKey: <uuid>
```

**buildPersonaHeaders() - Satır 34-45:**
```javascript
if (personaMode === PERSONA_MODES.STORE) {
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

**Headers Oluşturuldu:**
```
Content-Type: application/json
X-Active-Tenant-Id: 7ef9bc88-2d20-45ae-9f16-525181aad657
Idempotency-Key: <uuid>
Authorization: Bearer <token> (eğer authToken varsa)
```

---

### 3. Frontend: HTTP Request
**File:** `work/marketplace-web/src/api/client.js`  
**Satır 51-63:**

```javascript
export async function apiRequest(endpoint, options = {}) {
  const url = `${API_BASE_URL}${endpoint}`; // http://localhost:8080/api/v1/listings
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });
}
```

**HTTP Request:**
```
Method: POST
URL: http://localhost:8080/api/v1/listings
Headers:
  Content-Type: application/json
  X-Active-Tenant-Id: 7ef9bc88-2d20-45ae-9f16-525181aad657
  Idempotency-Key: <uuid>
  Authorization: Bearer <token> (eğer authToken varsa)
Body: {"category_id":1,"title":"2121","transaction_modes":["reservation"],...}
```

---

### 4. Browser: CORS Preflight
**Request:**
```
Method: OPTIONS
URL: http://localhost:8080/api/v1/listings
Headers:
  Origin: http://localhost:3002
  Access-Control-Request-Method: POST
  Access-Control-Request-Headers: content-type,x-active-tenant-id,authorization,idempotency-key
```

**Response:**
```
Status: 204 No Content
Headers:
  Access-Control-Allow-Origin: http://localhost:3002
  Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS
  Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept, X-Active-Tenant-Id, Idempotency-Key
  Access-Control-Max-Age: 86400
```

**Durum:** PASS

---

### 5. Backend: Nginx Proxy
**File:** `work/pazar/nginx.conf` (varsa) veya Docker routing

**Request:**
```
POST http://localhost:8080/api/v1/listings
→ Nginx → Laravel app (port 80)
```

---

### 6. Backend: Laravel Route
**File:** `work/pazar/routes/api/03a_listings_write.php`  
**Satır 14:**

```php
Route::middleware([
    \App\Http\Middleware\PersonaScope::class . ':store',
    'auth.any',
    'tenant.scope'
])->post('/v1/listings', function (\Illuminate\Http\Request $request) {
```

**Middleware Chain:**
1. PersonaScope:store
2. auth.any
3. tenant.scope
4. Handler

---

### 7. Backend: PersonaScope Middleware
**File:** `work/pazar/app/Http/Middleware/PersonaScope.php`  
**Satır 61-73:**

```php
if ($persona === 'store') {
    $tenantIdHeader = $request->header('X-Active-Tenant-Id');
    if (!$tenantIdHeader) {
        return response()->json([
            'error' => 'missing_header',
            'message' => 'X-Active-Tenant-Id header is required for store-scope operations'
        ], 400);
    }
    return $next($request);
}
```

**Kontrol:**
```
$request->header('X-Active-Tenant-Id') → "7ef9bc88-2d20-45ae-9f16-525181aad657"
```

**Durum:** PASS → Sonraki middleware'e geç

---

### 8. Backend: AuthAny Middleware
**File:** `work/pazar/app/Http/Middleware/AuthAny.php`  
**Satır 23-66:**

```php
public function handle(Request $request, Closure $next): Response
{
    // Session check
    if (Auth::check()) {
        return $next($request);
    }
    // Auth::check() → false

    // Bearer token check
    $bearerToken = $request->bearerToken();
    // $bearerToken → <token_value> veya null
    
    if ($bearerToken !== null) {
        // API key check
        $apiKey = env('HOS_OIDC_API_KEY');
        if ($apiKey !== null && $apiKey !== '' && $bearerToken === $apiKey) {
            return $next($request);
        }
        // API key match → false
        
        // JWT validation
        $jwtSecret = env('HOS_JWT_SECRET') ?: env('JWT_SECRET');
        if ($jwtSecret && strlen($jwtSecret) >= 32) {
            try {
                $payload = $this->verifyJWT($bearerToken, $jwtSecret);
                return $next($request);
            } catch (\Exception $e) {
                // JWT validation failed
            }
        }
    }

    // 401 Response
    return response()->json([
        'ok' => false,
        'error_code' => 'UNAUTHORIZED',
        'message' => 'Unauthenticated.',
        'request_id' => $requestId,
    ], 401);
}
```

**Kontrol Adımları:**
1. `Auth::check()` → false
2. `$request->bearerToken()` → `<token_value>` veya null
3. `$bearerToken === $apiKey` → false
4. `verifyJWT($bearerToken, $jwtSecret)` → Exception (JWT validation failed)
5. Response: 401

**Kırılma Noktası:** JWT validation fail

---

### 9. Laravel: bearerToken() Metodu
**Laravel Request Class:**

```php
public function bearerToken()
{
    $header = $this->header('Authorization', '');
    if (Str::startsWith($header, 'Bearer ')) {
        return Str::substr($header, 7);
    }
    return null;
}
```

**Veri:**
```
$request->header('Authorization') → "Bearer <token>" veya null
$bearerToken → "<token>" veya null
```

---

### 10. Backend: verifyJWT() Metodu
**File:** `work/pazar/app/Http/Middleware/AuthAny.php`  
**Satır 68-122:**

```php
protected function verifyJWT(string $token, string $secret): array
{
    try {
        $decoded = \Firebase\JWT\JWT::decode($token, new \Firebase\JWT\Key($secret, 'HS256'));
        return (array) $decoded;
    } catch (\Exception $e) {
        throw new \Exception('JWT validation failed: ' . $e->getMessage());
    }
}
```

**Kontrol:**
```
JWT::decode($bearerToken, $secret, 'HS256')
→ Exception: "JWT validation failed: ..."
```

**Olası Exception Nedenleri:**
- Token expired
- Token signature invalid (secret mismatch)
- Token format invalid
- Token malformed

---

## KIRILMA NOKTASI

### Akış
```
1. Frontend: getToken() → <token_value> veya null
2. Frontend: buildPersonaHeaders() → Authorization: Bearer <token> (eğer token varsa)
3. Browser: POST request → Authorization header gönderiliyor
4. Backend: PersonaScope → PASS
5. Backend: AuthAny → bearerToken() → <token_value>
6. Backend: verifyJWT() → Exception
7. Backend: 401 Response
```

### Kırılma Noktası
**File:** `work/pazar/app/Http/Middleware/AuthAny.php`  
**Satır 41-48:**

```php
try {
    $payload = $this->verifyJWT($bearerToken, $jwtSecret);
    return $next($request);
} catch (\Exception $e) {
    // JWT validation failed, continue to 401
}
```

**Sebep:**
- `verifyJWT()` Exception throw ediyor
- JWT decode fail ediyor
- Token geçersiz/expired veya secret mismatch

---

## VERİ KONTROLÜ

### Frontend Token
```javascript
localStorage.getItem('demo_auth_token')
// Beklenen: <jwt_token_string>
// Gerçek: <token_value> veya null
```

### Request Headers (Network Tab)
```
POST http://localhost:8080/api/v1/listings
Headers:
  Content-Type: application/json
  X-Active-Tenant-Id: 7ef9bc88-2d20-45ae-9f16-525181aad657
  Idempotency-Key: <uuid>
  Authorization: Bearer <token> (kontrol edilmeli)
```

### Backend JWT Secret
```bash
docker compose exec pazar-app php artisan tinker
>>> env('HOS_JWT_SECRET')
>>> env('JWT_SECRET')
```

### Backend Log
```bash
docker compose logs pazar-app | grep -i "jwt\|unauthorized\|401"
```

---

## KOD DEĞİŞİKLİKLERİ (WP-61)

### work/marketplace-web/src/api/client.js
**Satır 216:**
```javascript
createListing: (data, tenantId, authToken) => {
```

**Satır 220:**
```javascript
const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: activeTenantId, authToken });
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

---

## RESPONSE

### 401 Response Body
```json
{
  "ok": false,
  "error_code": "UNAUTHORIZED",
  "message": "Unauthenticated.",
  "request_id": "<uuid>"
}
```

### Response Headers
```
HTTP/1.1 401 Unauthorized
Content-Type: application/json
X-Request-Id: <uuid>
```

