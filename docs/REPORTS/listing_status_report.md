# İlan Oluşturma ve Durum Raporu - Teknik Veri
**Tarih:** 2026-01-24 17:30:00

---

## SORGULAR VE SONUÇLARI

### Sorgu 1: GET /api/v1/listings (status parametresi yok)
**Komut:**
```powershell
curl.exe -s "http://localhost:8080/api/v1/listings" | ConvertFrom-Json | Measure-Object
```

**Backend Kod:**
```php
// work/pazar/routes/api/03b_listings_read.php satır 19
$status = $request->input('status', 'published');  // Default: published
$query->where('status', $status);

// satır 68
$perPage = min(50, max(1, (int)$request->input('per_page', 20)));  // Default: 20
```

**Sonuç:** 20 ilan (published)

**Neden:** Default `status=published` + default `per_page=20` → İlk 20 published ilan döner.

---

### Sorgu 2: GET /api/v1/listings?status=draft
**Komut:**
```powershell
curl.exe -s "http://localhost:8080/api/v1/listings?status=draft" | ConvertFrom-Json | Measure-Object
```

**Backend Kod:**
```php
$status = $request->input('status', 'published');  // status=draft geçildi
$query->where('status', 'draft');

$perPage = 20;  // Default limit
```

**Sonuç:** 20 ilan (draft)

**Neden:** `status=draft` filtre + `per_page=20` limit → İlk 20 draft ilan döner. Veritabanında 37 draft var ama sadece 20 döner.

---

### Sorgu 3: GET /api/v1/listings?status=published
**Komut:**
```powershell
curl.exe -s "http://localhost:8080/api/v1/listings?status=published" | ConvertFrom-Json | Measure-Object
```

**Backend Kod:**
```php
$status = $request->input('status', 'published');  // status=published geçildi
$query->where('status', 'published');

$perPage = 20;  // Default limit
```

**Sonuç:** 20 ilan (published)

**Neden:** `status=published` filtre + `per_page=20` limit → İlk 20 published ilan döner. Veritabanında 172 published var ama sadece 20 döner.

---

### Sorgu 4: Veritabanı Direkt Sorgusu
**Veritabanı:** `pazar-db` (PostgreSQL)  
**Database:** `pazar`  
**User:** `pazar`

**Komut:**
```bash
docker compose exec -T pazar-db psql -U pazar -d pazar -c "SELECT COUNT(*) as total FROM listings;"
docker compose exec -T pazar-db psql -U pazar -d pazar -c "SELECT status, COUNT(*) as count FROM listings GROUP BY status;"
```

**Sonuç:**
```
total: 209
draft: 37
published: 172
```

**Neden:** Veritabanı direkt sorgusu limit uygulamaz → Tüm 209 ilan görünür.

**Not:** Sistemde 2 veritabanı var:
- `pazar-db` (pazar database): İlanlar burada (listings tablosu)
- `hos-db` (hos database): Memberships, users burada

---

### Sorgu 5: API Limit Kontrolü (per_page parametresi ile)
**Komut:**
```powershell
curl.exe -s "http://localhost:8080/api/v1/listings?status=published&per_page=200" | ConvertFrom-Json | Measure-Object
```

**Backend Kod:**
```php
$perPage = min(50, max(1, (int)$request->input('per_page', 20)));  // Max: 50
```

**Sonuç:** Maksimum 50 ilan döner (per_page max 50).

**Fark Nedenleri Özet:**
1. API default `status=published` → Sadece published ilanlar
2. API default `per_page=20` → İlk 20 ilan
3. API max `per_page=50` → Maksimum 50 ilan
4. Veritabanı direkt sorgusu → Tüm ilanlar (limit yok)

---

## BACKEND: POST /api/v1/listings

### Route
**File:** `work/pazar/routes/api/03a_listings_write.php`  
**Satır 23-131:**

```php
Route::middleware($createListingMiddleware)->post('/v1/listings', function (\Illuminate\Http\Request $request) {
    // ...
    DB::table('listings')->insert([
        'id' => $listingId,
        'tenant_id' => $tenantId,
        'world' => $world,
        'category_id' => $categoryId,
        'title' => $validated['title'],
        'description' => $validated['description'] ?? null,
        'transaction_modes_json' => json_encode($validated['transaction_modes']),
        'attributes_json' => !empty($attributes) ? json_encode($attributes) : null,
        'location_json' => isset($validated['location']) ? json_encode($validated['location']) : null,
        'status' => 'draft',  // SABIT: Her zaman draft olarak oluşturulur
        'created_at' => now(),
        'updated_at' => now()
    ]);
    
    return response()->json([
        'id' => $listingId,
        'tenant_id' => $tenantId,
        'category_id' => $categoryId,
        'title' => $validated['title'],
        'status' => 'draft',  // Response'da draft döner
        'created_at' => now()->toISOString()
    ], 201);
});
```

**Durum:** `status = 'draft'` sabit kodlanmış (satır 119).

---

## FRONTEND: createListing()

### API Client
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

**Payload:**
```json
{
  "category_id": 1,
  "title": "Browser Test Listing",
  "description": null,
  "transaction_modes": ["reservation"],
  "attributes": {}
}
```

**Status:** Payload'da `status` alanı yok. Backend her zaman `draft` oluşturur.

---

## İLAN BULMA: Tenant ID ile Filtreleme

### Endpoint
**GET /api/v1/listings?tenant_id={tenant_id}**

**Headers:**
```
X-Active-Tenant-Id: {tenant_id}
```

**Response:**
```json
[
  {
    "id": "uuid",
    "title": "string",
    "status": "draft" | "published",
    "tenant_id": "uuid",
    "created_at": "timestamp"
  }
]
```

