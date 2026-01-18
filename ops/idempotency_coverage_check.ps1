#!/usr/bin/env pwsh
# IDEMPOTENCY COVERAGE CHECK (WP-24)
# Validates that all endpoints requiring idempotency have it implemented.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== IDEMPOTENCY COVERAGE CHECK (WP-24) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$repoRoot = Split-Path -Parent $scriptDir

# Write snapshot file path
$writeSnapshot = Join-Path $repoRoot "contracts\api\marketplace.write.snapshot.json"

# Check snapshot file exists
if (-not (Test-Path $writeSnapshot)) {
    Write-Host "FAIL: Write snapshot not found: $writeSnapshot" -ForegroundColor Red
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

# Filter endpoints that require idempotency
$idempotencyRequired = $writeSnap | Where-Object { $_.idempotency_required -eq $true }

Write-Host "Found $($idempotencyRequired.Count) endpoints requiring idempotency" -ForegroundColor Gray
Write-Host ""

# Validate each endpoint has idempotency implementation
Write-Host "Validating idempotency implementation..." -ForegroundColor Yellow

$routeFiles = Get-ChildItem -Path (Join-Path $repoRoot "work\pazar\routes\api") -Filter "*.php" -File

# First, extract all POST routes from all files (similar to write_snapshot_check.ps1)
$allPostRoutes = @()
foreach ($routeFile in $routeFiles) {
    $content = Get-Content $routeFile.FullName -Raw
    
    # Pattern: Route::post('/v1/...') or Route::middleware(...)->post('/v1/...')
    $postRoutePattern = "Route::(?:middleware\([^)]+\)->)?post\(['""]([^'""]+)['""]"
    $matches = [regex]::Matches($content, $postRoutePattern)
    
    foreach ($match in $matches) {
        $routePath = $match.Groups[1].Value
        # Normalize path (add /api prefix if not present)
        if ($routePath -notmatch "^/api") {
            if ($routePath -match "^/") {
                $routePath = "/api$routePath"
            } else {
                $routePath = "/api/$routePath"
            }
        }
        $allPostRoutes += @{
            path = $routePath
            file = $routeFile.FullName
            content = $content
        }
    }
}

$missingIdempotency = @()

foreach ($endpoint in $idempotencyRequired) {
    $method = $endpoint.method
    $path = $endpoint.path
    $key = "$method $path"
    $requiredHeader = $endpoint.idempotency_key_header
    
    # Find route in extracted routes
    $foundRoute = $null
    foreach ($route in $allPostRoutes) {
        # Exact match
        if ($route.path -eq $path) {
            $foundRoute = $route
            break
        }
        # Pattern match: /api/v1/listings/{id}/offers matches /api/v1/listings/123/offers
        $pathPattern = $path -replace '\{[^}]+\}', '[^/]+'
        if ($route.path -match "^$pathPattern`$") {
            $foundRoute = $route
            break
        }
    }
    
    if (-not $foundRoute) {
        Write-Host "FAIL: Could not find route file for $key" -ForegroundColor Red
        $missingIdempotency += $key
        $hasFailures = $true
        continue
    }
    
    $foundInFile = $foundRoute.file
    $routeContent = $foundRoute.content
    
    if (-not $foundInFile) {
        Write-Host "FAIL: Could not find route file for $key" -ForegroundColor Red
        $missingIdempotency += $key
        $hasFailures = $true
        continue
    }
    
    # Check for Idempotency-Key header requirement
    $hasHeaderCheck = $false
    if ($routeContent -match "Idempotency-Key" -or $routeContent -match "idempotency.*key" -or $routeContent -match "IdempotencyKey") {
        $hasHeaderCheck = $true
    }
    
    if (-not $hasHeaderCheck) {
        Write-Host "FAIL: $key requires Idempotency-Key header but header check not found" -ForegroundColor Red
        Write-Host "  File: $(Split-Path -Leaf $foundInFile)" -ForegroundColor Gray
        Write-Host "  Expected header: $requiredHeader" -ForegroundColor Gray
        $missingIdempotency += $key
        $hasFailures = $true
        continue
    }
    
    # Check for idempotency_keys table usage
    $hasIdempotencyTable = $false
    if ($routeContent -match "idempotency_keys" -or $routeContent -match "idempotencyKeys") {
        $hasIdempotencyTable = $true
    }
    
    if (-not $hasIdempotencyTable) {
        Write-Host "WARN: $key may not use idempotency_keys table for replay detection" -ForegroundColor Yellow
        Write-Host "  File: $(Split-Path -Leaf $foundInFile)" -ForegroundColor Gray
    }
    
    # Check for idempotency replay logic (return cached response)
    $hasReplayLogic = $false
    if ($routeContent -match "existingIdempotency" -or $routeContent -match "response_json" -or $routeContent -match "cached.*response") {
        $hasReplayLogic = $true
    }
    
    if (-not $hasReplayLogic) {
        Write-Host "WARN: $key may not have idempotency replay logic (cached response)" -ForegroundColor Yellow
        Write-Host "  File: $(Split-Path -Leaf $foundInFile)" -ForegroundColor Gray
    } else {
        Write-Host "PASS: $key has idempotency implementation" -ForegroundColor Green
    }
}

Write-Host ""

# Summary
if ($missingIdempotency.Count -gt 0) {
    Write-Host "=== IDEMPOTENCY COVERAGE CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "Missing idempotency implementation: $($missingIdempotency.Count)" -ForegroundColor Red
    foreach ($missing in $missingIdempotency) {
        Write-Host "  - $missing" -ForegroundColor Red
    }
    exit 1
}

Write-Host "=== IDEMPOTENCY COVERAGE CHECK: PASS ===" -ForegroundColor Green
Write-Host "All endpoints requiring idempotency have it implemented" -ForegroundColor Green
exit 0

