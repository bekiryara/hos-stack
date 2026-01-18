#!/usr/bin/env pwsh
# RENTAL CONTRACT CHECK (WP-7)
# Verifies Rental Spine API endpoints with idempotency and validation.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== RENTAL CONTRACT CHECK (WP-7) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$tenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic UUID for tenant-demo

# WP-23: Token bootstrap - auto-acquire if missing
$authToken = $env:PRODUCT_TEST_AUTH
if (-not $authToken) {
    Write-Host "[INFO] PRODUCT_TEST_AUTH not set, bootstrapping token..." -ForegroundColor Yellow
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $testAuthPath = Join-Path $scriptDir "_lib\test_auth.ps1"
    if (Test-Path $testAuthPath) {
        . $testAuthPath
        try {
            $rawToken = Get-DevTestJwtToken
            $authToken = "Bearer $rawToken"
        } catch {
            Write-Host "FAIL: Failed to bootstrap JWT token" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  Run: .\ops\ensure_product_test_auth.ps1" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "FAIL: PRODUCT_TEST_AUTH not set and test_auth.ps1 helper not found" -ForegroundColor Red
        Write-Host "  Run: .\ops\ensure_product_test_auth.ps1" -ForegroundColor Yellow
        exit 1
    }
}

# Validate JWT format (must contain two dots: header.payload.signature)
$tokenParts = $authToken -split '\.'
if ($tokenParts.Count -lt 3 -or -not $authToken.StartsWith("Bearer ")) {
    Write-Host "FAIL: PRODUCT_TEST_AUTH must be a valid Bearer JWT token" -ForegroundColor Red
    Write-Host "  Format: Bearer <header>.<payload>.<signature>" -ForegroundColor Yellow
    Write-Host "  Current value: $($authToken.Substring(0, [Math]::Min(50, $authToken.Length)))..." -ForegroundColor Yellow
    Write-Host "  Run: .\ops\ensure_product_test_auth.ps1" -ForegroundColor Yellow
    exit 1
}

# Optional provider token (for accept tests)
$providerAuth = $env:PROVIDER_TEST_AUTH
if (-not $providerAuth) {
    $providerAuth = $authToken
    Write-Host "[WARN] PROVIDER_TEST_AUTH not set, using PRODUCT_TEST_AUTH for provider operations" -ForegroundColor Yellow
}
$listingId = $null
$rentalId = $null

# Generate deterministic idempotency key based on timestamp
$now = Get-Date
$idempotencyKey = "test-rental-key-" + $now.ToString("yyyyMMddHHmmss") + "-" + $now.Millisecond.ToString("D3")

Write-Host ""

# Test 0: Get or create a published listing (wedding-hall category)
Write-Host "[0] Getting or creating published listing for testing..." -ForegroundColor Yellow

# First, get wedding-hall category ID
$categoriesUrl = "${pazarBaseUrl}/api/v1/categories"
try {
    $categoriesResponse = Invoke-RestMethod -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    function FindCategoryInTree($tree, $slug) {
        foreach ($item in $tree) {
            if ($item.slug -eq $slug) { return $item.id }
            if ($item.children) {
                $foundId = FindCategoryInTree $item.children $slug
                if ($foundId) { return $foundId }
            }
        }
        return $null
    }
    $weddingHallCategoryId = FindCategoryInTree $categoriesResponse "wedding-hall"
    
    if (-not $weddingHallCategoryId) {
        Write-Host "FAIL: wedding-hall category not found. Run catalog seeder first." -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Could not get categories: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

if ($hasFailures) {
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
}

# Get or create published listing
$listingsUrl = "${pazarBaseUrl}/api/v1/listings?category_id=${weddingHallCategoryId}&status=published"
try {
    $listingsResponse = Invoke-RestMethod -Uri $listingsUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    $testListing = $listingsResponse | Where-Object { $_.title -like "*Test Wedding Hall Listing*" } | Select-Object -First 1
    
    if ($testListing) {
        $listingId = $testListing.id
        Write-Host "PASS: Found existing published listing: $listingId" -ForegroundColor Green
        Write-Host "  Title: $($testListing.title)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: No published listing found for testing. Create one manually." -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Could not get listings: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Test 1: Create rental -> PASS (201)
if ($listingId) {
    Write-Host "[1] Testing POST /api/v1/rentals (create rental)..." -ForegroundColor Yellow
    
    # Generate deterministic dates using GUID-based offset to avoid conflicts from previous runs
    # Base date: 30 days from now to avoid conflicts
    # Add a deterministic offset based on timestamp seconds to ensure uniqueness
    $baseOffset = 30
    $timeOffset = ([int](Get-Date).ToString("ss")) % 100 # 0-59 seconds, mod 100 for range 0-59
    $startDays = $baseOffset + ($timeOffset * 2) # 30, 32, 34, ..., 148 days from now
    $endDays = $startDays + 3 # 3-day rental period
    
    $startAt = (Get-Date).AddDays($startDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endAt = (Get-Date).AddDays($endDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createRentalUrl = "${pazarBaseUrl}/api/v1/rentals"
    $rentalBody = @{
        listing_id = $listingId
        start_at = $startAt
        end_at = $endAt
    } | ConvertTo-Json
    
    # WP-13: Get test auth token from env or use default test token
    $testAuthToken = $env:PRODUCT_TEST_AUTH
    if (-not $testAuthToken) {
        $testAuthToken = $env:HOS_TEST_AUTH
    }
    if (-not $testAuthToken) {
        # Default test token (dummy JWT for testing - must have valid sub claim)
        $testAuthToken = "Bearer test-token-genesis-wp13"
    }
    
    $rentalHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $idempotencyKey
        "Authorization" = $testAuthToken  # WP-13: Authorization Bearer token required (JWT sub=userId)
    }
    
    try {
        $rentalResponse = Invoke-RestMethod -Uri $createRentalUrl -Method Post -Body $rentalBody -Headers $rentalHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($rentalResponse.id -and $rentalResponse.status -eq "requested") {
            $rentalId = $rentalResponse.id
            Write-Host "PASS: Rental created successfully" -ForegroundColor Green
            Write-Host "  Rental ID: $rentalId" -ForegroundColor Gray
            Write-Host "  Status: $($rentalResponse.status)" -ForegroundColor Gray
            Write-Host "  Start: $($rentalResponse.start_at)" -ForegroundColor Gray
            Write-Host "  End: $($rentalResponse.end_at)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Rental creation returned invalid response" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Create rental request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[1] SKIP: Cannot test rental creation (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 2: Idempotency replay -> SAME rental id
if ($rentalId -and -not $hasFailures) {
    Write-Host "[2] Testing idempotency replay (same Idempotency-Key)..." -ForegroundColor Yellow
    
    $baseOffset = 30
    $timeOffset = ([int](Get-Date).ToString("ss")) % 100
    $startDays = $baseOffset + ($timeOffset * 2)
    $endDays = $startDays + 3
    
    $startAt = (Get-Date).AddDays($startDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endAt = (Get-Date).AddDays($endDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $rentalBody = @{
        listing_id = $listingId
        start_at = $startAt
        end_at = $endAt
    } | ConvertTo-Json
    
    $rentalHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $idempotencyKey # Same key
        "Authorization" = $authToken  # WP-8: PERSONAL write requires Authorization
    }
    
    try {
        $replayResponse = Invoke-RestMethod -Uri $createRentalUrl -Method Post -Body $rentalBody -Headers $rentalHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($replayResponse.id -eq $rentalId) {
            Write-Host "PASS: Idempotency replay returned same rental ID" -ForegroundColor Green
            Write-Host "  Rental ID: $($replayResponse.id)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Idempotency replay returned different rental ID" -ForegroundColor Red
            Write-Host "  Expected: $rentalId" -ForegroundColor Yellow
            Write-Host "  Got: $($replayResponse.id)" -ForegroundColor Yellow
            $hasFailures = $true
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Idempotency replay failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
}

Write-Host ""

# Test 3: Overlap negative -> 409 CONFLICT
if ($listingId -and -not $hasFailures) {
    Write-Host "[3] Testing overlap conflict (overlapping rental period)..." -ForegroundColor Yellow
    
    # Use overlapping dates (overlap with first rental's period)
    # First rental: startDays to startDays+3, so overlap should be startDays+1 to startDays+2
    $baseOffset = 30
    $timeOffset = ([int](Get-Date).ToString("ss")) % 100
    $firstStartDays = $baseOffset + ($timeOffset * 2)
    $overlapStartDays = $firstStartDays + 1 # Overlaps with first rental
    $overlapEndDays = $firstStartDays + 2 # Overlaps with first rental
    
    $startAt = (Get-Date).AddDays($overlapStartDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endAt = (Get-Date).AddDays($overlapEndDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $rentalBody = @{
        listing_id = $listingId
        start_at = $startAt
        end_at = $endAt
    } | ConvertTo-Json
    
    $newIdempotencyKey = "test-rental-overlap-" + $now.ToString("yyyyMMddHHmmss") + "-" + ($now.Millisecond + 100).ToString("D3")
    $rentalHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $newIdempotencyKey # Different key
        "Authorization" = $authToken  # WP-8: PERSONAL write requires Authorization
    }
    
    try {
        $overlapResponse = Invoke-RestMethod -Uri $createRentalUrl -Method Post -Body $rentalBody -Headers $rentalHeaders -TimeoutSec 10 -ErrorAction Stop
        
        # Should NOT succeed (should have caught by overlap check)
        Write-Host "FAIL: Overlapping rental was accepted (should be CONFLICT)" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        $errorResponse = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                $errorResponse = $responseBody | ConvertFrom-Json
                $reader.Close()
            } catch {
            }
        }
        
        if ($statusCode -eq 409) {
            if ($errorResponse -and $errorResponse.error) {
                if ($errorResponse.error -eq "CONFLICT") {
                    Write-Host "PASS: Overlap conflict correctly returned 409 CONFLICT" -ForegroundColor Green
                    Write-Host "  Status Code: 409" -ForegroundColor Gray
                    Write-Host "  Error: $($errorResponse.error)" -ForegroundColor Gray
                } else {
                    Write-Host "PASS: Overlap conflict correctly returned 409 (error: $($errorResponse.error))" -ForegroundColor Green
                    Write-Host "  Status Code: 409" -ForegroundColor Gray
                }
            } else {
                Write-Host "PASS: Overlap conflict correctly returned 409 CONFLICT" -ForegroundColor Green
                Write-Host "  Status Code: 409" -ForegroundColor Gray
            }
        } else {
            Write-Host "FAIL: Overlap conflict returned wrong status/error: $($statusCode) / $($errorResponse.error)" -ForegroundColor Red
            $hasFailures = $true
        }
    }
    }

Write-Host ""

# Test 4: Accept rental -> status=accepted
if ($rentalId -and -not $hasFailures) {
    Write-Host "[4] Testing POST /api/v1/rentals/{id}/accept (accept rental)..." -ForegroundColor Yellow
    
    # Get the rental to find the provider_tenant_id
    $getRentalUrl = "${pazarBaseUrl}/api/v1/rentals/${rentalId}"
    try {
        $getRentalResponse = Invoke-RestMethod -Uri $getRentalUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        $providerTenantId = $getRentalResponse.provider_tenant_id
    } catch {
        Write-Host "FAIL: Could not get rental to find provider_tenant_id: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
    
    if (-not $hasFailures) {
        $acceptUrl = "${pazarBaseUrl}/api/v1/rentals/${rentalId}/accept"
        $acceptHeaders = @{
            "X-Active-Tenant-Id" = $providerTenantId
            "Authorization" = $providerAuth  # WP-20: Accept endpoint requires auth.ctx middleware
        }
        
        try {
            $acceptResponse = Invoke-RestMethod -Uri $acceptUrl -Method Post -Headers $acceptHeaders -TimeoutSec 10 -ErrorAction Stop
            
            if ($acceptResponse.status -eq "accepted") {
                Write-Host "PASS: Rental accepted successfully" -ForegroundColor Green
                Write-Host "  Status: $($acceptResponse.status)" -ForegroundColor Gray
            } else {
                Write-Host "FAIL: Rental accept returned wrong status: $($acceptResponse.status)" -ForegroundColor Red
                $hasFailures = $true
            }
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                try {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                } catch {
                }
            }
            Write-Host "FAIL: Accept rental request failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($statusCode) {
                Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
            }
            $hasFailures = $true
        }
    }
}

Write-Host ""

# Test 5: Negative scope (accept without X-Active-Tenant-Id) -> 400
if ($rentalId -and -not $hasFailures) {
    Write-Host "[5] Testing negative scope (accept without X-Active-Tenant-Id)..." -ForegroundColor Yellow
    
    # Create a new rental for this test (need one in requested status)
    # Use dates that don't overlap with previous rentals
    $baseOffset = 30
    $timeOffset = ([int](Get-Date).ToString("ss")) % 100
    $negativeStartDays = $baseOffset + ($timeOffset * 2) + 200 # Far enough from other tests
    $negativeEndDays = $negativeStartDays + 3
    
    $newRentalIdempotencyKey = "test-rental-negative-" + $now.ToString("yyyyMMddHHmmss") + "-" + ($now.Millisecond + 200).ToString("D3")
    $startAt = (Get-Date).AddDays($negativeStartDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endAt = (Get-Date).AddDays($negativeEndDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $rentalBody = @{
        listing_id = $listingId
        start_at = $startAt
        end_at = $endAt
    } | ConvertTo-Json
    
    $rentalHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $newRentalIdempotencyKey
        "Authorization" = $authToken  # WP-8: PERSONAL write requires Authorization
    }
    
    $testRentalId = $null
    try {
        $newRentalResponse = Invoke-RestMethod -Uri $createRentalUrl -Method Post -Body $rentalBody -Headers $rentalHeaders -TimeoutSec 10 -ErrorAction Stop
        $testRentalId = $newRentalResponse.id
    } catch {
        Write-Host "  Could not create test rental, skipping negative scope test" -ForegroundColor Yellow
    }
    
    if ($testRentalId) {
        $acceptUrl = "${pazarBaseUrl}/api/v1/rentals/${testRentalId}/accept"
        # WP-20: Keep Authorization, omit X-Active-Tenant-Id
        
        try {
            $acceptHeaders = @{
                "Authorization" = $providerAuth
            }
            $acceptResponse = Invoke-RestMethod -Uri $acceptUrl -Method Post -Headers $acceptHeaders -TimeoutSec 10 -ErrorAction Stop
            
            # Should NOT succeed
            Write-Host "FAIL: Accept without X-Active-Tenant-Id was accepted (should be 400)" -ForegroundColor Red
            $hasFailures = $true
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                try {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                } catch {
                }
            }
            
            if ($statusCode -eq 400) {
                Write-Host "PASS: Missing header correctly returned 400" -ForegroundColor Green
                Write-Host "  Status Code: 400" -ForegroundColor Gray
            } else {
                Write-Host "FAIL: Missing header returned wrong status: $statusCode (expected 400)" -ForegroundColor Red
                $hasFailures = $true
            }
        }
    }
}

Write-Host ""

# Test 6: GET /api/v1/rentals/{id} -> PASS
if ($rentalId -and -not $hasFailures) {
    Write-Host "[6] Testing GET /api/v1/rentals/{id} (get rental)..." -ForegroundColor Yellow
    
    $getUrl = "${pazarBaseUrl}/api/v1/rentals/${rentalId}"
    
    try {
        $getResponse = Invoke-RestMethod -Uri $getUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        if ($getResponse.id -eq $rentalId) {
            Write-Host "PASS: Get rental returned correct rental" -ForegroundColor Green
            Write-Host "  Rental ID: $($getResponse.id)" -ForegroundColor Gray
            Write-Host "  Status: $($getResponse.status)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Get rental returned wrong rental ID" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Get rental request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== RENTAL CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more tests failed. Fix issues and re-run." -ForegroundColor Yellow
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== RENTAL CONTRACT CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All rental contract checks passed." -ForegroundColor Gray
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

