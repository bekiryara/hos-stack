# Storage Permissions Troubleshooting

## Symptoms

- UI routes (e.g., `/ui/admin/control-center`) return HTTP 500 errors
- Container logs show: `UnexpectedValueException (Monolog StreamHandler) cannot open /var/www/html/storage/logs/laravel.log: Permission denied.`
- Error pages show "Permission denied" for `laravel.log`

## Root Cause

On Windows, Docker bind mounts do not preserve Linux file permissions. If `/var/www/html/storage` is bind-mounted from Windows, `chown`/`chmod` commands inside the container have no effect, causing `php-fpm` (running as `www-data`) to be unable to write to `laravel.log`.

**Storage volume permissions drift** can also occur if named volumes are recreated or if the container entrypoint fails to enforce permissions on container start.

## Solution

The fix uses a multi-layered approach:

1. **Named volumes** (`pazar_storage`, `pazar_cache`) for runtime-writable directories in `docker-compose.yml`
2. **Robust entrypoint** (`docker-entrypoint.sh`) that enforces permissions idempotently on every container start with writability probe
3. **Fail-fast behavior**: If storage is not writable after all attempts, container exits with error instead of silently failing

## Troubleshooting Steps

### Step 1: Verify Container Status

```powershell
docker compose ps pazar-app
```

**Expected:** `pazar-app` container status is `Up`

**If not `Up`:** Start the container:
```powershell
docker compose up -d pazar-app
```

### Step 2: Run Storage Posture Check

```powershell
.\ops\storage_posture_check.ps1
```

**Expected Output:**
```
=== Storage Posture Check ===
Checking /var/www/html/storage writability...
Checking /var/www/html/storage/logs writability...
Checking laravel.log can be created...

=== Storage Posture Results ===

Check                                    Status Notes
-----                                    ------ -----
/var/www/html/storage writable            PASS   Directory exists and is writable
/var/www/html/storage/logs writable      PASS   Directory exists and is writable
laravel.log can be created               PASS   File can be created by www-data

[PASS] OVERALL STATUS: PASS (All storage checks passed)
```

**If FAIL:** Proceed to Step 3.

### Step 3: Check Container Logs for Entrypoint Failures

```powershell
docker compose logs pazar-app | Select-String "storage not writable"
```

**If found:** Entrypoint detected storage is not writable and container should have exited. Check named volumes are correctly configured.

### Step 4: Force Recreate Container

```powershell
# Recreate the container to ensure named volumes are used and entrypoint fixes permissions
docker compose down pazar-app
docker compose up -d --force-recreate pazar-app

# Wait a few seconds for container to fully start
Start-Sleep -Seconds 5
```

This ensures:
- Latest `docker-compose.yml` (with named volumes) is used
- `docker-entrypoint.sh` (with permission enforcement) runs
- Named volumes are initialized with correct permissions

### Step 5: Re-run Storage Posture Check

```powershell
.\ops\storage_posture_check.ps1
```

**Expected:** PASS

### Step 6: Test UI Access

```powershell
curl.exe -sS -w "\nHTTP_CODE:%{http_code}\n" http://localhost:8080/ui/admin/control-center 2>&1 | Select-Object -Last 3
```

**Expected:** HTTP 200 or 302 (redirect to login), NOT 500

### Step 7: Verify Permissions Inside Container (Manual Check)

```powershell
docker compose exec -T pazar-app sh -lc "ls -ld /var/www/html/storage /var/www/html/storage/logs /var/www/html/bootstrap/cache && ls -l /var/www/html/storage/logs/laravel.log 2>&1 || echo 'laravel.log not found'"
```

**Expected Output:**
```
drwxrwxr-x    5 www-data www-data      4096 Jan 10 16:23 /var/www/html/storage
drwxrwxr-x    2 www-data www-data      4096 Jan 10 16:23 /var/www/html/storage/logs
drwxrwxr-x    2 www-data www-data      4096 Jan 10 16:23 /var/www/html/bootstrap/cache
-rw-rw-r--    1 www-data www-data         0 Jan 10 16:23 /var/www/html/storage/logs/laravel.log
```

**Key Validation:**
- Directories and `laravel.log` should be owned by `www-data:www-data`
- Permissions should be `ug+rwX` (user/group read/write/execute)

## Prevention

- Use named volumes (`pazar_storage`, `pazar_cache`) for runtime-writable directories in `docker-compose.yml`
- Keep code directories bind-mounted for live development
- Ensure `docker-entrypoint.sh` enforces permissions idempotently on container start with writability probe
- Run `.\ops\storage_posture_check.ps1` as part of CI/CD pipeline

## Related

- `ops/storage_posture_check.ps1` - Automated storage posture verification
- `docs/PROOFS/storage_permissions_pass.md` - Proof documentation with acceptance tests

