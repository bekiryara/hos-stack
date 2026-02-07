# routes_snapshot.ps1 - Contract Gate (Route Snapshot)
# Validates that API routes haven't changed unexpectedly

$ErrorActionPreference = "Stop"
$failed = $false

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}
if (Test-Path "${scriptDir}\_lib\routes_json.ps1") {
    . "${scriptDir}\_lib\routes_json.ps1"
}

Write-Host "=== Contract Gate (Route Snapshot) ===" -ForegroundColor Cyan
Write-Host ""

# Paths
$snapshotPath = "ops\snapshots\routes.pazar.json"
$diffPath = "ops\diffs\routes.diff"
$tempPath = "ops\diffs\routes.current.json"

# Ensure directories exist
if (-not (Test-Path "ops\snapshots")) {
    Write-Host "[FAIL] FAIL: ops\snapshots directory not found" -ForegroundColor Red
    Write-Host "Run this locally to create initial snapshot:" -ForegroundColor Yellow
    Write-Host "  docker compose exec -T pazar-app php artisan route:list --json | Out-File -FilePath ops\snapshots\routes.pazar.json -Encoding UTF8" -ForegroundColor Gray
    Invoke-OpsExit 1
    return
}

if (-not (Test-Path "ops\diffs")) {
    New-Item -ItemType Directory -Path "ops\diffs" -Force | Out-Null
}

# Check if snapshot exists
if (-not (Test-Path $snapshotPath)) {
    Write-Host "[FAIL] FAIL: Route snapshot not found: $snapshotPath" -ForegroundColor Red
    Write-Host "Run this locally to create initial snapshot:" -ForegroundColor Yellow
    Write-Host "  docker compose exec -T pazar-app php artisan route:list --json | Out-File -FilePath $snapshotPath -Encoding UTF8" -ForegroundColor Gray
    Invoke-OpsExit 1
    return
}

Write-Host "[1] Checking Docker Compose status..." -ForegroundColor Yellow
$psOutput = docker compose ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] FAIL: docker compose ps failed" -ForegroundColor Red
    Write-Host $psOutput
    Invoke-OpsExit 1
    return
}

# Check if pazar-app is running
$pazarAppRunning = $psOutput | Select-String "pazar-app.*Up"
if (-not $pazarAppRunning) {
    Write-Host "  Pazar-app not running, starting services..." -ForegroundColor Yellow
    docker compose up -d 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] FAIL: docker compose up failed" -ForegroundColor Red
        Invoke-OpsExit 1
    return
    }
    Start-Sleep -Seconds 5
    Write-Host "  [OK] Services started" -ForegroundColor Green
} else {
    Write-Host "  [OK] Pazar-app is running" -ForegroundColor Green
}

Write-Host "`n[2] Generating current route snapshot..." -ForegroundColor Yellow
try {
    # Use canonical route JSON helper
    $rawJson = Get-RawPazarRouteListJson -ContainerName "pazar-app"
    $canonicalRoutes = Convert-RoutesJsonToCanonicalArray -RawJsonText $rawJson
    
    # Sanity check: route count should be reasonable (> 20)
    if ($canonicalRoutes.Count -lt 20) {
        Write-Host "[FAIL] FAIL: Route count too low ($($canonicalRoutes.Count)). Route JSON parse mismatch or artisan output changed." -ForegroundColor Red
        Invoke-OpsExit 1
        return
    }
    
    # Convert canonical routes back to JSON for comparison
    $currentRoutesJson = $canonicalRoutes | ConvertTo-Json -Depth 10
    $currentRoutesJson | Out-File -FilePath $tempPath -Encoding UTF8 -NoNewline
    
    Write-Host "  [OK] Current routes generated ($($canonicalRoutes.Count) routes)" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] FAIL: Error generating current routes: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-OpsExit 1
    return
}

Write-Host "`n[3] Comparing routes..." -ForegroundColor Yellow
try {
    # Load and parse JSON (normalize both snapshot and current)
    $snapshotContent = Get-Content $snapshotPath -Raw -Encoding UTF8
    $currentContent = Get-Content $tempPath -Raw -Encoding UTF8
    
    # Normalize snapshot (handle legacy formats)
    $snapshotRoutes = Convert-RoutesJsonToCanonicalArray -RawJsonText $snapshotContent
    
    # Current routes are already canonical
    $currentRoutes = $canonicalRoutes
    
    # Create route signature sets (method_primary + uri + name + action)
    # Note: middleware excluded from signature to avoid noisy diffs
    $snapshotSigs = @{}
    foreach ($route in $snapshotRoutes) {
        $methodPrimary = if ($route.method_primary) { $route.method_primary } else { $route.method }
        $sig = "$methodPrimary::$($route.uri)::$($route.name)::$($route.action)"
        $snapshotSigs[$sig] = $route
    }
    
    $currentSigs = @{}
    foreach ($route in $currentRoutes) {
        $methodPrimary = if ($route.method_primary) { $route.method_primary } else { $route.method }
        $sig = "$methodPrimary::$($route.uri)::$($route.name)::$($route.action)"
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
    Write-Host "  Snapshot routes: $($snapshotRoutes.Count)" -ForegroundColor Gray
    Write-Host "  Current routes: $($currentRoutes.Count)" -ForegroundColor Gray
    Write-Host "  Added: $($added.Count)" -ForegroundColor $(if ($added.Count -eq 0) { "Gray" } else { "Green" })
    Write-Host "  Removed: $($removed.Count)" -ForegroundColor $(if ($removed.Count -eq 0) { "Gray" } else { "Red" })
    
    if ($added.Count -eq 0 -and $removed.Count -eq 0) {
        Write-Host "  [OK] No route changes detected" -ForegroundColor Green
        
        # Clean up temp file
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force
        }
        if (Test-Path $diffPath) {
            Remove-Item $diffPath -Force
        }
        
        Write-Host "`n[PASS] CONTRACT PASSED" -ForegroundColor Green
        Invoke-OpsExit 0
        return
    } else {
        Write-Host "  [FAIL] Route changes detected" -ForegroundColor Red
        
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
                $diff += "[+] $($route.method) $($route.uri) → $($route.name)"
                $diff += "   Action: $($route.action)"
                $diff += ""
            }
        }
        
        if ($removed.Count -gt 0) {
            $diff += "## Removed Routes ($($removed.Count))"
            $diff += ""
            foreach ($route in $removed) {
                $diff += "[-] $($route.method) $($route.uri) → $($route.name)"
                $diff += "   Action: $($route.action)"
                $diff += ""
            }
        }
        
        # Save diff
        $diff | Out-File -FilePath $diffPath -Encoding UTF8
        
        Write-Host "`n[FAIL] CONTRACT FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "Route changes detected:" -ForegroundColor Yellow
        if ($added.Count -gt 0) {
            Write-Host "  [+] Added: $($added.Count) routes" -ForegroundColor Green
            foreach ($route in $added | Select-Object -First 5) {
                Write-Host "     - $($route.method) $($route.uri)" -ForegroundColor Gray
            }
            if ($added.Count -gt 5) {
                Write-Host "     ... and $($added.Count - 5) more" -ForegroundColor Gray
            }
        }
        if ($removed.Count -gt 0) {
            Write-Host "  [-] Removed: $($removed.Count) routes" -ForegroundColor Red
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
        
        Invoke-OpsExit 1
    return
    }
} catch {
    Write-Host "[FAIL] FAIL: Error comparing routes: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-OpsExit 1
    return
}

