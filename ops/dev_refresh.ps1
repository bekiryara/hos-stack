param(
    [switch]$FrontendOnly,
    [switch]$All
)

# WP-68: Dev Refresh Script
# Purpose: Deterministic refresh helper for development
# Modes: FrontendOnly (rebuild/restart web services) or All (full docker compose build+up)
# Must be safe: no db reset, no volume prune
# PowerShell 5.1 compatible, ASCII-only

$ErrorActionPreference = "Stop"

Write-Host "=== DEV REFRESH (WP-68) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Determine mode
$mode = "FrontendOnly"
if ($All) {
    $mode = "All"
} elseif (-not $FrontendOnly -and -not $All) {
    $mode = "FrontendOnly"  # Default
}

Write-Host "Mode: $mode" -ForegroundColor Yellow
Write-Host ""

if ($mode -eq "FrontendOnly") {
    Write-Host "=== FRONTEND ONLY MODE ===" -ForegroundColor Cyan
    Write-Host "Rebuilding/restarting web/frontend services only..." -ForegroundColor White
    Write-Host ""
    
    # Detect web services
    $webServices = @()
    try {
        $allServices = docker compose ps --services 2>&1
        if ($allServices -match 'hos-web') {
            $webServices += 'hos-web'
        }
        if ($allServices -match 'marketplace-web') {
            $webServices += 'marketplace-web'
        }
    } catch {
        Write-Host "WARN: Could not detect services, trying common names..." -ForegroundColor Yellow
        $webServices = @('hos-web', 'marketplace-web')
    }
    
    if ($webServices.Count -eq 0) {
        Write-Host "WARN: No web services found. Available services:" -ForegroundColor Yellow
        docker compose ps --services
        Write-Host ""
        Write-Host "Skipping frontend refresh." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found services: $($webServices -join ', ')" -ForegroundColor Gray
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
    
} elseif ($mode -eq "All") {
    Write-Host "=== ALL SERVICES MODE ===" -ForegroundColor Cyan
    Write-Host "Performing full docker compose build+up..." -ForegroundColor White
    Write-Host ""
    
    Write-Host "WARN: This will rebuild ALL services. Continue? (y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Running: docker compose up -d --build" -ForegroundColor Yellow
    docker compose up -d --build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: Full rebuild failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "PASS: All services rebuilt successfully" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== WHEN TO USE HARD REFRESH VS REBUILD ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Hard Refresh (Ctrl+F5 or Ctrl+Shift+R):" -ForegroundColor Yellow
Write-Host "  - Use when: Only UI text/layout changed and dev server is running" -ForegroundColor White
Write-Host "  - Use when: Changes are purely client-side JavaScript/CSS" -ForegroundColor White
Write-Host "  - Use when: Development server is actively serving latest files" -ForegroundColor White
Write-Host ""
Write-Host "Rebuild (this script):" -ForegroundColor Yellow
Write-Host "  - Use when: Built assets served by nginx/container (FrontendOnly mode)" -ForegroundColor White
Write-Host "  - Use when: Dockerfile or build process changed" -ForegroundColor White
Write-Host "  - Use when: package.json dependencies changed" -ForegroundColor White
Write-Host "  - Use when: Hard refresh doesn't show changes" -ForegroundColor White
Write-Host ""
Write-Host "Full Rebuild (All mode):" -ForegroundColor Yellow
Write-Host "  - Use when: Multiple services need rebuild" -ForegroundColor White
Write-Host "  - Use when: Docker Compose configuration changed" -ForegroundColor White
Write-Host ""

Write-Host "=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. Open browser:" -ForegroundColor Yellow
Write-Host "   - HOS Web: http://localhost:3002" -ForegroundColor White
Write-Host "   - Marketplace: http://localhost:3002/marketplace/" -ForegroundColor White
Write-Host ""
Write-Host "2. Perform hard refresh:" -ForegroundColor Yellow
Write-Host "   - Windows/Linux: Ctrl+Shift+R" -ForegroundColor White
Write-Host "   - Mac: Cmd+Shift+R" -ForegroundColor White
Write-Host ""
Write-Host "=== DEV REFRESH COMPLETE ===" -ForegroundColor Green

