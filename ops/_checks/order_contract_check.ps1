#!/usr/bin/env pwsh
# ORDER CONTRACT CHECK (WP-6)
# Verifies Order Spine API endpoints with idempotency and validation.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}
if (Test-Path "${scriptDir}\_lib\test_auth.ps1") {
    . "${scriptDir}\_lib\test_auth.ps1"
} else {
    Write-Host "FAIL: test_auth.ps1 not found" -ForegroundColor Red
    exit 1
}

Write-Host "=== ORDER CONTRACT CHECK (WP-6) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$hosBaseUrl = "http://localhost:3000"
$messagingBaseUrl = "http://localhost:8090"
$tenantId = $null
$authToken = $null
$userId = $null
$listingId = $null
$orderId = $null
$createOrderUrl = "${pazarBaseUrl}/api/v1/orders"

function Get-TenantIdFromMemberships {
    param([object]$Memberships)

    if (-not $Memberships) {
        return $null
    }

    $membershipsArray = $null
    if ($Memberships -is [Array]) {
        $membershipsArray = $Memberships
    } elseif ($Memberships -is [PSCustomObject]) {
        if ($Memberships.PSObject.Properties['items'] -and $Memberships.items -is [Array]) {
            $membershipsArray = $Memberships.items
        } elseif ($Memberships.PSObject.Properties['data'] -and $Memberships.data -is [Array]) {
            $membershipsArray = $Memberships.data
        }
    } elseif ($Memberships.items -is [Array]) {
        $membershipsArray = $Memberships.items
    } elseif ($Memberships.data -is [Array]) {
        $membershipsArray = $Memberships.data
    }

    if (-not $membershipsArray) {
        return $null
    }

    foreach ($membership in $membershipsArray) {
        $candidate = $membership.tenant_id
        if (-not $candidate -and $membership.tenant -and $membership.tenant.id) { $candidate = $membership.tenant.id }
        if (-not $candidate -and $membership.tenantId) { $candidate = $membership.tenantId }
        if (-not $candidate -and $membership.store_tenant_id) { $candidate = $membership.store_tenant_id }
        $parsed = [System.Guid]::Empty
        if ($candidate -and [System.Guid]::TryParse([string]$candidate, [ref]$parsed)) {
            return [string]$candidate
        }
    }

    return $null
}

function Get-JwtSub {
    param([string]$JwtToken)

    try {
        $parts = $JwtToken -split '\.'
        if ($parts.Count -lt 2) { return $null }
        $payloadBase64 = $parts[1]
        $padding = 4 - ($payloadBase64.Length % 4)
        if ($padding -ne 4) { $payloadBase64 += ('=' * $padding) }
        $payloadBytes = [System.Convert]::FromBase64String($payloadBase64)
        $payloadJson = [System.Text.Encoding]::UTF8.GetString($payloadBytes)
        $payload = $payloadJson | ConvertFrom-Json
        return $payload.sub
    } catch {
        return $null
    }
}

function FindCategoryInTree {
    param([object[]]$Tree, [string]$Slug)

    foreach ($item in $Tree) {
        if ($item.slug -eq $Slug) { return $item.id }
        if ($item.children) {
            $found = FindCategoryInTree -Tree $item.children -Slug $Slug
            if ($found) { return $found }
        }
    }

    return $null
}

