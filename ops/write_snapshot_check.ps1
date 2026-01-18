#!/usr/bin/env pwsh
# WRITE SNAPSHOT CHECK (WP-24)
# Validates WRITE endpoints against snapshot file to prevent drift.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== WRITE SNAPSHOT CHECK (WP-24) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$repoRoot = Split-Path -Parent $scriptDir

# Snapshot file path
$writeSnapshot = Join-Path $repoRoot "contracts\api\marketplace.write.snapshot.json"
$pazarRoutesDir = Join-Path $repoRoot "work\pazar\routes\api"

# Check snapshot file exists
if (-not (Test-Path $writeSnapshot)) {
    Write-Host "FAIL: Write snapshot not found: $writeSnapshot" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $pazarRoutesDir)) {
    Write-Host "FAIL: Pazar routes directory not found: $pazarRoutesDir" -ForegroundColor Red
    exit 1
}

# Load snapshot
Write-Host "Loading write snapshot..." -ForegroundColor Yellow
try {
    $writeSnap = Get-Content $writeSnapshot -Raw | ConvertFrom-Json
} catch {
    Write-Host "FAIL: Error loading write snapshot: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Extract POST/PUT/PATCH routes from all route module files
Write-Host "Extracting POST/PUT/PATCH routes from route modules..." -ForegroundColor Yellow

# Get all PHP files in routes/api directory
$routeFiles = Get-ChildItem -Path $pazarRoutesDir -Filter "*.php" -File

$foundRoutes = @()
foreach ($routeFile in $routeFiles) {
    $routeContent = Get-Content $routeFile.FullName -Raw
    
    # Pattern: Route::post('/v1/...') or Route::middleware(...)->post('/v1/...')
    $postRoutePattern = "Route::(?:middleware\([^)]+\)->)?post\(['""]([^'""]+)['""]"
    $matches = [regex]::Matches($routeContent, $postRoutePattern)
    
    foreach ($match in $matches) {
        $path = $match.Groups[1].Value
        # Normalize path (add /api prefix if not present)
        if ($path -notmatch "^/api") {
            if ($path -match "^/") {
                $path = "/api$path"
            } else {
                $path = "/api/$path"
            }
        }
        $foundRoutes += @{
            method = "POST"
            path = $path
            file = $routeFile.Name
        }
    }
    
    # Also check for PUT and PATCH (if any exist in future)
    $putRoutePattern = "Route::(?:middleware\([^)]+\)->)?put\(['""]([^'""]+)['""]"
    $matches = [regex]::Matches($routeContent, $putRoutePattern)
    foreach ($match in $matches) {
        $path = $match.Groups[1].Value
        if ($path -notmatch "^/api") {
            if ($path -match "^/") {
                $path = "/api$path"
            } else {
                $path = "/api/$path"
            }
        }
        $foundRoutes += @{
            method = "PUT"
            path = $path
            file = $routeFile.Name
        }
    }
    
    $patchRoutePattern = "Route::(?:middleware\([^)]+\)->)?patch\(['""]([^'""]+)['""]"
    $matches = [regex]::Matches($routeContent, $patchRoutePattern)
    foreach ($match in $matches) {
        $path = $match.Groups[1].Value
        if ($path -notmatch "^/api") {
            if ($path -match "^/") {
                $path = "/api$path"
            } else {
                $path = "/api/$path"
            }
        }
        $foundRoutes += @{
            method = "PATCH"
            path = $path
            file = $routeFile.Name
        }
    }
}

Write-Host "Found $($foundRoutes.Count) write routes" -ForegroundColor Gray

# Check each snapshot endpoint exists in routes
Write-Host ""
Write-Host "Validating snapshot endpoints against routes..." -ForegroundColor Yellow
$missingRoutes = @()
$extraRoutes = @()

foreach ($snap in $writeSnap) {
    $snapMethod = $snap.method
    $snapPath = $snap.path
    
    # Check if route exists
    $found = $false
    foreach ($route in $foundRoutes) {
        # Method must match
        if ($route.method -ne $snapMethod) {
            continue
        }
        
        # Exact path match
        if ($route.path -eq $snapPath) {
            $found = $true
            break
        }
        
        # Pattern match: /api/v1/listings/{id} matches /api/v1/listings/123
        $snapPathPattern = $snapPath -replace '\{[^}]+\}', '[^/]+'
        if ($route.path -match "^$snapPathPattern`$") {
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        $missingRoutes += "$snapMethod $snapPath"
        Write-Host "MISSING: $snapMethod $snapPath (owner: $($snap.owner), scope: $($snap.scope))" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "FOUND: $snapMethod $snapPath" -ForegroundColor Green
    }
}

# Check for extra write routes not in snapshot
Write-Host ""
Write-Host "Checking for extra write routes not in snapshot..." -ForegroundColor Yellow
$snapshotKeys = $writeSnap | ForEach-Object { "$($_.method) $($_.path)" }

foreach ($route in $foundRoutes) {
    $routeKey = "$($route.method) $($route.path)"
    $inSnapshot = $false
    
    foreach ($snapKey in $snapshotKeys) {
        # Exact match
        if ($routeKey -eq $snapKey) {
            $inSnapshot = $true
            break
        }
        
        # Pattern match (handle path parameters)
        $snapMethod = $snapKey -split ' ' | Select-Object -First 1
        $snapPath = $snapKey -replace '^\w+ ', ''
        
        if ($route.method -eq $snapMethod) {
            $snapPathPattern = $snapPath -replace '\{[^}]+\}', '[^/]+'
            if ($route.path -match "^$snapPathPattern`$") {
                $inSnapshot = $true
                break
            }
        }
    }
    
    if (-not $inSnapshot) {
        $extraRoutes += $routeKey
        Write-Host "EXTRA: $routeKey (in $($route.file) - not in snapshot)" -ForegroundColor Yellow
    }
}

Write-Host ""

# Summary
if ($missingRoutes.Count -gt 0) {
    Write-Host "=== WRITE SNAPSHOT CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "Missing routes: $($missingRoutes.Count)" -ForegroundColor Red
    Write-Host "Snapshot endpoints must exist in routes/api/*.php" -ForegroundColor Red
    exit 1
}

if ($extraRoutes.Count -gt 0) {
    Write-Host "=== WRITE SNAPSHOT CHECK: WARN ===" -ForegroundColor Yellow
    Write-Host "Extra write routes found: $($extraRoutes.Count) (not in snapshot)" -ForegroundColor Yellow
    Write-Host "Consider adding to snapshot or removing if not needed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== WRITE SNAPSHOT CHECK: PASS (with warnings) ===" -ForegroundColor Green
    exit 0
}

Write-Host "=== WRITE SNAPSHOT CHECK: PASS ===" -ForegroundColor Green
Write-Host "All snapshot endpoints found in routes" -ForegroundColor Green
exit 0

