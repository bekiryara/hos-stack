#!/usr/bin/env pwsh
# ACCOUNT PORTAL CONTRACT CHECK (WP-9)
# Verifies Account Portal Read Spine endpoints (/me/* and /store/*).

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== ACCOUNT PORTAL CONTRACT CHECK (WP-9) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$tenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic UUID for tenant-demo

# Generate deterministic UUID for test user
function Generate-TestUserId {
    $testString = "test-user-id-wp9"
    $md5Hash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes("tenant-namespace-$testString"))
    $hashHex = [System.BitConverter]::ToString($md5Hash).Replace("-", "").ToLower()
    return "$($hashHex.Substring(0,8))-$($hashHex.Substring(8,4))-$($hashHex.Substring(12,4))-$($hashHex.Substring(16,4))-$($hashHex.Substring(20,12))"
}
$testUserId = Generate-TestUserId

# WP-13: Get test auth token from env or use default test token
$testAuthToken = $env:PRODUCT_TEST_AUTH
if (-not $testAuthToken) {
    $testAuthToken = $env:HOS_TEST_AUTH
}
if (-not $testAuthToken) {
    # Default test token (dummy JWT for testing - must have valid sub claim)
    $testAuthToken = "Bearer test-token-genesis-wp13"
}

Write-Host "Testing Account Portal Read Spine endpoints:" -ForegroundColor Yellow
Write-Host "  Personal scope (/api/v1/me/*):" -ForegroundColor Gray
Write-Host "    1. GET /api/v1/me/orders" -ForegroundColor Gray
Write-Host "    2. GET /api/v1/me/rentals" -ForegroundColor Gray
Write-Host "    3. GET /api/v1/me/reservations" -ForegroundColor Gray
Write-Host "  Store scope (/api/v1/store/*):" -ForegroundColor Gray
Write-Host "    4. GET /api/v1/store/orders" -ForegroundColor Gray
Write-Host "    5. GET /api/v1/store/rentals" -ForegroundColor Gray
Write-Host "    6. GET /api/v1/store/reservations" -ForegroundColor Gray
Write-Host "    7. GET /api/v1/store/listings" -ForegroundColor Gray
Write-Host "  Negative tests:" -ForegroundColor Gray
Write-Host "    8. GET /api/v1/store/orders (without X-Active-Tenant-Id)" -ForegroundColor Gray
Write-Host ""

# Test 0: Ensure test data exists (create order, rental, reservation if needed)
Write-Host "[0] Preparing test data (order, rental, reservation)..." -ForegroundColor Yellow

