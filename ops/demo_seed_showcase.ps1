# Demo Seed Showcase Script (WP-REPORT)
# Creates 4 realistic listings to prove end-to-end wiring is correct
# Uses APIs only (no direct DB writes), idempotent

$ErrorActionPreference = "Stop"

Write-Host "=== DEMO SEED SHOWCASE (WP-REPORT) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$hosBaseUrl = "http://localhost:3000"

# Helper: Extract tenant_id robustly from memberships (reused from demo_seed_root_listings)
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

# Helper: Find category in tree by slug path (e.g., ["service", "events", "wedding-hall"])
function Find-CategoryBySlugPath {
    param(
        [object]$Tree,
        [string[]]$SlugPath
    )
    
    if ($SlugPath.Count -eq 0) {
        return $null
    }
    
    $currentSlug = $SlugPath[0]
    $remainingPath = $SlugPath[1..($SlugPath.Count - 1)]
    
    foreach ($item in $Tree) {
        if ($item.slug -eq $currentSlug) {
            if ($remainingPath.Count -eq 0) {
                return $item
            }
            if ($item.children) {
                return Find-CategoryBySlugPath -Tree $item.children -SlugPath $remainingPath
            }
        }
    }
    
    return $null
}

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

# Helper: Mask token (show last 6 chars max)
function Mask-Token {
    param([string]$token)
    if (-not $token) { return "" }
    if ($token.Length -le 6) { return "***" }
    return "***" + $token.Substring($token.Length - 6)
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
    $tokenMask = Mask-Token $jwtToken
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

# Step 4: Define showcase listings
Write-Host ""
Write-Host "[4] Defining showcase listings..." -ForegroundColor Yellow

$showcaseListings = @(
    @{
        Title = "Bando Presto (4 kisi)"
        SlugPath = @("service", "events", "wedding-hall")
        Description = "Wedding hall for 4 people. Perfect for intimate ceremonies."
        Attributes = @{
            capacity_max = 4
        }
    },
    @{
        Title = "Mercedes Kiralik Araba"
        SlugPath = @("vehicle", "car", "car-rental")
        Description = "Mercedes rental car. Luxury vehicle for your special occasions."
        Attributes = @{}
    },
    @{
        Title = "Adana Kebap"
        SlugPath = @("service", "food", "restaurant")
        Description = "Authentic Adana kebab restaurant. Traditional Turkish cuisine."
        Attributes = @{}
    },
    @{
        Title = "Ruyam Tekne Kiralama"
        SlugPath = @("service")  # Fallback to service root if boat category doesn't exist
        Description = "Boat rental service. Enjoy the sea with our rental boats."
        Attributes = @{}
    }
)

Write-Host "PASS: 4 showcase listings defined" -ForegroundColor Green

# Step 5: Resolve categories and create listings
Write-Host ""
Write-Host "[5] Resolving categories and creating listings..." -ForegroundColor Yellow
$results = @()

foreach ($listing in $showcaseListings) {
    $title = $listing.Title
    $slugPath = $listing.SlugPath
    $description = $listing.Description
    $attributes = $listing.Attributes
    
    Write-Host ""
    Write-Host "  Listing: $title" -ForegroundColor Cyan
    Write-Host "    Slug Path: $($slugPath -join ' / ')" -ForegroundColor Gray
    
    # Resolve category
    $category = Find-CategoryBySlugPath -Tree $categories -SlugPath $slugPath
    
    # Fallback: if not found, try parent category (e.g., "service" root)
    if (-not $category -and $slugPath.Count -gt 1) {
        Write-Host "    WARN: Category path not found, trying parent: $($slugPath[0])" -ForegroundColor Yellow
        $category = Find-CategoryBySlugPath -Tree $categories -SlugPath @($slugPath[0])
    }
    
    if (-not $category) {
        Write-Host "    FAIL: Category not found for path: $($slugPath -join ' / ')" -ForegroundColor Red
        $hasFailures = $true
        continue
    }
    
    $categoryId = $category.id
    $categorySlug = $category.slug
    Write-Host "    Category: $categorySlug (id: $categoryId)" -ForegroundColor Gray
    
    # Check if listing exists (by title exact match + category_id + status=published)
    $hasPublished = $false
    $existingListingId = $null
    
    try {
        $listingsResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings?category_id=$categoryId&status=published" `
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
        
        # Check for exact title match
        if ($listings) {
            foreach ($existingListing in $listings) {
                if ($existingListing.title -eq $title) {
                    $hasPublished = $true
                    $existingListingId = $existingListing.id
                    Write-Host "    EXISTS: Published listing found (id: $existingListingId)" -ForegroundColor Green
                    break
                }
            }
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
                title = $title
                description = $description
                status = "published"
                transaction_modes = @("reservation")
                attributes = $attributes
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
            
            # Publish listing if not already published
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
        CategoryId = $categoryId
        CategorySlug = $categorySlug
        ListingId = $existingListingId
        Status = if ($hasPublished) { "EXISTS" } else { "CREATED" }
    }
}

# Step 6: Print summary
Write-Host ""
Write-Host "=== DEMO SEED SHOWCASE SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

foreach ($result in $results) {
    $statusColor = if ($result.Status -eq "EXISTS") { "Green" } else { "Yellow" }
    Write-Host "[$($result.Status)] $($result.Title)" -ForegroundColor $statusColor
    Write-Host "  Category: $($result.CategorySlug) (id: $($result.CategoryId))" -ForegroundColor Gray
    if ($result.ListingId) {
        Write-Host "  Listing ID: $($result.ListingId)" -ForegroundColor Gray
        Write-Host "  Search URL: http://localhost:3002/marketplace/search/$($result.CategoryId)" -ForegroundColor Gray
        Write-Host "  Detail URL: http://localhost:3002/marketplace/listing/$($result.ListingId)" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($hasFailures) {
    Write-Host "=== DEMO SEED SHOWCASE: FAIL ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== DEMO SEED SHOWCASE: PASS ===" -ForegroundColor Green
    exit 0
}

