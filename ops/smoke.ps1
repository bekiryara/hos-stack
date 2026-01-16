#!/usr/bin/env pwsh
# GENESIS World Status Smoke Test (WP-1)
# Tests GET /world/status (Marketplace) and GET /worlds (Core)

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== GENESIS WORLD STATUS SMOKE TEST ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Test 1: Marketplace GET /api/world/status
Write-Host "[1] Testing Marketplace GET /api/world/status..." -ForegroundColor Yellow
$pazarWorldStatusUrl = "http://localhost:8080/api/world/status"
try {
    $response = Invoke-RestMethod -Uri $pazarWorldStatusUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
    
    # Validate response format (SPEC §24.4)
    if (-not $response.world_key) {
        Write-Host "FAIL: Missing 'world_key' in response" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($response.world_key -ne "marketplace") {
        Write-Host "FAIL: Expected world_key='marketplace', got '$($response.world_key)'" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($response.availability -ne "ONLINE") {
        Write-Host "FAIL: Expected availability='ONLINE', got '$($response.availability)'" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.phase) {
        Write-Host "FAIL: Missing 'phase' in response" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.version) {
        Write-Host "FAIL: Missing 'version' in response" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Marketplace /world/status returns valid response" -ForegroundColor Green
        Write-Host "  world_key: $($response.world_key)" -ForegroundColor Gray
        Write-Host "  availability: $($response.availability)" -ForegroundColor Gray
        Write-Host "  phase: $($response.phase)" -ForegroundColor Gray
        Write-Host "  version: $($response.version)" -ForegroundColor Gray
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
            # PowerShell 5.1 compatibility: try alternative property access
            try {
                $statusCode = $_.Exception.Response.StatusCode
            } catch {
                # Status code not available
            }
        }
    }
    
    if ($statusCode -eq 404) {
        Write-Host "FAIL: 404 Not Found - Endpoint does not exist: $pazarWorldStatusUrl" -ForegroundColor Red
        Write-Host "  Expected: GET $pazarWorldStatusUrl" -ForegroundColor Yellow
        Write-Host "  Check: Laravel routes/api.php should have Route::get('/world/status', ...)" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Marketplace /api/world/status request failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  URL: $pazarWorldStatusUrl" -ForegroundColor Yellow
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

Write-Host ""

# Test 2: Core GET /v1/worlds
Write-Host "[2] Testing Core GET /v1/worlds..." -ForegroundColor Yellow
$hosWorldsUrl = "http://localhost:3000/v1/worlds"
try {
    $response = Invoke-RestMethod -Uri $hosWorldsUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
    
    # Validate response format (SPEC §24.4)
    if (-not ($response -is [Array])) {
        Write-Host "FAIL: Expected array response, got $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $worldKeys = $response | ForEach-Object { $_.world_key }
        $hasCore = $worldKeys -contains "core"
        $hasMarketplace = $worldKeys -contains "marketplace"
        
        if (-not $hasCore) {
            Write-Host "FAIL: Response array missing 'core' world" -ForegroundColor Red
            $hasFailures = $true
        } elseif (-not $hasMarketplace) {
            Write-Host "FAIL: Response array missing 'marketplace' world" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Core /v1/worlds returns valid array with core and marketplace" -ForegroundColor Green
            foreach ($world in $response) {
                Write-Host "  - $($world.world_key): $($world.availability) ($($world.phase), v$($world.version))" -ForegroundColor Gray
            }
        }
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
            try {
                $statusCode = $_.Exception.Response.StatusCode
            } catch {
            }
        }
    }
    
    if ($statusCode -eq 404) {
        Write-Host "FAIL: 404 Not Found - Endpoint does not exist: $hosWorldsUrl" -ForegroundColor Red
        Write-Host "  Expected: GET $hosWorldsUrl" -ForegroundColor Yellow
        Write-Host "  Check: HOS API app.js should have app.get('/worlds', ...) registered with /v1 prefix" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Core /v1/worlds request failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  URL: $hosWorldsUrl" -ForegroundColor Yellow
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

Write-Host ""

# Test 3: Catalog Spine GET /api/v1/categories (WP-2)
Write-Host "[3] Testing Catalog GET /api/v1/categories..." -ForegroundColor Yellow
$pazarCategoriesUrl = "http://localhost:8080/api/v1/categories"
try {
    $response = Invoke-RestMethod -Uri $pazarCategoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "Response: $($response | ConvertTo-Json -Depth 5 -Compress)" -ForegroundColor Gray
    
    # Validate response format (tree structure)
    if (-not ($response -is [Array])) {
        Write-Host "FAIL: Expected array response, got $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    } else {
        # Check if we have at least one category (tree should have service > events > wedding-hall)
        if ($response.Count -eq 0) {
            Write-Host "WARN: Categories tree is empty (may need to run seeder)" -ForegroundColor Yellow
        } else {
            Write-Host "PASS: Catalog /v1/categories returns valid tree structure" -ForegroundColor Green
            Write-Host "  Categories in tree: $($response.Count)" -ForegroundColor Gray
            
            # Try to find wedding-hall in tree
            function FindInTree($tree, $slug) {
                foreach ($item in $tree) {
                    if ($item.slug -eq $slug) {
                        return $item
                    }
                    if ($item.children) {
                        $found = FindInTree $item.children $slug
                        if ($found) { return $found }
                    }
                }
                return $null
            }
            
            $weddingHall = FindInTree $response "wedding-hall"
            if ($weddingHall) {
                Write-Host "  Found wedding-hall category in tree" -ForegroundColor Gray
            } else {
                Write-Host "  WARN: wedding-hall category not found (may need to run seeder)" -ForegroundColor Yellow
            }
        }
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
            try {
                $statusCode = $_.Exception.Response.StatusCode
            } catch {
            }
        }
    }
    
    if ($statusCode -eq 404) {
        Write-Host "FAIL: 404 Not Found - Endpoint does not exist: $pazarCategoriesUrl" -ForegroundColor Red
        Write-Host "  Expected: GET $pazarCategoriesUrl" -ForegroundColor Yellow
        Write-Host "  Check: Laravel routes/api.php should have Route::get('/v1/categories', ...)" -ForegroundColor Yellow
        Write-Host "  Note: Empty array [] is acceptable if no categories seeded yet" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Catalog /api/v1/categories request failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  URL: $pazarCategoriesUrl" -ForegroundColor Yellow
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== SMOKE TEST: FAIL ===" -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== SMOKE TEST: PASS ===" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

