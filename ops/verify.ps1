# verify.ps1 - Stack health verification

param(
    [switch]$Release
)

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

# Check for RC0 mode via env var or -Release switch
$isRC0 = $Release -or ($env:RC0 -eq "1") -or ($env:RELEASE_CANDIDATE -eq "1")

Write-Host "=== Stack Verification ===" -ForegroundColor Cyan

# 1) Docker compose ps
Write-Host "`n[1] docker compose ps" -ForegroundColor Yellow
$psOutput = docker compose ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: docker compose ps failed" -ForegroundColor Red
    Write-Host $psOutput
    Invoke-OpsExit 1
    return
}
Write-Host $psOutput

# 2) H-OS health check
Write-Host "`n[2] H-OS health (http://localhost:3000/v1/health)" -ForegroundColor Yellow
try {
    $hosHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:3000/v1/health" -TimeoutSec 5
    if ($hosHealth.StatusCode -eq 200) {
        Write-Host "PASS: HTTP $($hosHealth.StatusCode) $($hosHealth.Content)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: HTTP $($hosHealth.StatusCode)" -ForegroundColor Red
        Invoke-OpsExit 1
        return
    }
} catch {
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-OpsExit 1
    return
}

# 3) Pazar health check (required in RC0 mode, optional otherwise)
Write-Host "`n[3] Pazar health (http://localhost:8080/up)" -ForegroundColor Yellow
try {
    $pazarHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8080/up" -TimeoutSec 5
    if ($pazarHealth.StatusCode -eq 200) {
        Write-Host "PASS: HTTP $($pazarHealth.StatusCode)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: HTTP $($pazarHealth.StatusCode)" -ForegroundColor Red
        Invoke-OpsExit 1
        return
    }
} catch {
    if ($isRC0) {
        Write-Host "FAIL: Pazar /up endpoint required for RC0 but not available: $($_.Exception.Message)" -ForegroundColor Red
        Invoke-OpsExit 1
        return
    } else {
        Write-Host "SKIP: Pazar not available (optional)" -ForegroundColor Yellow
    }
}

# 4) Pazar FS posture check (storage/logs writability)
Write-Host "`n[4] Pazar FS posture (storage/logs writability)" -ForegroundColor Yellow
try {
    $fsCheck = docker compose exec -T pazar-app sh -lc 'test -d storage/logs && touch storage/logs/laravel.log && test -w storage/logs/laravel.log' 2>&1
    $fsExitCode = $LASTEXITCODE
    
    if ($fsExitCode -eq 0) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Pass "Pazar FS posture: storage/logs writable"
        } else {
            Write-Host "PASS: Pazar FS posture - storage/logs writable" -ForegroundColor Green
        }
    } else {
        $fsOutput = $fsCheck | Out-String
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "Pazar FS posture: storage/logs not writable - $fsOutput"
        } else {
            Write-Host "FAIL: Pazar FS posture - storage/logs not writable" -ForegroundColor Red
            Write-Host $fsOutput -ForegroundColor Red
        }
        Write-Host "  Remediation: Ensure docker-compose.yml pazar-app has user: \"0:0\" for root permissions; restart pazar-app" -ForegroundColor Yellow
        Invoke-OpsExit 1
        return
    }
} catch {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "Pazar FS posture check failed: $($_.Exception.Message)"
    } else {
        Write-Host "FAIL: Pazar FS posture check failed - $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host "  Remediation: Ensure docker-compose.yml pazar-app has user: \"0:0\" for root permissions; restart pazar-app" -ForegroundColor Yellow
    Invoke-OpsExit 1
    return
}

Write-Host "`n=== VERIFICATION PASS ===" -ForegroundColor Green

