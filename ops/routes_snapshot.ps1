# routes_snapshot.ps1 - Contract Gate (Route Snapshot)
# Validates that API routes haven't changed unexpectedly

$ErrorActionPreference = "Stop"
$failed = $false

Write-Host "=== Contract Gate (Route Snapshot) ===" -ForegroundColor Cyan
Write-Host ""

# Paths
$snapshotPath = "ops\snapshots\routes.pazar.json"
$diffPath = "ops\diffs\routes.diff"
$tempPath = "ops\diffs\routes.current.json"

# Ensure directories exist
if (-not (Test-Path "ops\snapshots")) {
    Write-Host "❌ FAIL: ops\snapshots directory not found" -ForegroundColor Red
    Write-Host "Run this locally to create initial snapshot:" -ForegroundColor Yellow
    Write-Host "  docker compose exec -T pazar-app php artisan route:list --json | Out-File -FilePath ops\snapshots\routes.pazar.json -Encoding UTF8" -ForegroundColor Gray
    exit 1
}

if (-not (Test-Path "ops\diffs")) {
    New-Item -ItemType Directory -Path "ops\diffs" -Force | Out-Null
}

# Check if snapshot exists
if (-not (Test-Path $snapshotPath)) {
    Write-Host "❌ FAIL: Route snapshot not found: $snapshotPath" -ForegroundColor Red
    Write-Host "Run this locally to create initial snapshot:" -ForegroundColor Yellow
    Write-Host "  docker compose exec -T pazar-app php artisan route:list --json | Out-File -FilePath $snapshotPath -Encoding UTF8" -ForegroundColor Gray
    exit 1
}

Write-Host "[1] Checking Docker Compose status..." -ForegroundColor Yellow
$psOutput = docker compose ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ FAIL: docker compose ps failed" -ForegroundColor Red
    Write-Host $psOutput
    exit 1
}

# Check if pazar-app is running
$pazarAppRunning = $psOutput | Select-String "pazar-app.*Up"
if (-not $pazarAppRunning) {
    Write-Host "  Pazar-app not running, starting services..." -ForegroundColor Yellow
    docker compose up -d 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ FAIL: docker compose up failed" -ForegroundColor Red
        exit 1
    }
    Start-Sleep -Seconds 5
    Write-Host "  ✓ Services started" -ForegroundColor Green
} else {
    Write-Host "  ✓ Pazar-app is running" -ForegroundColor Green
}

Write-Host "`n[2] Generating current route snapshot..." -ForegroundColor Yellow
try {
    $currentRoutes = docker compose exec -T pazar-app php artisan route:list --json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ FAIL: php artisan route:list failed" -ForegroundColor Red
        Write-Host $currentRoutes
        exit 1
    }
    
    # Save current routes to temp file
    $currentRoutes | Out-File -FilePath $tempPath -Encoding UTF8
    Write-Host "  ✓ Current routes generated" -ForegroundColor Green
} catch {
    Write-Host "❌ FAIL: Error generating current routes: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n[3] Comparing routes..." -ForegroundColor Yellow
try {
    # Load and parse JSON
    $snapshotContent = Get-Content $snapshotPath -Raw -Encoding UTF8
    $currentContent = Get-Content $tempPath -Raw -Encoding UTF8
    
    # Parse JSON
    $snapshotRoutes = $snapshotContent | ConvertFrom-Json
    $currentRoutes = $currentContent | ConvertFrom-Json
    
    # Create route signature sets (method + uri + name)
    $snapshotSigs = @{}
    foreach ($route in $snapshotRoutes) {
        $sig = "$($route.method)::$($route.uri)::$($route.name)"
        $snapshotSigs[$sig] = $route
    }
    
    $currentSigs = @{}
    foreach ($route in $currentRoutes) {
        $sig = "$($route.method)::$($route.uri)::$($route.name)"
        $currentSigs[$sig] = $route
    }
    
    # Find differences
    $added = @()
    $removed = @()
    
    foreach ($sig in $currentSigs.Keys) {
        if (-not $snapshotSigs.ContainsKey($sig)) {
            $added += $currentSigs[$sig]
        }
    }
    
    foreach ($sig in $snapshotSigs.Keys) {
        if (-not $currentSigs.ContainsKey($sig)) {
            $removed += $snapshotSigs[$sig]
        }
    }
    
    # Report results
    if ($added.Count -eq 0 -and $removed.Count -eq 0) {
        Write-Host "  ✓ No route changes detected" -ForegroundColor Green
        Write-Host "  Total routes: $($snapshotRoutes.Count)" -ForegroundColor Gray
        
        # Clean up temp file
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force
        }
        if (Test-Path $diffPath) {
            Remove-Item $diffPath -Force
        }
        
        Write-Host "`n✅ CONTRACT PASSED" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "  ❌ Route changes detected" -ForegroundColor Red
        
        # Generate diff report
        $diff = @()
        $diff += "# Route Contract Diff"
        $diff += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $diff += ""
        $diff += "## Summary"
        $diff += "- Snapshot routes: $($snapshotRoutes.Count)"
        $diff += "- Current routes: $($currentRoutes.Count)"
        $diff += "- Added: $($added.Count)"
        $diff += "- Removed: $($removed.Count)"
        $diff += ""
        
        if ($added.Count -gt 0) {
            $diff += "## Added Routes ($($added.Count))"
            $diff += ""
            foreach ($route in $added) {
                $diff += "➕ $($route.method) $($route.uri) → $($route.name)"
                $diff += "   Action: $($route.action)"
                $diff += ""
            }
        }
        
        if ($removed.Count -gt 0) {
            $diff += "## Removed Routes ($($removed.Count))"
            $diff += ""
            foreach ($route in $removed) {
                $diff += "➖ $($route.method) $($route.uri) → $($route.name)"
                $diff += "   Action: $($route.action)"
                $diff += ""
            }
        }
        
        # Save diff
        $diff | Out-File -FilePath $diffPath -Encoding UTF8
        
        Write-Host "`n❌ CONTRACT FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "Route changes detected:" -ForegroundColor Yellow
        if ($added.Count -gt 0) {
            Write-Host "  ➕ Added: $($added.Count) routes" -ForegroundColor Green
            foreach ($route in $added | Select-Object -First 5) {
                Write-Host "     - $($route.method) $($route.uri)" -ForegroundColor Gray
            }
            if ($added.Count -gt 5) {
                Write-Host "     ... and $($added.Count - 5) more" -ForegroundColor Gray
            }
        }
        if ($removed.Count -gt 0) {
            Write-Host "  ➖ Removed: $($removed.Count) routes" -ForegroundColor Red
            foreach ($route in $removed | Select-Object -First 5) {
                Write-Host "     - $($route.method) $($route.uri)" -ForegroundColor Gray
            }
            if ($removed.Count -gt 5) {
                Write-Host "     ... and $($removed.Count - 5) more" -ForegroundColor Gray
            }
        }
        Write-Host ""
        Write-Host "Diff saved to: $diffPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If these changes are intentional:" -ForegroundColor Cyan
        Write-Host "  1. Review the diff: cat $diffPath" -ForegroundColor Gray
        Write-Host "  2. Update snapshot: docker compose exec -T pazar-app php artisan route:list --json | Out-File -FilePath $snapshotPath -Encoding UTF8" -ForegroundColor Gray
        Write-Host "  3. Commit the updated snapshot" -ForegroundColor Gray
        
        exit 1
    }
} catch {
    Write-Host "❌ FAIL: Error comparing routes: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

