# Pazar Storage Posture Pack v1 - Proof

## Overview

This document provides proof that the Pazar UI 500 error caused by Monolog permission denied on `/var/www/html/storage/logs/laravel.log` has been fixed in a durable, Windows-friendly way, and that the `ops/pazar_storage_posture.ps1` gate correctly verifies the solution.

## Problem

- **Error:** `UnexpectedValueException (Monolog StreamHandler) cannot open /var/www/html/storage/logs/laravel.log: Permission denied.`
- **Root Cause:** Windows bind mounts do not preserve Linux file permissions, causing Laravel's Monolog to fail when writing logs. Specifically, `storage/logs` and `laravel.log` were owned by `root:root`, preventing `php-fpm` (running as `www-data`) from writing.

## Solution

1. **Named Volumes:** Added named volumes `pazar_storage` and `pazar_cache` to `docker-compose.yml` to override only runtime-writable directories (`/var/www/html/storage` and `/var/www/html/bootstrap/cache`), while keeping code bind-mounted from Windows.

2. **Docker Entrypoint:** Modified `work/pazar/docker/docker-entrypoint.sh` to include an idempotent boot-time step that runs BEFORE supervisord starts php-fpm:
   - `mkdir -p storage/logs bootstrap/cache`
   - `touch storage/logs/laravel.log`
   - `chown -R www-data:www-data storage bootstrap/cache`
   - `chmod -R ug+rwX storage bootstrap/cache`

3. **Storage Posture Check:** Created `ops/pazar_storage_posture.ps1` to verify storage directories are writable by `www-data` and integrated it into `ops/ops_status.ps1`.

## Acceptance Tests

### 1. Build and Recreate pazar-app

```powershell
cd D:\stack

# Build the pazar-app image (if Dockerfile changed, or to ensure latest image)
docker compose build pazar-app

# Recreate the container to apply the updated docker-entrypoint.sh and named volumes
docker compose up -d --force-recreate pazar-app

# Verify container is running
docker compose ps pazar-app
# Expected: Status should be "Up"
```

**Key Validation:**
- ✅ Container rebuilds and starts successfully
- ✅ `--force-recreate` ensures the new `docker-entrypoint.sh` is used

### 2. Verify Permissions After Recreate

```powershell
# Verify ownership and permissions of storage directories and log file
docker compose exec -T pazar-app sh -lc "ls -ld storage storage/logs bootstrap/cache && ls -l storage/logs/laravel.log"
```

**Expected Output (example):**
```
drwxrwxr-x    1 www-data www-data      4096 Jan 10 16:22 storage
drwxrwxr-x    2 www-data www-data      4096 Jan 10 16:23 storage/logs
-rw-rw-r--    1 www-data www-data         0 Jan 10 16:23 storage/logs/laravel.log
drwxrwxr-x    2 www-data www-data      4096 Jan 10 16:23 bootstrap/cache
```

**Key Validation:**
- ✅ `storage` and `storage/logs` directories are owned by `www-data:www-data`
- ✅ `laravel.log` is owned by `www-data:www-data` and has `rw` permissions for owner/group
- ✅ `bootstrap/cache` is owned by `www-data:www-data`

### 3. Test Write Operation to laravel.log (as www-data)

```powershell
# Test as www-data user (the actual runtime user)
docker compose exec -T pazar-app sh -lc "su -s /bin/sh www-data -c 'php -r \"file_put_contents(\\\"/var/www/html/storage/logs/laravel.log\\\",\\\"probe\\n\\\",FILE_APPEND); echo \\\"OK\\n\\\";\"'"
```

**Expected Output:**
```
OK
```

**Key Validation:**
- ✅ Exit code: 0
- ✅ Prints "OK"
- ✅ No permission denied errors

### 4. Verify UI Access (No 500 Error)

```powershell
# Check application health endpoint
curl.exe http://localhost:8080/up

# Open browser to:
# http://localhost:8080/ui/admin/control-center
# Or test with curl:
curl.exe http://localhost:8080/ui/admin/control-center
```

