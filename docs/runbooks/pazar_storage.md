# Pazar Storage Permission Troubleshooting

## Overview

This runbook provides steps to diagnose and resolve "Permission denied" errors related to Laravel's log files (`/var/www/html/storage/logs/laravel.log`) within the `pazar-app` Docker container. These errors typically manifest as UI 500 errors and are often caused by incorrect file permissions, especially on Windows bind mounts.

## Problem Symptoms

- Pazar UI returns HTTP 500 errors
- Container logs show `UnexpectedValueException (Monolog StreamHandler) cannot open /var/www/html/storage/logs/laravel.log: Permission denied.`
- `ops/pazar_storage_posture.ps1` returns `FAIL`

## Root Cause

- The `php-fpm` process inside the container runs as the `www-data` user
- If `storage/logs` or `laravel.log` are not writable by `www-data`, Monolog cannot write logs
- On Windows, Docker bind mounts can sometimes result in `root:root` ownership for files/directories, overriding the container's `chown` commands unless explicitly handled

## Solution

**Named Volumes:** Use named Docker volumes (`pazar_storage`, `pazar_cache`) for runtime-writable directories (`/var/www/html/storage` and `/var/www/html/bootstrap/cache`) to avoid Windows bind mount permission issues.

**Why Named Volumes:**
- Named volumes are managed by Docker and preserve Linux file permissions correctly
- Windows bind mounts (`./work/pazar/storage`) can cause permission issues because Windows doesn't have the same ownership/permission model as Linux
- Code directories remain bind-mounted for live development, but runtime-writable directories use named volumes

## Troubleshooting Steps

1. **Verify Container Status:**
   ```powershell
   docker compose ps pazar-app
   ```
   - **Expected:** `pazar-app` container status is `Up`
   - **If not `Up`:** Start the container: `docker compose up -d pazar-app`

2. **Run Pazar Storage Posture Check:**
   ```powershell
   .\ops\pazar_storage_posture.ps1
   ```
   - **Expected:** `OVERALL STATUS: PASS`
   - **If `WARN`:** Container might not be running (see step 1)
   - **If `FAIL`:** Proceed to step 3

3. **Inspect Permissions Inside Container:**
   ```powershell
   docker compose exec -T pazar-app sh -lc "ls -ld storage storage/logs bootstrap/cache; ls -l storage/logs/laravel.log || true; id"
   ```
   - **Expected:** `storage`, `storage/logs`, `bootstrap/cache` directories and `laravel.log` file should be owned by `www-data:www-data` and have `ug+rwX` permissions
   - `id` command should show `uid=33(www-data) gid=33(www-data)` for the `php-fpm` process
   - **If permissions are `root:root` or incorrect:** The `docker-entrypoint.sh` script might not have run or named volumes are not correctly mounted

4. **Force Recreate Container (Apply Fixes):**
   The fix relies on named volumes and a docker-entrypoint.sh script that runs on container start. To ensure these are applied:
   ```powershell
   # Recreate the container (no rebuild needed if image is up-to-date)
   docker compose up -d --force-recreate pazar-app
   ```
   - This will ensure the latest `docker-compose.yml` (with named volumes) and `docker-entrypoint.sh` (with permission enforcement) are used

5. **Re-run Storage Posture Check:**
   ```powershell
   .\ops\pazar_storage_posture.ps1
   ```
   - **Expected:** `OVERALL STATUS: PASS`

6. **Test UI Access:**
   ```powershell
   curl.exe http://localhost:8080/ui/admin/control-center
   ```
   - **Expected:** HTTP 200 or 302 (redirect to login), NOT 500

## Remediation (Manual if Automated Fix Fails)

If the above steps do not resolve the issue, you can manually attempt to fix permissions inside the running container:

```powershell
docker compose exec -T pazar-app sh -lc "
  mkdir -p /var/www/html/storage/logs /var/www/html/bootstrap/cache &&
  touch /var/www/html/storage/logs/laravel.log &&
  chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache &&
  chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache
"
# Then restart php-fpm if needed (or the whole container)
docker compose exec -T pazar-app supervisorctl restart php-fpm
```

After manual remediation, re-run `.\ops\pazar_storage_posture.ps1` to verify.
