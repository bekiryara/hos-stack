#!/usr/bin/env pwsh
# LISTING CONTRACT CHECK (WP-3)
# Verifies Supply Spine API endpoints with schema validation.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== LISTING CONTRACT CHECK (WP-3) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# WP-30: Bootstrap auth token if missing
$authLibPath = Join-Path $scriptDir "_lib\test_auth.ps1"
if (Test-Path $authLibPath) {
    . $authLibPath
}

$authToken = $env:PRODUCT_TEST_AUTH
if (-not $authToken -or $authToken -notmatch '^Bearer\s+.+\..+\..+$') {
    Write-Host "[INFO] PRODUCT_TEST_AUTH not set, bootstrapping token..." -ForegroundColor Yellow
    try {
        $rawToken = Get-DevTestJwtToken
        $authToken = "Bearer $rawToken"
        $env:PRODUCT_TEST_AUTH = $authToken
        Write-Host "  PASS: Token bootstrapped successfully" -ForegroundColor Green
    } catch {
        Write-Host "FAIL: PRODUCT_TEST_AUTH not set and bootstrap failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Remediation: Ensure H-OS service is running and accessible" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[INFO] Using existing PRODUCT_TEST_AUTH token" -ForegroundColor Gray
}

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$tenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic UUID for tenant-demo (WP-8: store-scope requires UUID format)
$listingId = $null
$weddingHallId = $null

# Test 1: GET /api/v1/categories (must be non-empty)
Write-Host "[1] Testing GET /api/v1/categories..." -ForegroundColor Yellow
$categoriesUrl = "${pazarBaseUrl}/api/v1/categories"
try {
    $categoriesResponse = Invoke-RestMethod -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if (-not ($categoriesResponse -is [Array]) -or $categoriesResponse.Count -eq 0) {
        Write-Host "FAIL: Categories endpoint returned empty or invalid response" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Categories endpoint returns non-empty array" -ForegroundColor Green
        Write-Host "  Root categories: $($categoriesResponse.Count)" -ForegroundColor Gray
        
        # Find wedding-hall category ID (id: 5)
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
        $weddingHallId = FindCategoryInTree $categoriesResponse "wedding-hall"
        
        if ($weddingHallId) {
            Write-Host "  Found 'wedding-hall' category with ID: $weddingHallId" -ForegroundColor Green
        } else {
            Write-Host "FAIL: 'wedding-hall' category not found" -ForegroundColor Red
            $hasFailures = $true
        }
    }
} catch {
    Write-Host "FAIL: Categories request failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Test 2: POST /api/v1/listings (create DRAFT listing) - WP-30: Requires Authorization + X-Active-Tenant-Id
if (-not $weddingHallId) {
    Write-Host "[2] SKIP: Cannot test create listing (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[2] Testing POST /api/v1/listings (create DRAFT)..." -ForegroundColor Yellow
    $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
    $listingBody = @{
        category_id = $weddingHallId
        title = "Test Wedding Hall Listing"
        description = "A test wedding hall listing for WP-3"
        transaction_modes = @("reservation")
        attributes = @{
            capacity_max = 500
        }
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            "X-Active-Tenant-Id" = $tenantId
        }
        $createResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $createResponse.id) {
        Write-Host "FAIL: Create listing response missing 'id'" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($createResponse.status -ne "draft") {
        Write-Host "FAIL: Expected status='draft', got '$($createResponse.status)'" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $createResponse.tenant_id) {
        Write-Host "FAIL: Create listing response missing 'tenant_id'" -ForegroundColor Red
        $hasFailures = $true
    } else {
        # Note: tenant_id is UUID format (database requirement), not the original header value
        # The important check is that tenant_id is set and matches on publish
        $listingId = $createResponse.id
        Write-Host "PASS: Listing created successfully" -ForegroundColor Green
        Write-Host "  Listing ID: $listingId" -ForegroundColor Gray
        Write-Host "  Status: $($createResponse.status)" -ForegroundColor Gray
        Write-Host "  Category ID: $($createResponse.category_id)" -ForegroundColor Gray
    }
    } catch {
        $statusCode = $null
        $responseBody = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                # Read response body for 422 errors
                if ($statusCode -eq 422) {
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                }
            } catch {
            }
        }
        Write-Host "FAIL: Create listing request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
            if ($responseBody) {
                Write-Host "  422 body: $responseBody" -ForegroundColor Yellow
            }
        }
        $hasFailures = $true
    }
}

Write-Host ""

