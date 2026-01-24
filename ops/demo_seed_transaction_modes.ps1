# Demo Seed Transaction Modes (WP-63)
# Creates 3 published listings with different transaction mode combinations
# Uses APIs only (no direct DB writes), idempotent

$ErrorActionPreference = "Stop"

Write-Host "=== DEMO SEED TRANSACTION MODES (WP-63) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$hosBaseUrl = "http://localhost:3000"

# Helper: Extract tenant_id from memberships (reused from demo_seed_root_listings)
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
    
    if (-not $membershipsArray -or $membershipsArray.Count -eq 0) {
        return $null
    }
    
    $firstMembership = $membershipsArray[0]
    if ($firstMembership.tenant_id) {
        return $firstMembership.tenant_id
    }
    if ($firstMembership.tenant -and $firstMembership.tenant.id) {
        return $firstMembership.tenant.id
    }
    
    return $null
}

# Step 1: Bootstrap JWT token
Write-Host "[1] Acquiring JWT token..." -ForegroundColor Yellow
try {
    . "$PSScriptRoot\_lib\test_auth.ps1"
    $apiKey = $env:HOS_API_KEY
    if (-not $apiKey) {
        $apiKey = "dev-api-key"
    }
    $jwtToken = Get-DevTestJwtToken -HosApiKey $apiKey
    if (-not $jwtToken) {
        throw "Failed to obtain JWT token"
    }
    $tokenMask = if ($jwtToken.Length -gt 6) { "***" + $jwtToken.Substring($jwtToken.Length - 6) } else { "***" }
    Write-Host "PASS: Token acquired ($tokenMask)" -ForegroundColor Green
} catch {
    Write-Host "FAIL: JWT token acquisition failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Resolve tenant_id
Write-Host ""
Write-Host "[2] Resolving tenant_id..." -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $jwtToken"
        "Content-Type" = "application/json"
    }
    $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    
    if (-not $tenantId) {
        throw "Could not extract tenant_id from memberships"
    }
    Write-Host "  Tenant ID: $tenantId" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: Could not resolve tenant_id: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Get category ID (use Service category = 1)
Write-Host ""
Write-Host "[3] Getting category ID..." -ForegroundColor Yellow
$categoryId = 1
Write-Host "  Using category ID: $categoryId (Service)" -ForegroundColor Green

# Step 4: Create 3 listings with different transaction mode combinations
Write-Host ""
Write-Host "[4] Creating listings with different transaction modes..." -ForegroundColor Yellow
$results = @()

$testListings = @(
    @{
        Title = "WP-63 Reservation Only"
        TransactionModes = @("reservation")
    },
    @{
        Title = "WP-63 Rental + Reservation"
        TransactionModes = @("rental", "reservation")
    },
    @{
        Title = "WP-63 Sale Only"
        TransactionModes = @("sale")
    }
)

foreach ($testListing in $testListings) {
    $title = $testListing.Title
    $transactionModes = $testListing.TransactionModes
    $modesStr = $transactionModes -join ", "
    
    Write-Host ""
    Write-Host "  Listing: $title" -ForegroundColor Cyan
    Write-Host "    Transaction Modes: $modesStr" -ForegroundColor Gray
    
    # Check if listing already exists
    $existingListingId = $null
    try {
        $searchResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings?status=published&limit=50" `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        $listings = $null
        if ($searchResponse -is [Array]) {
            $listings = $searchResponse
        } elseif ($searchResponse.data) {
            $listings = $searchResponse.data
        } elseif ($searchResponse.items) {
            $listings = $searchResponse.items
        } else {
            $listings = @($searchResponse)
        }
        
        $existing = $listings | Where-Object { $_.title -eq $title }
        if ($existing) {
            $existingListingId = $existing[0].id
            Write-Host "    EXISTS: Listing found (id: $existingListingId)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    WARN: Could not check existing listings: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Create listing if not exists
    if (-not $existingListingId) {
        try {
            Write-Host "    Creating new listing..." -ForegroundColor Gray
            
            $listingBody = @{
                category_id = $categoryId
                title = $title
                description = "WP-63 transaction mode proof test"
                transaction_modes = $transactionModes
                attributes = @{}
            }
            
            $createBody = $listingBody | ConvertTo-Json
            
            $createResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings" `
                -Method Post `
                -Headers @{
                    "Authorization" = "Bearer $jwtToken"
                    "X-Active-Tenant-Id" = $tenantId
                    "Content-Type" = "application/json"
                } `
                -Body $createBody `
                -TimeoutSec 10 `
                -ErrorAction Stop
            
            $listingId = $createResponse.id
            
            # Publish listing
            if ($createResponse.status -ne "published") {
                $publishResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings/$listingId/publish" `
                    -Method Post `
                    -Headers @{
                        "Authorization" = "Bearer $jwtToken"
                        "X-Active-Tenant-Id" = $tenantId
                    } `
                    -TimeoutSec 10 `
                    -ErrorAction Stop
            }
            
            Write-Host "    CREATED: Listing created and published (id: $listingId)" -ForegroundColor Green
            $existingListingId = $listingId
        } catch {
            Write-Host "    FAIL: Could not create listing: $($_.Exception.Message)" -ForegroundColor Red
            $hasFailures = $true
            continue
        }
    }
    
    # Store result
    $results += @{
        Title = $title
        TransactionModes = $modesStr
        ListingId = $existingListingId
        Status = if ($existingListingId) { "EXISTS" } else { "CREATED" }
    }
}

# Step 5: Print summary
Write-Host ""
Write-Host "=== TRANSACTION MODES SEED SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

foreach ($result in $results) {
    $statusColor = if ($result.Status -eq "EXISTS") { "Green" } else { "Yellow" }
    Write-Host "[$($result.Status)] $($result.Title)" -ForegroundColor $statusColor
    Write-Host "  Transaction Modes: $($result.TransactionModes)" -ForegroundColor Gray
    if ($result.ListingId) {
        Write-Host "  Listing ID: $($result.ListingId)" -ForegroundColor Gray
        Write-Host "  View URL: http://localhost:3002/marketplace/listing/$($result.ListingId)" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "Search URL: http://localhost:3002/marketplace/search/$categoryId" -ForegroundColor Cyan
Write-Host ""

if ($hasFailures) {
    Write-Host "WARNING: Some listings failed to create" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "SUCCESS: All transaction mode listings ready" -ForegroundColor Green
    exit 0
}

