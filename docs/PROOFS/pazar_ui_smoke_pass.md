# Pazar UI Smoke Gate Pass Proof

## Acceptance Criteria

1. **UI Endpoint Accessibility**: `/ui/admin/control-center` returns 200 OK or 302 Redirect (login redirect acceptable), MUST NOT return 500.

2. **Logging Regression Detection**: No "Permission denied", "laravel.log" errors, or "UnexpectedValueException" found in pazar-app logs after request.

3. **Exit Codes**: 0 PASS (UI accessible, no logging errors), 1 FAIL (500 error or logging regression), 2 WARN (stack not reachable).

4. **Integration**: Gate integrated into `ops/ops_status.ps1` as blocking check (after storage_posture).

5. **CI Workflow**: `.github/workflows/pazar-ui-smoke.yml` exists and runs on docker-entrypoint.sh/docker-compose.yml changes.

## Expected Output Format

### PASS Example

```
[INFO] === Pazar UI Smoke Test ===
[INFO] Testing UI endpoint: http://localhost:8080/ui/admin/control-center
[PASS] UI endpoint returned 200 (acceptable)
[INFO] Scanning pazar-app logs for permission denied errors...
[PASS] No logging regression detected in logs

Check                                    Status Notes
--------------------------------------------------------------------------------
UI Smoke Test                             PASS   UI accessible, no logging errors

OVERALL STATUS: PASS
```

### WARN Example (Stack Not Available)

```
[INFO] === Pazar UI Smoke Test ===
[WARN] Docker stack not available (SKIP)

Check                                    Status Notes
--------------------------------------------------------------------------------
UI Smoke Test                             WARN   Docker stack not running

OVERALL STATUS: WARN
```

### FAIL Example (500 Error)

```
[INFO] === Pazar UI Smoke Test ===
[INFO] Testing UI endpoint: http://localhost:8080/ui/admin/control-center
[FAIL] UI endpoint returned 500 Internal Server Error
[INFO] This likely indicates a logging permission denied regression.
[INFO] Action: Inspect pazar-app logs for 'Permission denied' or 'laravel.log' errors

Check                                    Status Notes
--------------------------------------------------------------------------------
UI Smoke Test                             FAIL   UI endpoint returned 500

OVERALL STATUS: FAIL
```

### FAIL Example (Logging Regression)

```
[INFO] === Pazar UI Smoke Test ===
[INFO] Testing UI endpoint: http://localhost:8080/ui/admin/control-center
[PASS] UI endpoint returned 200 (acceptable)
[INFO] Scanning pazar-app logs for permission denied errors...
[FAIL] Logging regression detected in pazar-app logs
[INFO]   - Found 'Permission denied' in logs
[INFO]   - Found 'laravel.log' error in logs
[INFO] Action: Check HOS_LARAVEL_LOG_STDOUT=1 is set and docker-entrypoint.sh symlinks laravel.log to stdout

Check                                    Status Notes
--------------------------------------------------------------------------------
UI Smoke Test                             FAIL   Logging regression detected

OVERALL STATUS: FAIL
```

## Verification Steps

1. **Verify docker-compose.yml has HOS_LARAVEL_LOG_STDOUT=1**:
   ```powershell
   Select-String -Path docker-compose.yml -Pattern "HOS_LARAVEL_LOG_STDOUT"
   ```
   Expected: `HOS_LARAVEL_LOG_STDOUT: "1"`

2. **Verify docker-entrypoint.sh handles HOS_LARAVEL_LOG_STDOUT**:
   ```powershell
   Select-String -Path work/pazar/docker/docker-entrypoint.sh -Pattern "HOS_LARAVEL_LOG_STDOUT"
   ```
   Expected: Check for env var and symlink creation logic

3. **Run the gate**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\ops\pazar_ui_smoke.ps1
   ```
   Expected: PASS (exit code 0)

4. **Verify integration in ops_status.ps1**:
   ```powershell
   Select-String -Path ops/ops_status.ps1 -Pattern "pazar_ui_smoke"
   ```
   Expected: Check registry entry with Blocking=$true

5. **Verify CI workflow exists**:
   ```powershell
   Test-Path .github/workflows/pazar-ui-smoke.yml
   ```
   Expected: True

## Evidence

### Files Changed

- `docker-compose.yml`: Added `HOS_LARAVEL_LOG_STDOUT: "1"` to pazar-app environment
- `work/pazar/docker/docker-entrypoint.sh`: Added stdout logging symlink logic when `HOS_LARAVEL_LOG_STDOUT=1`
- `ops/pazar_ui_smoke.ps1`: New UI smoke gate script
- `ops/ops_status.ps1`: Integrated pazar_ui_smoke as blocking check
- `.github/workflows/pazar-ui-smoke.yml`: New CI workflow
- `docs/runbooks/pazar_ui_smoke.md`: New runbook
- `docs/PROOFS/pazar_ui_smoke_pass.md`: This proof document
- `docs/RULES.md`: Added Rule 71
- `CHANGELOG.md`: Added Logging Stability + UI Smoke Gate Pack v1 entry

### Guarantees Preserved

- No domain refactoring
- No schema changes
- No new dependencies
- PowerShell 5.1 compatible
- ASCII-only output markers
- Safe exit behavior (Invoke-OpsExit)
- Existing error contract preserved
- Request ID behavior preserved
- Tenant/world boundary enforcement preserved

### Minimal Diff

- Only touched necessary files (docker-compose.yml, docker-entrypoint.sh, ops scripts, docs)
- No unrelated refactors
- No route redesign
- No schema changes

