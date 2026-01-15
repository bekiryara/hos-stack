# Smoke Surface Gate Runbook

**Purpose**: Validates critical surfaces don't return 500/regression errors. Ensures RC0 is truly "release-safe" by catching Monolog permission errors and other critical failures before release.

**Script**: `ops/smoke_surface.ps1`

## What It Checks

1. **Pazar /up → 200**: Health check endpoint must return HTTP 200
2. **Pazar /metrics → 200 AND Content-Type starts with "text/plain" AND body contains pazar_ metric AND no BOM artifact**: Metrics endpoint must return Prometheus-compatible format without UTF-8 BOM
3. **API error contract smoke**: GET `/api/non-existent-endpoint` → 404 JSON envelope includes `request_id` (non-null)
4. **Admin UI surface must not 500**: GET `/ui/admin/control-center` (no auth) should be either 200 or 302/401/403, BUT MUST NOT be 500. If response is 500 or contains Monolog "Permission denied" in body, mark FAIL with remediation hints.
5. **Optional (WARN-only)**: If Prometheus reachable (9090), verify `/api/v1/targets` has pazar job up; else WARN.

## How to Run

### Local (Interactive)

```powershell
.\ops\smoke_surface.ps1
```

### With Custom Base URL

```powershell
.\ops\smoke_surface.ps1 -BaseUrl "http://localhost:8080"
```

### With Prometheus URL

```powershell
.\ops\smoke_surface.ps1 -BaseUrl "http://localhost:8080" -PrometheusUrl "http://localhost:9090"
```

### CI (Automated)

The gate runs automatically on:
- Pull requests to `main` or `develop`
- Pushes to `main` or `develop`
- When Pazar code, smoke_surface.ps1, docker-compose.yml, or workflow file changes

See `.github/workflows/smoke-surface.yml` for CI configuration.

## Expected Output

### PASS

```
=== SMOKE SURFACE GATE ===
Timestamp: 2026-01-11 12:00:00
Base URL: http://localhost:8080

Check 1: Pazar /up endpoint
  [PASS] Pazar /up - HTTP 200 OK

Check 2: Pazar /metrics endpoint
  [PASS] Pazar /metrics - HTTP 200, Content-Type text/plain, body contains pazar_ metric, no BOM

Check 3: API error contract smoke
  [PASS] API error contract - HTTP 404 with JSON envelope (ok, error_code, message, request_id non-null)

Check 4: Admin UI surface (no 500)
  [PASS] Admin UI surface - HTTP 200 OK

Check 5: Prometheus targets (optional)
  [PASS] Prometheus targets - Pazar job found and UP

=== SMOKE SURFACE GATE RESULTS ===

Check                Status Notes
-----                ------ -----
Pazar /up            PASS   HTTP 200 OK
Pazar /metrics       PASS   HTTP 200, Content-Type text/plain, body contains pazar_ metric, no BOM
API error contract   PASS   HTTP 404 with JSON envelope (ok, error_code, message, request_id non-null)
Admin UI surface     PASS   HTTP 200 OK
Prometheus targets   PASS   Pazar job found and UP

OVERALL STATUS: PASS
```

### WARN (Optional Checks Skipped)

```
Check 5: Prometheus targets (optional)
  [WARN] Prometheus targets - Prometheus not reachable at http://localhost:9090 (optional check)

OVERALL STATUS: WARN
```

### FAIL (Monolog Permission Error)

```
Check 4: Admin UI surface (no 500)
  [FAIL] Admin UI surface - HTTP 500 Internal Server Error (Monolog permission error detected). Remediation: storage/logs and bootstrap/cache writable by php-fpm user (www-data); ensure runtime permission fix executes on every container start (not only one-time init); confirm storage volume is named volume not bind mount (avoid Windows perms)

OVERALL STATUS: FAIL
```

## How to Interpret Results

- **PASS**: All critical checks passed. RC0 release-safe.
- **WARN**: Optional checks (Prometheus) skipped or failed, but critical checks passed. Review warnings but release can proceed.
- **FAIL**: Critical check failed (500 error, missing endpoint, contract violation). **Release blocked**. Fix issues and re-run.

## Common Failures

### 1. Pazar /up Returns Non-200

**Symptom**: FAIL status, "Expected HTTP 200, got 503" (or similar)

**Causes**:
- Docker stack not running
- Pazar service not healthy
- Database connection issues

**Solution**:
1. Check Docker stack: `docker compose ps`
2. Check Pazar logs: `docker compose logs pazar-app`
3. Verify database connectivity
4. Restart stack: `docker compose restart pazar-app`

### 2. Pazar /metrics Missing Content-Type or BOM

**Symptom**: FAIL status, "Expected Content-Type starting with 'text/plain'" or "Response contains UTF-8 BOM artifact"

**Causes**:
- Middleware or controller returning wrong Content-Type
- Response encoding issue (BOM added)

