#!/usr/bin/env pwsh
# RESERVATION CONTRACT CHECK (WP-4)
# Verifies Reservation Spine API endpoints with idempotency and validation.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== RESERVATION CONTRACT CHECK (WP-4) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$hosBaseUrl = "http://localhost:3000"
$REQUEST_TIMEOUT_SEC = 30
$tenantId = $null
$authToken = $null
$listingId = $null
$offerId = $null
$reservationId = $null

# Load test_auth helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\test_auth.ps1") {
    . "${scriptDir}\_lib\test_auth.ps1"
} else {
    Write-Host "FAIL: test_auth.ps1 not found" -ForegroundColor Red
    exit 1
}

# Helper: Extract tenant_id robustly from memberships
function Get-TenantIdFromMemberships {
    param([object]$Memberships)
    
    if (-not $Memberships) {
        return $null
    }
    
    $membershipsArray = $null
    
    if ($Memberships -is [Array]) {
        $membershipsArray = $Memberships
    }
    elseif ($Memberships -is [PSCustomObject]) {
        if ($Memberships.PSObject.Properties['items'] -and $Memberships.items -is [Array]) {
            $membershipsArray = $Memberships.items
        }
        elseif ($Memberships.PSObject.Properties['data'] -and $Memberships.data -is [Array]) {
            $membershipsArray = $Memberships.data
        }
    }
    elseif ($Memberships.items -is [Array]) {
        $membershipsArray = $Memberships.items
    }
    elseif ($Memberships.data -is [Array]) {
        $membershipsArray = $Memberships.data
    }
    
    if (-not $membershipsArray) {
        return $null
    }
    
    if ($membershipsArray.Count -eq 0) {
        return $null
    }
    
    foreach ($membership in $membershipsArray) {
        $tid = $null
        
        if ($membership.tenant_id) {
            $tid = $membership.tenant_id
        }
        elseif ($membership.tenant -and $membership.tenant.id) {
            $tid = $membership.tenant.id
        }
        elseif ($membership.tenant -and $membership.tenant.PSObject.Properties['id']) {
            $tid = $membership.tenant.id
        }
        elseif ($membership.tenantId) {
            $tid = $membership.tenantId
        }
        elseif ($membership.store_tenant_id) {
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

# Helper: Create reservation with retry on 409 CONFLICT (slot overlap)
function New-HighEntropySlotWindow {
    param(
        [int]$DaysAhead,
        [int]$DurationHours
    )
    $now = Get-Date
    $guid = [System.Guid]::NewGuid().ToString("N")
    $hash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($guid))
    $offset = [Math]::Abs([BitConverter]::ToInt32($hash, 0)) % 200000  # spread across many days
    $base = $now.AddDays($DaysAhead).AddMinutes($offset)
    $start = $base.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $end = $base.AddHours($DurationHours).ToString("yyyy-MM-ddTHH:mm:ssZ")
    return @{ slot_start = $start; slot_end = $end }
}

function Invoke-CreateReservationWithRetry {
    param(
        [string]$PazarBaseUrl,
        [string]$AuthToken,
        [string]$ListingId,
        [int]$PartySize,
        [string]$OfferId,
        [string]$IdempotencyPrefix,
        [int]$DaysAhead = 90,
        [int]$DurationHours = 4,
        [int]$MaxAttempts = 6
    )
    $url = "${PazarBaseUrl}/api/v1/reservations"
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        $now = Get-Date
        $key = "${IdempotencyPrefix}-" + $now.ToString("yyyyMMddHHmmss") + "-" + $now.Millisecond.ToString("D3") + "-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
        $slot = New-HighEntropySlotWindow -DaysAhead $DaysAhead -DurationHours $DurationHours
        $bodyObj = @{
            listing_id = $ListingId
            slot_start = $slot.slot_start
            slot_end = $slot.slot_end
            party_size = $PartySize
        }
        if ($OfferId) { $bodyObj.offer_id = $OfferId }
        $body = $bodyObj | ConvertTo-Json
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $AuthToken
            "Idempotency-Key" = $key
        }
        try {
            $resp = Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $headers -TimeoutSec $REQUEST_TIMEOUT_SEC -ErrorAction Stop
            return @{ response = $resp; body = $body; idempotency_key = $key; slot_start = $slot.slot_start; slot_end = $slot.slot_end }
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
            }
            if ($statusCode -eq 409) {
                # slot overlap; retry with a different slot/key
                continue
            }
            throw
        }
    }
    throw "Could not create reservation without slot conflict after $MaxAttempts attempts"
}

