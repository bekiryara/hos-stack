# Prototype Demo Orchestrator (WP-46)
# Orchestrates existing smoke scripts (no duplication)

$ErrorActionPreference = "Stop"

Write-Host "=== PROTOTYPE DEMO (WP-46) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Step 1: Prototype smoke
Write-Host "[1] Running prototype smoke..." -ForegroundColor Yellow
try {
    $output = & "$PSScriptRoot\prototype_smoke.ps1" 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host ""
        Write-Host "FAIL: Stack not ready" -ForegroundColor Red
        Write-Host "  Run: docker compose up -d" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "PASS: Prototype smoke completed" -ForegroundColor Green
    }
} catch {
    Write-Host ""
    Write-Host "FAIL: Stack not ready" -ForegroundColor Red
    Write-Host "  Run: docker compose up -d" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2: Prototype flow smoke
Write-Host "[2] Running prototype flow smoke..." -ForegroundColor Yellow
try {
    $output = & "$PSScriptRoot\prototype_flow_smoke.ps1" 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host ""
        Write-Host "FAIL: E2E flow failed" -ForegroundColor Red
        Write-Host "  See hints above; verify HOS is running and dev auth works." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "PASS: Prototype flow smoke completed" -ForegroundColor Green
    }
} catch {
    Write-Host ""
    Write-Host "FAIL: E2E flow failed" -ForegroundColor Red
    Write-Host "  See hints above; verify HOS is running and dev auth works." -ForegroundColor Yellow
    exit 1
}

# Success: Print click targets
Write-Host ""
Write-Host "=== Click Targets ===" -ForegroundColor Cyan
Write-Host "  HOS Web: http://localhost:3002" -ForegroundColor Gray
Write-Host "  HOS Worlds: http://localhost:3000/v1/worlds" -ForegroundColor Gray
Write-Host "  Pazar Status: http://localhost:8080/api/world/status" -ForegroundColor Gray
Write-Host "  Messaging Status: http://localhost:8090/api/world/status" -ForegroundColor Gray
Write-Host ""
Write-Host "PASS: Prototype demo ready" -ForegroundColor Green
exit 0

