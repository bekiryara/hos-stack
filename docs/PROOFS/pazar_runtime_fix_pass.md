# Pazar Runtime Fix Pass v1

## Goal
Fix Pazar 500 errors caused by RouteRegistrar::defaults() and log permission issues. Ensure Laravel errors are visible in docker logs and storage permissions are safe in dev.

## Changes Applied

### A) Fixed Wrong "defaults" Call (Root Cause 2)

**Problem**: `Route::defaults()` method does not exist in Laravel 11.x, causing `UnexpectedValueException`.

**Solution**: Removed `Route::defaults()` calls from `work/pazar/routes/api.php`. The world parameter is already handled by middleware (`world.lock:commerce`, `world.lock:food`, `world.lock:rentals`), so URL defaults are not needed.

**Files Modified**:
- `work/pazar/routes/api.php` - Removed 3 `Route::defaults()` calls (lines 32, 48, 64)

### B) Force Logging to STDERR (Root Cause 1)

**Problem**: Laravel tries to write to `storage/logs/laravel.log` which causes permission denied errors.

**Solution**: 
1. `docker-compose.yml` already has `LOG_CHANNEL=stderr` and `LOG_LEVEL=debug`
2. Created `work/pazar/config/logging.php` with `stderr` channel that writes to `php://stderr`
3. Entrypoint already clears caches with `optimize:clear`

**Files Modified**:
- `work/pazar/config/logging.php` (NEW) - Created with stderr channel configuration

### C) Dev Permissions for Storage/Cache

**Problem**: Permission denied when writing to storage/logs in dev environment.

**Solution**: Entrypoint already has DEV MODE section (h) that applies permissive permissions when `APP_ENV=local` or `APP_DEBUG=true`:
- `chmod -R 0777 storage bootstrap/cache`
- `chown -R www-data:www-data storage bootstrap/cache`

**Files Modified**:
- `work/pazar/docker/docker-entrypoint.sh` - Already configured (section h)

### D) Supervisord Scheduler Stability

**Problem**: Scheduler exits 0 and triggers FATAL restarts.

**Solution**: Already configured in `work/pazar/docker/supervisord.conf`:
- `autorestart=false`
- `startretries=0`
- `exitcodes=0`

**Files Modified**:
- `work/pazar/docker/supervisord.conf` - Already configured

## Verification Commands

```powershell
# 1) Rebuild + up
docker compose build pazar-app
docker compose up -d pazar-db pazar-app

# 2) Wait for startup
Start-Sleep -Seconds 10

# 3) Health check
curl.exe -i http://localhost:8080/up
# Expected: HTTP/1.1 200 OK + "ok"

# 4) Root page (should not be 500)
curl.exe -i http://localhost:8080/ | Select-Object -First 20
# Expected: NOT 500; acceptable if 200/302/404, but must not crash with RouteRegistrar::defaults or log permission denied

# 5) Logs visible
docker compose logs --tail 120 pazar-app
# Expected: Laravel errors (if any) appear in logs; no "Permission denied" for laravel.log

# 6) Optional verification
.\ops\verify.ps1
# Expected: Pazar health PASS, and no "service pazar-app is not running"
```

## Expected Results

1. **No RouteRegistrar::defaults error**: Routes load without `UnexpectedValueException`
2. **No permission denied**: Laravel logs to stderr, not storage/logs/laravel.log
3. **Logs visible**: All Laravel errors appear in `docker compose logs pazar-app`
4. **Storage permissions safe**: Dev mode applies 0777 permissions (Windows bind-mount friendly)
5. **Scheduler stable**: No FATAL restarts when schedule:work exits 0
6. **Root page loads**: `/` returns 200/302/404 (not 500)

## Files Modified

1. `work/pazar/routes/api.php` - Removed `Route::defaults()` calls (3 instances)
2. `work/pazar/config/logging.php` (NEW) - Created with stderr channel
3. `work/pazar/docker/docker-entrypoint.sh` - Already has dev permissions (no change needed)
4. `work/pazar/docker/supervisord.conf` - Already has scheduler stability (no change needed)
5. `docker-compose.yml` - Already has LOG_CHANNEL=stderr (no change needed)

## Risk Assessment

1. **Low Risk**: Only route file and config changes, no domain logic
2. **Backward Compatible**: Middleware already handles world parameter, removing defaults doesn't break functionality
3. **Non-Breaking**: Logging to stderr is already configured, just ensuring config file exists
4. **Deterministic**: All changes are explicit and minimal