# Test 3: POST /api/v1/listings/{id}/publish - WP-30: Requires Authorization + X-Active-Tenant-Id
if ($listingId) {
    Write-Host "[3] Testing POST /api/v1/listings/$listingId/publish..." -ForegroundColor Yellow
    $publishUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}/publish"
    try {
        $headers = @{
            "Authorization" = $authToken
            "X-Active-Tenant-Id" = $tenantId
        }
        $publishResponse = Invoke-RestMethod -Uri $publishUrl -Method Post -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        if ($publishResponse.status -ne "published") {
            Write-Host "FAIL: Expected status='published', got '$($publishResponse.status)'" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Listing published successfully" -ForegroundColor Green
            Write-Host "  Status: $($publishResponse.status)" -ForegroundColor Gray
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Publish listing request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[3] SKIP: Cannot test publish (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 4: GET /api/v1/listings/{id}
if ($listingId) {
    Write-Host "[4] Testing GET /api/v1/listings/$listingId..." -ForegroundColor Yellow
    $getListingUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}"
    try {
        $getResponse = Invoke-RestMethod -Uri $getListingUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        if ($getResponse.status -ne "published") {
            Write-Host "FAIL: Expected status='published', got '$($getResponse.status)'" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($getResponse.id -ne $listingId) {
            Write-Host "FAIL: Mismatched listing ID" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Get listing returns correct data" -ForegroundColor Green
            Write-Host "  Status: $($getResponse.status)" -ForegroundColor Gray
            Write-Host "  Attributes: $($getResponse.attributes | ConvertTo-Json -Compress)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "FAIL: Get listing request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
} else {
    Write-Host "[4] SKIP: Cannot test get listing (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 5: GET /api/v1/listings?category_id={weddingHallId}
if (-not $weddingHallId) {
    Write-Host "[5] SKIP: Cannot test search listings (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[5] Testing GET /api/v1/listings?category_id=$weddingHallId..." -ForegroundColor Yellow
    $searchUrl = "${pazarBaseUrl}/api/v1/listings?category_id=$weddingHallId"
    try {
        $searchResponse = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if (-not ($searchResponse -is [Array])) {
        Write-Host "FAIL: Search listings returned non-array response" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($listingId -and -not ($searchResponse | Where-Object { $_.id -eq $listingId })) {
        Write-Host "FAIL: Created listing not found in search results" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Search listings returns results" -ForegroundColor Green
        Write-Host "  Results count: $($searchResponse.Count)" -ForegroundColor Gray
        if ($listingId) {
            $found = $searchResponse | Where-Object { $_.id -eq $listingId }
            if ($found) {
                Write-Host "  Created listing found in results" -ForegroundColor Gray
            }
        }
    }
    } catch {
        Write-Host "FAIL: Search listings request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 6: Negative - POST /api/v1/listings without Authorization header (WP-30: expect 401)
if (-not $weddingHallId) {
    Write-Host "[6] SKIP: Cannot test negative case (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[6] Testing POST /api/v1/listings without Authorization header (negative test - expect 401)..." -ForegroundColor Yellow
    $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
    $listingBody = @{
        category_id = $weddingHallId
        title = "Test Without Auth"
        transaction_modes = @("reservation")
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "X-Active-Tenant-Id" = $tenantId
        }
        $negativeResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        Write-Host "FAIL: Request without Authorization should have failed, but succeeded" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        $responseBody = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
            } catch {
            }
        }
        if ($statusCode -eq 401) {
            Write-Host "PASS: Request without Authorization correctly rejected (status: 401)" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Expected 401, got status: $statusCode" -ForegroundColor Red
            if ($responseBody) {
                Write-Host "  Response: $($responseBody.Substring(0, [Math]::Min(200, $responseBody.Length)))" -ForegroundColor Yellow
            }
            $hasFailures = $true
        }
    }
}

Write-Host ""

# Test 7: Negative - POST /api/v1/listings without X-Active-Tenant-Id header (WP-30: WITH Authorization, expect 400)
if (-not $weddingHallId) {
    Write-Host "[7] SKIP: Cannot test negative case (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[7] Testing POST /api/v1/listings without X-Active-Tenant-Id header (negative test - WITH Authorization, expect 400)..." -ForegroundColor Yellow
    $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
    $listingBody = @{
        category_id = $weddingHallId
        title = "Test Without Tenant Header"
        transaction_modes = @("reservation")
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
        }
        $negativeResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        Write-Host "FAIL: Request without X-Active-Tenant-Id should have failed, but succeeded" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        $responseBody = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
            } catch {
            }
        }
        if ($statusCode -eq 400 -or $statusCode -eq 403) {
            Write-Host "PASS: Request without X-Active-Tenant-Id correctly rejected (status: $statusCode)" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Expected 400/403, got status: $statusCode" -ForegroundColor Red
            if ($responseBody) {
                Write-Host "  Response: $($responseBody.Substring(0, [Math]::Min(200, $responseBody.Length)))" -ForegroundColor Yellow
            }
            $hasFailures = $true
        }
    }
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== LISTING CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    # Always use hard exit (not Invoke-OpsExit) to ensure exit code propagation
    exit 1
} else {
    Write-Host "=== LISTING CONTRACT CHECK: PASS ===" -ForegroundColor Green
    # Always use hard exit (not Invoke-OpsExit) to ensure exit code propagation
    exit 0
}

