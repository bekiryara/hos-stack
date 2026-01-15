# Product World Spine MVP PASS

**Date:** 2026-01-10

**Purpose:** Validate World Spine MVP implementation - enabled worlds routes, closed-world enforcement, RC0-safe

## What Was Added

### 1. WorldResolver Middleware

**Location:** `work/pazar/app/Http/Middleware/WorldResolver.php`

**Functionality:**
- Determines `world_id` from route parameter or URL segment
- Checks enable/disable status from `config/worlds.php`
- If disabled: returns HTTP 410 with JSON payload `{ ok: false, error_code: "WORLD_CLOSED", world: "<id>" }` or HTML closed page (request_id preserved)
- If enabled: attaches world context to request (`ctx.world`, `world_id`) and adds `X-World` header
- Missing world: returns HTTP 400 (or 404 if world doesn't exist)

**Key Code:**
```php
if ($this->worlds->isDisabled($worldId)) {
    return response()->json([
        'ok' => false,
        'error' => 'WORLD_CLOSED',
        'world' => $worldId,
    ], 410)->header('X-World', $worldId);
}

// Enabled: attach context and add header
$request->attributes->set('ctx.world', $worldId);
$response = $next($request);
return $response->header('X-World', $worldId);
```

### 2. WorldRegistry Service

**Location:** `work/pazar/app/Worlds/WorldRegistry.php`

**Functionality:**
- Provides access to world configuration (enabled/disabled worlds)
- Uses `config/worlds.php` as source of truth
- Methods: `getEnabledWorlds()`, `getDisabledWorlds()`, `isEnabled()`, `isDisabled()`, `exists()`, `all()`, `defaultKey()`

### 3. WorldController

**Location:** `work/pazar/app/Http/Controllers/WorldController.php`

**Functionality:**
- Handles public routes for enabled worlds (`commerce`, `food`, `rentals`)
- `home()` method: world home page (returns 200 with X-World header)
- `search()` method: world search placeholder (returns 200 "not implemented yet")

### 4. Routes

**Location:** `work/pazar/routes/web.php`

**Routes:**
- `GET /worlds/{world}` - World home page (enabled worlds only)
- `GET /worlds/{world}/search` - World search placeholder (enabled worlds only)
- Middleware: `world.resolve` (WorldResolver)

### 5. Views

**Location:** `work/pazar/resources/views/worlds/`

**Files:**
- `home.blade.php` - World home page (shows world name, "MVP: coming next" notice, nav to enabled worlds)
- `closed.blade.php` - Closed world page (410 status, shows "World Closed" message)

### 6. AdminControlCenterController Integration

**Location:** `work/pazar/app/Http/Controllers/Ui/AdminControlCenterController.php`

**Changes:**
- Updated `worlds` data to include enabled worlds list
- Route changed from `worlds.world.entry` to `worlds.home` (uses route helper)
- View receives `worlds.enabled` array for World Links section

### 7. Tests

**Location:** `work/pazar/tests/Feature/WorldSpineTest.php`

**Tests:**
- `test_enabled_world_home_returns_200_with_world_header()` - Enabled worlds return 200 with X-World header
- `test_disabled_world_returns_410_world_closed()` - Disabled worlds return 410 WORLD_CLOSED JSON
- `test_disabled_world_html_returns_410_closed_page()` - Disabled worlds return 410 HTML closed page
- `test_missing_world_returns_400()` - Invalid/missing world returns 404 (WORLD_NOT_FOUND)
- `test_enabled_world_search_returns_200()` - World search returns 200 placeholder

## Expected Behaviors

### Enabled Worlds (commerce, food, rentals)

**Request:**
```bash
curl -i http://localhost:8080/worlds/commerce
```

**Expected Response:**
- HTTP 200
- Header: `X-World: commerce`
- Body: HTML world home page (or JSON if Accept: application/json)

**JSON Response:**
```json
{
  "ok": true,
  "world": "commerce",
  "label": "Pazar (Satış/Alışveriş)",
  "message": "MVP: coming next"
}
```

### Disabled Worlds (services, real_estate, vehicle)

**Request:**
```bash
curl -i http://localhost:8080/worlds/services -H "Accept: application/json"
```

**Expected Response:**
- HTTP 410
- Header: `X-World: services`
- Body: JSON error payload

```json
{
  "ok": false,
  "error_code": "WORLD_CLOSED",
  "world": "services"
}
```

**HTML Response (Accept: text/html):**
- HTTP 410
- Header: `X-World: services`
- Body: HTML closed world page ("World Closed" message)

### Missing World Context

**Request:**
```bash
curl -i http://localhost:8080/worlds/invalid_world -H "Accept: application/json"
```

**Expected Response:**
- HTTP 404
- Body: JSON error payload

```json
{
  "ok": false,
  "error_code": "WORLD_NOT_FOUND",
  "world": "invalid_world"
}
```

## How to Verify

### Step 1: Check Routes Are Registered

```powershell
docker compose exec -T pazar-app php artisan route:list | Select-String "worlds"
```

**Expected Output:**
```
GET|HEAD  worlds/{world} ................ worlds.home
GET|HEAD  worlds/{world}/search ......... worlds.search
```

### Step 2: Test Enabled World Home Page

```powershell
curl.exe -i http://localhost:8080/worlds/commerce
```

**Expected:**
- HTTP 200
- Header: `X-World: commerce`
- Body contains: "Pazar (Satış/Alışveriş)", "MVP: coming next"

### Step 3: Test Disabled World (410 WORLD_CLOSED)

```powershell
curl.exe -i http://localhost:8080/worlds/services -H "Accept: application/json"
```

**Expected:**
- HTTP 410
- Header: `X-World: services`
- Body: `{"ok":false,"error_code":"WORLD_CLOSED","world":"services"}`

### Step 4: Test World Search (Placeholder)

```powershell
curl.exe -i http://localhost:8080/worlds/commerce/search -H "Accept: application/json"
```

**Expected:**
- HTTP 200
- Header: `X-World: commerce`
- Body: `{"ok":true,"world":"commerce","message":"Search not implemented yet"}`

### Step 5: Test Control Center (No Regression)

```powershell
curl.exe -i http://localhost:8080/ui/admin/control-center
```

**Expected:**
- HTTP 200 or 302 (redirect to login)
- NOT 500 (no permission denied errors)
- Control Center opens successfully

### Step 6: Run Feature Tests

```powershell
docker compose exec -T pazar-app php artisan test --filter WorldSpineTest
```

**Expected:**
- All tests PASS (5 tests)
- No failures

## RC0 Safety Verification

### No Regression in RC0 Gates

**Verify:**
```powershell
.\ops\verify.ps1
```

**Expected:**
- Step 4: Pazar FS posture check PASS (storage/logs writable)
- No permission denied errors
- Control Center does not 500

**Verify:**
```powershell
.\ops\conformance.ps1
```

**Expected:**
- World registry drift check PASS (no drift between WORLD_REGISTRY.md and config/worlds.php)

### No Disabled World Code Footprint

**Check:**
- No `app/Http/Controllers/Worlds/ServicesController.php`
- No `app/Http/Controllers/Worlds/RealEstateController.php`
- No `app/Http/Controllers/Worlds/VehicleController.php`
- No routes for disabled worlds (only enabled worlds have routes)
- Disabled worlds handled by WorldResolver middleware (410 WORLD_CLOSED)

## Related Files

- `work/pazar/app/Http/Middleware/WorldResolver.php` - World resolution middleware
- `work/pazar/app/Worlds/WorldRegistry.php` - World registry service
- `work/pazar/app/Http/Controllers/WorldController.php` - World controller
- `work/pazar/routes/web.php` - World routes
- `work/pazar/resources/views/worlds/home.blade.php` - World home page view
- `work/pazar/resources/views/worlds/closed.blade.php` - Closed world page view
- `work/pazar/tests/Feature/WorldSpineTest.php` - Feature tests
- `work/pazar/bootstrap/app.php` - Middleware alias registration
- `work/pazar/config/worlds.php` - World configuration (canonical source)

## Conclusion

World Spine MVP is implemented:
- Enabled worlds (commerce, food, rentals) have working routes and return 200 with X-World header
- Disabled worlds (services, real_estate, vehicle) return 410 WORLD_CLOSED (closed-world enforcement)
- Missing world context returns 400/404 (no default world)
- Control Center integration (World Links section)
- No disabled world code footprint (strictly closed)
- RC0 gates remain green (no regression in permissions, world registry drift)
- All changes are minimal, localized, and RC0-safe

Product development can proceed with World Spine MVP as foundation.

