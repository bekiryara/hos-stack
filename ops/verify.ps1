# verify.ps1 - Stack health verification

$ErrorActionPreference = "Stop"

Write-Host "=== Stack Verification ===" -ForegroundColor Cyan

# 1) Docker compose ps
Write-Host "`n[1] docker compose ps" -ForegroundColor Yellow
$psOutput = docker compose ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: docker compose ps failed" -ForegroundColor Red
    Write-Host $psOutput
    exit 1
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
        exit 1
    }
} catch {
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3) Pazar health check (optional)
Write-Host "`n[3] Pazar health (http://localhost:8080/up)" -ForegroundColor Yellow
try {
    $pazarHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8080/up" -TimeoutSec 5
    Write-Host "PASS: HTTP $($pazarHealth.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "SKIP: Pazar not available (optional)" -ForegroundColor Yellow
}

Write-Host "`n=== VERIFICATION PASS ===" -ForegroundColor Green

