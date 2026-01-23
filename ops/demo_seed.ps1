# Demo Seed Script (WP-60)
# Ensures deterministic demo data: at least 1 published listing per root category
# Uses APIs only (no direct DB writes), idempotent

$ErrorActionPreference = "Stop"

Write-Host "=== DEMO SEED (WP-60) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$hosBaseUrl = "http://localhost:3000"

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

# Helper: Extract tenant_id robustly from memberships (reused from prototype_flow_smoke)
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
        $tenantId = $null
        
        if ($membership.tenant_id) {
            $tenantId = $membership.tenant_id
        }
        elseif ($membership.tenant -and $membership.tenant.id) {
            $tenantId = $membership.tenant.id
        }
        elseif ($membership.tenant -and $membership.tenant.PSObject.Properties['id']) {
            $tenantId = $membership.tenant.id
        }
        elseif ($membership.tenantId) {
            $tenantId = $membership.tenantId
        }
        elseif ($membership.store_tenant_id) {
            $tenantId = $membership.store_tenant_id
        }
        
        if ($tenantId -and $tenantId -is [string] -and $tenantId.Trim().Length -gt 0) {
            $guidResult = [System.Guid]::Empty
            if ([System.Guid]::TryParse($tenantId, [ref]$guidResult)) {
                return $tenantId
            }
        }
    }
    
    return $null
}