# Get wedding-hall category ID
$weddingHallId = $null
$categoriesUrl = "${pazarBaseUrl}/api/v1/categories"
try {
    $categoriesResponse = Invoke-RestMethod -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
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
} catch {
    Write-Host "WARN: Could not get categories: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Get or create published listing
$listingId = $null
if ($weddingHallId) {
    try {
        # Try to find existing published listing for this tenant
        $listingsUrl = "${pazarBaseUrl}/api/v1/listings?tenant_id=${tenantId}&status=all"
        $listingsResponse = Invoke-RestMethod -Uri $listingsUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        if ($listingsResponse -is [Array] -and $listingsResponse.Count -gt 0) {
            $listingId = $listingsResponse[0].id
            Write-Host "  Found existing listing: $listingId" -ForegroundColor Gray
        } else {
            # Create new listing
            $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
            $listingBody = @{
                category_id = $weddingHallId
                title = "Test Listing for WP-9"
                description = "Test listing for Account Portal Read Spine"
                transaction_modes = @("sale", "rental", "reservation")
                attributes = @{
                    capacity_max = 500
                }
            } | ConvertTo-Json
            $listingHeaders = @{
                "Content-Type" = "application/json"
                "X-Active-Tenant-Id" = $tenantId
            }
            $createListingResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $listingHeaders -TimeoutSec 10 -ErrorAction Stop
            $listingId = $createListingResponse.id
            
            # Publish listing
            $publishUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}/publish"
            Invoke-RestMethod -Uri $publishUrl -Method Post -Headers $listingHeaders -TimeoutSec 10 -ErrorAction Stop | Out-Null
            Write-Host "  Created and published listing: $listingId" -ForegroundColor Gray
        }
    } catch {
        Write-Host "WARN: Could not get/create listing: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create test order (if listing exists)
$orderId = $null
if ($listingId) {
    try {
        $now = Get-Date
        $idempotencyKey = "test-order-wp9-" + $now.ToString("yyyyMMddHHmmss")
        $createOrderUrl = "${pazarBaseUrl}/api/v1/orders"
        $orderBody = @{
            listing_id = $listingId
            quantity = 1
        } | ConvertTo-Json
        $orderHeaders = @{
            "Content-Type" = "application/json"
            "Idempotency-Key" = $idempotencyKey
            "Authorization" = $testAuthToken
        }
        $createOrderResponse = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $orderBody -Headers $orderHeaders -TimeoutSec 10 -ErrorAction Stop
        $orderId = $createOrderResponse.id
        Write-Host "  Created order: $orderId" -ForegroundColor Gray
    } catch {
        Write-Host "WARN: Could not create order: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create test rental (if listing exists)
$rentalId = $null
if ($listingId) {
    try {
        $now = Get-Date
        $idempotencyKey = "test-rental-wp9-" + $now.ToString("yyyyMMddHHmmss")
        $startAt = (Get-Date).AddDays(30).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endAt = (Get-Date).AddDays(33).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $createRentalUrl = "${pazarBaseUrl}/api/v1/rentals"
        $rentalBody = @{
            listing_id = $listingId
            start_at = $startAt
            end_at = $endAt
        } | ConvertTo-Json
        $rentalHeaders = @{
            "Content-Type" = "application/json"
            "Idempotency-Key" = $idempotencyKey
            "Authorization" = $testAuthToken
        }
        $createRentalResponse = Invoke-RestMethod -Uri $createRentalUrl -Method Post -Body $rentalBody -Headers $rentalHeaders -TimeoutSec 10 -ErrorAction Stop
        $rentalId = $createRentalResponse.id
        Write-Host "  Created rental: $rentalId" -ForegroundColor Gray
    } catch {
        Write-Host "WARN: Could not create rental: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Create test reservation (if listing exists)
$reservationId = $null
if ($listingId) {
    try {
        $now = Get-Date
        $idempotencyKey = "test-reservation-wp9-" + $now.ToString("yyyyMMddHHmmss")
        $slotStart = (Get-Date).AddDays(40).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $slotEnd = (Get-Date).AddDays(40).AddHours(4).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $createReservationUrl = "${pazarBaseUrl}/api/v1/reservations"
        $reservationBody = @{
            listing_id = $listingId
            slot_start = $slotStart
            slot_end = $slotEnd
            party_size = 100
        } | ConvertTo-Json
        $reservationHeaders = @{
            "Content-Type" = "application/json"
            "Idempotency-Key" = $idempotencyKey
            "Authorization" = $testAuthToken
        }
        $createReservationResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $reservationBody -Headers $reservationHeaders -TimeoutSec 10 -ErrorAction Stop
        $reservationId = $createReservationResponse.id
        Write-Host "  Created reservation: $reservationId" -ForegroundColor Gray
    } catch {
        Write-Host "WARN: Could not create reservation: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""

# Test 1: GET /api/v1/me/orders (Personal scope)
Write-Host "[1] Testing GET /api/v1/me/orders (Personal scope)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/me/orders"
    $headers = @{ "Authorization" = $testAuthToken }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $response.PSObject.Properties['data']) {
        Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.PSObject.Properties['meta']) {
        Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: GET /api/v1/me/orders returns valid response" -ForegroundColor Green
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
    if ($statusCode -eq 401) {
        Write-Host "FAIL: AUTH_REQUIRED (401) - Authorization token required" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

# Test 2: GET /api/v1/me/rentals (Personal scope)
Write-Host "[2] Testing GET /api/v1/me/rentals (Personal scope)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/me/rentals"
    $headers = @{ "Authorization" = $testAuthToken }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $response.PSObject.Properties['data']) {
        Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.PSObject.Properties['meta']) {
        Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: GET /api/v1/me/rentals returns valid response" -ForegroundColor Green
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
    if ($statusCode -eq 401) {
        Write-Host "FAIL: AUTH_REQUIRED (401) - Authorization token required" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

# Test 3: GET /api/v1/me/reservations (Personal scope)
Write-Host "[3] Testing GET /api/v1/me/reservations (Personal scope)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/me/reservations"
    $headers = @{ "Authorization" = $testAuthToken }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $response.PSObject.Properties['data']) {
        Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.PSObject.Properties['meta']) {
        Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: GET /api/v1/me/reservations returns valid response" -ForegroundColor Green
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
    if ($statusCode -eq 401) {
        Write-Host "FAIL: AUTH_REQUIRED (401) - Authorization token required" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

# Test 4: GET /api/v1/store/orders (Store scope)
Write-Host "[4] Testing GET /api/v1/store/orders (Store scope)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/store/orders"
    $headers = @{ "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $response.PSObject.Properties['data']) {
        Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.PSObject.Properties['meta']) {
        Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: GET /api/v1/store/orders returns valid response" -ForegroundColor Green
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
    if ($statusCode -eq 400) {
        Write-Host "FAIL: Missing X-Active-Tenant-Id header (400)" -ForegroundColor Red
    } elseif ($statusCode -eq 403) {
        Write-Host "FAIL: FORBIDDEN_SCOPE (403)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

# Test 5: GET /api/v1/store/rentals (Store scope)
Write-Host "[5] Testing GET /api/v1/store/rentals (Store scope)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/store/rentals"
    $headers = @{ "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $response.PSObject.Properties['data']) {
        Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.PSObject.Properties['meta']) {
        Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: GET /api/v1/store/rentals returns valid response" -ForegroundColor Green
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
    if ($statusCode -eq 400) {
        Write-Host "FAIL: Missing X-Active-Tenant-Id header (400)" -ForegroundColor Red
    } elseif ($statusCode -eq 403) {
        Write-Host "FAIL: FORBIDDEN_SCOPE (403)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

# Test 6: GET /api/v1/store/reservations (Store scope)
Write-Host "[6] Testing GET /api/v1/store/reservations (Store scope)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/store/reservations"
    $headers = @{ "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $response.PSObject.Properties['data']) {
        Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.PSObject.Properties['meta']) {
        Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: GET /api/v1/store/reservations returns valid response" -ForegroundColor Green
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
    if ($statusCode -eq 400) {
        Write-Host "FAIL: Missing X-Active-Tenant-Id header (400)" -ForegroundColor Red
    } elseif ($statusCode -eq 403) {
        Write-Host "FAIL: FORBIDDEN_SCOPE (403)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

# Test 7: GET /api/v1/store/listings (Store scope)
Write-Host "[7] Testing GET /api/v1/store/listings (Store scope)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/store/listings"
    $headers = @{ "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $response.PSObject.Properties['data']) {
        Write-Host "FAIL: Response missing 'data' field" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.PSObject.Properties['meta']) {
        Write-Host "FAIL: Response missing 'meta' field" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: GET /api/v1/store/listings returns valid response" -ForegroundColor Green
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
    if ($statusCode -eq 400) {
        Write-Host "FAIL: Missing X-Active-Tenant-Id header (400)" -ForegroundColor Red
    } elseif ($statusCode -eq 403) {
        Write-Host "FAIL: FORBIDDEN_SCOPE (403)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

# Test 8: Negative test - GET /api/v1/store/orders without X-Active-Tenant-Id
Write-Host "[8] Testing GET /api/v1/store/orders (without X-Active-Tenant-Id - should FAIL)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/store/orders"
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Expected 400/403 error, got 200 OK" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    if ($statusCode -eq 400 -or $statusCode -eq 403) {
        Write-Host "PASS: Correctly rejected request without X-Active-Tenant-Id (Status: $statusCode)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Expected 400/403, got $statusCode" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

if ($hasFailures) {
    Write-Host "=== ACCOUNT PORTAL CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more endpoint checks failed." -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== ACCOUNT PORTAL CONTRACT CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All Account Portal Read Spine endpoints are working correctly." -ForegroundColor Green
    exit 0
}


