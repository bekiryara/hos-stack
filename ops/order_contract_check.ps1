#!/usr/bin/env pwsh
# ORDER CONTRACT CHECK (WP-6)
# Verifies Order Spine API endpoints with idempotency and validation.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== ORDER CONTRACT CHECK (WP-6) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$tenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic UUID for tenant-demo
$listingId = $null
$orderId = $null

# Generate deterministic idempotency key based on timestamp
$now = Get-Date
$idempotencyKey = "test-order-key-" + $now.ToString("yyyyMMddHHmmss") + "-" + $now.Millisecond.ToString("D3")

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

# Test 1: Create order -> PASS (201)
if ($listingId) {
    Write-Host "[1] Testing POST /api/v1/orders (create order)..." -ForegroundColor Yellow
    
    $createOrderUrl = "${pazarBaseUrl}/api/v1/orders"
    $orderBody = @{
        listing_id = $listingId
        quantity = 1
    } | ConvertTo-Json
    
    $orderHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $idempotencyKey
    }
    
    try {
        $orderResponse = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $orderBody -Headers $orderHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($orderResponse.id -and $orderResponse.status -eq "placed") {
            $orderId = $orderResponse.id
            Write-Host "PASS: Order created successfully" -ForegroundColor Green
            Write-Host "  Order ID: $orderId" -ForegroundColor Gray
            Write-Host "  Status: $($orderResponse.status)" -ForegroundColor Gray
            Write-Host "  Quantity: $($orderResponse.quantity)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Order creation returned invalid response" -ForegroundColor Red
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
        Write-Host "FAIL: Create order request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[1] SKIP: Cannot test order creation (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 1b: Verify messaging thread created for order
Write-Host "[1b] Testing Messaging thread creation for order..." -ForegroundColor Yellow
if ($orderId) {
    try {
        $messagingBaseUrl = "http://localhost:8090"
        $apiKey = "dev-messaging-key"
        $byContextHeaders = @{
            "messaging-api-key" = $apiKey
        }
        
        $byContextUrl = "${messagingBaseUrl}/api/v1/threads/by-context?context_type=order&context_id=$orderId"
        $messagingResponse = Invoke-RestMethod -Uri $byContextUrl -Method Get -Headers $byContextHeaders -TimeoutSec 5 -ErrorAction Stop
        
        if ($messagingResponse.thread_id) {
            Write-Host "PASS: Messaging thread exists for order" -ForegroundColor Green
            Write-Host "  Thread ID: $($messagingResponse.thread_id)" -ForegroundColor Gray
            Write-Host "  Context: order / $orderId" -ForegroundColor Gray
            Write-Host "  Participants: $($messagingResponse.participants.Count)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Messaging thread not found for order" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Could not verify messaging thread: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Note: Messaging service may be unavailable, but thread should exist if service is up" -ForegroundColor Yellow
        $hasFailures = $true
    }
} else {
    Write-Host "SKIP: Cannot verify messaging thread (order ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 2: Idempotency replay -> SAME order id
if ($listingId) {
    Write-Host "[2] Testing POST /api/v1/orders (idempotency replay)..." -ForegroundColor Yellow
    
    $replayOrderBody = @{
        listing_id = $listingId
        quantity = 1
    } | ConvertTo-Json
    
    $replayOrderHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $idempotencyKey # Same key as Test 1
    }
    
    try {
        $replayResponse = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $replayOrderBody -Headers $replayOrderHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($replayResponse.id -eq $orderId) {
            Write-Host "PASS: Idempotency replay returned same order ID" -ForegroundColor Green
            Write-Host "  Order ID: $($replayResponse.id)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Idempotency replay returned different order ID" -ForegroundColor Red
            Write-Host "  Expected: $orderId" -ForegroundColor Yellow
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
        Write-Host "FAIL: Idempotency replay request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[2] SKIP: Cannot test idempotency (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 3: Unpublished listing -> FAIL (422)
if ($listingId) {
    Write-Host "[3] Testing POST /api/v1/orders (unpublished listing)..." -ForegroundColor Yellow
    
    # First, create a draft listing (or get existing draft)
    $draftListingBody = @{
        category_id = $weddingHallCategoryId
        title = "Test Draft Listing for Order Test"
        status = "draft"
        attributes_json = @{
            capacity_max = 100
        }
    } | ConvertTo-Json -Depth 10
    
    $draftListingHeaders = @{
        "Content-Type" = "application/json"
        "X-Active-Tenant-Id" = $tenantId
    }
    
    try {
        $draftListingUrl = "${pazarBaseUrl}/api/v1/listings"
        $draftListingResponse = Invoke-RestMethod -Uri $draftListingUrl -Method Post -Body $draftListingBody -Headers $draftListingHeaders -TimeoutSec 10 -ErrorAction Stop
        $draftListingId = $draftListingResponse.id
        
        # Now try to create order with draft listing
        $draftOrderBody = @{
            listing_id = $draftListingId
            quantity = 1
        } | ConvertTo-Json
        
        $draftOrderHeaders = @{
            "Content-Type" = "application/json"
            "Idempotency-Key" = "test-order-draft-" + (Get-Date -Format "yyyyMMddHHmmss")
        }
        
        try {
            $draftOrderResponse = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $draftOrderBody -Headers $draftOrderHeaders -TimeoutSec 10 -ErrorAction Stop
            Write-Host "FAIL: Order creation should have failed for draft listing" -ForegroundColor Red
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
                Write-Host "PASS: Order creation correctly rejected for draft listing (status: 422)" -ForegroundColor Green
            } else {
                Write-Host "FAIL: Expected 422, got status: $statusCode" -ForegroundColor Red
                $hasFailures = $true
            }
        }
    } catch {
        Write-Host "WARN: Could not create draft listing for test: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Skipping unpublished listing test" -ForegroundColor Gray
    }
} else {
    Write-Host "[3] SKIP: Cannot test unpublished listing (listing ID not available)" -ForegroundColor Yellow
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== ORDER CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== ORDER CONTRACT CHECK: PASS ===" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}