# Bootstrap JWT token and get tenant_id
Write-Host "[PREP] Acquiring JWT token and tenant_id..." -ForegroundColor Yellow
try {
    $apiKey = $env:HOS_API_KEY
    if (-not $apiKey) {
        $apiKey = "dev-api-key"
    }
    $jwtToken = Get-DevTestJwtToken -HosApiKey $apiKey
    if (-not $jwtToken) {
        throw "Failed to obtain JWT token"
    }
    $authToken = "Bearer $jwtToken"
    $tokenMask = if ($jwtToken.Length -gt 6) { "***" + $jwtToken.Substring($jwtToken.Length - 6) } else { "***" }
    Write-Host "PASS: Token acquired ($tokenMask)" -ForegroundColor Green
    
    # Get tenant_id from memberships (for listing creation)
    $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" `
        -Headers @{ "Authorization" = $authToken } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    
    if (-not $tenantId) {
        Write-Host "  No valid tenant_id found, bootstrapping via admin API..." -ForegroundColor Yellow
        $apiKey = $env:HOS_API_KEY
        if (-not $apiKey) { $apiKey = "dev-api-key" }
        $upsertBody = @{
            tenantSlug = "tenant-a"
            userEmail  = "testuser@example.com"
            role       = "owner"
        } | ConvertTo-Json

        $upsertReq = Invoke-WebRequest -Uri "$hosBaseUrl/v1/admin/memberships/upsert" `
            -Method Post `
            -Body $upsertBody `
            -ContentType "application/json" `
            -Headers @{ "x-hos-api-key" = $apiKey } `
            -TimeoutSec 10 `
            -ErrorAction Stop

        $upsertResp = $upsertReq.Content | ConvertFrom-Json
        if (-not $upsertResp.tenant_id) {
            throw "Membership bootstrap failed (admin upsert missing tenant_id)"
        }

        $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" `
            -Headers @{ "Authorization" = $authToken } `
            -TimeoutSec 5 `
            -ErrorAction Stop
        $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    }
    
    if (-not $tenantId) {
        Write-Host "FAIL: No valid tenant_id found in memberships. HOS not running or login failed." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "PASS: tenant_id acquired: $tenantId" -ForegroundColor Green
} catch {
    Write-Host "FAIL: JWT token or tenant_id acquisition failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Remediation: Ensure H-OS service is running: docker compose ps" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Generate deterministic idempotency key based on timestamp
# Include milliseconds to ensure uniqueness across back-to-back runs
$now = Get-Date
$idempotencyKey = "test-reservation-key-" + $now.ToString("yyyyMMddHHmmss") + "-" + $now.Millisecond.ToString("D3")

# Clean up old test reservations from previous runs (to avoid slot conflicts)
# Only clean reservations with our test listing pattern
Write-Host "[PREP] Cleaning up old test reservations..." -ForegroundColor Gray
try {
    # Get test listing ID first (if exists)
    $testListingSearch = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings?status=published" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($testListingSearch -is [Array] -and $testListingSearch.Count -gt 0) {
        $testListing = $testListingSearch | Where-Object { $_.title -like "*WP-4.1*" } | Select-Object -First 1
        if ($testListing) {
            # Delete old reservations for this listing (via API or direct DB - using API for safety)
            # Note: This is a cleanup step, not a test requirement
            Write-Host "  Found test listing, old reservations will be handled by idempotency/overlap checks" -ForegroundColor Gray
        }
    }
} catch {
    # Ignore cleanup errors
}
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

# Try to find existing published listing in wedding-hall category
$searchUrl = "${pazarBaseUrl}/api/v1/listings?category_id=${weddingHallCategoryId}&status=published"
try {
    $listingsResponse = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    $createFreshListing = $true

    if ($listingsResponse -is [Array] -and $listingsResponse.Count -gt 0) {
        # Prefer a listing owned by our active tenant so we can attach offers/packages.
        $owned = $listingsResponse | Where-Object { $_.tenant_id -eq $tenantId -and [double]($_.price) -gt 0 } | Select-Object -First 1
        $picked = $owned
        if (-not $picked) {
            $picked = $listingsResponse | Where-Object { [double]($_.price) -gt 0 } | Select-Object -First 1
        }
        if ($picked) {
            $createFreshListing = $false
            $listingId = $picked.id
            Write-Host "PASS: Found existing published canonical-priced listing: $listingId" -ForegroundColor Green
            Write-Host "  Title: $($picked.title)" -ForegroundColor Gray
            Write-Host "  Price: $($picked.price) $($picked.price_currency)" -ForegroundColor Gray
            Write-Host "  Capacity Max: $($picked.attributes.capacity_max)" -ForegroundColor Gray
            if ($picked.tenant_id -ne $tenantId) {
                Write-Host "  WARN: Picked listing is not owned by active tenant; offer (package) create may fail. Will create our own listing if needed." -ForegroundColor Yellow
            }
        }
    }

    if ($createFreshListing) {
        # Create a new listing if none exists
        Write-Host "  No suitable canonical-priced listing found. Creating new listing..." -ForegroundColor Yellow
        $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
        $listingBody = @{
            category_id = $weddingHallCategoryId
            title = "Test Wedding Hall Listing (WP-4.1)"
            description = "Deterministic test listing for reservation contract check"
            price_amount = 50000
            currency = "TRY"
            transaction_modes = @("reservation")
            attributes = @{
                capacity_max = 500
                city = "Istanbul"
                offer_variant = "reservation"
                interaction_mode = "flow"
            }
        } | ConvertTo-Json -Compress
        
        $listingHeaders = @{
            "Authorization" = $authToken
            "X-Active-Tenant-Id" = $tenantId
            "Content-Type" = "application/json"
        }
        
        try {
            $createListingResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Headers $listingHeaders -Body $listingBody -TimeoutSec 10 -ErrorAction Stop
            
            # Response might have 'id' or 'listing_id' field
            if ($createListingResponse.id) {
                $listingId = $createListingResponse.id
            } elseif ($createListingResponse.listing_id) {
                $listingId = $createListingResponse.listing_id
            } else {
                throw "Response missing listing ID"
            }
            
            # Publish the listing
            $publishUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}/publish"
            $publishHeaders = @{
                "Authorization" = $authToken
                "X-Active-Tenant-Id" = $tenantId
            }
            Invoke-RestMethod -Uri $publishUrl -Method Post -Headers $publishHeaders -TimeoutSec 10 -ErrorAction Stop | Out-Null
            
            Write-Host "PASS: Created and published listing: $listingId" -ForegroundColor Green
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                try {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                } catch {
                }
            }
            Write-Host "FAIL: Could not create listing: $($_.Exception.Message)" -ForegroundColor Red
            if ($statusCode) {
                Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
            }
            $hasFailures = $true
        }
    }
} catch {
    Write-Host "FAIL: Could not get/create listings: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

if (-not $listingId) {
    Write-Host "SKIP: Cannot continue without a published listing" -ForegroundColor Yellow
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
}

Write-Host ""

# MVP: Create a package offer for the listing (offer_id)
# This enables reservation to reference the selected package.
Write-Host "[0b] Creating a package offer for reservation (offer_id)..." -ForegroundColor Yellow
try {
    $offerKey = "test-offer-" + (Get-Date).ToString("yyyyMMddHHmmss") + "-" + (Get-Date).Millisecond.ToString("D3")
    $offerCode = "pkg-" + (Get-Date).ToString("yyyyMMddHHmmss") + "-" + (Get-Date).Millisecond.ToString("D3")
    $offerBody = @{
        code = $offerCode
        name = "Test Package (WP-4)"
        price_amount = 100000
        price_currency = "TRY"
        billing_model = "one_time"
        # Keep attributes null in contract check to avoid any hardcoded package content.
        attributes = $null
    } | ConvertTo-Json -Compress

    $offerHeaders = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "X-Active-Tenant-Id" = $tenantId
        "Idempotency-Key" = $offerKey
    }

    $offerResp = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings/${listingId}/offers" -Method Post -Headers $offerHeaders -Body $offerBody -TimeoutSec 10 -ErrorAction Stop
    if ($offerResp -and $offerResp.id) {
        $offerId = $offerResp.id
        Write-Host "PASS: Offer created for listing" -ForegroundColor Green
        Write-Host "  Offer ID: $offerId" -ForegroundColor Gray
    } else {
        Write-Host "WARN: Offer create returned invalid response; continuing without offer_id" -ForegroundColor Yellow
        $offerId = $null
    }
} catch {
    # If the picked listing is not owned by tenant, offer create will 403.
    # In that case, create our own listing+publish and retry once.
    $statusCode = $null
    if ($_.Exception.Response) {
        try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
    }
    if ($statusCode -eq 403) {
        Write-Host "WARN: Offer create forbidden (listing not owned). Creating our own published listing and retrying..." -ForegroundColor Yellow
        try {
            # Create+publish a fresh listing owned by this tenant
            $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
            $listingBody = @{
                category_id = $weddingHallCategoryId
                title = "Test Wedding Hall Listing (WP-4.1 Owned)"
                description = "Owned listing for reservation+offer linking"
                transaction_modes = @("reservation")
                attributes = @{
                    capacity_max = 500
                    city = "Istanbul"
                }
            } | ConvertTo-Json -Compress
            $listingHeaders = @{
                "Authorization" = $authToken
                "X-Active-Tenant-Id" = $tenantId
                "Content-Type" = "application/json"
            }
            $createListingResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Headers $listingHeaders -Body $listingBody -TimeoutSec 10 -ErrorAction Stop
            $listingId = $createListingResponse.id
            Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings/${listingId}/publish" -Method Post -Headers @{ "Authorization" = $authToken; "X-Active-Tenant-Id" = $tenantId } -TimeoutSec 10 -ErrorAction Stop | Out-Null

            # Retry offer create
            $offerKey = "test-offer-" + (Get-Date).ToString("yyyyMMddHHmmss") + "-" + (Get-Date).Millisecond.ToString("D3")
            $offerHeaders = @{
                "Content-Type" = "application/json"
                "Authorization" = $authToken
                "X-Active-Tenant-Id" = $tenantId
                "Idempotency-Key" = $offerKey
            }
            $offerBody = @{
                code = $offerCode
                name = "Test Package (WP-4)"
                price_amount = 100000
                price_currency = "TRY"
                billing_model = "one_time"
                attributes = $null
            } | ConvertTo-Json -Compress
            $offerResp = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings/${listingId}/offers" -Method Post -Headers $offerHeaders -Body $offerBody -TimeoutSec 10 -ErrorAction Stop
            if ($offerResp -and $offerResp.id) {
                $offerId = $offerResp.id
                Write-Host "PASS: Offer created for owned listing" -ForegroundColor Green
                Write-Host "  Offer ID: $offerId" -ForegroundColor Gray
            } else {
                Write-Host "WARN: Offer create returned invalid response after retry; continuing without offer_id" -ForegroundColor Yellow
                $offerId = $null
            }
        } catch {
            Write-Host "WARN: Could not create owned listing/offer: $($_.Exception.Message) (continuing without offer_id)" -ForegroundColor Yellow
            $offerId = $null
        }
    } else {
        Write-Host "WARN: Could not create offer: $($_.Exception.Message) (continuing without offer_id)" -ForegroundColor Yellow
        $offerId = $null
    }
}

