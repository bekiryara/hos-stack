# Storage Posture Runbook

## Overview

The Storage Posture checks verify that Laravel storage and cache directories are writable by the runtime user (`www-data`), preventing Monolog permission denied errors (`laravel.log` write failures).

There are two complementary checks:
- **Storage Write Check** (`ops/storage_write_check.ps1`): Validates log append works from container runtime context (www-data user perspective)
- **Storage Posture Check** (`ops/storage_posture_check.ps1`): Verifies directories are writable by www-data user

## Why This Fails on Windows/Docker

On Windows, Docker bind mounts do not preserve Linux file permissions correctly. When volumes are first created, they may be owned by `root:root`, preventing `php-fpm` (running as `www-data`) from writing to `laravel.log`. This causes:

- HTTP 500 errors on UI routes
- Monolog `UnexpectedValueException`: "Permission denied" for `/var/www/html/storage/logs/laravel.log`
- Control Center (`/ui/admin/control-center`) and other UI routes fail

## Entrypoint Script Solution

The fix uses an **entrypoint script** (`work/pazar/docker/docker-entrypoint.sh`) that runs on every container start BEFORE nginx/php-fpm handles requests:

1. Creates required directories: `/var/www/html/storage/logs`, `/var/www/html/bootstrap/cache`, etc.
2. Sets ownership: `chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache`
3. Sets permissions: `chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache`
4. Ensures empty `laravel.log` exists (creates if missing)
5. Performs writability probe: `touch /var/www/html/storage/logs/laravel.log`

**Execution Flow:**
```
docker compose up
  → pazar-app container starts (as root via user: "0:0")
  → docker-entrypoint.sh runs (ensures permissions)
  → exec supervisord (starts nginx/php-fpm as www-data)
  → www-data can write to laravel.log
```

## Named Volume Rationale

The solution uses **named volumes** for runtime-writable directories:
- `pazar_storage` - Mounted at `/var/www/html/storage` (logs, cache, sessions)
- `pazar_cache` - Mounted at `/var/www/html/bootstrap/cache` (compiled views, routes)

Benefits:
- Named volumes preserve Linux file permissions correctly
- Allows entrypoint script to set ownership on every container start
- Code remains bind-mounted from Windows (no performance impact)

## What storage_write_check.ps1 Does

The `ops/storage_write_check.ps1` script (worker perspective validation):

1. Checks if `pazar-app` container is running
2. Verifies paths exist: `/var/www/html/storage`, `/var/www/html/storage/logs`, `/var/www/html/bootstrap/cache`
3. Verifies `laravel.log` exists
4. **CRITICAL**: Tests append as `www-data` user (`su -s /bin/sh www-data -c "echo test >> laravel.log"`)
5. If `su` is missing, returns WARN with manual check instructions
6. Reports PASS/WARN/FAIL with remediation hints

This check validates the **actual runtime behavior** that php-fpm workers will experience.

## What storage_posture_check.ps1 Does

The `ops/storage_posture_check.ps1` script (directory writability):

1. Checks if `pazar-app` container is running
2. Tests `/var/www/html/storage` writability (via `www-data` user)
3. Tests `/var/www/html/storage/logs` writability
4. Tests `laravel.log` can be created/appended
5. Tests `/var/www/html/bootstrap/cache` writability
6. Reports PASS/WARN/FAIL with remediation hints

## How to Validate Success

### 1. Check Container Logs for Entrypoint Success

```powershell
docker compose logs pazar-app | Select-String -Pattern "storage not writable|FAIL|WARN"
```

**Expected:** No "storage not writable" or "FAIL" messages from entrypoint

### 2. Verify Storage Permissions Inside Container

```powershell
# Check storage directory exists and is writable
docker compose exec -T pazar-app sh -c "test -d /var/www/html/storage && echo 'PASS' || echo 'FAIL'"

# Check storage/logs directory exists and is writable
docker compose exec -T pazar-app sh -c "test -d /var/www/html/storage/logs && echo 'PASS' || echo 'FAIL'"

# Check laravel.log is writable (touch + append test)
docker compose exec -T pazar-app sh -c "touch /var/www/html/storage/logs/laravel.log && echo 'probe' >> /var/www/html/storage/logs/laravel.log && tail -1 /var/www/html/storage/logs/laravel.log && echo 'PASS' || echo 'FAIL'"

# Check ownership (should be www-data:www-data)
docker compose exec -T pazar-app sh -c "stat -c '%U:%G' /var/www/html/storage"
```

**Expected:** All commands print "PASS", ownership shows `www-data:www-data`

### 3. Run Storage Write Check (Worker Perspective)

```powershell
.\ops\storage_write_check.ps1
```