Write-Host "[PREP] Acquiring JWT token and tenant_id..." -ForegroundColor Yellow
try {
    $apiKey = $env:HOS_API_KEY
    if (-not $apiKey) { $apiKey = 'dev-api-key' }
    $jwtToken = Get-DevTestJwtToken -HosBaseUrl $hosBaseUrl -HosApiKey $apiKey
    if (-not $jwtToken) { throw 'Failed to obtain JWT token' }
    $authToken = "Bearer $jwtToken"
    $env:PRODUCT_TEST_AUTH = $authToken
    $env:HOS_TEST_AUTH = $authToken
    $userId = Get-JwtSub -JwtToken $jwtToken
    if (-not $userId) { throw 'Could not extract user ID from JWT' }

    $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" -Headers @{ 'Authorization' = $authToken } -TimeoutSec 10 -ErrorAction Stop
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    if (-not $tenantId) { throw 'No tenant_id found in memberships' }

    Write-Host "PASS: tenant_id acquired: $tenantId" -ForegroundColor Green
    Write-Host "PASS: user_id acquired: $userId" -ForegroundColor Green
} catch {
    Write-Host "FAIL: Could not bootstrap auth/tenant: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[0] Getting or creating published listing for testing..." -ForegroundColor Yellow
try {
    $categories = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/categories" -Method Get -TimeoutSec 15 -ErrorAction Stop
    $weddingHallCategoryId = FindCategoryInTree -Tree $categories -Slug 'wedding-hall'
    if (-not $weddingHallCategoryId) { throw 'wedding-hall category not found' }

    $publishedListings = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings?category_id=$weddingHallCategoryId&status=published" -Method Get -TimeoutSec 15 -ErrorAction Stop
    $existingListing = $publishedListings | Where-Object { $_.tenant_id -eq $tenantId } | Select-Object -First 1
    if ($existingListing) {
        $listingId = $existingListing.id
        Write-Host "PASS: Found published listing: $listingId" -ForegroundColor Green
        Write-Host "  Title: $($existingListing.title)" -ForegroundColor Gray
    } else {
        $createListingBody = @{
            category_id = $weddingHallCategoryId
            title = "Test Order Listing $(Get-Date -Format 'yyyyMMddHHmmss')"
            description = 'Test listing for order contract check'
            transaction_modes = @('sale')
            attributes = @{ capacity_max = 100 }
        } | ConvertTo-Json
        $storeHeaders = @{
            'Content-Type' = 'application/json'
            'Authorization' = $authToken
            'X-Active-Tenant-Id' = $tenantId
        }
        $draft = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings" -Method Post -Body $createListingBody -Headers $storeHeaders -TimeoutSec 15 -ErrorAction Stop
        $listingId = $draft.id
        Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings/$listingId/publish" -Method Post -Headers $storeHeaders -TimeoutSec 15 -ErrorAction Stop | Out-Null
        Write-Host "PASS: Created and published listing: $listingId" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Could not get/create listing for test: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
$now = Get-Date
$idempotencyKey = 'test-order-key-' + $now.ToString('yyyyMMddHHmmss') + '-' + $now.Millisecond.ToString('D3')
$orderBody = @{ listing_id = $listingId; quantity = 1 } | ConvertTo-Json
$orderHeaders = @{
    'Content-Type' = 'application/json'
    'Authorization' = $authToken
    'Idempotency-Key' = $idempotencyKey
}

Write-Host "[1] Testing POST /api/v1/orders (create order)..." -ForegroundColor Yellow
try {
    $orderResponse = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $orderBody -Headers $orderHeaders -TimeoutSec 15 -ErrorAction Stop
    if ($orderResponse.id -and $orderResponse.status -eq 'placed') {
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
    Write-Host "FAIL: Create order request failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""
if ($orderId -and -not $hasFailures) {
    Write-Host "[2] Testing buyer order read..." -ForegroundColor Yellow
    try {
        $buyerOrders = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/orders?buyer_user_id=$userId" -Method Get -Headers @{ 'Authorization' = $authToken } -TimeoutSec 15 -ErrorAction Stop
        $ordersArray = @()
        if ($buyerOrders -is [Array]) { $ordersArray = $buyerOrders }
        elseif ($buyerOrders.data -is [Array]) { $ordersArray = $buyerOrders.data }
        elseif ($buyerOrders.items -is [Array]) { $ordersArray = $buyerOrders.items }
        $foundOrder = $ordersArray | Where-Object { $_.id -eq $orderId } | Select-Object -First 1
        if ($foundOrder) {
            Write-Host "PASS: Created order found in buyer orders" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Created order not found in buyer orders" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Buyer orders read failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""
if ($orderId -and -not $hasFailures) {
    Write-Host "[3] Testing idempotency replay..." -ForegroundColor Yellow
    try {
        $replayResponse = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $orderBody -Headers $orderHeaders -TimeoutSec 15 -ErrorAction Stop
        if ($replayResponse.id -eq $orderId) {
            Write-Host "PASS: Idempotency replay returned same order ID" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Idempotency replay returned different order ID" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Idempotency replay failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""
if ($orderId -and -not $hasFailures) {
    Write-Host "[4] Testing POST /api/v1/orders/{id}/accept..." -ForegroundColor Yellow
    try {
        $acceptHeaders = @{ 'Authorization' = $authToken; 'X-Active-Tenant-Id' = $tenantId }
        $acceptResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/orders/$orderId/accept" -Method Post -Headers $acceptHeaders -TimeoutSec 15 -ErrorAction Stop
        if ($acceptResponse.status -eq 'accepted') {
            Write-Host "PASS: Order accepted successfully" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Order accept returned wrong status: $($acceptResponse.status)" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Accept order request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""
if (-not $hasFailures) {
    Write-Host "[5] Testing unpublished listing negative..." -ForegroundColor Yellow
    try {
        $draftBody = @{
            category_id = $weddingHallCategoryId
            title = "Draft Order Listing $(Get-Date -Format 'yyyyMMddHHmmss')"
            description = 'Draft listing negative test'
            transaction_modes = @('reservation')
            attributes = @{ capacity_max = 50 }
        } | ConvertTo-Json
        $storeHeaders = @{
            'Content-Type' = 'application/json'
            'Authorization' = $authToken
            'X-Active-Tenant-Id' = $tenantId
        }
        $draftListing = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings" -Method Post -Body $draftBody -Headers $storeHeaders -TimeoutSec 15 -ErrorAction Stop
        $negativeHeaders = @{
            'Content-Type' = 'application/json'
            'Authorization' = $authToken
            'Idempotency-Key' = 'test-order-draft-' + (Get-Date -Format 'yyyyMMddHHmmssfff')
        }
        $negativeBody = @{ listing_id = $draftListing.id; quantity = 1 } | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $negativeBody -Headers $negativeHeaders -TimeoutSec 15 -ErrorAction Stop | Out-Null
            Write-Host "FAIL: Draft listing order should have been rejected" -ForegroundColor Red
            $hasFailures = $true
        } catch {
            $statusCode = $null
            try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch { }
            if ($statusCode -eq 422) {
                Write-Host "PASS: Draft listing order correctly rejected with 422" -ForegroundColor Green
            } else {
                Write-Host "FAIL: Expected 422 for draft listing order, got $statusCode" -ForegroundColor Red
                $hasFailures = $true
            }
        }
    } catch {
        Write-Host "FAIL: Draft listing negative setup failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""
if ($orderId -and -not $hasFailures) {
    Write-Host "[6] Checking messaging thread by context..." -ForegroundColor Yellow
    try {
        $threadResponse = Invoke-RestMethod -Uri "$messagingBaseUrl/api/v1/threads/by-context?context_type=order&context_id=$orderId" -Method Get -Headers @{ 'messaging-api-key' = 'dev-messaging-key' } -TimeoutSec 5 -ErrorAction Stop
        if ($threadResponse.thread_id) {
            Write-Host "PASS: Messaging thread exists for order" -ForegroundColor Green
        } else {
            Write-Host "WARN: Messaging response did not include thread_id" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "WARN: Could not verify messaging thread: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
if (-not $hasFailures) {
    Write-Host "[7] Testing canonical listing price path..." -ForegroundColor Yellow
    try {
        $canonicalTitle = "Canonical Price Probe $(Get-Date -Format 'yyyyMMddHHmmss')"
        $canonicalCreateBody = @{
            category_id = $weddingHallCategoryId
            title = $canonicalTitle
            description = 'Canonical price path probe'
            price_amount = 4321
            currency = 'TRY'
            transaction_modes = @('reservation')
            attributes = @{ capacity_max = 25 }
        } | ConvertTo-Json
        $canonicalStoreHeaders = @{
            'Content-Type' = 'application/json'
            'Authorization' = $authToken
            'X-Active-Tenant-Id' = $tenantId
            'Idempotency-Key' = 'test-canonical-listing-' + [guid]::NewGuid().ToString()
        }
        $canonicalDraft = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings" -Method Post -Body $canonicalCreateBody -Headers $canonicalStoreHeaders -TimeoutSec 15 -ErrorAction Stop
        $canonicalListingId = $canonicalDraft.id

        Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings/$canonicalListingId/publish" -Method Post -Headers @{
            'Authorization' = $authToken
            'X-Active-Tenant-Id' = $tenantId
        } -TimeoutSec 15 -ErrorAction Stop | Out-Null

        $canonicalListing = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings/$canonicalListingId" -Method Get -TimeoutSec 15 -ErrorAction Stop
        if ($canonicalListing.price -ne 4321 -or $canonicalListing.price_currency -ne 'TRY') {
            throw "Listing read did not prefer canonical price_amount (price=$($canonicalListing.price), currency=$($canonicalListing.price_currency))"
        }

        $canonicalOrderHeaders = @{
            'Content-Type' = 'application/json'
            'Authorization' = $authToken
            'Idempotency-Key' = 'test-canonical-order-' + [guid]::NewGuid().ToString()
        }
        $canonicalOrderBody = @{
            listing_id = $canonicalListingId
            quantity = 2
        } | ConvertTo-Json
        $canonicalOrder = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $canonicalOrderBody -Headers $canonicalOrderHeaders -TimeoutSec 15 -ErrorAction Stop

        if (-not $canonicalOrder.totals) {
            throw 'Canonical price order did not return totals'
        }
        if ($canonicalOrder.totals.unit_price -ne 4321 -or $canonicalOrder.totals.subtotal -ne 8642 -or $canonicalOrder.totals.currency -ne 'TRY') {
            throw "Order totals did not use canonical listing price (unit=$($canonicalOrder.totals.unit_price), subtotal=$($canonicalOrder.totals.subtotal), currency=$($canonicalOrder.totals.currency))"
        }

        Write-Host "PASS: Canonical listing price path works for read + order snapshot" -ForegroundColor Green
        Write-Host "  Listing ID: $canonicalListingId" -ForegroundColor Gray
    } catch {
        Write-Host "FAIL: Canonical listing price path failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""
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
