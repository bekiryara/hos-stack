# storage_posture_check.ps1 - Verify Pazar storage and cache directories are writable
# PowerShell 5.1 compatible, ASCII-only output

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
        Write-Info "=== Storage Posture Check ==="
    } else {
        Write-Host "=== Storage Posture Check ===" -ForegroundColor Cyan
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
    
    # Check 1: /var/www/html/storage writable
    Write-Host "Checking /var/www/html/storage writability..." -ForegroundColor Gray
    $cmd = "test -d /var/www/html/storage && su -s /bin/sh www-data -c 'test -w /var/www/html/storage' && echo 'WRITABLE' || echo 'NOT_WRITABLE'"
    $storageCheck = docker exec $containerName sh -lc $cmd 2>&1
    if ($storageCheck -match "WRITABLE") {
        $checks += [PSCustomObject]@{ Check = "/var/www/html/storage writable"; Status = "PASS"; Notes = "Directory exists and is writable" }
    } else {
        $checks += [PSCustomObject]@{ Check = "/var/www/html/storage writable"; Status = "FAIL"; Notes = "Directory missing or not writable" }
        $failCount++
    }
    
    # Check 2: /var/www/html/storage/logs writable
    Write-Host "Checking /var/www/html/storage/logs writability..." -ForegroundColor Gray
    $cmd = "test -d /var/www/html/storage/logs && su -s /bin/sh www-data -c 'test -w /var/www/html/storage/logs' && echo 'WRITABLE' || echo 'NOT_WRITABLE'"
    $storageLogsCheck = docker exec $containerName sh -lc $cmd 2>&1
    if ($storageLogsCheck -match "WRITABLE") {
        $checks += [PSCustomObject]@{ Check = "/var/www/html/storage/logs writable"; Status = "PASS"; Notes = "Directory exists and is writable" }
    } else {
        $checks += [PSCustomObject]@{ Check = "/var/www/html/storage/logs writable"; Status = "FAIL"; Notes = "Directory missing or not writable" }
        $failCount++
    }
    
    # Check 3: laravel.log can be created
    Write-Host "Checking laravel.log can be created..." -ForegroundColor Gray
    $cmd = "su -s /bin/sh www-data -c 'touch /var/www/html/storage/logs/laravel.log.test && rm -f /var/www/html/storage/logs/laravel.log.test && echo \"CREATED\" || echo \"NOT_CREATED\"'"
    $createCheck = docker exec $containerName sh -lc $cmd 2>&1
    if ($createCheck -match "CREATED") {
        $checks += [PSCustomObject]@{ Check = "laravel.log can be created"; Status = "PASS"; Notes = "File can be created by www-data" }
    } else {
        $checks += [PSCustomObject]@{ Check = "laravel.log can be created"; Status = "FAIL"; Notes = "File cannot be created by www-data" }
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
        Write-Host "  - Recreate container: docker compose down pazar-app && docker compose up -d --force-recreate pazar-app" -ForegroundColor Gray
        Write-Host "  - Check container logs: docker compose logs pazar-app | Select-String 'storage not writable'" -ForegroundColor Gray
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

