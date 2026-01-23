# Demo Seed Root Listings Script (WP-60)
# Ensures at least 1 published listing exists for EACH ROOT category
# Uses APIs only (no direct DB writes), idempotent

$ErrorActionPreference = "Stop"

Write-Host "=== DEMO SEED ROOT LISTINGS (WP-60) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$hosBaseUrl = "http://localhost:3000"

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

# Helper: Get root categories (parent_id null)
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

# Step 4: Identify root categories (prefer slugs: vehicle, real-estate, service; else parent_id null)
Write-Host ""
Write-Host "[4] Identifying root categories..." -ForegroundColor Yellow
$targetSlugs = @("vehicle", "real-estate", "service")
$rootCategories = @()

# First try to find by slug
foreach ($slug in $targetSlugs) {
    $category = Find-CategoryBySlug -Tree $categories -Slug $slug
    if ($category -and -not $category.parent_id) {
        $rootCategories += $category
        Write-Host "  Found: $slug (id: $($category.id))" -ForegroundColor Gray
    }
}

# Fallback: if not all found by slug, use all root categories (parent_id null)
if ($rootCategories.Count -lt 3) {
    Write-Host "  Using all root categories (parent_id null)..." -ForegroundColor Yellow
    $allRoots = Get-RootCategories -Tree $categories
    foreach ($root in $allRoots) {
        $found = $rootCategories | Where-Object { $_.id -eq $root.id }
        if (-not $found) {
            $rootCategories += $root
        }
    }
}

# Sort by slug or id for deterministic ordering
$rootCategories = $rootCategories | Sort-Object { if ($_.slug) { $_.slug } else { $_.id } }

if ($rootCategories.Count -eq 0) {
    Write-Host "FAIL: No root categories found" -ForegroundColor Red
    exit 1
}

Write-Host "PASS: Found $($rootCategories.Count) root categories" -ForegroundColor Green

# Step 5: Ensure at least 1 published listing per root category
Write-Host ""
Write-Host "[5] Ensuring published listings per root category..." -ForegroundColor Yellow
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
            
            # Build listing body (minimal required fields)
            $listingBody = @{
                category_id = $categoryId
                title = "DEMO ROOT $($categorySlug.ToUpper()) Listing"
                description = "demo seed"
                status = "published"
                transaction_modes = @("reservation")
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
        CategoryId = $categoryId
        CategorySlug = $categorySlug
        CategoryName = $categoryName
        ListingId = $existingListingId
        Status = if ($hasPublished) { "EXISTS" } else { "CREATED" }
    }
}

# Step 6: WP-48 - Seed showcase listings (deterministic demo data)
Write-Host ""
Write-Host "[6] Seeding showcase listings (WP-48)..." -ForegroundColor Yellow
$showcaseListings = @(
    @{ Title = "Bando Presto (4 kişi)"; Slug = "wedding-hall"; FallbackSlug = "events" }  # WP-62: Use leaf category directly
    @{ Title = "Ruyam Tekne Kiralık"; Slug = "vehicle"; FallbackSlug = "real-estate" }
    @{ Title = "Mercedes (Kiralık)"; Slug = "car-rental"; FallbackSlug = "car" }
    @{ Title = "Adana Kebap"; Slug = "restaurant"; FallbackSlug = "food" }
)

$showcaseResults = @()

