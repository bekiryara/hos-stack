# PROOF: PersonaScope Middleware Alias Fix

**Date:** 2026-01-19  
**Issue:** GET /api/v1/categories returns 500 with "Target class [persona.scope] does not exist"  
**Fix:** Added `persona.scope` alias to `bootstrap/app.php` middleware aliases

## Verification Commands

### 1. Clear Laravel Caches
```bash
docker compose exec pazar-app php artisan config:clear
docker compose exec pazar-app php artisan route:clear
```

**Output:**
```
INFO  Configuration cache cleared successfully.
INFO  Route cache cleared successfully.
```

### 2. Restart Container
```bash
docker compose restart pazar-app
```

**Output:**
```
Container stack-pazar-app-1  Restarting
Container stack-pazar-app-1  Started
```

### 3. Test GET /api/v1/categories

**Command:**
```bash
curl -i http://localhost:8080/api/v1/categories
```

**Response:**
```
HTTP/1.1 200 OK
```

**Status:** ✅ **PASS** - Endpoint returns 200 (not 500)

### 4. Verify Route Registration

**Command:**
```bash
docker compose exec pazar-app php artisan route:list --path=categories
```

**Output:**
```
GET|HEAD   api/v1/categories ...................
GET|HEAD   api/v1/categories/{id}/filter-schema
```

**Status:** ✅ **PASS** - Routes are registered

### 5. Verify Middleware Alias in Container

**Command:**
```bash
docker compose exec pazar-app sh -c "grep -A 2 'tenant.scope' bootstrap/app.php"
```

**Output (after fix):**
```
'tenant.scope' => \App\Http\Middleware\TenantScope::class, // WP-26: Store-scope X-Active-Tenant-Id + membership enforcement
'persona.scope' => \App\Http\Middleware\PersonaScope::class, // WP-8: Persona-based header enforcement
```

**Status:** ✅ **PASS** - Alias is present in container

## Before Fix

**Error:**
```
HTTP/1.1 500 Internal Server Error
{"ok":false,"error_code":"INTERNAL_ERROR","message":"Server error."}
```

**Logs:**
```
Target class [persona.scope] does not exist.
```

## After Fix

**Response:**
```
HTTP/1.1 200 OK
```

**Status:** ✅ **FIXED** - No more 500 errors

## Guardrail Added

Added guardrail check in `ops/catalog_contract_check.ps1`:
- Checks for HTTP 500 status
- Checks for "Target class [persona.scope] does not exist" error message
- Fails fast if middleware registration issue detected

## Files Modified

1. **work/pazar/bootstrap/app.php** (line 71)
   - Added: `'persona.scope' => \App\Http\Middleware\PersonaScope::class,`

2. **ops/catalog_contract_check.ps1**
   - Added guardrail check for 500 errors and middleware registration errors

## Acceptance Criteria

- ✅ GET /api/v1/categories returns 200 (or non-500 controlled error)
- ✅ No "Target class [persona.scope] does not exist" in logs
- ✅ Ops contract check includes guardrail and passes
- ✅ Minimal diff, deterministic


