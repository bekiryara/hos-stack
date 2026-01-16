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
$tenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic UUID for tenant-demo
$listingId = $null
$reservationId = $null

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
    
    if ($listingsResponse -is [Array] -and $listingsResponse.Count -gt 0) {
        $listingId = $listingsResponse[0].id
        Write-Host "PASS: Found existing published listing: $listingId" -ForegroundColor Green
        Write-Host "  Title: $($listingsResponse[0].title)" -ForegroundColor Gray
        Write-Host "  Capacity Max: $($listingsResponse[0].attributes.capacity_max)" -ForegroundColor Gray
    } else {
        # Create a new listing if none exists
        Write-Host "  No published listing found. Creating new listing..." -ForegroundColor Yellow
        $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
        $listingBody = @{
            category_id = $weddingHallCategoryId
            title = "Test Wedding Hall Listing (WP-4.1)"
            description = "Deterministic test listing for reservation contract check"
            transaction_modes = @("reservation")
            attributes = @{
                capacity_max = 500
                city = "Istanbul"
            }
        } | ConvertTo-Json -Compress
        
        $listingHeaders = @{
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
            Invoke-RestMethod -Uri $publishUrl -Method Post -Headers $listingHeaders -TimeoutSec 10 -ErrorAction Stop | Out-Null
            
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

# Test 1: Create reservation (party_size <= capacity_max) => PASS 201
Write-Host "[1] Testing POST /api/v1/reservations (party_size <= capacity_max)..." -ForegroundColor Yellow
$createReservationUrl = "${pazarBaseUrl}/api/v1/reservations"

# Generate unique future slot window: now + 30 days + unique offset
# Use idempotency key hash to ensure uniqueness across runs
$testNow = Get-Date
# Create unique offset based on idempotency key hash (ensures each run gets unique slot)
$idempotencyHash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($idempotencyKey))
$slotOffsetMinutes = [BitConverter]::ToInt32($idempotencyHash, 0) % 1440  # 0-1439 minutes (24 hours)
if ($slotOffsetMinutes -lt 0) { $slotOffsetMinutes += 1440 }  # Ensure positive
$slotBase = $testNow.AddDays(90).AddMinutes($slotOffsetMinutes)
$slotStart = $slotBase.Date.AddHours($slotBase.Hour).AddMinutes($slotBase.Minute).ToString("yyyy-MM-ddTHH:mm:ssZ")
$slotEnd = $slotBase.Date.AddHours($slotBase.Hour).AddMinutes($slotBase.Minute).AddHours(4).ToString("yyyy-MM-ddTHH:mm:ssZ")
$partySize = 100  # Should be <= capacity_max

$reservationBody = @{
    listing_id = $listingId
    slot_start = $slotStart
    slot_end = $slotEnd
    party_size = $partySize
} | ConvertTo-Json

try {
    $headers = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $idempotencyKey
    }
    $createResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $reservationBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $createResponse.id) {
        Write-Host "FAIL: Create reservation response missing 'id'" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($createResponse.status -ne "requested") {
        Write-Host "FAIL: Expected status='requested', got '$($createResponse.status)'" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $reservationId = $createResponse.id
        Write-Host "PASS: Reservation created successfully" -ForegroundColor Green
        Write-Host "  Reservation ID: $reservationId" -ForegroundColor Gray
        Write-Host "  Status: $($createResponse.status)" -ForegroundColor Gray
        Write-Host "  Party Size: $($createResponse.party_size)" -ForegroundColor Gray
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
            "Idempotency-Key" = $idempotencyKey
        }
        $replayResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $reservationBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
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
    $hasFailures = $true
}

Write-Host ""

# Test 3: Create conflict reservation same slot => PASS 409
Write-Host "[3] Testing POST /api/v1/reservations (conflict - same slot)..." -ForegroundColor Yellow
$conflictIdempotencyKey = "test-conflict-key-" + (Get-Date -Format "yyyyMMddHHmmss")
# Use the SAME slot as test 1 to create a conflict (but different idempotency key)
$conflictBody = @{
    listing_id = $listingId
    slot_start = $slotStart
    slot_end = $slotEnd
    party_size = 50
} | ConvertTo-Json

