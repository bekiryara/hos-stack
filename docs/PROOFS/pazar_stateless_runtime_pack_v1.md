# Pazar Stateless Laravel Runtime (H-OS Contract) Pack v1

## Goal
Make Pazar runtime stateless: env-only config, no .env file dependency, stderr logging, dev-friendly permissions, non-fatal scheduler.

## Changes Applied

### A) docker-compose.yml (pazar-app service)

**Changes**:
1. Added `APP_KEY` placeholder comment (generate via proof commands)
2. Removed `.env` file mount (stateless runtime, all config from ENV)
3. Verified `LOG_CHANNEL=stderr` and `LOG_LEVEL=debug` are set
4. Verified storage/cache volumes: `pazar_storage:/var/www/html/storage`, `pazar_cache:/var/www/html/bootstrap/cache`

**Files Modified**:
- `docker-compose.yml` - Removed .env mount, added APP_KEY placeholder

### B) work/pazar/docker/docker-entrypoint.sh

**Changes**:
1. Added `LOG_CHANNEL=stderr` check: if set, skip laravel.log file creation entirely
2. Laravel writes to `php://stderr` which is captured by docker logs
3. Legacy fallback: if not stderr, create laravel.log with permissive permissions (for compatibility)
4. DEV MODE section already applies `chmod -R 0777` when `APP_ENV=local` or `APP_DEBUG=true`
5. `optimize:clear` already best-effort (non-fatal)

**Files Modified**:
- `work/pazar/docker/docker-entrypoint.sh` - Added LOG_CHANNEL=stderr check, skip laravel.log when stderr

### C) work/pazar/docker/supervisord.conf

**Changes**:
1. Added `autostart=false` to `[program:laravel-scheduler]` (dev mode: scheduler disabled)
2. Kept `autorestart=false`, `startretries=0`, `exitcodes=0` (non-fatal if started manually)
3. php-fpm and nginx unchanged

**Files Modified**:
- `work/pazar/docker/supervisord.conf` - Added autostart=false to scheduler

### D) work/pazar/docker/nginx/default.conf

**Changes**:
1. Added `/up` nginx-level endpoint (returns 200 "ok" without Laravel)
2. Laravel front controller standard unchanged

**Files Modified**:
- `work/pazar/docker/nginx/default.conf` - Added /up endpoint

## Verification Commands

```powershell
# Run from: D:\stack

# 0) Rebuild + restart Pazar
docker compose build pazar-app
docker compose up -d pazar-db pazar-app
Start-Sleep -Seconds 5
docker compose ps

# 1) /up nginx-level must be OK (Laravel down olsa bile)
curl.exe -i http://localhost:8080/up

# 2) Generate APP_KEY (env-only). Output: base64:....
# NOTE: This does NOT write .env. Copy the printed key into docker-compose.yml pazar-app APP_KEY=
docker compose exec -T pazar-app sh -lc "php -r '\$k=random_bytes(32); echo \"base64:\".base64_encode(\$k).\"\\n\";'"

# 3) After you paste APP_KEY into docker-compose.yml, restart only pazar-app
docker compose up -d pazar-app
Start-Sleep -Seconds 5

# 4) Verify env inside container (should show APP_ENV/APP_DEBUG/LOG_CHANNEL/APP_KEY)
docker compose exec -T pazar-app sh -lc "env | egrep 'APP_ENV|APP_DEBUG|LOG_CHANNEL|LOG_LEVEL|APP_KEY' | sort"

# 5) Verify storage writable by www-data
docker compose exec -T pazar-app sh -lc "id; ls -ld storage storage/logs bootstrap/cache; su -s /bin/sh -c 'echo TEST > storage/logs/_w && rm -f storage/logs/_w && echo WRITE_OK' www-data || echo WRITE_FAIL"

# 6) Hit / and capture logs (errors must appear in docker logs, not hidden)
curl.exe -i http://localhost:8080/ | Select-Object -First 30
docker compose logs --tail 200 pazar-app

# 7) Stack verify
.\ops\verify.ps1
```

## Expected Results

1. **/up endpoint**: HTTP 200 "ok" (nginx-level, Laravel-independent)
2. **Container stability**: pazar-app stays "Up", no scheduler FATAL loop
3. **Storage writable**: www-data can write to storage/logs (WRITE_OK)
4. **Logs visible**: Laravel errors appear in `docker compose logs pazar-app` (stderr)
5. **Verify script**: Pazar health PASS, no "service pazar-app is not running" error

## Risk Assessment

1. **Low risk**: Only runtime/ops contract changes; domain logic/routes/schema unchanged
2. **No data loss**: pazar_db_data / pazar_storage / pazar_cache volumes preserved
3. **DEV-focused**: Permissive permissions (0777) only for local; production behavior not targeted
4. **Scheduler stability**: Scheduler disabled in dev (autostart=false) improves app stability; business logic unaffected
5. **Easy rollback**: Entrypoint/supervisord/nginx/compose env changes can be reverted

## Files Changed

1. `docker-compose.yml` - Removed .env mount, added APP_KEY placeholder
2. `work/pazar/docker/docker-entrypoint.sh` - Added LOG_CHANNEL=stderr check, skip laravel.log when stderr
3. `work/pazar/docker/supervisord.conf` - Added autostart=false to scheduler
4. `work/pazar/docker/nginx/default.conf` - Added /up endpoint

## Next Steps

After runtime is stable, investigate RouteRegistrar::defaults mismatch:
```bash
docker compose exec -T pazar-app sh -lc "grep -R --line-number '->defaults(' routes app bootstrap vendor 2>/dev/null | head -n 50"
```








