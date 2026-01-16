# Storage Permissions Runbook

## Overview

The Storage Permissions check (`ops/storage_permissions_check.ps1`) verifies that Laravel storage directories are correctly configured with proper permissions, preventing Monolog permission denied errors (`laravel.log` write failures).

## Why This Fails on Windows/Docker

On Windows, Docker bind mounts do not preserve Linux file permissions correctly. When volumes are first created, they may be owned by `root:root`, preventing `php-fpm` (running as `www-data`) from writing to `laravel.log`. This causes:

- HTTP 500 errors on UI routes
- Monolog `UnexpectedValueException`: "Permission denied" for `/var/www/html/storage/logs/laravel.log`
- Control Center (`/ui/admin/control-center`) and other UI routes fail

## Named Volume Rationale

The solution uses **named volumes** for runtime-writable directories:
- `pazar_storage` - Mounted at `/var/www/html/storage` (logs, cache, sessions)
- `pazar_cache` - Mounted at `/var/www/html/bootstrap/cache` (compiled views, routes)

Benefits:
- Named volumes preserve Linux file permissions correctly
- Allows the `pazar-perms-init` one-shot service to set ownership before the app starts
- Code remains bind-mounted from Windows (no performance impact)

## What pazar-perms-init Does

The `pazar-perms-init` service (defined in `docker-compose.yml`) is a **one-shot init container** that:

1. Runs as `root` (`user: "0:0"`) before `pazar-app` starts
2. Creates required directories: `/var/www/html/storage/logs`, `/var/www/html/bootstrap/cache`
3. Sets ownership: `chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache`
4. Sets permissions: `chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache`
5. Prints `[PASS] Permissions initialized` and exits

**Execution Flow:**
```
docker compose up
  → pazar-perms-init runs (one-shot, as root)
  → Sets permissions on named volumes
  → pazar-app waits (depends_on: condition: service_completed_successfully)
  → pazar-app starts (php-fpm runs as www-data)
  → www-data can write to laravel.log
```

## Storage Self-Heal Script (ensure_storage.sh)

In addition to `pazar-perms-init`, the `pazar-app` service runs `ensure_storage.sh` **on every container start** (via `docker-compose.yml` command override). This ensures storage permissions are fixed even if the container is restarted without recreating volumes.

**Location:** `work/pazar/docker/ensure_storage.sh`

**What it does:**
1. Creates required directories (`storage/logs`, `bootstrap/cache`)
2. Sets ownership to `www-data:www-data`
3. Sets permissions (`chmod -R ug+rwX`)
4. Creates `laravel.log` with `chmod 0666` (bulletproof append-safe permissions)

**Why this is needed:**
- Prevents Monolog "Permission denied" errors on container restart
- Ensures permissions are fixed on every start (not just one-time init)
- Works with named volumes (avoids Windows bind mount permission issues)

**Execution Flow:**
```
docker compose restart pazar-app
  → ensure_storage.sh runs (before supervisord)
  → Fixes permissions on storage directories
  → Prints [PASS] Storage self-heal completed
  → supervisord starts php-fpm
  → www-data can write to laravel.log
```

## How to Validate Success

### 1. Check pazar-perms-init Completed

```powershell
docker compose ps pazar-perms-init
```

**Expected:** Status should be "Exited (0)" (completed successfully)

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

### 3. Run Storage Permissions Check

```powershell
.\ops\storage_permissions_check.ps1
```

**Expected Output:**
```
=== STORAGE PERMISSIONS CHECK ===
Timestamp: 2026-01-11 HH:MM:SS

Checking storage directory...
Checking storage/logs directory...
Checking Laravel log file writability...
Checking bootstrap/cache directory...

=== STORAGE PERMISSIONS CHECK RESULTS ===

Check                                    Status Notes
--------------------------------------------------------------------------------
Storage Directory                         [PASS] Path exists and writable (owner: www-data:www-data)
Storage Logs Directory                    [PASS] Path exists and writable (owner: www-data:www-data)
Laravel Log File                          [PASS] laravel.log exists and writable
Bootstrap Cache Directory                 [PASS] Path exists and writable (owner: www-data:www-data)

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

### Storage Permissions Check FAIL

**Symptoms:**
- `storage_permissions_check.ps1` reports FAIL
- Directory not writable or ownership incorrect

**Remediation:**
1. Ensure `pazar-perms-init` ran successfully:
   ```powershell
   docker compose logs pazar-perms-init
   ```
   - Look for `[PASS] Permissions initialized` in output

2. Manually run permissions init:
   ```powershell
   docker compose run --rm pazar-perms-init
   ```

3. Manually fix permissions (as root):
   ```powershell
   docker compose exec -T pazar-app chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
   docker compose exec -T pazar-app chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache
   ```

4. Restart pazar-app:
   ```powershell
   docker compose restart pazar-app
   ```

5. Re-run check:
   ```powershell
   .\ops\storage_permissions_check.ps1
   ```

### pazar-perms-init Failed

**Symptoms:**
- `docker compose ps pazar-perms-init` shows "Exited (1)" or "Exited (2)"
- `pazar-app` won't start (waiting for init)

**Remediation:**
1. Check init service logs:
   ```powershell
   docker compose logs pazar-perms-init
   ```

2. Verify named volumes exist:
   ```powershell
   docker volume ls | Select-String "pazar"
   ```
   - Should show `pazar_storage` and `pazar_cache`

3. Remove and recreate volumes (if needed):
   ```powershell
   docker compose down -v
   docker volume rm pazar_storage pazar_cache
   docker compose up -d
   ```

### UI Still Returns 500 After Fix

**Symptoms:**
- Permissions check PASS
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

## Related Documentation

- `docs/runbooks/incident.md` - UI 500 Permission Denied Troubleshooting section
- `docs/PROOFS/storage_permissions_pass.md` - Proof document with acceptance evidence
- `docs/RULES.md` - Storage-permissions gate rule (Rule 48)
