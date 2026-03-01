#!/usr/bin/env pwsh
# RENTAL CONTRACT CHECK (WP-7)
# Verifies Rental Spine API endpoints with idempotency and overlap validation.
# PowerShell 5.1 compatible, ASCII-only output where possible.
 
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
$hosBaseUrl = "http://localhost:3000"
$providerTenantId = $null
$activeTenantId = $null
 
# Load test_auth helper
if (Test-Path "${scriptDir}\_lib\test_auth.ps1") {
    . "${scriptDir}\_lib\test_auth.ps1"
} else {
    Write-Host "FAIL: test_auth.ps1 not found" -ForegroundColor Red
    exit 1
}
 
function Get-JwtSub {
    param([string]$JwtToken)
    try {
        $parts = $JwtToken -split '\.'
        if ($parts.Count -lt 2) { return $null }
        $payloadBase64 = $parts[1]
        $padding = 4 - ($payloadBase64.Length % 4)
        if ($padding -ne 4) { $payloadBase64 = $payloadBase64 + ("=" * $padding) }
        $payloadBytes = [System.Convert]::FromBase64String($payloadBase64)
        $payloadJson = [System.Text.Encoding]::UTF8.GetString($payloadBytes)
        $payload = $payloadJson | ConvertFrom-Json
        return $payload.sub
    } catch {
        return $null
    }
}
 
