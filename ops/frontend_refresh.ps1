param(
    [switch]$Build
)

# WP-68: Frontend Refresh Script
# Purpose: Deterministic "apply changes" command for frontend updates
# Must NOT modify git state

$ErrorActionPreference = "Stop"

Write-Host "=== FRONTEND REFRESH (WP-68) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Detect available web services
$availableServices = docker compose ps --services 2>&1 | Where-Object { $_ -match 'web' }
$webServices = @()

if ($availableServices -match 'hos-web') {
    $webServices += 'hos-web'
    Write-Host "Found service: hos-web" -ForegroundColor Gray
}

if ($availableServices -match 'marketplace-web') {
    $webServices += 'marketplace-web'
    Write-Host "Found service: marketplace-web" -ForegroundColor Gray
}

if ($webServices.Count -eq 0) {
    Write-Host "WARN: No web services found. Available services:" -ForegroundColor Yellow
    docker compose ps --services
    Write-Host ""
    Write-Host "Skipping frontend refresh." -ForegroundColor Yellow
    exit 0
}

if ($Build) {
    Write-Host "Mode: REBUILD (--Build switch)" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($service in $webServices) {
        Write-Host "Rebuilding $service..." -ForegroundColor Yellow
        docker compose up -d --build $service
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAIL: Rebuild failed for $service" -ForegroundColor Red
            exit 1
        }
        Write-Host "PASS: $service rebuilt successfully" -ForegroundColor Green
    }
} else {
    Write-Host "Mode: RESTART (default)" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($service in $webServices) {
        Write-Host "Restarting $service..." -ForegroundColor Yellow
        docker compose restart $service
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAIL: Restart failed for $service" -ForegroundColor Red
            exit 1
        }
        Write-Host "PASS: $service restarted successfully" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. Open browser and navigate to:" -ForegroundColor Yellow
Write-Host "   - HOS Web: http://localhost:3002" -ForegroundColor White
Write-Host "   - Marketplace: http://localhost:3002/marketplace/" -ForegroundColor White
Write-Host ""
Write-Host "2. Perform hard refresh in browser:" -ForegroundColor Yellow
Write-Host "   - Windows/Linux: Ctrl+Shift+R" -ForegroundColor White
Write-Host "   - Mac: Cmd+Shift+R" -ForegroundColor White
Write-Host ""
Write-Host "3. If changes don't appear:" -ForegroundColor Yellow
Write-Host "   - Run with -Build switch: .\ops\frontend_refresh.ps1 -Build" -ForegroundColor White
Write-Host "   - Or clear browser cache manually" -ForegroundColor White
Write-Host ""
Write-Host "=== FRONTEND REFRESH COMPLETE ===" -ForegroundColor Green
