# Storage Self-Heal Pass

**Date**: 2026-01-11  
**Purpose**: Verify storage self-heal script prevents Monolog "Permission denied" errors by ensuring storage/logs and bootstrap/cache are writable on every container start.

## Overview

Storage self-heal script (`work/pazar/docker/ensure_storage.sh`) runs before supervisord on every container start, ensuring:
- `storage/logs` and `bootstrap/cache` directories exist and are writable by `www-data` user
- `laravel.log` exists and has `chmod 0666` (bulletproof append-safe permissions)
- No Monolog "Permission denied" errors occur when UI routes are accessed

## Test Scenario 1: Container Start with Storage Self-Heal

**Command:**
```bash
docker compose restart pazar-app
docker compose logs pazar-app | grep -i "storage\|permission\|PASS"
```

**Expected Output:**
```
[PASS] Storage self-heal completed
```

**Verification:**
- ✅ Storage self-heal script runs on container start
- ✅ Script completes successfully (PASS message)
- ✅ No permission errors in logs

**Result**: ✅ Storage self-heal runs on every container start.

## Test Scenario 2: UI Route Not 500 (No Monolog Permission Error)

**Command:**
```bash
curl -i http://localhost:8080/ui/admin/control-center
```

**Expected Output:**
```
HTTP/1.1 200 OK
...
```

**Or if auth required:**
```
HTTP/1.1 302 Found
Location: /login
...
```

**Must NOT be:**
```
HTTP/1.1 500 Internal Server Error
...
{"error":"Permission denied","message":"The stream or file \"/var/www/html/storage/logs/laravel.log\" could not be opened..."}
```

**Verification:**
- ✅ UI route returns 200, 302, 401, or 403 (NOT 500)
- ✅ No Monolog permission error in response body
- ✅ No permission errors in container logs

**Result**: ✅ UI routes do not throw Monolog permission errors.

## Test Scenario 3: Laravel.log Writable Check Inside Container

**Command:**
```bash
docker compose exec pazar-app ls -la /var/www/html/storage/logs/laravel.log
docker compose exec -u www-data pazar-app sh -c "echo 'test' >> /var/www/html/storage/logs/laravel.log"
```

**Expected Output:**
```
-rw-rw-rw- 1 www-data www-data 1234 Jan 11 12:00 /var/www/html/storage/logs/laravel.log
```

**Verification:**
- ✅ `laravel.log` exists
- ✅ Permissions are `0666` (rw-rw-rw-)
- ✅ Owner is `www-data:www-data`
- ✅ `www-data` user can append to file (no permission denied)

**Result**: ✅ Laravel.log is writable by www-data user.

## Test Scenario 4: Storage Directories Writable

**Command:**
```bash
docker compose exec -u www-data pazar-app touch /var/www/html/storage/logs/test.log
docker compose exec -u www-data pazar-app touch /var/www/html/bootstrap/cache/test.php
```

**Expected Output:**
```
(No error, files created successfully)
```

**Verification:**
- ✅ `www-data` user can create files in `storage/logs`
- ✅ `www-data` user can create files in `bootstrap/cache`
- ✅ No permission denied errors

**Result**: ✅ Storage directories are writable by www-data user.

## Test Scenario 5: Smoke Surface Gate PASS

**Command:**
```powershell
.\ops\smoke_surface.ps1
```

**Expected Output:**
```
Check 4: Admin UI surface (no 500)
  [PASS] Admin UI surface - HTTP 200 OK

OVERALL STATUS: PASS
```

**Verification:**
- ✅ Smoke surface gate passes (Admin UI surface check)
- ✅ No 500 errors detected
- ✅ No Monolog permission errors detected

**Result**: ✅ Smoke surface gate validates storage self-heal is working.

## Result

✅ Storage self-heal successfully:
- Runs on every container start (via docker-compose.yml command override)
- Ensures storage/logs and bootstrap/cache are writable by www-data
- Creates laravel.log with chmod 0666 (bulletproof append-safe)
- Prevents Monolog "Permission denied" errors
- UI routes return 200/302/401/403 (NOT 500)
- Smoke surface gate validates no 500 errors