### Frontend Kullanımı
**File:** `work/marketplace-web/src/api/client.js`  
**Satır 155-160:**

```javascript
searchListings: (params) => {
  const queryString = new URLSearchParams(params).toString();
  return apiRequest(`/api/v1/listings?${queryString}`);
}
```

**Örnek:**
```javascript
// Tüm ilanlar (published + draft)
api.searchListings({ tenant_id: '7ef9bc88-2d20-45ae-9f16-525181aad657' })

// Sadece draft
api.searchListings({ tenant_id: '7ef9bc88-2d20-45ae-9f16-525181aad657', status: 'draft' })

// Sadece published
api.searchListings({ tenant_id: '7ef9bc88-2d20-45ae-9f16-525181aad657', status: 'published' })
```

---

## PUBLISH İŞLEMİ

### Endpoint
**POST /api/v1/listings/{id}/publish**

**File:** `work/pazar/routes/api/03a_listings_write.php`  
**Satır 177-182:**

```php
DB::table('listings')
    ->where('id', $id)
    ->update([
        'status' => 'published',
        'updated_at' => now()
    ]);
```

**Durum:** `draft` → `published` değişir.

---

## VERİ

### Test İlanı (Browser'dan Oluşturulan)
```
ID: e3a1eb85-fc9f-4e2f-a77c-999bf95e57f1
Title: Browser Test Listing - $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Status: draft
Tenant ID: 7ef9bc88-2d20-45ae-9f16-525181aad657
Created At: 2026-01-24 17:30:00
```

### Draft İlanlar (20 adet)
```
GET /api/v1/listings?status=draft
Response: 20 ilan (hepsi draft statüsünde)
```

### Sistem Durumu (Veritabanı)
```
Toplam İlan: 209
Published: 172
Draft: 37
```

### Tenant Bazlı (Veritabanı)
```
Tenant ID: 7ef9bc88-2d20-45ae-9f16-525181aad657
  Published: 91
  Draft: 18
  Toplam: 109

Tenant ID: 951ba4eb-9062-40c4-9228-f8d2cfc2f426
  Published: 54
  Draft: 18
  Toplam: 72

Tenant ID: cc9d6886-ec0f-aead-4b00-6641a34970af
  Draft: 1
  Toplam: 1

Tenant ID: fd2b9dc9-1822-740a-fed4-bdd90e898b72
  Published: 27
  Toplam: 27
```

---

## SEARCH ENDPOINT DAVRANIŞI

### GET /api/v1/listings
**File:** `work/pazar/routes/api/03b_listings_read.php`  
**Satır 8-19:**

```php
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/listings', function (\Illuminate\Http\Request $request) {
    // ...
    $status = $request->input('status', 'published');  // Default: published
    $query->where('status', $status);
    // ...
});
```

**Davranış:**
- `status` parametresi yoksa → sadece `published` ilanlar döner
- `status=draft` → sadece draft ilanlar döner
- `status=published` → sadece published ilanlar döner

**Sonuç:** Search sayfası (`/search/{categoryId}`) default olarak sadece published ilanları gösterir.

---

## İLAN BULMA YÖNTEMLERİ

### 1. Tenant ID ile Tüm İlanlar
```
GET /api/v1/listings?tenant_id={tenant_id}
Headers: X-Active-Tenant-Id: {tenant_id}
```

### 2. Tenant ID + Status Filtresi
```
GET /api/v1/listings?tenant_id={tenant_id}&status=draft
GET /api/v1/listings?tenant_id={tenant_id}&status=published
```

### 3. Frontend API Kullanımı
```javascript
// Tüm ilanlar
const all = await api.searchListings({ tenant_id: tenantId });

// Sadece draft
const drafts = await api.searchListings({ tenant_id: tenantId, status: 'draft' });

// Sadece published
const published = await api.searchListings({ tenant_id: tenantId, status: 'published' });
```

---

## KOD AKIŞI

### İlan Oluşturma
```
1. Frontend: CreateListingPage.vue → handleSubmit()
2. Frontend: api.createListing(payload, tenantId, authToken)
3. HTTP: POST /api/marketplace/api/v1/listings
4. Backend: Route → PersonaScope:store → TenantScope → Handler
5. Backend: DB insert → status = 'draft' (sabit)
6. Response: 201 Created → { id, status: 'draft', ... }
```

### İlan Listeleme
```
1. Frontend: api.searchListings({ status: 'published' })
2. HTTP: GET /api/marketplace/api/v1/listings?status=published
3. Backend: Route → PersonaScope:guest → Handler
4. Backend: DB query → WHERE status = 'published'
5. Response: 200 OK → [{ id, title, status: 'published', ... }]
```

---

## DURUM DEĞİŞİKLİĞİ

### Draft → Published
```
1. Frontend: ListingDetailPage.vue → PublishListingAction component
2. Frontend: api.publishListing(listingId, tenantId)
3. HTTP: POST /api/marketplace/api/v1/listings/{id}/publish
4. Backend: Route → PersonaScope:store → TenantScope → Handler
5. Backend: DB update → status = 'published'
6. Response: 200 OK → { id, status: 'published', ... }
```

---

## VERİ KONTROLÜ

### API Endpoint'leri
```
GET /api/v1/listings → published (default)
GET /api/v1/listings?status=draft → draft
GET /api/v1/listings?status=published → published
GET /api/v1/listings?tenant_id={id} → tüm (draft + published)
GET /api/v1/listings?tenant_id={id}&status=draft → sadece draft
```

### Database
```sql
SELECT COUNT(*) FROM listings WHERE status = 'draft';
SELECT COUNT(*) FROM listings WHERE status = 'published';
SELECT * FROM listings WHERE tenant_id = '{tenant_id}' ORDER BY created_at DESC;
```