**Solution**:
1. Check `work/pazar/app/Http/Controllers/MetricsController.php`
2. Ensure `Content-Type: text/plain; version=0.0.4` header is set
3. Ensure response encoding is UTF-8 without BOM
4. Test locally: `curl -i http://localhost:8080/api/metrics`

### 3. API Error Contract Missing request_id

**Symptom**: FAIL status, "HTTP 404 but missing fields: request_id (null/empty)"

**Causes**:
- Error envelope middleware not applied
- RequestId middleware missing or broken

**Solution**:
1. Check `work/pazar/app/Http/Middleware/RequestId.php` exists and is registered
2. Verify error envelope middleware is applied to API routes
3. Test: `curl http://localhost:8080/api/non-existent-endpoint` and verify JSON response has `request_id`

### 4. Admin UI Returns 500 (Monolog Permission Error)

**Symptom**: FAIL status, "HTTP 500 Internal Server Error (Monolog permission error detected)"

**Causes**:
- `storage/logs` directory not writable by `www-data` user
- `bootstrap/cache` directory not writable
- Named volume permissions issue (Windows bind mount)
- Entrypoint script not running on container start

**Solution**:

1. **Check storage permissions**:
   ```bash
   docker compose exec pazar-app ls -la /var/www/html/storage/logs
   docker compose exec pazar-app touch /var/www/html/storage/logs/laravel.log
   ```

2. **Verify entrypoint script runs on every start**:
   - Check `work/pazar/docker/docker-entrypoint.sh` exists
   - Verify `docker-compose.yml` has entrypoint configured
   - Ensure entrypoint sets `chmod 0666` on `laravel.log` and fixes permissions

3. **Verify named volumes (not bind mounts)**:
   - Check `docker-compose.yml` uses named volumes (`pazar_storage`, `pazar_cache`)
   - Avoid bind mounts on Windows (permission issues)

4. **Fix permissions manually (if needed)**:
   ```bash
   docker compose exec -u root pazar-app chown -R www-data:www-data /var/www/html/storage
   docker compose exec -u root pazar-app chmod -R 775 /var/www/html/storage
   docker compose exec -u root pazar-app chmod 0666 /var/www/html/storage/logs/laravel.log
   ```

5. **Restart container**:
   ```bash
   docker compose restart pazar-app
   ```

6. **Verify fix**:
   ```bash
   curl http://localhost:8080/ui/admin/control-center
   # Should return 200, 302, 401, or 403 (NOT 500)
   ```

### 5. Prometheus Targets WARN

**Symptom**: WARN status, "Prometheus not reachable" or "Pazar job not found"

**Causes**:
- Prometheus not running (optional check, non-blocking)
- Pazar job not configured in Prometheus
- Prometheus scrape config missing

**Solution**:
- This is **non-blocking** (WARN only)
- If observability is required, configure Prometheus scrape config for Pazar metrics endpoint
- See `docs/runbooks/observability.md` for Prometheus setup

## Troubleshooting

### Stack Not Running

If all checks fail with connection errors:
1. Start Docker stack: `docker compose up -d`
2. Wait for services: `docker compose ps` (all services should be "Up")
3. Check health: `curl http://localhost:8080/up`

### Intermittent Failures

If checks pass sometimes but fail other times:
1. Check service logs: `docker compose logs pazar-app`
2. Check for resource constraints (CPU/memory)
3. Verify database connectivity
4. Check for race conditions in startup scripts

### False Positives

If a check fails but the service appears healthy:
1. Verify the check logic in `ops/smoke_surface.ps1`
2. Test endpoint manually: `curl -i http://localhost:8080/...`
3. Check if recent changes broke the contract
4. Update check if contract changed intentionally (with proof)

## Related Documentation

- `docs/RULES.md` - Rule 57: RC0 requires smoke-surface gate PASS/WARN (FAIL blocks release)
- `docs/runbooks/rc0_release.md` - RC0 release process
- `docs/runbooks/storage_permissions.md` - Storage permissions troubleshooting
- `docs/PROOFS/smoke_surface_pass.md` - Acceptance tests

## Incident Response

If Smoke Surface Gate fails in CI:
1. Check PR description for Pazar code changes
2. Verify Docker stack is running and healthy
3. Check for Monolog permission errors (most common)
4. Run `.\ops\smoke_surface.ps1` locally to reproduce
5. Fix issues (storage permissions, error contract, etc.)
6. Re-run CI check

If Monolog permission error persists:
1. Generate incident bundle: `.\ops\incident_bundle.ps1`
2. Check storage permissions: `.\ops\storage_permissions_check.ps1`
3. Review `work/pazar/docker/docker-entrypoint.sh`
4. Verify `docker-compose.yml` named volumes configuration
5. Fix permissions and restart stack
6. Re-run smoke surface gate



