#!/usr/bin/env pwsh
# READ SNAPSHOT CHECK (WP-13)
# Validates READ endpoints against snapshot files to prevent drift.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== READ SNAPSHOT CHECK (WP-13) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$repoRoot = Split-Path -Parent $scriptDir

# Snapshot file paths
$accountPortalSnapshot = Join-Path $repoRoot "contracts\api\account_portal.read.snapshot.json"
$marketplaceSnapshot = Join-Path $repoRoot "contracts\api\marketplace.read.snapshot.json"
$pazarRoutesFile = Join-Path $repoRoot "work\pazar\routes\api.php"

# Check snapshot files exist
if (-not (Test-Path $accountPortalSnapshot)) {
    Write-Host "FAIL: Account Portal snapshot not found: $accountPortalSnapshot" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $marketplaceSnapshot)) {
    Write-Host "FAIL: Marketplace snapshot not found: $marketplaceSnapshot" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $pazarRoutesFile)) {
    Write-Host "FAIL: Pazar routes file not found: $pazarRoutesFile" -ForegroundColor Red
    exit 1
}

# Load snapshots
Write-Host "Loading snapshots..." -ForegroundColor Yellow
try {
    $accountPortalSnap = Get-Content $accountPortalSnapshot -Raw | ConvertFrom-Json
    $marketplaceSnap = Get-Content $marketplaceSnapshot -Raw | ConvertFrom-Json
} catch {
    Write-Host "FAIL: Error loading snapshots: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Extract GET routes from api.php
Write-Host "Extracting GET routes from $pazarRoutesFile..." -ForegroundColor Yellow
$routeContent = Get-Content $pazarRoutesFile -Raw

# Pattern: Route::get('/v1/...') or Route::middleware(...)->get('/v1/...')
$getRoutePattern = "Route::(?:middleware\([^)]+\)->)?get\(['""]([^'""]+)['""]"
$matches = [regex]::Matches($routeContent, $getRoutePattern)

$foundRoutes = @()
foreach ($match in $matches) {
    $path = $match.Groups[1].Value
    # Normalize path (remove leading slash if present, add /api prefix)
    if ($path -notmatch "^/api") {
        if ($path -match "^/") {
            $path = "/api$path"
        } else {
            $path = "/api/$path"
        }
    }
    # Handle path parameters {id} -> {id}
    $foundRoutes += $path
}

Write-Host "Found $($foundRoutes.Count) GET routes" -ForegroundColor Gray

# Combine snapshots
$allSnapshots = @($accountPortalSnap) + @($marketplaceSnap)

# Check each snapshot endpoint exists in routes
Write-Host ""
Write-Host "Validating snapshot endpoints against routes..." -ForegroundColor Yellow
$missingRoutes = @()
$extraRoutes = @()

foreach ($snap in $allSnapshots) {
    $snapPath = $snap.path
    # Check if route exists (exact match or with {id} parameter)
    $found = $false
    foreach ($route in $foundRoutes) {
        # Exact match
        if ($route -eq $snapPath) {
            $found = $true
            break
        }
        # Parameter match: /api/v1/listings/{id} matches /api/v1/listings/123
        $snapPathPattern = $snapPath -replace '\{[^}]+\}', '[^/]+'
        if ($route -match "^$snapPathPattern`$") {
            $found = $true
            break
        }
        # Reverse: route pattern matches snapshot
        $routePattern = $route -replace '[^/]+', '[^/]+'
        if ($snapPath -match "^$routePattern`$") {
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        $missingRoutes += $snapPath
        Write-Host "MISSING: $($snap.method) $snapPath (owner: $($snap.owner), scope: $($snap.scope))" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "FOUND: $($snap.method) $snapPath" -ForegroundColor Green
    }
}

# Check for extra GET routes not in snapshot (warn only for now)
Write-Host ""
Write-Host "Checking for extra GET routes not in snapshot..." -ForegroundColor Yellow
$snapshotPaths = $allSnapshots | ForEach-Object { $_.path }
foreach ($route in $foundRoutes) {
    $inSnapshot = $false
    foreach ($snapPath in $snapshotPaths) {
        # Exact match
        if ($route -eq $snapPath) {
            $inSnapshot = $true
            break
        }
        # Pattern match
        $snapPathPattern = $snapPath -replace '\{[^}]+\}', '[^/]+'
        if ($route -match "^$snapPathPattern`$") {
            $inSnapshot = $true
            break
        }
    }
    
    if (-not $inSnapshot) {
        # Skip system routes like /ping, /up, /world/status
        if ($route -notmatch "^(/api)?/(ping|up|world/status)") {
            $extraRoutes += $route
            Write-Host "EXTRA: GET $route (not in snapshot - may need to be added)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# Summary
if ($missingRoutes.Count -gt 0) {
    Write-Host "=== READ SNAPSHOT CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "Missing routes: $($missingRoutes.Count)" -ForegroundColor Red
    Write-Host "Snapshot endpoints must exist in routes/api.php" -ForegroundColor Red
    exit 1
}

if ($extraRoutes.Count -gt 0) {
    Write-Host "=== READ SNAPSHOT CHECK: WARN ===" -ForegroundColor Yellow
    Write-Host "Extra routes found: $($extraRoutes.Count) (not in snapshot)" -ForegroundColor Yellow
    Write-Host "Consider adding to snapshot or removing if not needed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== READ SNAPSHOT CHECK: PASS (with warnings) ===" -ForegroundColor Green
    exit 0
}

Write-Host "=== READ SNAPSHOT CHECK: PASS ===" -ForegroundColor Green
Write-Host "All snapshot endpoints found in routes" -ForegroundColor Green
exit 0

