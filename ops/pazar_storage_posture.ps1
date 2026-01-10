# pazar_storage_posture.ps1 - Verify Pazar storage and cache directories are writable
# PowerShell 5.1 compatible

param(
    [switch]$Ci
)

# Load shared output helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}

$ErrorActionPreference = "Continue"

# Ensure we're in repo root
$repoRoot = Split-Path -Parent $scriptDir
Push-Location $repoRoot
try {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "=== Pazar Storage Posture Check ==="
    } else {
        Write-Host "=== Pazar Storage Posture Check ===" -ForegroundColor Cyan
    }
    
    # Check if pazar-app container exists and is running
    $containerName = "stack-pazar-app-1"
    $containerExists = docker ps --format "{{.Names}}" | Select-String -Pattern "^${containerName}$" -Quiet
    if (-not $containerExists) {
        # Try alternative naming (project name might be different)
        $containerExists = docker ps --format "{{.Names}}" | Select-String -Pattern "pazar-app" -Quiet
        if ($containerExists) {
            $containerName = (docker ps --format "{{.Names}}" | Select-String -Pattern "pazar-app").Line
        }
    }
    
    if (-not $containerExists) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Warn "pazar-app container not found or not running (SKIP)"
        } else {
            Write-Host "[WARN] pazar-app container not found or not running (SKIP)" -ForegroundColor Yellow
        }
        $global:LASTEXITCODE = 2
        if ($Ci) {
            exit 2
        } else {
            return 2
        }
    }
    
    $checks = @()
    $failCount = 0
    $warnCount = 0
    
    # Check 1: storage/logs exists
    Write-Host "Checking storage/logs directory..." -ForegroundColor Gray
    $cmd = "test -d /var/www/html/storage/logs && echo 'EXISTS' || echo 'MISSING'"
    $storageLogsCheck = docker exec $containerName sh -lc $cmd 2>&1
    if ($storageLogsCheck -match "EXISTS") {
        $checks += [PSCustomObject]@{ Check = "storage/logs directory exists"; Status = "PASS"; Notes = "Directory exists" }
    } else {
        $checks += [PSCustomObject]@{ Check = "storage/logs directory exists"; Status = "FAIL"; Notes = "Directory missing" }
        $failCount++
    }
    
    # Check 2: laravel.log exists
    Write-Host "Checking laravel.log file..." -ForegroundColor Gray
    $cmd = "test -f /var/www/html/storage/logs/laravel.log && echo 'EXISTS' || echo 'MISSING'"
    $laravelLogExists = docker exec $containerName sh -lc $cmd 2>&1
    if ($laravelLogExists -match "EXISTS") {
        $checks += [PSCustomObject]@{ Check = "laravel.log file exists"; Status = "PASS"; Notes = "File exists" }
    } else {
        $checks += [PSCustomObject]@{ Check = "laravel.log file exists"; Status = "FAIL"; Notes = "File missing" }
        $failCount++
    }
    
    # Check 3: laravel.log writable by www-data
    Write-Host "Checking laravel.log writability..." -ForegroundColor Gray
    $cmd = "su -s /bin/sh www-data -c 'test -w /var/www/html/storage/logs/laravel.log && echo \"WRITABLE\" || echo \"NOT_WRITABLE\"'"
    $laravelLogWritableCheck = docker exec $containerName sh -lc $cmd 2>&1
    if ($laravelLogWritableCheck -match "WRITABLE") {
        $checks += [PSCustomObject]@{ Check = "laravel.log writable by www-data"; Status = "PASS"; Notes = "File is writable" }
    } else {
        $checks += [PSCustomObject]@{ Check = "laravel.log writable by www-data"; Status = "FAIL"; Notes = "File not writable by www-data" }
        $failCount++
    }

    # Check 4: Write test to laravel.log
    Write-Host "Testing write operation to laravel.log..." -ForegroundColor Gray
    $cmd = "su -s /bin/sh www-data -c 'php -r \"file_put_contents(\\\"/var/www/html/storage/logs/laravel.log\\\",\\\"probe\\n\\\",FILE_APPEND); echo \\\"OK\\n\\\";\"'"
    $writeTest = docker exec $containerName sh -lc $cmd 2>&1
    if ($writeTest -match "OK") {
        $checks += [PSCustomObject]@{ Check = "Write test to laravel.log"; Status = "PASS"; Notes = "Write operation succeeded" }
    } else {
        $checks += [PSCustomObject]@{ Check = "Write test to laravel.log"; Status = "FAIL"; Notes = "Write operation failed: $writeTest" }
        $failCount++
    }
    
    # Check 5: bootstrap/cache writable
    Write-Host "Checking bootstrap/cache directory..." -ForegroundColor Gray
    $cmd = "test -d /var/www/html/bootstrap/cache && su -s /bin/sh www-data -c 'test -w /var/www/html/bootstrap/cache' && echo 'WRITABLE' || echo 'NOT_WRITABLE'"
    $bootstrapCacheCheck = docker exec $containerName sh -lc $cmd 2>&1
    if ($bootstrapCacheCheck -match "WRITABLE") {
        $checks += [PSCustomObject]@{ Check = "bootstrap/cache writable"; Status = "PASS"; Notes = "Directory exists and is writable" }
    } else {
        $checks += [PSCustomObject]@{ Check = "bootstrap/cache writable"; Status = "FAIL"; Notes = "Directory missing or not writable" }
        $failCount++
    }
    
    # Summary
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "=== Storage Posture Results ==="
    } else {
        Write-Host "=== Storage Posture Results ===" -ForegroundColor Cyan
    }
    Write-Host ""
    $checks | Format-Table -Property Check, Status, Notes -AutoSize
    
    # Determine overall status
    Write-Host ""
    if ($failCount -gt 0) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "OVERALL STATUS: FAIL ($failCount failures)"
        } else {
            Write-Host "[FAIL] OVERALL STATUS: FAIL ($failCount failures)" -ForegroundColor Red
        }
        Write-Host "Remediation hints:" -ForegroundColor Yellow
        Write-Host "  - Ensure named volumes (pazar_storage, pazar_cache) are properly mounted in docker-compose.yml" -ForegroundColor Gray
        Write-Host "  - Verify docker-entrypoint.sh is correctly setting permissions on container start" -ForegroundColor Gray
        Write-Host "  - Manually check permissions inside the container: docker compose exec -T pazar-app sh -lc 'ls -ld storage storage/logs bootstrap/cache; ls -l storage/logs/laravel.log'" -ForegroundColor Gray
        Write-Host "  - Try restarting the container: docker compose up -d --no-build pazar-app" -ForegroundColor Gray
        $global:LASTEXITCODE = 1
        if ($Ci) {
            exit 1
        } else {
            return 1
        }
    } else {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Pass "OVERALL STATUS: PASS (All storage checks passed)"
        } else {
            Write-Host "[PASS] OVERALL STATUS: PASS (All storage checks passed)" -ForegroundColor Green
        }
        $global:LASTEXITCODE = 0
        if ($Ci) {
            exit 0
        } else {
            return 0
        }
    }
} finally {
    Pop-Location
}
