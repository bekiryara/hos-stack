# Pazar Image Bootstrap Fix v1

## Patch Summary

**Problem**: Pazar-app Docker image crashed due to missing Laravel bootstrap directories and nginx config path mismatch.

**Solution**: 
1. Added `mkdir -p storage bootstrap/cache` to Dockerfile RUN block (ensures directories exist before chown)
2. Created minimal `work/pazar/artisan` file (Laravel bootstrap requirement)
3. Fixed nginx config path: `/etc/nginx/http.d/default.conf` → `/etc/nginx/conf.d/default.conf` (Alpine nginx standard)
4. Removed redundant `./docker/ensure_storage.sh` call from compose command (docker-entrypoint.sh already handles storage setup)

## Files Modified

1. `work/pazar/docker/Dockerfile`
   - Line 20: Added `mkdir -p storage bootstrap/cache` before chown
   - Line 15: Changed nginx config path from `/etc/nginx/http.d/default.conf` to `/etc/nginx/conf.d/default.conf`

2. `work/pazar/artisan` (NEW)
   - Minimal PHP script for Laravel bootstrap

3. `docker-compose.yml`
   - Line 98: Removed `./docker/ensure_storage.sh` from pazar-app command (redundant, docker-entrypoint.sh handles it)

## Risk Analysis

1. **Low Risk**: Changes are minimal and localized to build/bootstrap only - no domain logic, routes, or schemas touched.
2. **No Data Loss**: No volume deletions (pazar_db_data, pazar_storage, pazar_cache preserved).
3. **Backward Compatible**: Existing HOS core services unaffected, only Pazar build/bootstrap fixed.
4. **Deterministic**: All changes are explicit file operations with no runtime behavior changes.
5. **Rollback Safe**: Can revert Dockerfile/compose changes if needed; artisan file is minimal and safe.

## Copy-Paste Commands

```powershell
# 1) Build Pazar services
docker compose build pazar-app

# 2) Start Pazar services
docker compose up -d pazar-db pazar-app

# 3) Check container status
docker compose ps

# 4) Verify Pazar /up endpoint
curl.exe -i http://localhost:8080/up

# 5) Check logs
docker compose logs --tail 200 pazar-app

# 6) Run verification
.\ops\verify.ps1

# 7) Run ops status
.\ops\ops_status.ps1
```

## Expected Results

- `docker compose ps`: pazar-app status = "Up" (not Restarting)
- `curl.exe -i http://localhost:8080/up`: HTTP 200 OK
- `.\ops\verify.ps1`: Pazar FS posture PASS (no "service pazar-app is not running")
- `.\ops\ops_status.ps1`: Core-dependent checks no longer SKIP with CORE_UNAVAILABLE











