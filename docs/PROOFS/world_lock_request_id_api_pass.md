# World Lock + Request ID API Pass

**Date:** 2026-01-15  
**Scope:** WorldLock middleware + RequestId API stack integration + Commerce read-path fix

## Evidence Items

### 1. WorldLock Middleware Created

**File:** `work/pazar/app/Http/Middleware/WorldLock.php`

**Verification:**
```bash
# Check middleware exists
ls work/pazar/app/Http/Middleware/WorldLock.php
```

**Expected:** File exists with `handle(Request $request, Closure $next, string $world)` method that:
- Validates world is enabled using `config('worlds.enabled')`
- Returns 404 with `WORLD_DISABLED` or `WORLD_INVALID` error if world is disabled/unknown
- Sets `ctx.world` and `world` attributes on request
- Adds `X-World` header to response

### 2. WorldLock Registered in Bootstrap

**File:** `work/pazar/bootstrap/app.php`

**Verification:**
```bash
# Check alias registration
grep -A 1 "world.lock" work/pazar/bootstrap/app.php
```

**Expected:** Line contains:
```php
'world.lock' => \App\Http\Middleware\WorldLock::class,
```

### 3. WorldLock Applied to Commerce Routes

**File:** `work/pazar/routes/api.php`

**Verification:**
```bash
# Check commerce routes have world.lock:commerce middleware
grep -A 5 "v1/commerce" work/pazar/routes/api.php
```

**Expected:** Commerce routes include:
```php
Route::middleware(['world.lock:commerce', 'auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
```

### 4. RequestId Middleware Added to API Stack

**File:** `work/pazar/bootstrap/app.php`

**Verification:**
```bash
# Check API middleware stack
grep -A 3 "api(append" work/pazar/bootstrap/app.php
```

**Expected:** Contains:
```php
$middleware->api(append: [
    \App\Http\Middleware\RequestId::class,
]);
```

### 5. Commerce Read-Path Fix (Graceful ctx.world Handling)

**File:** `work/pazar/app/Http/Controllers/Api/Commerce/ListingController.php`

**Verification:**
```bash
# Check index() and show() methods
grep -A 10 "Enforce world scope" work/pazar/app/Http/Controllers/Api/Commerce/ListingController.php
```

**Expected:** Code contains:
```php
// Enforce world scope (defensive: if ctx.world missing, default to commerce; if present and mismatch, error)
$worldId = $request->attributes->get('ctx.world');
if (empty($worldId)) {
    // Defensive default: if world.lock middleware didn't run, assume commerce (should not happen, but safe fallback)
    $worldId = 'commerce';
    $request->attributes->set('ctx.world', $worldId);
} elseif ($worldId !== 'commerce') {
    // Mismatch protection: if world is set but not commerce, return error
    return $this->worldContextInvalid($request);
}
```

### 6. API Responses Include X-Request-Id Header

**Verification:**
```bash
# Test API endpoint
curl -i -X GET "http://localhost:8080/api/v1/commerce/listings" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-Id: $TENANT_ID"
```

**Expected Response Headers:**
```
HTTP/1.1 200 OK
X-Request-Id: <uuid>
X-World: commerce
Content-Type: application/json
```

**Expected Response Body:**
```json
{
  "ok": true,
  "data": { ... },
  "request_id": "<uuid>"
}
```

### 7. Request Attribute ctx.world Set via WorldLock

**Verification:**
```bash
# Check Laravel logs for ctx.world attribute
docker compose logs pazar-app | grep "ctx.world"
```

**Expected:** Log entries show `ctx.world: commerce` in request context.

## Summary

✅ WorldLock middleware created and registered  
✅ WorldLock applied to Commerce routes  
✅ RequestId middleware added to API stack  
✅ Commerce read-path handles missing ctx.world gracefully  
✅ API responses include X-Request-Id header  
✅ Request attribute ctx.world set via WorldLock



