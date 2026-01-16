# Pazar Runtime 500 Root Cause + RC0 Gate Unblock Pack v1

## Diagnostic Commands Output

### Container Status
```
NAME                IMAGE                COMMAND                  SERVICE     CREATED          STATUS                    PORTS
stack-hos-api-1     stack-hos-api        "docker-entrypoint.s…"   hos-api     2 hours ago      Up 2 hours               127.0.0.1:3000->3000/tcp
stack-hos-db-1      postgres:16-alpine   "docker-entrypoint.s…"   hos-db      4 hours ago      Up 2 hours (healthy)   5432/tcp
stack-hos-web-1     stack-hos-web        "/docker-entrypoint.…"   hos-web     4 hours ago      Up 2 hours              127.0.0.1:3002->80/tcp
stack-pazar-app-1   stack-pazar-app      "/usr/local/bin/dock…"   pazar-app   26 minutes ago   Up 26 minutes          127.0.0.1:8080->80/tcp
stack-pazar-db-1    postgres:16-alpine   "docker-entrypoint.s…"   pazar-db    2 hours ago      Up 2 hours (healthy)   5432/tcp
```

### /up Endpoint (nginx-level, working)
```
HTTP/1.1 200 OK
Server: nginx
Date: Wed, 14 Jan 2026 15:04:36 GMT
Content-Type: text/plain
Content-Length: 3
Connection: keep-alive

ok
```

### /metrics Endpoint (500 error)
```
HTTP/1.1 500 Internal Server Error
Server: nginx
Date: Wed, 14 Jan 2026 15:04:42 GMT
Content-Type: text/html; charset=UTF-8
Transfer-Encoding: chunked
Connection: keep-alive
X-Powered-By: PHP/8.4.16
```

### /api/products Endpoint (500 error)
```
HTTP/1.1 500 Internal Server Error
Server: nginx
Date: Wed, 14 Jan 2026 15:04:43 GMT
Content-Type: text/html; charset=UTF-8
Transfer-Encoding: chunked
Connection: keep-alive
X-Powered-By: PHP/8.4.16
```

### Artisan Route List (polluted output)
```
Pazar bootstrap ready
```

**Root Cause Identified**: The `work/pazar/artisan` file is a minimal echo script (`echo "Pazar bootstrap ready\n"`), not the real Laravel artisan bootstrap. This causes:
1. `php artisan route:list --json` to output "Pazar bootstrap ready" instead of JSON
2. Laravel routes to fail because artisan commands don't work
3. `/metrics` and `/api/products` to return 500 because Laravel can't bootstrap properly

### PHP Version
```
PHP 8.4.16 (cli) (built: Jan  9 2026 22:46:17)
```

### Storage Permissions
```
storage:
total 16
drwxrwxr-x    4 www-data www-data      4096 Jan 14 14:51 .
drwxrwxrwt    1 www-data www-data      4096 Jan 14 14:38 ..
drwxrwxr-x    5 www-data www-data      4096 Jan 12 12:34 framework
drwxrwxr-x    2 www-data www-data      4096 Jan 14 14:51 logs

storage/logs:
total 8
drwxrwxr-x    2 www-data www-data      4096 Jan 14 14:51 .
drwxrwxr-x    4 www-data www-data      4096 Jan 14 14:51 ..
lrwxrwxrwx    1 root     root            12 Jan 14 14:38 laravel.log -> /proc/1/fd/1
```

## Root Causes Summary

### A) Artisan File Issue
- **Problem**: `work/pazar/artisan` is minimal echo, not Laravel bootstrap
- **Impact**: All artisan commands fail, route:list outputs pollution, Laravel can't bootstrap
- **Fix**: Replace with real Laravel artisan bootstrap

### B) Security Audit JSON Parse Issue
- **Problem**: `php artisan route:list --json` outputs "Pazar bootstrap ready" before JSON
- **Impact**: `ConvertFrom-Json` fails because output is polluted
- **Fix**: Strip non-JSON lines in `ops/_lib/routes_json.ps1`

### C) SLO Check PowerShell Argument Bug
- **Problem**: `@("-N", "30")` passes "-N" as string value, not parameter name
- **Impact**: "Cannot convert value '-N' to Int32" error
- **Fix**: Change to `@("-N", 30)` (integer value)

### D) Storage Permissions Check Hang
- **Problem**: `docker compose exec` calls may hang without timeout
- **Impact**: Script stalls at "Laravel log file writability..."
- **Fix**: Add `timeout 5` to all docker exec commands

### E) Conformance World Registry Drift
- **Status**: Registry and config already match (services, real_estate, vehicle disabled)
- **No fix needed**: Both files are correct

## Fixes Applied

### 1. work/pazar/artisan
**Before**: Minimal echo script
**After**: Real Laravel artisan bootstrap with proper kernel handling

### 2. ops/_lib/routes_json.ps1
**Before**: Direct JSON parse, fails on polluted output
**After**: Strips non-JSON lines, finds first `[` or `{`, extracts JSON block

### 3. ops/rc0_check.ps1
**Before**: `@("-N", "30")` (string value)
**After**: `@("-N", 30)` (integer value)

### 4. ops/rc0_release_bundle.ps1
**Before**: `@("-N", "30")` (string value)
**After**: `@("-N", 30)` (integer value)

### 5. ops/storage_permissions_check.ps1
**Before**: No timeout on docker exec calls
**After**: All docker exec calls wrapped with `timeout 5`

## Expected Results After Rebuild

1. `curl http://localhost:8080/up` => HTTP 200 "ok" (nginx-level, already working)
2. `curl http://localhost:8080/metrics` => HTTP 200 with Prometheus metrics
3. `curl http://localhost:8080/api/products` => HTTP 422 (validation error: world param required) or 401/403 (auth required)
4. `php artisan route:list --json` => Valid JSON array (no "Pazar bootstrap ready" pollution)
5. `.\ops\security_audit.ps1` => PASS (JSON parse succeeds)
6. `.\ops\slo_check.ps1 -N 30` => No argument parsing error
7. `.\ops\storage_permissions_check.ps1` => Completes without hanging
8. `.\ops\conformance.ps1` => PASS for [A] (world registry drift)

## Verification Commands

```powershell
# 1) Rebuild pazar-app with fixed artisan
docker compose build pazar-app

# 2) Restart services
docker compose up -d pazar-db pazar-app

# 3) Wait for startup
Start-Sleep -Seconds 10

# 4) Test endpoints
curl.exe -i http://localhost:8080/up
curl.exe -i http://localhost:8080/metrics
curl.exe -i http://localhost:8080/api/products
curl.exe -i "http://localhost:8080/api/products?world=commerce"

# 5) Test artisan
docker compose exec -T pazar-app php artisan route:list --json --no-ansi | Select-Object -First 5

# 6) Run gates
.\ops\verify.ps1
.\ops\security_audit.ps1
.\ops\slo_check.ps1 -N 30
.\ops\storage_permissions_check.ps1
.\ops\conformance.ps1
.\ops\rc0_check.ps1
```