foreach ($showcase in $showcaseListings) {
    $title = $showcase.Title
    $slug = $showcase.Slug
    $fallbackSlug = $showcase.FallbackSlug
    
    Write-Host ""
    Write-Host "  Showcase: $title (target slug: $slug)" -ForegroundColor Cyan
    
    # Find category by slug (try primary, then fallback)
    $category = Find-CategoryBySlug -Tree $categories -Slug $slug
    if (-not $category) {
        $category = Find-CategoryBySlug -Tree $categories -Slug $fallbackSlug
    }
    
    if (-not $category) {
        Write-Host "    SKIP: Category not found (slug: $slug, fallback: $fallbackSlug)" -ForegroundColor Yellow
        continue
    }
    
    $categoryId = $category.id
    $categorySlug = $category.slug
    
    # Check if listing already exists (idempotent: by title + tenant + category)
    $listingExists = $false
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
        
        if ($listings) {
            $matchingListing = $listings | Where-Object { 
                $_.title -eq $title -and $_.tenant_id -eq $tenantId 
            }
            if ($matchingListing) {
                $listingExists = $true
                $existingListingId = $matchingListing[0].id
                Write-Host "    EXISTS: Listing found (id: $existingListingId)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "    WARN: Could not check existing listings: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Create listing if not exists
    if (-not $listingExists) {
        try {
            Write-Host "    Creating listing..." -ForegroundColor Gray
            
            # Build listing body
            $listingBody = @{
                category_id = $categoryId
                title = $title
                description = "WP-48 showcase listing"
                transaction_modes = @("reservation", "rental")
                attributes = @{}
            }
            
            # WP-49: Add capacity_max for wedding-hall/events/restaurant categories
            if ($categorySlug -match "wedding-hall|events|restaurant|food") {
                # Ensure capacity_max is an integer (not string) for backend validation
                $listingBody.attributes["capacity_max"] = [int]100
            }
            
            # WP-49: Use -Compress to avoid whitespace issues that might confuse Laravel validation
            $createBody = $listingBody | ConvertTo-Json -Depth 3 -Compress
            
            # Generate idempotency key from title+tenant+category
            $idempotencyKey = ($title + $tenantId + $categoryId).GetHashCode().ToString()
            
            # WP-49: Use Invoke-WebRequest with explicit UTF-8 encoding to ensure Laravel receives the body correctly
            $createBodyBytes = [System.Text.Encoding]::UTF8.GetBytes($createBody)
            $webRequest = Invoke-WebRequest -Uri "$pazarBaseUrl/api/v1/listings" `
                -Method Post `
                -Headers @{
                    "Authorization" = "Bearer $jwtToken"
                    "X-Active-Tenant-Id" = $tenantId
                    "Idempotency-Key" = $idempotencyKey
                } `
                -Body $createBodyBytes `
                -ContentType "application/json; charset=utf-8" `
                -TimeoutSec 10 `
                -ErrorAction Stop
            
            $createResponse = $webRequest.Content | ConvertFrom-Json
            
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
            # WP-49: Enhanced error handling to show 422 response details
            $errorMsg = $_.Exception.Message
            $statusCode = $null
            $errorDetails = ""
            
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $errorBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                    
                    if ($errorBody) {
                        try {
                            $errorJson = $errorBody | ConvertFrom-Json
                            if ($errorJson.message) {
                                $errorDetails = " (${statusCode}: $($errorJson.message))"
                            } elseif ($errorJson.error) {
                                $errorDetails = " (${statusCode}: $($errorJson.error))"
                            } elseif ($errorJson.required_attributes) {
                                $errorDetails = " (${statusCode}: missing required attributes: $($errorJson.required_attributes -join ', '))"
                            } else {
                                $errorDetails = " (${statusCode}: $($errorBody.Substring(0, [Math]::Min(150, $errorBody.Length))))"
                            }
                            # WP-49: Print full error response for 422 debugging
                            if ($statusCode -eq 422) {
                                Write-Host "    DEBUG: Full 422 error response: $errorBody" -ForegroundColor Yellow
                            }
                        } catch {
                            $errorDetails = " (${statusCode}: response body not JSON: $($errorBody.Substring(0, [Math]::Min(100, $errorBody.Length))))"
                            if ($statusCode -eq 422) {
                                Write-Host "    DEBUG: Raw 422 response: $errorBody" -ForegroundColor Yellow
                            }
                        }
                    }
                } catch {
                    if ($statusCode) {
                        $errorDetails = " (HTTP $statusCode)"
                    }
                }
            }
            
            Write-Host "    FAIL: Could not create listing: $errorMsg$errorDetails" -ForegroundColor Red
            $hasFailures = $true
            continue
        }
    }
    
    $showcaseResults += @{
        Title = $title
        CategoryId = $categoryId
        CategorySlug = $categorySlug
        ListingId = $existingListingId
        Status = if ($listingExists) { "EXISTS" } else { "CREATED" }
    }
}

# Step 7: Print summary
Write-Host ""
Write-Host "=== DEMO SEED ROOT LISTINGS SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

foreach ($result in $results) {
    $statusColor = if ($result.Status -eq "EXISTS") { "Green" } else { "Yellow" }
    Write-Host "[$($result.Status)] $($result.CategoryName) (slug: $($result.CategorySlug))" -ForegroundColor $statusColor
    Write-Host "  Category ID: $($result.CategoryId)" -ForegroundColor Gray
    if ($result.ListingId) {
        Write-Host "  Listing ID: $($result.ListingId)" -ForegroundColor Gray
    }
    Write-Host "  Search URL: http://localhost:3002/marketplace/search/$($result.CategoryId)" -ForegroundColor Gray
    Write-Host ""
}

if ($showcaseResults.Count -gt 0) {
    Write-Host "=== SHOWCASE LISTINGS (WP-48) ===" -ForegroundColor Cyan
    Write-Host ""
    foreach ($showcase in $showcaseResults) {
        $statusColor = if ($showcase.Status -eq "EXISTS") { "Green" } else { "Yellow" }
        Write-Host "[$($showcase.Status)] $($showcase.Title)" -ForegroundColor $statusColor
        Write-Host "  Category: $($showcase.CategorySlug) (id: $($showcase.CategoryId))" -ForegroundColor Gray
        if ($showcase.ListingId) {
            Write-Host "  Listing ID: $($showcase.ListingId)" -ForegroundColor Gray
            Write-Host "  Search URL: http://localhost:3002/marketplace/search/$($showcase.CategoryId)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

if ($hasFailures) {
    Write-Host "=== DEMO SEED ROOT LISTINGS: FAIL ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== DEMO SEED ROOT LISTINGS: PASS ===" -ForegroundColor Green
    exit 0
}