**Expected Output:**
```
=== STORAGE WRITE CHECK ===
Timestamp: 2026-01-11 HH:MM:SS

Checking paths exist...
Checking laravel.log exists...
Checking worker append (www-data user)...

=== STORAGE WRITE CHECK RESULTS ===

Check                                    Status Notes
--------------------------------------------------------------------------------
Paths exist                               [PASS] storage, storage/logs, bootstrap/cache exist
laravel.log exists                        [PASS] File exists
Worker append (www-data)                  [PASS] www-data user can append to laravel.log

OVERALL STATUS: PASS
```

### 4. Run Storage Posture Check

```powershell
.\ops\storage_posture_check.ps1
```

**Expected Output:**
```
=== STORAGE POSTURE CHECK ===
Timestamp: 2026-01-11 HH:MM:SS

Checking /var/www/html/storage writability...
Checking /var/www/html/storage/logs writability...
Checking laravel.log can be created...

=== STORAGE POSTURE CHECK RESULTS ===

Check                                    Status Notes
--------------------------------------------------------------------------------
/var/www/html/storage writable           [PASS] Directory exists and is writable
/var/www/html/storage/logs writable      [PASS] Directory exists and is writable
laravel.log can be created               [PASS] File can be created by www-data

OVERALL STATUS: PASS
```

### 4. Verify UI Routes No Longer 500

```powershell
# Test Control Center endpoint
curl.exe -i http://localhost:8080/ui/admin/control-center
```

**Expected:** HTTP 200 or 302 (redirect), **NOT** HTTP 500

### 5. Check Laravel Logs for Permission Errors

```powershell
docker compose logs pazar-app --tail 50 | Select-String -Pattern "permission|Permission|denied|Denied"
```

**Expected:** No permission denied errors in logs

## Troubleshooting

### Storage Posture Check FAIL

**Symptoms:**
- `storage_posture_check.ps1` reports FAIL
- Directory not writable or ownership incorrect

**Remediation:**
1. Ensure container is running as root (check `docker-compose.yml`):
   ```yaml
   pazar-app:
     user: "0:0"  # Must be root for chown operations
   ```

2. Check entrypoint script executed successfully:
   ```powershell
   docker compose logs pazar-app | Select-String -Pattern "storage not writable"
   ```
   - If found: entrypoint failed, check named volumes exist

3. Manually fix permissions (as root):
   ```powershell
   docker compose exec -T pazar-app sh -c "chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache"
   docker compose exec -T pazar-app sh -c "chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache"
   ```

4. Recreate container:
   ```powershell
   docker compose down pazar-app
   docker compose up -d --force-recreate pazar-app
   ```

5. Re-run check:
   ```powershell
   .\ops\storage_posture_check.ps1
   ```

### Entrypoint Script Failed

**Symptoms:**
- `docker compose logs pazar-app` shows "[FAIL] storage not writable"
- Container exits early (supervisord never starts)

**Remediation:**
1. Verify named volumes exist:
   ```powershell
   docker volume ls | Select-String "pazar"
   ```
   - Should show `pazar_storage` and `pazar_cache`

2. Remove and recreate volumes (if needed):
   ```powershell
   docker compose down -v
   docker volume rm pazar_storage pazar_cache 2>$null
   docker compose up -d
   ```

3. Check `docker-compose.yml` configuration:
   - `pazar-app` must have `user: "0:0"` for root permissions
   - `pazar-app` must have `depends_on: pazar-perms-init: condition: service_completed_successfully` (if using init service)
   - Named volumes (`pazar_storage`, `pazar_cache`) must be correctly mounted

### UI Still Returns 500 After Fix

**Symptoms:**
- Storage posture check PASS
- UI routes still return HTTP 500

**Remediation:**
1. Check PHP-FPM error logs:
   ```powershell
   docker compose exec -T pazar-app tail -50 /var/log/php-fpm/error.log
   ```

2. Verify php-fpm user:
   ```powershell
   docker compose exec -T pazar-app ps aux | Select-String "php-fpm"
   ```
   - Should show processes running as `www-data`

3. Check Laravel logs:
   ```powershell
   docker compose exec -T pazar-app cat /var/www/html/storage/logs/laravel.log | Select-Object -Last 20
   ```

4. Restart pazar-app:
   ```powershell
   docker compose restart pazar-app
   ```

## Prevention

- Use named volumes (`pazar_storage`, `pazar_cache`) for runtime-writable directories in `docker-compose.yml`
- Keep code directories bind-mounted for live development
- Ensure `docker-entrypoint.sh` runs on every container start (via `ENTRYPOINT` in Dockerfile)
- Ensure `pazar-app` runs as root (`user: "0:0"`) for initial permissions fix
- Run `.\ops\storage_posture_check.ps1` as part of CI/CD pipeline
- Ensure `ops_status.ps1` includes storage_posture as BLOCKING check

## Related Documentation

- `ops/storage_posture_check.ps1` - Automated storage posture verification
- `docs/PROOFS/storage_posture_pass.md` - Proof documentation with acceptance tests
- `docs/RULES.md` - Storage posture gate rule (RC0 requirement)
- `work/pazar/docker/docker-entrypoint.sh` - Entrypoint script that ensures permissions on every start