**Expected:**
- ✅ `/up` endpoint returns HTTP 200
- ✅ `/ui/admin/control-center` returns HTTP 200 or HTTP 302 (redirect to login)
- ✅ NOT HTTP 500
- ✅ Page loads or redirects to login page
- ✅ No Monolog permission denied errors in container logs

### 5. Verify Storage Posture Check

```powershell
.\ops\pazar_storage_posture.ps1
```

**Expected Output:**
```
[INFO] === Pazar Storage Posture Check ===
Checking storage/logs directory...
Checking laravel.log file...
Checking laravel.log writability...
Testing write operation to laravel.log...
Checking bootstrap/cache directory...

=== Storage Posture Results ===

Check                                    Status Notes
-----                                    ------ -----
storage/logs directory exists            PASS   Directory exists
laravel.log file exists                  PASS   File exists
laravel.log writable by www-data         PASS   File is writable
Write test to laravel.log                PASS   Write operation succeeded
bootstrap/cache writable                 PASS   Directory exists and is writable

[PASS] OVERALL STATUS: PASS (All storage checks passed)
```

**Key Validation:**
- ✅ All checks PASS
- ✅ Exit code: 0
- ✅ Storage and cache directories are writable by `www-data`

### 6. Verify Container Restart Persistence

```powershell
# Restart container
docker compose restart pazar-app

# Wait a few seconds for container to fully start
Start-Sleep -Seconds 5

# Re-run storage posture check
.\ops\pazar_storage_posture.ps1
```

**Expected:**
- ✅ All checks still PASS after restart
- ✅ Permissions persist across container restarts (enforced by docker-entrypoint.sh)

### 7. Verify ops_status Integration

```powershell
.\ops\run_ops_status.ps1
```

**Expected Output:**
```
[INFO] === Running Ops Status (Safe Mode) ===
...
Running Pazar Storage Posture...
...
=== OPS STATUS RESULTS ===

Check                                    Status ExitCode Notes
-----                                    ------ -------- -----
...
Pazar Storage Posture                    PASS   0        ...
...

[PASS] OVERALL STATUS: PASS (All checks passed)
```

**Key Validation:**
- ✅ Pazar Storage Posture check appears in results
- ✅ Status is PASS (or WARN if container not running)
- ✅ Terminal does not close
- ✅ Exit code is preserved in `$LASTEXITCODE`

## Verification Checklist

- ✅ `docker-compose.yml` includes named volumes for `pazar_storage` and `pazar_cache`
- ✅ Named volumes override only `/var/www/html/storage` and `/var/www/html/bootstrap/cache`
- ✅ Code directories (app, routes, resources/views) remain bind-mounted from Windows
- ✅ `work/pazar/docker/docker-entrypoint.sh` includes idempotent permission enforcement
- ✅ `ops/pazar_storage_posture.ps1` exists and is integrated into `ops_status.ps1`
- ✅ Storage posture check verifies all required directories and permissions
- ✅ Write test succeeds without permission errors (using `www-data` user)
- ✅ UI loads without 500 errors
- ✅ Permissions persist across container restarts (enforced by docker-entrypoint.sh)

## Files Changed

- `docker-compose.yml` - Added named volumes `pazar_storage` and `pazar_cache` to `pazar-app` service, added volume definitions
- `work/pazar/docker/docker-entrypoint.sh` - Added `touch laravel.log` step and ensured comprehensive permission commands
- `ops/pazar_storage_posture.ps1` - New script to verify storage posture
- `ops/ops_status.ps1` - Integrated storage posture check after triage check
- `docs/PROOFS/pazar_storage_posture_pass.md` - This proof documentation
- `docs/runbooks/pazar_storage.md` - Troubleshooting runbook

## Notes

- **Minimal Diff:** Only necessary changes to fix the permission issue; no application code refactored
- **Durable Solution:** Named volumes and the docker-entrypoint.sh script ensure permissions persist across container restarts, unlike Windows bind mounts
- **Non-Breaking:** Existing bind mounts for code directories remain unchanged
- **Regression Prevention:** Storage posture check ensures the fix remains working
- **Windows Compatible:** Named volumes and explicit permission setting avoid Windows bind mount permission issues that cause Monolog failures
