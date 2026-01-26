# WP-68C: Prototype / Demo Verification Entrypoint
# Purpose: Quick verification that prototype/demo environment is ready
# PowerShell 5.1 compatible, ASCII-only

$ErrorActionPreference = "Stop"

Write-Host "=== PROTOTYPE / DEMO VERIFICATION (WP-68C) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Check 1: Frontend Smoke Test
Write-Host "[1] Running frontend smoke test..." -ForegroundColor Yellow
try {
    & .\ops\frontend_smoke.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: Frontend smoke test failed" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Frontend smoke test" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Frontend smoke test error: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Check 2: World Status
Write-Host "[2] Checking world status..." -ForegroundColor Yellow
try {
    & .\ops\world_status_check.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: World status check failed" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: World status check" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: World status check error: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

if ($hasFailures) {
    Write-Host "=== PROTOTYPE VERIFICATION FAILED ===" -ForegroundColor Red
    Write-Host "Some checks failed. Review output above." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "=== PROTOTYPE VERIFICATION PASSED ===" -ForegroundColor Green
    Write-Host "Prototype/demo environment is ready." -ForegroundColor White
    exit 0
}

