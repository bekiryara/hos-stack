#!/usr/bin/env pwsh
# WP-2: Catalog Contract Check Script
# Verifies marketplace catalog spine endpoints (SPEC §6.2)

$ErrorActionPreference = "Stop"

# Load safe exit helper if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== CATALOG CONTRACT CHECK (WP-2) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$weddingHallId = $null

# Test 1: GET /api/v1/categories
Write-Host "[1] Testing GET /api/v1/categories..." -ForegroundColor Yellow
$categoriesUrl = "http://localhost:8080/api/v1/categories"

# Guardrail: Check for 500 errors and "Target class [persona.scope] does not exist" error
Write-Host "  [Guardrail] Checking for middleware registration errors..." -ForegroundColor Gray
try {
    $httpResponse = Invoke-WebRequest -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    $statusCode = $httpResponse.StatusCode
    $responseBody = $httpResponse.Content
    
    # Check for 500 status
    if ($statusCode -eq 500) {
        Write-Host "FAIL: GET /api/v1/categories returns 500 Internal Server Error" -ForegroundColor Red
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        if ($responseBody -match "Target class \[persona\.scope\] does not exist") {
            Write-Host "  ERROR: Middleware alias 'persona.scope' is not registered" -ForegroundColor Red
            Write-Host "  Fix: Ensure 'persona.scope' => PersonaScope::class is in bootstrap/app.php" -ForegroundColor Yellow
        }
        $hasFailures = $true
        # Don't continue with JSON parsing if 500
        throw "HTTP 500 error detected"
    }
    
    # Parse JSON response
    $response = $responseBody | ConvertFrom-Json
} catch {
    # If it's our guardrail throw, re-throw
    if ($_.Exception.Message -eq "HTTP 500 error detected") {
        throw
    }
    
    # Check for 500 errors in exception
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
    
    if ($statusCode -eq 500) {
        Write-Host "FAIL: GET /api/v1/categories returns 500 Internal Server Error" -ForegroundColor Red
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        Write-Host "  This may indicate middleware registration issues (e.g., 'persona.scope' alias not found)" -ForegroundColor Yellow
        $hasFailures = $true
        throw "HTTP 500 error detected"
    }
    
    # Otherwise try Invoke-RestMethod for JSON parsing
    try {
        $response = Invoke-RestMethod -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "Response: $($response | ConvertTo-Json -Depth 3 -Compress)" -ForegroundColor Gray

    # Validate response format
    if (-not ($response -is [Array])) {
        Write-Host "FAIL: Expected array response, got $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($response.Count -eq 0) {
        Write-Host "FAIL: Categories tree is empty (run seeder?)" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Categories endpoint returns non-empty tree" -ForegroundColor Green
        Write-Host "  Root categories: $($response.Count)" -ForegroundColor Gray
        
        # Find wedding-hall category ID for next test
        function FindCategoryInTree($tree, $slug) {
            foreach ($item in $tree) {
                if ($item.slug -eq $slug) {
                    return $item
                }
                if ($item.children) {
                    $found = FindCategoryInTree $item.children $slug
                    if ($found) { return $found }
                }
            }
            return $null
        }
        
        $weddingHall = FindCategoryInTree $response "wedding-hall"
        if ($weddingHall) {
            $weddingHallId = $weddingHall.id
            Write-Host "  Found wedding-hall category (id: $weddingHallId)" -ForegroundColor Gray
        } else {
            Write-Host "  WARN: wedding-hall category not found in tree" -ForegroundColor Yellow
        }
        
        # Check for required roots (must be exactly: vehicle, real-estate, service)
        $rootSlugs = $response | ForEach-Object { $_.slug }
        $hasVehicle = $rootSlugs -contains "vehicle"
        $hasRealEstate = $rootSlugs -contains "real-estate"
        $hasService = $rootSlugs -contains "service"
        
        # Fail if not exactly these three root categories
        if (-not ($hasVehicle -and $hasRealEstate -and $hasService)) {
            Write-Host "FAIL: Missing required root categories" -ForegroundColor Red
            Write-Host "  Required: vehicle, real-estate, service" -ForegroundColor Yellow
            Write-Host "  Found: $($rootSlugs -join ', ')" -ForegroundColor Yellow
            Write-Host "  Missing: vehicle=$hasVehicle, real-estate=$hasRealEstate, service=$hasService" -ForegroundColor Yellow
            $hasFailures = $true
        } elseif ($response.Count -ne 3) {
            Write-Host "FAIL: Expected exactly 3 root categories, got $($response.Count)" -ForegroundColor Red
            Write-Host "  Found: $($rootSlugs -join ', ')" -ForegroundColor Yellow
            $hasFailures = $true
        } else {
            Write-Host "  PASS: All required root categories present (vehicle, real-estate, service)" -ForegroundColor Green
        }
        
        # WP-17: Regression check - call endpoint twice to prevent redeclare fatal
        Write-Host "  WP-17: Testing double-call to prevent redeclare fatal..." -ForegroundColor Gray
        try {
            $response2 = Invoke-RestMethod -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
            if (-not ($response2 -is [Array])) {
                Write-Host "  FAIL: Second call returned non-array response (fatal redeclare risk)" -ForegroundColor Red
                $hasFailures = $true
            } elseif ($response2.Count -ne $response.Count) {
                Write-Host "  FAIL: Second call returned different category count ($($response.Count) vs $($response2.Count))" -ForegroundColor Red
                $hasFailures = $true
            } else {
                Write-Host "  PASS: Second call succeeded (no redeclare fatal)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  FAIL: Second call failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    This indicates a redeclare fatal risk (WP-17)" -ForegroundColor Yellow
            $hasFailures = $true
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
        Write-Host "FAIL: 404 Not Found - Endpoint does not exist: $categoriesUrl" -ForegroundColor Red
        Write-Host "  Expected: GET $categoriesUrl" -ForegroundColor Yellow
        Write-Host "  Check: Laravel routes/api.php should have Route::get('/v1/categories', ...)" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Categories request failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  URL: $categoriesUrl" -ForegroundColor Yellow
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

Write-Host ""

# Test 2: GET /api/v1/categories/{id}/filter-schema
if ($weddingHallId) {
    Write-Host "[2] Testing GET /api/v1/categories/$weddingHallId/filter-schema..." -ForegroundColor Yellow
    $filterSchemaUrl = "http://localhost:8080/api/v1/categories/$weddingHallId/filter-schema"
    try {
        $response = Invoke-RestMethod -Uri $filterSchemaUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Host "Response: $($response | ConvertTo-Json -Depth 3 -Compress)" -ForegroundColor Gray

        # Validate response format
        if (-not $response.category_id) {
            Write-Host "FAIL: Missing 'category_id' in response" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($null -eq $response.filters) {
            Write-Host "FAIL: Missing 'filters' array in response" -ForegroundColor Red
            $hasFailures = $true
        } elseif (-not ($response.filters -is [Array])) {
            Write-Host "FAIL: 'filters' should be an array, got $($response.filters.GetType().Name)" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Filter schema endpoint returns valid response" -ForegroundColor Green
            Write-Host "  Category ID: $($response.category_id)" -ForegroundColor Gray
            Write-Host "  Category Slug: $($response.category_slug)" -ForegroundColor Gray
            Write-Host "  Active filters: $($response.filters.Count)" -ForegroundColor Gray
            
            # If wedding-hall exists, check for capacity_max filter with required=true
            if ($weddingHallId -and $response.category_id -eq $weddingHallId) {
                $capacityMaxFilter = $response.filters | Where-Object { $_.attribute_key -eq "capacity_max" }
                if (-not $capacityMaxFilter) {
                    Write-Host "FAIL: wedding-hall category missing 'capacity_max' filter in schema" -ForegroundColor Red
                    $hasFailures = $true
                } elseif ($capacityMaxFilter.required -ne $true) {
                    Write-Host "FAIL: wedding-hall capacity_max filter must have required=true, got required=$($capacityMaxFilter.required)" -ForegroundColor Red
                    $hasFailures = $true
                } else {
                    Write-Host "  PASS: wedding-hall has capacity_max filter with required=true" -ForegroundColor Green
                }
            }
            
            if ($response.filters.Count -gt 0) {
                Write-Host "  Filter attributes:" -ForegroundColor Gray
                foreach ($filter in $response.filters) {
                    Write-Host "    - $($filter.attribute_key) ($($filter.value_type), required: $($filter.required))" -ForegroundColor Gray
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
            Write-Host "FAIL: 404 Not Found - Endpoint or category does not exist: $filterSchemaUrl" -ForegroundColor Red
            Write-Host "  Expected: GET $filterSchemaUrl" -ForegroundColor Yellow
            Write-Host "  Check: Laravel routes/api.php should have Route::get('/v1/categories/{id}/filter-schema', ...)" -ForegroundColor Yellow
        } else {
            Write-Host "FAIL: Filter schema request failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  URL: $filterSchemaUrl" -ForegroundColor Yellow
            if ($statusCode) {
                Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
            }
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[2] SKIP: Cannot test filter-schema endpoint (wedding-hall category ID not found)" -ForegroundColor Yellow
    Write-Host "  Run seeder to populate categories: docker compose exec pazar-app php artisan db:seed --class=CatalogSpineSeeder" -ForegroundColor Gray
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== CATALOG CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    # Always use hard exit (not Invoke-OpsExit) to ensure exit code propagation
    exit 1
} else {
    Write-Host "=== CATALOG CONTRACT CHECK: PASS ===" -ForegroundColor Green
    # Always use hard exit (not Invoke-OpsExit) to ensure exit code propagation
    exit 0
}



