# Pazar UI Smoke Gate Runbook

## Overview

The Pazar UI Smoke Gate (`ops/pazar_ui_smoke.ps1`) validates that the Pazar admin UI endpoint (`/ui/admin/control-center`) is accessible and that no logging permission denied errors are present in container logs. This gate prevents UI 500 errors caused by Monolog "Permission denied" errors when Laravel cannot write to `storage/logs/laravel.log`.

## What It Checks

1. **UI Endpoint Accessibility**: HTTP GET to `http://localhost:8080/ui/admin/control-center` must return 200 OK or 302 Redirect (login redirect is acceptable). MUST NOT return 500 Internal Server Error.

2. **Logging Regression Detection**: After the request, scans the last 100 lines of `docker compose logs pazar-app` for:
   - "Permission denied" (case-insensitive)
   - "laravel.log" errors (e.g., "could not be opened", "failed to open")
   - "UnexpectedValueException"

   If any of these indicators are found, the gate FAILs with a clear remediation hint.

## How to Run

### Local Development

```powershell
# Ensure Docker stack is running
docker compose up -d

# Run the gate
powershell -ExecutionPolicy Bypass -File .\ops\pazar_ui_smoke.ps1
```

### With CI

The gate runs automatically via `.github/workflows/pazar-ui-smoke.yml` on:
- Pull requests to `main` or `develop` affecting:
  - `work/pazar/docker/docker-entrypoint.sh`
  - `docker-compose.yml`
  - `ops/pazar_ui_smoke.ps1`
  - `.github/workflows/pazar-ui-smoke.yml`
- Pushes to `main` or `develop` affecting the same paths

## Interpreting Results

### PASS (Exit Code 0)

- UI endpoint returned 200 OK or 302 Redirect
- No permission denied errors found in logs
- No "laravel.log" errors found in logs
- No "UnexpectedValueException" found in logs

**Action**: None. Proceed with RC0 release.

### WARN (Exit Code 2)

- Docker stack not available (container not running)
- pazar-app container not found

**Action**: Start Docker stack and re-run. WARN is acceptable for local development when stack is intentionally down.

### FAIL (Exit Code 1)

**Scenario 1: UI endpoint returned 500**
```
[FAIL] UI endpoint returned 500 Internal Server Error
This likely indicates a logging permission denied regression.
Action: Inspect pazar-app logs for 'Permission denied' or 'laravel.log' errors
```

**Scenario 2: Logging regression detected**
```
[FAIL] Logging regression detected in pazar-app logs
  - Found 'Permission denied' in logs
  - Found 'laravel.log' error in logs
Action: Check HOS_LARAVEL_LOG_STDOUT=1 is set and docker-entrypoint.sh symlinks laravel.log to stdout
```

**Scenario 3: Unexpected status code**
```
[FAIL] UI endpoint returned unexpected status code: 404
```

## Troubleshooting

### UI Returns 500

1. **Check pazar-app logs**:
   ```powershell
   docker compose logs --tail=100 pazar-app
   ```

2. **Look for permission denied errors**:
   - "Permission denied" in logs
   - "laravel.log could not be opened"
   - "UnexpectedValueException"

3. **Verify stdout logging is enabled**:
   ```powershell
   docker compose exec pazar-app env | Select-String "HOS_LARAVEL_LOG_STDOUT"
   ```
   Should show: `HOS_LARAVEL_LOG_STDOUT=1`

4. **Verify laravel.log symlink**:
   ```powershell
   docker compose exec pazar-app ls -la /var/www/html/storage/logs/laravel.log
   ```
   Should show: `lrwxrwxrwx ... laravel.log -> /proc/1/fd/1`

5. **If symlink missing, check docker-entrypoint.sh**:
   - Ensure `HOS_LARAVEL_LOG_STDOUT=1` check exists
   - Ensure symlink creation: `ln -sf /proc/1/fd/1 /var/www/html/storage/logs/laravel.log`

### Logging Regression Detected

1. **Verify docker-compose.yml**:
   ```yaml
   pazar-app:
     environment:
       HOS_LARAVEL_LOG_STDOUT: "1"
   ```

2. **Restart pazar-app container**:
   ```powershell
   docker compose restart pazar-app
   ```

3. **Re-run the gate**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\ops\pazar_ui_smoke.ps1
   ```

### Endpoint Not Reachable

1. **Check Docker stack status**:
   ```powershell
   docker compose ps
   ```

2. **Check pazar-app is healthy**:
   ```powershell
   curl http://localhost:8080/up
   ```

3. **Check port binding**:
   ```powershell
   netstat -an | Select-String "8080"
   ```

## Integration

### ops_status.ps1

The gate is integrated into `ops/ops_status.ps1` as a **BLOCKING** check:
- **Id**: `pazar_ui_smoke`
- **Name**: `Pazar UI Smoke`
- **Position**: After `storage_posture`, before `pazar_storage_posture`
- **OnFailAction**: `incident_bundle`

### CI Workflow

The gate runs automatically in CI via `.github/workflows/pazar-ui-smoke.yml`:
- Brings up core stack (root compose)
- Runs `ops/pazar_ui_smoke.ps1`
- On FAIL: Uploads docker compose logs as artifact
- Always: Cleans up (docker compose down)

## Related Documentation

- `docs/RULES.md` Rule 71: "UI smoke gate must PASS before RC0"
- `work/pazar/docker/docker-entrypoint.sh`: Logging symlink logic
- `docker-compose.yml`: HOS_LARAVEL_LOG_STDOUT environment variable