try {
    $headers = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = $conflictIdempotencyKey
    }
    $conflictResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $conflictBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
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
        "Idempotency-Key" = $invalidIdempotencyKey
    }
    $invalidResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $invalidBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
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
    
    # Create a fresh reservation for accept test (different slot, different idempotency key)
    # Use high-entropy slot generation to avoid conflicts with existing reservations
    $acceptTestNow = Get-Date
    $acceptTestIdempotencyKey = "test-accept-key-" + $acceptTestNow.ToString("yyyyMMddHHmmss") + "-" + $acceptTestNow.Millisecond.ToString("D3") + "-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    # Use timestamp + random offset for unique slot (ensures each run gets different slot)
    $acceptTotalSeconds = (($acceptTestNow.Hour * 3600) + ($acceptTestNow.Minute * 60) + $acceptTestNow.Second + $acceptTestNow.Millisecond / 1000.0)
    $acceptSlotOffsetMinutes = ([Math]::Floor($acceptTotalSeconds / 60) + ([System.Guid]::NewGuid().GetHashCode() % 1000)) % 1440
    $acceptTestSlotBase = $acceptTestNow.AddDays(92).AddHours(1).AddMinutes($acceptSlotOffsetMinutes)
    $acceptTestSlotStart = $acceptTestSlotBase.Date.AddHours($acceptTestSlotBase.Hour).AddMinutes($acceptTestSlotBase.Minute).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $acceptTestSlotEnd = $acceptTestSlotBase.Date.AddHours($acceptTestSlotBase.Hour).AddMinutes($acceptTestSlotBase.Minute).AddHours(4).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $acceptTestReservationBody = @{
        listing_id = $listingId
        slot_start = $acceptTestSlotStart
        slot_end = $acceptTestSlotEnd
        party_size = 50
    } | ConvertTo-Json
    
    try {
        # Create reservation for accept test
        $acceptTestHeaders = @{
            "Content-Type" = "application/json"
            "Idempotency-Key" = $acceptTestIdempotencyKey
        }
        $acceptTestCreateResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $acceptTestReservationBody -Headers $acceptTestHeaders -TimeoutSec 10 -ErrorAction Stop
        $acceptTestReservationId = $acceptTestCreateResponse.id
        
        # Now test accept
        $acceptUrl = "${pazarBaseUrl}/api/v1/reservations/${acceptTestReservationId}/accept"
        
        # Get listing to find provider_tenant_id
        $listingResponse = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings/${listingId}" -Method Get -TimeoutSec 10 -ErrorAction Stop
        $providerTenantId = $listingResponse.tenant_id
        
        $acceptHeaders = @{
            "X-Active-Tenant-Id" = $providerTenantId
        }
        $acceptResponse = Invoke-RestMethod -Uri $acceptUrl -Method Post -Headers $acceptHeaders -TimeoutSec 10 -ErrorAction Stop
        
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
    
    # Create a fresh reservation for reject test (different slot, different idempotency key)
    # Use high-entropy slot generation to avoid conflicts with existing reservations
    $rejectTestNow = Get-Date
    $rejectTestIdempotencyKey = "test-reject-key-" + $rejectTestNow.ToString("yyyyMMddHHmmss") + "-" + $rejectTestNow.Millisecond.ToString("D3") + "-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    # Use timestamp + random offset for unique slot (ensures each run gets different slot)
    $rejectTotalSeconds = (($rejectTestNow.Hour * 3600) + ($rejectTestNow.Minute * 60) + $rejectTestNow.Second + $rejectTestNow.Millisecond / 1000.0)
    $rejectSlotOffsetMinutes = ([Math]::Floor($rejectTotalSeconds / 60) + ([System.Guid]::NewGuid().GetHashCode() % 1000)) % 1440
    $rejectTestSlotBase = $rejectTestNow.AddDays(93).AddHours(2).AddMinutes($rejectSlotOffsetMinutes)
    $rejectTestSlotStart = $rejectTestSlotBase.Date.AddHours($rejectTestSlotBase.Hour).AddMinutes($rejectTestSlotBase.Minute).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $rejectTestSlotEnd = $rejectTestSlotBase.Date.AddHours($rejectTestSlotBase.Hour).AddMinutes($rejectTestSlotBase.Minute).AddHours(4).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $rejectTestReservationBody = @{
        listing_id = $listingId
        slot_start = $rejectTestSlotStart
        slot_end = $rejectTestSlotEnd
        party_size = 50
    } | ConvertTo-Json
    
    try {
        # Create reservation for reject test
        $rejectTestHeaders = @{
            "Content-Type" = "application/json"
            "Idempotency-Key" = $rejectTestIdempotencyKey
        }
        $rejectTestCreateResponse = Invoke-RestMethod -Uri $createReservationUrl -Method Post -Body $rejectTestReservationBody -Headers $rejectTestHeaders -TimeoutSec 10 -ErrorAction Stop
        $rejectTestReservationId = $rejectTestCreateResponse.id
        
        # Now test reject (missing header)
        $acceptUrl = "${pazarBaseUrl}/api/v1/reservations/${rejectTestReservationId}/accept"
        
        try {
            $headers = @{
                # No X-Active-Tenant-Id header
            }
            $rejectResponse = Invoke-RestMethod -Uri $acceptUrl -Method Post -Headers $headers -TimeoutSec 10 -ErrorAction Stop
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