# Acquire JWT token
Write-Host "[PREP] Acquiring JWT token..." -ForegroundColor Yellow
try {
    $apiKey = $env:HOS_API_KEY
    if (-not $apiKey) { $apiKey = "dev-api-key" }
    $jwtToken = Get-DevTestJwtToken -HosBaseUrl $hosBaseUrl -HosApiKey $apiKey
    if (-not $jwtToken) { throw "Failed to obtain JWT token" }
 
    $authHeader = "Bearer $jwtToken"
    $tokenMask = if ($jwtToken.Length -gt 6) { "***" + $jwtToken.Substring($jwtToken.Length - 6) } else { "***" }
    Write-Host "PASS: Token acquired ($tokenMask)" -ForegroundColor Green
 
    # Export for other scripts (best-effort)
    $env:PRODUCT_TEST_AUTH = $authHeader
    $env:HOS_TEST_AUTH = $authHeader
} catch {
    Write-Host "FAIL: Token acquisition failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
 
$userId = Get-JwtSub -JwtToken $jwtToken
if (-not $userId) {
    Write-Host "FAIL: Could not extract user ID (sub) from JWT token" -ForegroundColor Red
    exit 1
}
Write-Host "Auth enabled: User ID from token: $userId" -ForegroundColor Gray
Write-Host ""

# Helper: Extract tenant_id robustly from memberships
function Get-TenantIdFromMemberships {
    param([object]$Memberships)

    if (-not $Memberships) { return $null }

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

    if (-not $membershipsArray -or $membershipsArray.Count -eq 0) { return $null }

    foreach ($membership in $membershipsArray) {
        $tid = $null
        if ($membership.tenant_id) {
            $tid = $membership.tenant_id
        } elseif ($membership.tenant -and $membership.tenant.id) {
            $tid = $membership.tenant.id
        } elseif ($membership.tenantId) {
            $tid = $membership.tenantId
        } elseif ($membership.store_tenant_id) {
            $tid = $membership.store_tenant_id
        }

        if ($tid -and $tid -is [string] -and $tid.Trim().Length -gt 0) {
            $guidResult = [System.Guid]::Empty
            if ([System.Guid]::TryParse($tid, [ref]$guidResult)) {
                return $tid
            }
        }
    }

    return $null
}

# Acquire active tenant for deterministic listing bootstrap
Write-Host "[PREP] Resolving active tenant..." -ForegroundColor Yellow
try {
    $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" `
        -Headers @{ "Authorization" = $authHeader } `
        -TimeoutSec 10 `
        -ErrorAction Stop
    $activeTenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    if (-not $activeTenantId) {
        throw "No tenant_id found in memberships"
    }
    Write-Host "PASS: Active tenant resolved: $activeTenantId" -ForegroundColor Green
} catch {
    Write-Host "FAIL: Could not resolve active tenant: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Helper: find wedding-hall category id
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
 
# Test 0: Get or create a published canonical-priced listing
Write-Host "[0] Getting or creating published listing for testing..." -ForegroundColor Yellow
$listingId = $null
try {
    $categories = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/categories" -Method Get -TimeoutSec 10 -ErrorAction Stop
    $weddingHallCategoryId = FindCategoryInTree $categories "wedding-hall"
    if (-not $weddingHallCategoryId) {
        Write-Host "FAIL: wedding-hall category not found. Seed catalog first." -ForegroundColor Red
        exit 1
    }
 
    $listings = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings?category_id=$weddingHallCategoryId&status=published" -Method Get -TimeoutSec 10 -ErrorAction Stop
    $testListing = $listings | Where-Object { $_.tenant_id -eq $activeTenantId -and [double]($_.price) -gt 0 } | Select-Object -First 1
    if (-not $testListing) {
        $testListing = $listings | Where-Object { [double]($_.price) -gt 0 } | Select-Object -First 1
    }
    if ($testListing -and $testListing.id) {
        $listingId = $testListing.id
        Write-Host "PASS: Found existing published canonical-priced listing: $listingId" -ForegroundColor Green
        Write-Host "  Title: $($testListing.title)" -ForegroundColor Gray
        Write-Host "  Price: $($testListing.price) $($testListing.price_currency)" -ForegroundColor Gray
    } else {
        Write-Host "  No suitable listing found. Creating canonical-priced rental listing..." -ForegroundColor Yellow
        $createListingBody = @{
            category_id = $weddingHallCategoryId
            title = "Test Rental Listing (WP-7)"
            description = "Deterministic rental contract listing"
            price_amount = 15000
            currency = "TRY"
            transaction_modes = @("rental")
            attributes = @{
                capacity_max = 500
                city = "Istanbul"
                offer_variant = "rental"
                interaction_mode = "flow"
            }
        } | ConvertTo-Json -Compress
        $createHeaders = @{
            "Authorization" = $authHeader
            "X-Active-Tenant-Id" = $activeTenantId
            "Content-Type" = "application/json"
        }
        $createdListing = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings" -Method Post -Headers $createHeaders -Body $createListingBody -TimeoutSec 10 -ErrorAction Stop
        $listingId = if ($createdListing.id) { $createdListing.id } else { $createdListing.listing_id }
        Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings/$listingId/publish" -Method Post -Headers @{
            "Authorization" = $authHeader
            "X-Active-Tenant-Id" = $activeTenantId
        } -TimeoutSec 10 -ErrorAction Stop | Out-Null
        Write-Host "PASS: Created and published rental listing: $listingId" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Could not get listing for test: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
 
Write-Host ""
 
# Generate deterministic idempotency key base
$now = Get-Date
$idempotencyKey = "test-rental-key-" + $now.ToString("yyyyMMddHHmmss") + "-" + $now.Millisecond.ToString("D3")
 
# Test 1: Create rental -> PASS (201)
Write-Host "[1] Testing POST /api/v1/rentals (create rental)..." -ForegroundColor Yellow
$rentalId = $null
try {
    # Use future dates to avoid conflicts
    $baseOffset = 30
    $timeOffset = ([int](Get-Date).ToString("ss")) % 100
    $startDays = $baseOffset + ($timeOffset * 2)
    $endDays = $startDays + 3
 
    $startAt = (Get-Date).AddDays($startDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endAt = (Get-Date).AddDays($endDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
 
    $createRentalUrl = "$pazarBaseUrl/api/v1/rentals"
    $rentalBody = @{
        listing_id = $listingId
        start_at = $startAt
        end_at = $endAt
    } | ConvertTo-Json
 
    $headers = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $idempotencyKey
        "Authorization" = $authHeader
        "X-Requester-User-Id" = $userId
    }
 
    $resp = Invoke-RestMethod -Uri $createRentalUrl -Method Post -Body $rentalBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    if ($resp.id -and $resp.status -eq "requested" -and $resp.price_amount -and $resp.price_currency -and $resp.pricing_source -eq "listing") {
        $rentalId = $resp.id
        $providerTenantId = $resp.provider_tenant_id
        Write-Host "PASS: Rental created successfully" -ForegroundColor Green
        Write-Host "  Rental ID: $rentalId" -ForegroundColor Gray
        Write-Host "  Status: $($resp.status)" -ForegroundColor Gray
        Write-Host "  Price: $($resp.price_amount) $($resp.price_currency)" -ForegroundColor Gray
        Write-Host "  Pricing Source: $($resp.pricing_source)" -ForegroundColor Gray
        Write-Host "  Start: $($resp.start_at)" -ForegroundColor Gray
        Write-Host "  End: $($resp.end_at)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Rental creation returned invalid pricing snapshot response" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Create rental request failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}
 
Write-Host ""
 
# Test 2: Idempotency replay -> SAME rental id
if ($rentalId -and -not $hasFailures) {
    Write-Host "[2] Testing idempotency replay (same Idempotency-Key)..." -ForegroundColor Yellow
    try {
        $replayHeaders = @{
            "Content-Type" = "application/json"
            "Idempotency-Key" = $idempotencyKey
            "Authorization" = $authHeader
            "X-Requester-User-Id" = $userId
        }
        $replayBody = @{
            listing_id = $listingId
            start_at = $startAt
            end_at = $endAt
        } | ConvertTo-Json
 
        $replay = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/rentals" -Method Post -Body $replayBody -Headers $replayHeaders -TimeoutSec 10 -ErrorAction Stop
        if ($replay.id -eq $rentalId -and $replay.price_amount -and $replay.price_currency -and $replay.pricing_source -eq "listing") {
            Write-Host "PASS: Idempotency replay returned same rental ID" -ForegroundColor Green
            Write-Host "  Rental ID: $($replay.id)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Idempotency replay returned invalid rental snapshot" -ForegroundColor Red
            Write-Host "  Expected: $rentalId" -ForegroundColor Yellow
            Write-Host "  Got: $($replay.id)" -ForegroundColor Yellow
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Idempotency replay failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}
 
Write-Host ""
 
# Test 3: Overlap negative -> 409 CONFLICT
if ($rentalId -and -not $hasFailures) {
    Write-Host "[3] Testing overlap conflict (overlapping rental period)..." -ForegroundColor Yellow
    try {
        $overlapStartAt = (Get-Date).AddDays($startDays + 1).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $overlapEndAt = (Get-Date).AddDays($startDays + 2).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $overlapKey = "test-rental-overlap-" + $now.ToString("yyyyMMddHHmmss") + "-" + ($now.Millisecond + 100).ToString("D3")
 
        $overlapHeaders = @{
            "Content-Type" = "application/json"
            "Idempotency-Key" = $overlapKey
            "Authorization" = $authHeader
            "X-Requester-User-Id" = $userId
        }
        $overlapBody = @{
            listing_id = $listingId
            start_at = $overlapStartAt
            end_at = $overlapEndAt
        } | ConvertTo-Json
 
        # Should NOT succeed
        Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/rentals" -Method Post -Body $overlapBody -Headers $overlapHeaders -TimeoutSec 10 -ErrorAction Stop | Out-Null
        Write-Host "FAIL: Overlapping rental was accepted (expected 409)" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch { }
        if ($statusCode -eq 409) {
            Write-Host "PASS: Overlap conflict correctly returned 409 CONFLICT" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Overlap conflict returned unexpected status: $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
    }
}
 
Write-Host ""
 
# Test 4: Accept rental -> status=accepted
if ($rentalId -and -not $hasFailures) {
    Write-Host "[4] Testing POST /api/v1/rentals/{id}/accept (accept rental)..." -ForegroundColor Yellow
    try {
        if (-not $providerTenantId) {
            Write-Host "FAIL: provider_tenant_id not found on rental" -ForegroundColor Red
            $hasFailures = $true
        } else {
            $acceptHeaders = @{
                "X-Active-Tenant-Id" = $providerTenantId
                "Authorization" = $authHeader
            }
            $acceptResp = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/rentals/$rentalId/accept" -Method Post -Headers $acceptHeaders -TimeoutSec 10 -ErrorAction Stop
            if ($acceptResp.status -eq "accepted" -and $acceptResp.price_amount -and $acceptResp.price_currency -and $acceptResp.pricing_source -eq "listing") {
                Write-Host "PASS: Rental accepted successfully" -ForegroundColor Green
                Write-Host "  Status: $($acceptResp.status)" -ForegroundColor Gray
                Write-Host "  Price: $($acceptResp.price_amount) $($acceptResp.price_currency)" -ForegroundColor Gray
            } else {
                Write-Host "FAIL: Accept returned invalid pricing snapshot response" -ForegroundColor Red
                $hasFailures = $true
            }
        }
    } catch {
        Write-Host "FAIL: Accept rental request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}
 
Write-Host ""
 
# Test 5: Negative scope (accept without X-Active-Tenant-Id) -> 400
if ($rentalId -and -not $hasFailures) {
    Write-Host "[5] Testing negative scope (accept without X-Active-Tenant-Id)..." -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/rentals/$rentalId/accept" -Method Post -Headers @{ "Authorization" = $authHeader } -TimeoutSec 10 -ErrorAction Stop | Out-Null
        Write-Host "FAIL: Accept without X-Active-Tenant-Id was accepted (expected 400)" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch { }
        if ($statusCode -eq 400) {
            Write-Host "PASS: Missing header correctly returned 400" -ForegroundColor Green
            Write-Host "  Status Code: 400" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Missing header returned unexpected status: $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
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
