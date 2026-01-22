#!/usr/bin/env pwsh
# SEARCH CONTRACT CHECK (WP-8)
# Verifies Search & Discovery Thin Slice endpoints with filters and availability.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== SEARCH CONTRACT CHECK (WP-8) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$weddingHallId = $null

# Helper function to find category ID in tree
function FindCategoryInTree($tree, $slug) {
    foreach ($item in $tree) {
        if ($item.slug -eq $slug) {
            return $item.id
        }
        if ($item.children) {
            $foundId = FindCategoryInTree $item.children $slug
            if ($foundId) { return $foundId }
        }
    }
    return $null
}

# Get wedding-hall category ID
Write-Host "[0] Getting wedding-hall category ID..." -ForegroundColor Yellow
$categoriesUrl = "${pazarBaseUrl}/api/v1/categories"
try {
    $categoriesResponse = Invoke-RestMethod -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    $weddingHallId = FindCategoryInTree $categoriesResponse "wedding-hall"
    
    if (-not $weddingHallId) {
        Write-Host "FAIL: wedding-hall category not found" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Found wedding-hall category ID: $weddingHallId" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Could not get categories: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Test 1: Basic category search PASS
if ($weddingHallId -and -not $hasFailures) {
    Write-Host "[1] Testing GET /api/v1/search?category_id=$weddingHallId (basic category search)..." -ForegroundColor Yellow
    $searchUrl = "${pazarBaseUrl}/api/v1/search?category_id=$weddingHallId"
    
    try {
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        # Validate response format (should have data and meta)
        if (-not $response.data) {
            Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
            $hasFailures = $true
        } elseif (-not $response.meta) {
            Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
            $hasFailures = $true
        } elseif (-not ($response.data -is [Array])) {
            Write-Host "FAIL: Response.data is not an array" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Basic category search returned valid response" -ForegroundColor Green
            Write-Host "  Total listings: $($response.meta.total)" -ForegroundColor Gray
            Write-Host "  Results: $($response.data.Count)" -ForegroundColor Gray
            Write-Host "  Page: $($response.meta.page)" -ForegroundColor Gray
            Write-Host "  Per page: $($response.meta.per_page)" -ForegroundColor Gray
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Basic search request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[1] SKIP: Cannot test basic search (category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 2: Empty result PASS (search for non-existent category or filters)
if ($weddingHallId -and -not $hasFailures) {
    Write-Host "[2] Testing GET /api/v1/search?category_id=$weddingHallId&city=NonExistentCity (empty result)..." -ForegroundColor Yellow
    $searchUrl = "${pazarBaseUrl}/api/v1/search?category_id=$weddingHallId&city=NonExistentCity"
    
    try {
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        # Empty result is VALID - should return empty array with meta
        if (-not $response.PSObject.Properties['data']) {
            Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
            Write-Host "  Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Yellow
            $hasFailures = $true
        } elseif ($response.data.Count -ne 0) {
            Write-Host "FAIL: Expected empty result, got $($response.data.Count) items" -ForegroundColor Red
            $hasFailures = $true
        } elseif (-not $response.meta) {
            Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($response.meta.total -ne 0) {
            Write-Host "FAIL: Expected meta.total=0, got $($response.meta.total)" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Empty result returned correctly (empty array with meta)" -ForegroundColor Green
            Write-Host "  Total: $($response.meta.total)" -ForegroundColor Gray
            Write-Host "  Results: $($response.data.Count)" -ForegroundColor Gray
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Empty result test failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[2] SKIP: Cannot test empty result (category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 3: Invalid filter FAIL (missing category_id)
Write-Host "[3] Testing GET /api/v1/search (missing category_id - should FAIL)..." -ForegroundColor Yellow
$searchUrl = "${pazarBaseUrl}/api/v1/search"

try {
    $response = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "FAIL: Expected VALIDATION_ERROR (422), got 200 OK" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    
    if ($statusCode -eq 422) {
        Write-Host "PASS: Missing category_id returns VALIDATION_ERROR (422)" -ForegroundColor Green
    } elseif ($statusCode) {
        Write-Host "FAIL: Expected VALIDATION_ERROR (422), got $statusCode" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "FAIL: Invalid filter test failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 4: Pagination enforced PASS
if ($weddingHallId -and -not $hasFailures) {
    Write-Host "[4] Testing GET /api/v1/search?category_id=$weddingHallId&page=1&per_page=2 (pagination)..." -ForegroundColor Yellow
    $searchUrl = "${pazarBaseUrl}/api/v1/search?category_id=$weddingHallId&page=1&per_page=2"
    
    try {
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        # Validate pagination
        if (-not $response.meta) {
            Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($response.meta.per_page -ne 2) {
            Write-Host "FAIL: Expected per_page=2, got $($response.meta.per_page)" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($response.meta.page -ne 1) {
            Write-Host "FAIL: Expected page=1, got $($response.meta.page)" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($response.data.Count -gt 2) {
            Write-Host "FAIL: Expected at most 2 items, got $($response.data.Count)" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Pagination enforced correctly" -ForegroundColor Green
            Write-Host "  Page: $($response.meta.page)" -ForegroundColor Gray
            Write-Host "  Per page: $($response.meta.per_page)" -ForegroundColor Gray
            Write-Host "  Total: $($response.meta.total)" -ForegroundColor Gray
            Write-Host "  Results: $($response.data.Count)" -ForegroundColor Gray
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Pagination test failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[4] SKIP: Cannot test pagination (category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 5: Deterministic order PASS (created_at DESC)
if ($weddingHallId -and -not $hasFailures) {
    Write-Host "[5] Testing GET /api/v1/search?category_id=$weddingHallId&per_page=10 (deterministic order)..." -ForegroundColor Yellow
    $searchUrl = "${pazarBaseUrl}/api/v1/search?category_id=$weddingHallId&per_page=10"
    
    try {
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        # Check if results are ordered by created_at DESC
        if ($response.data.Count -ge 2) {
            $firstCreatedAt = [DateTime]::Parse($response.data[0].created_at)
            $secondCreatedAt = [DateTime]::Parse($response.data[1].created_at)
            
            if ($firstCreatedAt -lt $secondCreatedAt) {
                Write-Host "FAIL: Results not ordered by created_at DESC (first: $firstCreatedAt, second: $secondCreatedAt)" -ForegroundColor Red
                $hasFailures = $true
            } else {
                Write-Host "PASS: Results ordered by created_at DESC" -ForegroundColor Green
                Write-Host "  First created_at: $firstCreatedAt" -ForegroundColor Gray
                Write-Host "  Second created_at: $secondCreatedAt" -ForegroundColor Gray
            }
        } else {
            Write-Host "SKIP: Not enough results to verify ordering (need at least 2, got $($response.data.Count))" -ForegroundColor Yellow
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Deterministic order test failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[5] SKIP: Cannot test deterministic order (category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Summary
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
if ($hasFailures) {
    Write-Host "FAIL: Search contract check failed" -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "PASS: All search contract checks passed" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

