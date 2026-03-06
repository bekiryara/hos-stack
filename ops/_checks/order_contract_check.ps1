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
$canRunSellerActions = $false
$orderCompatibleCategoryId = $null
$orderCompatibleAttrs = @{}
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

    # Order flow requires service_time_model=none (policy primitive).
    # Pick tenant-owned published listing with sale mode + compatible service model.
    $publishedListings = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings?status=published&per_page=50" -Method Get -TimeoutSec 15 -ErrorAction Stop
    $existingListing = $publishedListings | Where-Object {
        $_.tenant_id -eq $tenantId -and
        ($_.transaction_modes -is [Array]) -and
        ($_.transaction_modes -contains 'sale') -and
        ((-not $_.attributes) -or (-not $_.attributes.service_time_model) -or ([string]$_.attributes.service_time_model -eq 'none'))
    } | Select-Object -First 1
    if (-not $existingListing) {
        $existingListing = $publishedListings | Where-Object {
            ($_.transaction_modes -is [Array]) -and
            ($_.transaction_modes -contains 'sale') -and
            ((-not $_.attributes) -or (-not $_.attributes.service_time_model) -or ([string]$_.attributes.service_time_model -eq 'none'))
        } | Select-Object -First 1
        if (-not $existingListing) {
            throw 'No published order-compatible listing found (requires transaction_mode=sale and service_time_model=none)'
        }
        Write-Host "WARN: Using non-tenant listing for order create tests; seller-only actions will be skipped." -ForegroundColor Yellow
    } else {
        $canRunSellerActions = $true
    }
    $listingId = $existingListing.id
    $orderCompatibleCategoryId = $existingListing.category_id
    $orderCompatibleAttrs = @{}
    if ($existingListing.attributes) {
        $existingListing.attributes.PSObject.Properties | ForEach-Object { $orderCompatibleAttrs[$_.Name] = $_.Value }
    }
    Write-Host "PASS: Selected order-compatible published listing: $listingId" -ForegroundColor Green
    Write-Host "  Title: $($existingListing.title)" -ForegroundColor Gray
    Write-Host "  Category: $($existingListing.category_id)" -ForegroundColor Gray
    Write-Host "  Listing Tenant: $($existingListing.tenant_id)" -ForegroundColor Gray
} catch {
    Write-Host "FAIL: Could not get/create listing for test: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
$idempotencyKey = 'test-order-key-v1-' + [string]$listingId
$orderBody = @{ listing_id = $listingId; quantity = 1 } | ConvertTo-Json
$orderHeaders = @{
    'Content-Type' = 'application/json'
    'Authorization' = $authToken
    'Idempotency-Key' = $idempotencyKey
}

Write-Host "[1] Testing POST /api/v1/orders (create order)..." -ForegroundColor Yellow
try {
    $orderResponse = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $orderBody -Headers $orderHeaders -TimeoutSec 15 -ErrorAction Stop
    if ($orderResponse.id -and $orderResponse.status -eq 'placed' -and $orderResponse.totals -and $orderResponse.totals.pricing_source -eq 'listing') {
        $orderId = $orderResponse.id
        Write-Host "PASS: Order created successfully" -ForegroundColor Green
        Write-Host "  Order ID: $orderId" -ForegroundColor Gray
        Write-Host "  Status: $($orderResponse.status)" -ForegroundColor Gray
        Write-Host "  Quantity: $($orderResponse.quantity)" -ForegroundColor Gray
        Write-Host "  Price: $($orderResponse.totals.unit_price) $($orderResponse.totals.currency)" -ForegroundColor Gray
        Write-Host "  Pricing Source: $($orderResponse.totals.pricing_source)" -ForegroundColor Gray
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
        if ($foundOrder -and $foundOrder.totals -and $foundOrder.totals.pricing_source -eq 'listing') {
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
        if ($replayResponse.id -eq $orderId -and $replayResponse.totals -and $replayResponse.totals.pricing_source -eq 'listing') {
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
if ($orderId -and -not $hasFailures -and $canRunSellerActions) {
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

if ($orderId -and -not $hasFailures -and -not $canRunSellerActions) {
    Write-Host "[4] SKIP: Seller accept test skipped (selected listing not owned by active tenant)." -ForegroundColor Yellow
}

Write-Host ""
if (-not $hasFailures) {
    Write-Host "[5] Testing unpublished listing negative..." -ForegroundColor Yellow
    try {
        $draftBody = @{
            category_id = $weddingHallCategoryId
            title = "Draft Order Listing $(Get-Date -Format 'yyyyMMddHHmmss')"
            description = 'Draft listing negative test'
            price_amount = 999
            currency = 'TRY'
            transaction_modes = @('reservation')
            location = @{
                city = 'Istanbul'
                district = 'Besiktas'
                neighborhood = 'Levent Mah.'
                address_line = 'Test Mahallesi 1'
            }
            attributes = @{
                capacity_max = 50
                offer_variant = 'reservation'
                interaction_mode = 'flow'
            }
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
        $canonicalListingId = $listingId
        $canonicalListing = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings/$canonicalListingId" -Method Get -TimeoutSec 15 -ErrorAction Stop
        $expectedUnit = [double]$canonicalListing.price
        $expectedCurrency = [string]$canonicalListing.price_currency
        if ($expectedUnit -le 0 -or [string]::IsNullOrWhiteSpace($expectedCurrency)) {
            throw "Selected listing does not expose canonical price fields (price=$expectedUnit, currency=$expectedCurrency)"
        }

        $canonicalOrderHeaders = @{
            'Content-Type' = 'application/json'
            'Authorization' = $authToken
            'Idempotency-Key' = 'test-canonical-order-v1-' + [string]$canonicalListingId
        }
        $canonicalOrderBody = @{
            listing_id = $canonicalListingId
            quantity = 2
        } | ConvertTo-Json
        $canonicalOrder = Invoke-RestMethod -Uri $createOrderUrl -Method Post -Body $canonicalOrderBody -Headers $canonicalOrderHeaders -TimeoutSec 15 -ErrorAction Stop

        if (-not $canonicalOrder.totals) {
            throw 'Canonical price order did not return totals'
        }
        $expectedSubtotal = [double]($expectedUnit * 2)
        if ($canonicalOrder.totals.unit_price -ne $expectedUnit -or $canonicalOrder.totals.subtotal -ne $expectedSubtotal -or $canonicalOrder.totals.currency -ne $expectedCurrency -or $canonicalOrder.totals.pricing_source -ne 'listing') {
            throw "Order totals did not use canonical listing price (expected_unit=$expectedUnit expected_subtotal=$expectedSubtotal expected_currency=$expectedCurrency actual_unit=$($canonicalOrder.totals.unit_price) actual_subtotal=$($canonicalOrder.totals.subtotal) actual_currency=$($canonicalOrder.totals.currency) source=$($canonicalOrder.totals.pricing_source))"
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