# Helper: Find category in tree by slug
function Find-CategoryBySlug {
    param(
        [object]$Tree,
        [string]$Slug
    )
    
    foreach ($item in $Tree) {
        if ($item.slug -eq $Slug) {
            return $item
        }
        if ($item.children) {
            $found = Find-CategoryBySlug -Tree $item.children -Slug $Slug
            if ($found) {
                return $found
            }
        }
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

# Step 2: Get tenant_id from memberships
Write-Host ""
Write-Host "[2] Getting tenant_id from memberships..." -ForegroundColor Yellow
$tenantId = $null
try {
    $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" `
        -Headers @{ "Authorization" = "Bearer $jwtToken" } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    
    if (-not $tenantId) {
        Write-Host "  No valid tenant_id found, attempting bootstrap..." -ForegroundColor Yellow
        $bootstrapScript = Join-Path $PSScriptRoot "ensure_demo_membership.ps1"
        if (Test-Path $bootstrapScript) {
            & $bootstrapScript -HosBaseUrl $hosBaseUrl -TenantSlug "tenant-a" -Email "testuser@example.com" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" `
                    -Headers @{ "Authorization" = "Bearer $jwtToken" } `
                    -TimeoutSec 5 `
                    -ErrorAction Stop
                $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
            }
        }
    }
    
    if (-not $tenantId) {
        Write-Host "FAIL: No valid tenant_id found in memberships" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "PASS: tenant_id acquired: $tenantId" -ForegroundColor Green
} catch {
    Write-Host "FAIL: Memberships request failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Fetch categories
Write-Host ""
Write-Host "[3] Fetching categories..." -ForegroundColor Yellow
$categories = $null
try {
    $categoriesResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/categories" `
        -TimeoutSec 10 `
        -ErrorAction Stop
    
    $categories = $categoriesResponse
    Write-Host "PASS: Categories fetched" -ForegroundColor Green
} catch {
    Write-Host "FAIL: Categories request failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 4: Identify root categories (target slugs: service, vehicle, real-estate)
Write-Host ""
Write-Host "[4] Identifying root categories..." -ForegroundColor Yellow
$targetSlugs = @("service", "vehicle", "real-estate")
$rootCategories = @()

foreach ($slug in $targetSlugs) {
    $category = Find-CategoryBySlug -Tree $categories -Slug $slug
    if ($category) {
        $rootCategories += $category
        Write-Host "  Found: $slug (id: $($category.id))" -ForegroundColor Gray
    } else {
        Write-Host "  WARN: Category '$slug' not found" -ForegroundColor Yellow
    }
}

# Fallback: if no target slugs found, use root categories (parent_id null)
if ($rootCategories.Count -eq 0) {
    Write-Host "  No target slugs found, using root categories (parent_id null)..." -ForegroundColor Yellow
    function Get-RootCategories {
        param([object]$Tree)
        $roots = @()
        foreach ($item in $Tree) {
            if (-not $item.parent_id) {
                $roots += $item
            }
            if ($item.children) {
                $roots += Get-RootCategories -Tree $item.children
            }
        }
        return $roots
    }
    $rootCategories = Get-RootCategories -Tree $categories
    Write-Host "  Found $($rootCategories.Count) root categories" -ForegroundColor Gray
}

if ($rootCategories.Count -eq 0) {
    Write-Host "FAIL: No root categories found" -ForegroundColor Red
    exit 1
}

Write-Host "PASS: Found $($rootCategories.Count) root categories" -ForegroundColor Green

# Step 5: Ensure at least 1 published listing per category
Write-Host ""
Write-Host "[5] Ensuring published listings per category..." -ForegroundColor Yellow
$results = @()

foreach ($category in $rootCategories) {
    $categoryId = $category.id
    $categorySlug = $category.slug
    $categoryName = $category.name
    
    Write-Host ""
    Write-Host "  Category: $categoryName (id: $categoryId, slug: $categorySlug)" -ForegroundColor Cyan
    
    # Check if published listing exists
    $hasPublished = $false
    $existingListingId = $null
    
    try {
        $listingsResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings?category_id=$categoryId&status=published&limit=1" `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        $listings = $null
        if ($listingsResponse -is [Array]) {
            $listings = $listingsResponse
        } elseif ($listingsResponse.data) {
            $listings = $listingsResponse.data
        } elseif ($listingsResponse.items) {
            $listings = $listingsResponse.items
        } else {
            $listings = @($listingsResponse)
        }
        
        if ($listings -and $listings.Count -gt 0) {
            $hasPublished = $true
            $existingListingId = $listings[0].id
            Write-Host "    EXISTS: Published listing found (id: $existingListingId)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    WARN: Could not check existing listings: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Create listing if none exists
    if (-not $hasPublished) {
        try {
            Write-Host "    Creating new listing..." -ForegroundColor Gray
            
            # Build listing body
            $listingBody = @{
                category_id = $categoryId
                title = "DEMO $($categorySlug.ToUpper()) Listing"
                description = "Demo listing for $categoryName category (WP-60)"
                transaction_modes = @("reservation")
                attributes = @{}
            }
            
            # Add capacity_max if category implies it (wedding-hall, restaurant, etc.)
            if ($categorySlug -match "wedding|restaurant|hall|venue") {
                $listingBody.attributes.capacity_max = 100
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
            $publishResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings/$listingId/publish" `
                -Method Post `
                -Headers @{
                    "Authorization" = "Bearer $jwtToken"
                    "X-Active-Tenant-Id" = $tenantId
                } `
                -TimeoutSec 10 `
                -ErrorAction Stop
            
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
        CategoryId = $categoryId
        CategorySlug = $categorySlug
        CategoryName = $categoryName
        ListingId = $existingListingId
        Status = if ($hasPublished) { "EXISTS" } else { "CREATED" }
    }
}

# Step 6: Print summary
Write-Host ""
Write-Host "=== DEMO SEED SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

foreach ($result in $results) {
    $statusColor = if ($result.Status -eq "EXISTS") { "Green" } else { "Yellow" }
    Write-Host "[$($result.Status)] $($result.CategoryName) (slug: $($result.CategorySlug))" -ForegroundColor $statusColor
    Write-Host "  Category ID: $($result.CategoryId)" -ForegroundColor Gray
    if ($result.ListingId) {
        Write-Host "  Listing ID: $($result.ListingId)" -ForegroundColor Gray
        Write-Host "  Search URL: http://localhost:3002/marketplace/search/$($result.CategoryId)" -ForegroundColor Gray
        Write-Host "  Listing URL: http://localhost:3002/marketplace/listing/$($result.ListingId)" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($hasFailures) {
    Write-Host "=== DEMO SEED: FAIL ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== DEMO SEED: PASS ===" -ForegroundColor Green
    exit 0
}

