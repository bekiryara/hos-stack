#!/usr/bin/env pwsh
# OFFER CONTRACT CHECK (WP-9)
# Verifies Offers/Pricing Spine API endpoints with idempotency and validation.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== OFFER CONTRACT CHECK (WP-9) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$hosBaseUrl = "http://localhost:3000"
$tenantId = $null
$authToken = $null
$listingId = $null
$offerId = $null

if (Test-Path "${scriptDir}\_lib\test_auth.ps1") {
    . "${scriptDir}\_lib\test_auth.ps1"
} else {
    Write-Host "FAIL: test_auth.ps1 not found" -ForegroundColor Red
    exit 1
}

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
        $membershipsArray = @()
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

# Generate deterministic idempotency key based on timestamp
$now = Get-Date
$idempotencyKey = "test-offer-key-" + $now.ToString("yyyyMMddHHmmss") + "-" + $now.Millisecond.ToString("D3")

Write-Host "[PREP] Acquiring JWT token and tenant_id..." -ForegroundColor Yellow
try {
    $apiKey = $env:HOS_API_KEY
    if (-not $apiKey) { $apiKey = "dev-api-key" }
    $jwtToken = Get-DevTestJwtToken -HosBaseUrl $hosBaseUrl -HosApiKey $apiKey
    if (-not $jwtToken) { throw "Failed to obtain JWT token" }
    $authToken = "Bearer $jwtToken"
    $env:PRODUCT_TEST_AUTH = $authToken
    $env:HOS_TEST_AUTH = $authToken

    $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" -Headers @{ "Authorization" = $authToken } -TimeoutSec 10 -ErrorAction Stop
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    if (-not $tenantId) { throw "No tenant_id found in memberships" }
    Write-Host "PASS: tenant_id acquired: $tenantId" -ForegroundColor Green
} catch {
    Write-Host "FAIL: Could not bootstrap auth/tenant: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 0: Get wedding-hall category ID
Write-Host "[0] Getting wedding-hall category ID..." -ForegroundColor Yellow

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
    } else {
        Write-Host "PASS: Found wedding-hall category ID: $weddingHallCategoryId" -ForegroundColor Green
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

Write-Host ""

# Test 1: Create DRAFT listing
Write-Host "[1] Creating DRAFT listing..." -ForegroundColor Yellow

try {
    $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
    $listingBody = @{
        category_id = $weddingHallCategoryId
        title = "Test Wedding Hall Listing for WP-9 Offers $(Get-Date -Format 'yyyyMMddHHmmss')"
        description = "Test listing for offers contract check"
        transaction_modes = @("reservation")
        location = @{
            city = "Istanbul"
            district = "Besiktas"
            neighborhood = "Levent Mah."
            address_line = "Test Mahallesi 1"
        }
        attributes = @{
            capacity_max = 100
        }
    } | ConvertTo-Json

    $listingHeaders = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "X-Active-Tenant-Id" = $tenantId
    }

    $listingResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $listingHeaders -TimeoutSec 10 -ErrorAction Stop
    if ($listingResponse.id -and $listingResponse.status -eq "draft") {
        $listingId = $listingResponse.id
        Write-Host "PASS: Draft listing created successfully" -ForegroundColor Green
        Write-Host "  Listing ID: $listingId" -ForegroundColor Gray
        Write-Host "  Status: $($listingResponse.status)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Listing creation returned invalid response" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Could not create listing: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Test 2: Create offer with Idempotency-Key -> PASS (201)
if ($listingId -and -not $hasFailures) {
    Write-Host "[2] Testing POST /api/v1/listings/${listingId}/offers (create offer)..." -ForegroundColor Yellow
    
    $createOfferUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}/offers"
    $offerBody = @{
        code = "basic-package"
        name = "Basic Package"
        price_amount = 10000
        price_currency = "TRY"
        billing_model = "one_time"
        attributes = $null
    } | ConvertTo-Json
    
    $offerHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $idempotencyKey
        "Authorization" = $authToken
        "X-Active-Tenant-Id" = $tenantId
    }
    
    try {
        $offerResponse = Invoke-RestMethod -Uri $createOfferUrl -Method Post -Body $offerBody -Headers $offerHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($offerResponse.id -and $offerResponse.code -eq "basic-package" -and $offerResponse.status -eq "active") {
            $offerId = $offerResponse.id
            Write-Host "PASS: Offer created successfully" -ForegroundColor Green
            Write-Host "  Offer ID: $offerId" -ForegroundColor Gray
            Write-Host "  Code: $($offerResponse.code)" -ForegroundColor Gray
            Write-Host "  Status: $($offerResponse.status)" -ForegroundColor Gray
            Write-Host "  Billing Model: $($offerResponse.billing_model)" -ForegroundColor Gray
            Write-Host "  Price: $($offerResponse.price_amount) $($offerResponse.price_currency)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Offer creation returned invalid response" -ForegroundColor Red
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
        Write-Host "FAIL: Create offer request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
}

Write-Host ""

# Test 3: Idempotency replay -> SAME offer id
if ($offerId -and -not $hasFailures) {
    Write-Host "[3] Testing idempotency replay (same Idempotency-Key)..." -ForegroundColor Yellow
    
    $offerBody = @{
        code = "basic-package"
        name = "Basic Package"
        price_amount = 10000
        price_currency = "TRY"
        billing_model = "one_time"
        attributes = $null
    } | ConvertTo-Json
    
    $offerHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $idempotencyKey # Same key
        "Authorization" = $authToken
        "X-Active-Tenant-Id" = $tenantId
    }
    
    try {
        $replayResponse = Invoke-RestMethod -Uri $createOfferUrl -Method Post -Body $offerBody -Headers $offerHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($replayResponse.id -eq $offerId) {
            Write-Host "PASS: Idempotency replay returned same offer ID" -ForegroundColor Green
            Write-Host "  Offer ID: $($replayResponse.id)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Idempotency replay returned different offer ID" -ForegroundColor Red
            Write-Host "  Expected: $offerId" -ForegroundColor Yellow
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

# Test 4: GET /v1/listings/{id}/offers -> created offer listed
if ($listingId -and $offerId -and -not $hasFailures) {
    Write-Host "[4] Testing GET /api/v1/listings/${listingId}/offers..." -ForegroundColor Yellow
    
    $listOffersUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}/offers"
    try {
        $listOffersResponse = Invoke-RestMethod -Uri $listOffersUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        $foundOffer = $listOffersResponse | Where-Object { $_.id -eq $offerId } | Select-Object -First 1
        
        if ($foundOffer) {
            Write-Host "PASS: Created offer found in listing offers list" -ForegroundColor Green
            Write-Host "  Offer ID: $($foundOffer.id)" -ForegroundColor Gray
            Write-Host "  Code: $($foundOffer.code)" -ForegroundColor Gray
            Write-Host "  Status: $($foundOffer.status)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Created offer not found in listing offers list" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Get listing offers failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 5: POST /v1/offers/{id}/deactivate -> status inactive
if ($offerId -and -not $hasFailures) {
    Write-Host "[5] Testing POST /api/v1/offers/${offerId}/deactivate..." -ForegroundColor Yellow
    
    $deactivateOfferUrl = "${pazarBaseUrl}/api/v1/offers/${offerId}/deactivate"
    $deactivateHeaders = @{
        "Authorization" = $authToken
        "X-Active-Tenant-Id" = $tenantId
    }
    
    try {
        $deactivateResponse = Invoke-RestMethod -Uri $deactivateOfferUrl -Method Post -Headers $deactivateHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($deactivateResponse.id -eq $offerId -and $deactivateResponse.status -eq "inactive") {
            Write-Host "PASS: Offer deactivated successfully" -ForegroundColor Green
            Write-Host "  Offer ID: $($deactivateResponse.id)" -ForegroundColor Gray
            Write-Host "  Status: $($deactivateResponse.status)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Offer deactivation returned invalid response" -ForegroundColor Red
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
        Write-Host "FAIL: Deactivate offer request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
}

Write-Host ""

# Test 6: GET /v1/offers/{id} -> status inactive
if ($offerId -and -not $hasFailures) {
    Write-Host "[6] Testing GET /api/v1/offers/${offerId}..." -ForegroundColor Yellow
    
    $getOfferUrl = "${pazarBaseUrl}/api/v1/offers/${offerId}"
    try {
        $getOfferResponse = Invoke-RestMethod -Uri $getOfferUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        if ($getOfferResponse.id -eq $offerId -and $getOfferResponse.status -eq "inactive") {
            Write-Host "PASS: Offer retrieved with inactive status" -ForegroundColor Green
            Write-Host "  Offer ID: $($getOfferResponse.id)" -ForegroundColor Gray
            Write-Host "  Status: $($getOfferResponse.status)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Offer retrieval returned invalid status" -ForegroundColor Red
            Write-Host "  Expected status: inactive" -ForegroundColor Yellow
            Write-Host "  Got status: $($getOfferResponse.status)" -ForegroundColor Yellow
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Get offer failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 7: Negative test - Create offer without X-Active-Tenant-Id -> 400
if ($listingId -and -not $hasFailures) {
    Write-Host "[7] Testing negative: Create offer without X-Active-Tenant-Id..." -ForegroundColor Yellow
    
    $offerBody = @{
        code = "test-package"
        name = "Test Package"
        price_amount = 5000
        price_currency = "TRY"
        billing_model = "one_time"
    } | ConvertTo-Json
    
    $invalidHeaders = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "Idempotency-Key" = "test-offer-no-tenant-" + $now.ToString("yyyyMMddHHmmss")
        # No X-Active-Tenant-Id header
    }
    
    try {
        $invalidResponse = Invoke-RestMethod -Uri $createOfferUrl -Method Post -Body $offerBody -Headers $invalidHeaders -TimeoutSec 10 -ErrorAction Stop
        Write-Host "FAIL: Expected 400 error, but request succeeded" -ForegroundColor Red
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
            Write-Host "PASS: Correctly returned 400 for missing X-Active-Tenant-Id" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Expected 400, got $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
    }
}

Write-Host ""

# Test 8: Negative test - Invalid billing_model -> 422 VALIDATION_ERROR
if ($listingId -and -not $hasFailures) {
    Write-Host "[8] Testing negative: Invalid billing_model..." -ForegroundColor Yellow
    
    $invalidOfferBody = @{
        code = "invalid-package"
        name = "Invalid Package"
        price_amount = 5000
        price_currency = "TRY"
        billing_model = "invalid_model" # Invalid value
    } | ConvertTo-Json
    
    $invalidBillingHeaders = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = "test-offer-invalid-billing-" + $now.ToString("yyyyMMddHHmmss")
        "Authorization" = $authToken
        "X-Active-Tenant-Id" = $tenantId
    }
    
    try {
        $invalidResponse = Invoke-RestMethod -Uri $createOfferUrl -Method Post -Body $invalidOfferBody -Headers $invalidBillingHeaders -TimeoutSec 10 -ErrorAction Stop
        Write-Host "FAIL: Expected 422 VALIDATION_ERROR, but request succeeded" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        $errorBody = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorBody = $reader.ReadToEnd() | ConvertFrom-Json
            } catch {
            }
        }
        if ($statusCode -eq 422) {
            Write-Host "PASS: Correctly returned 422 VALIDATION_ERROR for invalid billing_model" -ForegroundColor Green
            if ($errorBody -and $errorBody.error) {
                Write-Host "  Error: $($errorBody.error)" -ForegroundColor Gray
            }
        } else {
            Write-Host "FAIL: Expected 422, got $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
    }
}

Write-Host ""

if ($hasFailures) {
    Write-Host "=== OFFER CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more offer contract checks failed." -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== OFFER CONTRACT CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All offer contract checks passed." -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