Write-Host ""

# Test 1: Create reservation (party_size <= capacity_max) => PASS 201
Write-Host "[1] Testing POST /api/v1/reservations (party_size <= capacity_max)..." -ForegroundColor Yellow
$createReservationUrl = "${pazarBaseUrl}/api/v1/reservations"

$partySize = 100  # Should be <= capacity_max

try {
    $created = Invoke-CreateReservationWithRetry -PazarBaseUrl $pazarBaseUrl -AuthToken $authToken -ListingId $listingId -PartySize $partySize -OfferId $offerId -IdempotencyPrefix "test-reservation-key" -DaysAhead 120 -DurationHours 4 -MaxAttempts 8
    $createResponse = $created.response
    $reservationBody = $created.body
    $idempotencyKey = $created.idempotency_key
    $slotStart = $created.slot_start
    $slotEnd = $created.slot_end
    
    if (-not $createResponse.id) {
        Write-Host "FAIL: Create reservation response missing 'id'" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($createResponse.status -ne "requested") {
        Write-Host "FAIL: Expected status='requested', got '$($createResponse.status)'" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($offerId -and $createResponse.offer_id -ne $offerId) {
        Write-Host "FAIL: Expected offer_id to match created offer" -ForegroundColor Red
        Write-Host "  Expected: $offerId" -ForegroundColor Yellow
        Write-Host "  Got: $($createResponse.offer_id)" -ForegroundColor Yellow
        $hasFailures = $true
    } elseif (-not $createResponse.price_amount) {
        Write-Host "FAIL: Create reservation response missing price_amount snapshot" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $createResponse.price_currency) {
        Write-Host "FAIL: Create reservation response missing price_currency snapshot" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($offerId -and $createResponse.pricing_source -ne 'offer') {
        Write-Host "FAIL: Expected pricing_source='offer' when offer_id is used" -ForegroundColor Red
        $hasFailures = $true
    } elseif ((-not $offerId) -and $createResponse.pricing_source -ne 'listing') {
        Write-Host "FAIL: Expected pricing_source='listing' when no offer_id is used" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $reservationId = $createResponse.id
        Write-Host "PASS: Reservation created successfully" -ForegroundColor Green
        Write-Host "  Reservation ID: $reservationId" -ForegroundColor Gray
        Write-Host "  Status: $($createResponse.status)" -ForegroundColor Gray
        Write-Host "  Party Size: $($createResponse.party_size)" -ForegroundColor Gray
        Write-Host "  Price: $($createResponse.price_amount) $($createResponse.price_currency)" -ForegroundColor Gray
        Write-Host "  Pricing Source: $($createResponse.pricing_source)" -ForegroundColor Gray
        if ($offerId) {
            Write-Host "  Offer ID: $($createResponse.offer_id)" -ForegroundColor Gray
        }
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    Write-Host "FAIL: Create reservation request failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($statusCode) {
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

Write-Host ""

# Test 1b: Verify messaging thread created (WP-5 integration)
Write-Host "[1b] Testing Messaging thread creation for reservation..." -ForegroundColor Yellow
if ($reservationId) {
    try {
        $messagingBaseUrl = "http://localhost:8090"
        $apiKey = "dev-messaging-key"
        $byContextHeaders = @{
            "messaging-api-key" = $apiKey
        }
        
        $byContextUrl = "${messagingBaseUrl}/api/v1/threads/by-context?context_type=reservation&context_id=$reservationId"
        $messagingResponse = Invoke-RestMethod -Uri $byContextUrl -Method Get -Headers $byContextHeaders -TimeoutSec 5 -ErrorAction Stop
        
        if ($messagingResponse.thread_id) {
            Write-Host "PASS: Messaging thread exists for reservation" -ForegroundColor Green
            Write-Host "  Thread ID: $($messagingResponse.thread_id)" -ForegroundColor Gray
            Write-Host "  Context: reservation / $reservationId" -ForegroundColor Gray
            Write-Host "  Participants: $($messagingResponse.participants.Count)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Messaging thread not found for reservation" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        Write-Host "FAIL: Could not verify messaging thread: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Note: Messaging service may be unavailable, but thread should exist if service is up" -ForegroundColor Yellow
        $hasFailures = $true
    }
} else {
    Write-Host "SKIP: Cannot verify messaging thread (reservation ID not available)" -ForegroundColor Yellow
}
Write-Host ""

# Test 2: Replay same request with same Idempotency-Key => PASS same reservation id
if ($reservationId) {
    Write-Host "[2] Testing POST /api/v1/reservations (idempotency replay)..." -ForegroundColor Yellow
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            "Idempotency-Key" = $idempotencyKey
        }
        $replayResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $reservationBody -Headers $headers -TimeoutSec $REQUEST_TIMEOUT_SEC -ErrorAction Stop
        
        if ($replayResponse.id -ne $reservationId) {
            Write-Host "FAIL: Idempotency replay returned different reservation ID" -ForegroundColor Red
            Write-Host "  Expected: $reservationId" -ForegroundColor Yellow
            Write-Host "  Got: $($replayResponse.id)" -ForegroundColor Yellow
            $hasFailures = $true
        } else {
            Write-Host "PASS: Idempotency replay returned same reservation ID" -ForegroundColor Green
            Write-Host "  Reservation ID: $($replayResponse.id)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "FAIL: Idempotency replay request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
} else {
    Write-Host "[2] SKIP: Cannot test idempotency (reservation ID not available)" -ForegroundColor Yellow
}

Write-Host ""

# Test 3: Create conflict reservation same slot => PASS 409
Write-Host "[3] Testing POST /api/v1/reservations (conflict - same slot)..." -ForegroundColor Yellow
$conflictIdempotencyKey = "test-conflict-key-" + (Get-Date -Format "yyyyMMddHHmmss")
# Use the SAME slot as test 1 to create a conflict (but different idempotency key).
# If Test-1 failed, slotStart/slotEnd will be null; in that case skip this test to avoid false failures.
if (-not $slotStart -or -not $slotEnd) {
    Write-Host "SKIP: Cannot test conflict (slotStart/slotEnd not available; create step failed)" -ForegroundColor Yellow
} else {
    $conflictBody = @{
        listing_id = $listingId
        slot_start = $slotStart
        slot_end = $slotEnd
        party_size = 50
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            "Idempotency-Key" = $conflictIdempotencyKey
        }
        $conflictResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $conflictBody -Headers $headers -TimeoutSec $REQUEST_TIMEOUT_SEC -ErrorAction Stop
        Write-Host "FAIL: Conflict reservation should have failed but succeeded" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        if ($statusCode -eq 409) {
            Write-Host "PASS: Conflict reservation correctly rejected (status: 409)" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Expected 409 CONFLICT, got status: $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
    }
}

Write-Host ""

# Test 4: Create reservation with party_size > capacity_max => PASS 422 (VALIDATION_ERROR)
Write-Host "[4] Testing POST /api/v1/reservations (party_size > capacity_max)..." -ForegroundColor Yellow
$invalidIdempotencyKey = "test-invalid-key-" + (Get-Date -Format "yyyyMMddHHmmss")
    # Use different slot window (31 days + different hour) to avoid conflicts
    $invalidTestNow = Get-Date
    $invalidIdempotencyHash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($invalidIdempotencyKey))
    $invalidSlotOffsetMinutes = [BitConverter]::ToInt32($invalidIdempotencyHash, 4) % 1440  # Use different hash bytes
    if ($invalidSlotOffsetMinutes -lt 0) { $invalidSlotOffsetMinutes += 1440 }
    $invalidSlotBase = $invalidTestNow.AddDays(91).AddHours(2).AddMinutes($invalidSlotOffsetMinutes)
    $invalidSlotStart = $invalidSlotBase.Date.AddHours($invalidSlotBase.Hour).AddMinutes($invalidSlotBase.Minute).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $invalidSlotEnd = $invalidSlotBase.Date.AddHours($invalidSlotBase.Hour).AddMinutes($invalidSlotBase.Minute).AddHours(4).ToString("yyyy-MM-ddTHH:mm:ssZ")
$invalidBody = @{
    listing_id = $listingId
    slot_start = $invalidSlotStart
    slot_end = $invalidSlotEnd
    party_size = 10000  # Way over capacity_max
} | ConvertTo-Json

try {
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "Idempotency-Key" = $invalidIdempotencyKey
    }
    $invalidResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $invalidBody -Headers $headers -TimeoutSec $REQUEST_TIMEOUT_SEC -ErrorAction Stop
    Write-Host "FAIL: Invalid reservation should have failed but succeeded" -ForegroundColor Red
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
        } catch {
        }
    }
    if ($statusCode -eq 422) {
        if ($errorResponse -and $errorResponse.error -eq "VALIDATION_ERROR") {
            Write-Host "PASS: Invalid reservation correctly rejected (status: 422, VALIDATION_ERROR)" -ForegroundColor Green
            Write-Host "  Error: $($errorResponse.message)" -ForegroundColor Gray
        } else {
            Write-Host "PASS: Invalid reservation correctly rejected (status: 422)" -ForegroundColor Green
        }
    } else {
        Write-Host "FAIL: Expected 422 VALIDATION_ERROR, got status: $statusCode" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 5: Accept with correct X-Active-Tenant-Id => PASS
# Create a fresh reservation for accept test (to avoid conflicts from previous runs)
if ($listingId) {
    Write-Host "[5] Testing POST /api/v1/reservations/{id}/accept (correct tenant)..." -ForegroundColor Yellow
    
    try {
        $acceptCreated = Invoke-CreateReservationWithRetry -PazarBaseUrl $pazarBaseUrl -AuthToken $authToken -ListingId $listingId -PartySize 50 -OfferId $null -IdempotencyPrefix "test-accept-key" -DaysAhead 140 -DurationHours 4 -MaxAttempts 8
        $acceptTestCreateResponse = $acceptCreated.response
        $acceptTestReservationId = $acceptTestCreateResponse.id
        
        # Now test accept
        $acceptUrl = "${pazarBaseUrl}/api/v1/reservations/${acceptTestReservationId}/accept"
        
        # Get listing to find provider_tenant_id
        $listingResponse = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings/${listingId}" -Method Get -TimeoutSec 10 -ErrorAction Stop
        $providerTenantId = $listingResponse.tenant_id
        
        $acceptHeaders = @{
            "Authorization" = $authToken
            "X-Active-Tenant-Id" = $providerTenantId
        }
        $acceptResponse = Invoke-RestMethod -Uri $acceptUrl -Method Post -Headers $acceptHeaders -TimeoutSec $REQUEST_TIMEOUT_SEC -ErrorAction Stop
        
        if ($acceptResponse.status -ne "accepted") {
            Write-Host "FAIL: Expected status='accepted', got '$($acceptResponse.status)'" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Reservation accepted successfully" -ForegroundColor Green
            Write-Host "  Status: $($acceptResponse.status)" -ForegroundColor Gray
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Accept reservation request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[5] SKIP: Cannot test accept (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 6: Accept with missing/incorrect tenant header => PASS reject (400/403)
# Use the reservation from test 5 (if it exists) or create a fresh one
if ($listingId) {
    Write-Host "[6] Testing POST /api/v1/reservations/{id}/accept (missing header)..." -ForegroundColor Yellow
    
    try {
        $rejectCreated = Invoke-CreateReservationWithRetry -PazarBaseUrl $pazarBaseUrl -AuthToken $authToken -ListingId $listingId -PartySize 50 -OfferId $null -IdempotencyPrefix "test-reject-key" -DaysAhead 150 -DurationHours 4 -MaxAttempts 8
        $rejectTestCreateResponse = $rejectCreated.response
        $rejectTestReservationId = $rejectTestCreateResponse.id
        
        # Now test reject (missing header)
        $acceptUrl = "${pazarBaseUrl}/api/v1/reservations/${rejectTestReservationId}/accept"
        
        try {
            $headers = @{
                # No X-Active-Tenant-Id header
            }
            $rejectResponse = Invoke-RestMethod -Uri $acceptUrl -Method Post -Headers $headers -TimeoutSec $REQUEST_TIMEOUT_SEC -ErrorAction Stop
            Write-Host "FAIL: Request without header should have failed but succeeded" -ForegroundColor Red
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
                Write-Host "PASS: Request without header correctly rejected (status: $statusCode)" -ForegroundColor Green
            } else {
                Write-Host "FAIL: Expected 400/403, got status: $statusCode" -ForegroundColor Red
                $hasFailures = $true
            }
        }
    } catch {
        Write-Host "FAIL: Could not create reservation for reject test: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
} else {
    Write-Host "[6] SKIP: Cannot test reject (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== RESERVATION CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== RESERVATION CONTRACT CHECK: PASS ===" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

