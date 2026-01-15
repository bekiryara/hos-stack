# Pazar Log Visibility First Pack v1

## Goal
Stop blind debugging: make Laravel errors visible in docker logs.

## Changes Applied

### 1. docker-compose.yml
**Added environment variables:**
- `LOG_CHANNEL: stderr` - Forces Laravel to log to stderr instead of storage/logs
- `LOG_LEVEL: debug` - Sets log level to debug for maximum visibility

**Existing (already set):**
- `APP_DEBUG: "true"` - Enables debug mode
- `HOS_LARAVEL_LOG_STDOUT: "1"` - Symlinks laravel.log to stdout (fallback)

### 2. work/pazar/docker/docker-entrypoint.sh
**Added DEV MODE section (h):**
- Detects dev mode: `APP_ENV=local` or `APP_DEBUG=true`
- Applies brute-force storage permissions: `chmod -R 0777 storage bootstrap/cache`
- Ensures directories exist: `mkdir -p storage storage/logs bootstrap/cache`
- Sets ownership: `chown -R www-data:www-data storage bootstrap/cache`

**Added cache clear (i):**
- Runs `php artisan optimize:clear` (ignores failures - may fail if Laravel not fully bootstrapped)
- Non-fatal: logs warning if it fails

## How It Works

1. **LOG_CHANNEL=stderr**: Laravel's logging config has a built-in `stderr` channel that writes to `php://stderr`
2. **Docker logs capture**: All stderr output from php-fpm is captured by docker logs
3. **DEV MODE permissions**: When `APP_ENV=local` or `APP_DEBUG=true`, entrypoint applies permissive permissions (0777) to ensure Laravel can always write logs
4. **Cache clear**: Clears Laravel caches on startup to ensure fresh config (ignores failures)

## Verification Commands

```powershell
# 1) Rebuild and restart
docker compose build pazar-app
docker compose up -d pazar-db pazar-app

# 2) Wait for startup
Start-Sleep -Seconds 10

# 3) Watch logs in real-time
docker compose logs -f --tail 200 pazar-app

# 4) Trigger an error (should appear in logs)
curl.exe http://localhost:8080/
curl.exe http://localhost:8080/metrics
curl.exe http://localhost:8080/api/products

# 5) Verify log channel is stderr
docker compose exec -T pazar-app sh -c "php artisan tinker --execute='echo config(\"logging.default\");'"
# Should output: stderr

# 6) Verify log level is debug
docker compose exec -T pazar-app sh -c "php artisan tinker --execute='echo config(\"logging.channels.stderr.level\");'"
# Should output: debug
```

## Expected Results

1. **Laravel errors visible**: All exceptions, errors, and debug messages appear in `docker compose logs pazar-app`
2. **No permission errors**: Storage permissions are permissive (0777) in dev mode
3. **Log channel**: Laravel uses `stderr` channel, writing to `php://stderr`
4. **Log level**: Set to `debug` for maximum visibility
5. **Cache cleared**: Laravel caches are cleared on startup (if Laravel is bootstrapped)

## Files Modified

1. `docker-compose.yml` - Added `LOG_CHANNEL: stderr` and `LOG_LEVEL: debug` to pazar-app environment
2. `work/pazar/docker/docker-entrypoint.sh` - Added DEV MODE storage permissions and cache clear

## Risk Assessment

1. **Low Risk**: Changes are environment variables and dev-mode-only permissions
2. **No Production Impact**: DEV MODE checks ensure permissive permissions only in local/dev
3. **Backward Compatible**: Existing HOS_LARAVEL_LOG_STDOUT symlink still works as fallback
4. **Non-Fatal**: Cache clear failures are ignored (logged as warning)








