#!/usr/bin/env pwsh
# LISTING CONTRACT CHECK (WP-3)
# Verifies Supply Spine API endpoints with schema validation.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== LISTING CONTRACT CHECK (WP-3) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$hosBaseUrl = "http://localhost:3000"
$tenantId = $null
$authToken = $null
$listingId = $null
$weddingHallId = $null

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

# Bootstrap JWT token and get tenant_id
Write-Host "[0] Acquiring JWT token and tenant_id..." -ForegroundColor Yellow
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
    
    # Get tenant_id from memberships
    $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" `
        -Headers @{ "Authorization" = $authToken } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    
    if (-not $tenantId) {
        Write-Host "  No valid tenant_id found, attempting bootstrap..." -ForegroundColor Yellow
        $bootstrapScript = Join-Path $scriptDir "ensure_demo_membership.ps1"
        if (Test-Path $bootstrapScript) {
            & $bootstrapScript -HosBaseUrl $hosBaseUrl -TenantSlug "tenant-a" -Email "testuser@example.com" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" `
                    -Headers @{ "Authorization" = $authToken } `
                    -TimeoutSec 5 `
                    -ErrorAction Stop
                $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
            }
        }
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

# Test 1: GET /api/v1/categories (must be non-empty)
Write-Host "[1] Testing GET /api/v1/categories..." -ForegroundColor Yellow
$categoriesUrl = "${pazarBaseUrl}/api/v1/categories"
try {
    $categoriesResponse = Invoke-RestMethod -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if (-not ($categoriesResponse -is [Array]) -or $categoriesResponse.Count -eq 0) {
        Write-Host "FAIL: Categories endpoint returned empty or invalid response" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Categories endpoint returns non-empty array" -ForegroundColor Green
        Write-Host "  Root categories: $($categoriesResponse.Count)" -ForegroundColor Gray
        
        # Find wedding-hall category ID (id: 5)
        function FindCategoryInTree($tree, $slug) {
            foreach ($item in $tree) {
                if ($item.slug -eq $slug) {
                    return $item.id
                }
                if ($item.children) {
                    $foundId = FindCategoryInTree $item.children $slug
                    if ($foundId) { return $foundId }
                }
            }
            return $null
        }
        $weddingHallId = FindCategoryInTree $categoriesResponse "wedding-hall"
        
        if ($weddingHallId) {
            Write-Host "  Found 'wedding-hall' category with ID: $weddingHallId" -ForegroundColor Green
        } else {
            Write-Host "FAIL: 'wedding-hall' category not found" -ForegroundColor Red
            $hasFailures = $true
        }
    }
} catch {
    Write-Host "FAIL: Categories request failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Test 2: Negative - POST /api/v1/listings without Authorization header (expect 401)
if (-not $weddingHallId) {
    Write-Host "[2] SKIP: Cannot test negative case (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[2] Testing POST /api/v1/listings without Authorization header (negative test)..." -ForegroundColor Yellow
    $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
    $listingBody = @{
        category_id = $weddingHallId
        title = "Test Without Auth"
        transaction_modes = @("reservation")
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "X-Active-Tenant-Id" = $tenantId
            # No Authorization header
        }
        $negativeResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        Write-Host "FAIL: Request without Authorization should have failed, but succeeded" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        $errorResponse = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                try {
                    $errorResponse = $responseBody | ConvertFrom-Json
                } catch {
                }
            } catch {
            }
        }
        if ($statusCode -eq 401) {
            if ($errorResponse -and $errorResponse.error_code -eq "AUTH_REQUIRED") {
                Write-Host "PASS: Request without Authorization correctly rejected (status: 401, AUTH_REQUIRED)" -ForegroundColor Green
            } else {
                Write-Host "PASS: Request without Authorization correctly rejected (status: 401)" -ForegroundColor Green
            }
        } else {
            Write-Host "FAIL: Expected 401 AUTH_REQUIRED, got status: $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
    }
}

Write-Host ""

# Test 3: Negative - POST /api/v1/listings with Authorization but missing X-Active-Tenant-Id (expect 400)
if (-not $weddingHallId) {
    Write-Host "[3] SKIP: Cannot test negative case (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[3] Testing POST /api/v1/listings with Authorization but missing X-Active-Tenant-Id (negative test)..." -ForegroundColor Yellow
    $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
    $listingBody = @{
        category_id = $weddingHallId
        title = "Test Without Tenant Header"
        transaction_modes = @("reservation")
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            # No X-Active-Tenant-Id header
        }
        $negativeResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        Write-Host "FAIL: Request without X-Active-Tenant-Id should have failed, but succeeded" -ForegroundColor Red
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
            Write-Host "PASS: Request without X-Active-Tenant-Id correctly rejected (status: $statusCode)" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Expected 400/403, got status: $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
    }
}

Write-Host ""

# Test 4: POST /api/v1/listings (create DRAFT listing) - success path
if (-not $weddingHallId) {
    Write-Host "[4] SKIP: Cannot test create listing (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[4] Testing POST /api/v1/listings (create DRAFT)..." -ForegroundColor Yellow
    $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
    $listingBody = @{
        category_id = $weddingHallId
        title = "Test Wedding Hall Listing"
        description = "A test wedding hall listing for WP-3"
        transaction_modes = @("reservation")
        attributes = @{
            capacity_max = 500
        }
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            "X-Active-Tenant-Id" = $tenantId
        }
        $createResponse = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $createResponse.id) {
        Write-Host "FAIL: Create listing response missing 'id'" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($createResponse.status -ne "draft") {
        Write-Host "FAIL: Expected status='draft', got '$($createResponse.status)'" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $createResponse.tenant_id) {
        Write-Host "FAIL: Create listing response missing 'tenant_id'" -ForegroundColor Red
        $hasFailures = $true
    } else {
        # Note: tenant_id is UUID format (database requirement), not the original header value
        # The important check is that tenant_id is set and matches on publish
        $listingId = $createResponse.id
        Write-Host "PASS: Listing created successfully" -ForegroundColor Green
        Write-Host "  Listing ID: $listingId" -ForegroundColor Gray
        Write-Host "  Status: $($createResponse.status)" -ForegroundColor Gray
        Write-Host "  Category ID: $($createResponse.category_id)" -ForegroundColor Gray
    }
    } catch {
        $statusCode = $null
        $responseBody = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                # Read response body for 422 errors
                if ($statusCode -eq 422) {
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                }
            } catch {
            }
        }
        Write-Host "FAIL: Create listing request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
            if ($responseBody) {
                Write-Host "  422 body: $responseBody" -ForegroundColor Yellow
            }
        }
        $hasFailures = $true
    }
}

Write-Host ""

# Test 5: POST /api/v1/listings/{id}/publish
if ($listingId) {
    Write-Host "[5] Testing POST /api/v1/listings/$listingId/publish..." -ForegroundColor Yellow
    $publishUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}/publish"
    try {
        $headers = @{
            "Authorization" = $authToken
            "X-Active-Tenant-Id" = $tenantId
        }
        $publishResponse = Invoke-RestMethod -Uri $publishUrl -Method Post -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        if ($publishResponse.status -ne "published") {
            Write-Host "FAIL: Expected status='published', got '$($publishResponse.status)'" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Listing published successfully" -ForegroundColor Green
            Write-Host "  Status: $($publishResponse.status)" -ForegroundColor Gray
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Publish listing request failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[5] SKIP: Cannot test publish (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 6: GET /api/v1/listings/{id}
if ($listingId) {
    Write-Host "[6] Testing GET /api/v1/listings/$listingId..." -ForegroundColor Yellow
    $getListingUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}"
    try {
        $getResponse = Invoke-RestMethod -Uri $getListingUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        if ($getResponse.status -ne "published") {
            Write-Host "FAIL: Expected status='published', got '$($getResponse.status)'" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($getResponse.id -ne $listingId) {
            Write-Host "FAIL: Mismatched listing ID" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Get listing returns correct data" -ForegroundColor Green
            Write-Host "  Status: $($getResponse.status)" -ForegroundColor Gray
            Write-Host "  Attributes: $($getResponse.attributes | ConvertTo-Json -Compress)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "FAIL: Get listing request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
} else {
    Write-Host "[6] SKIP: Cannot test get listing (listing ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 7: GET /api/v1/listings?category_id={weddingHallId}
if (-not $weddingHallId) {
    Write-Host "[7] SKIP: Cannot test search listings (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[7] Testing GET /api/v1/listings?category_id=$weddingHallId..." -ForegroundColor Yellow
    $searchUrl = "${pazarBaseUrl}/api/v1/listings?category_id=$weddingHallId"
    try {
        $searchResponse = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if (-not ($searchResponse -is [Array])) {
        Write-Host "FAIL: Search listings returned non-array response" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($listingId -and -not ($searchResponse | Where-Object { $_.id -eq $listingId })) {
        Write-Host "FAIL: Created listing not found in search results" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Search listings returns results" -ForegroundColor Green
        Write-Host "  Results count: $($searchResponse.Count)" -ForegroundColor Gray
        if ($listingId) {
            $found = $searchResponse | Where-Object { $_.id -eq $listingId }
            if ($found) {
                Write-Host "  Created listing found in results" -ForegroundColor Gray
            }
        }
    }
    } catch {
        Write-Host "FAIL: Search listings request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}


Write-Host ""

# Test 8: WP-48 - Recursive category search (parent category includes child listings)
if (-not $listingId -or -not $weddingHallId) {
    Write-Host "[8] SKIP: Cannot test recursive category search (listing ID or wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[8] Testing recursive category search (WP-48)..." -ForegroundColor Yellow
    Write-Host "  Created listing is in wedding-hall category (child of service root)" -ForegroundColor Gray
    Write-Host "  Testing if service root category search includes wedding-hall listings..." -ForegroundColor Gray
    
    # Helper function to find category ID in tree by slug
    function FindCategoryInTree($tree, $slug) {
        foreach ($item in $tree) {
            if ($item.slug -eq $slug) {
                return $item.id
            }
            if ($item.children) {
                $foundId = FindCategoryInTree $item.children $slug
                if ($foundId) { return $foundId }
            }
        }
        return $null
    }
    
    # Get categories tree to find service root category
    $categoriesUrl = "${pazarBaseUrl}/api/v1/categories"
    try {
        $categoriesResponse = Invoke-RestMethod -Uri $categoriesUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        $serviceRootId = FindCategoryInTree $categoriesResponse "service"
        
        if (-not $serviceRootId) {
            Write-Host "  WARN: service root category not found, skipping recursive test" -ForegroundColor Yellow
        } else {
            Write-Host "  Found service root category ID: $serviceRootId" -ForegroundColor Gray
            
            # Search listings with service root category_id
            $recursiveSearchUrl = "${pazarBaseUrl}/api/v1/listings?category_id=$serviceRootId&status=published"
            try {
                $recursiveSearchResponse = Invoke-RestMethod -Uri $recursiveSearchUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
                
                if (-not ($recursiveSearchResponse -is [Array])) {
                    Write-Host "FAIL: Recursive search returned non-array response" -ForegroundColor Red
                    $hasFailures = $true
                } else {
                    $foundListing = $recursiveSearchResponse | Where-Object { $_.id -eq $listingId }
                    if ($foundListing) {
                        Write-Host "PASS: Recursive category search works - wedding-hall listing found under service root" -ForegroundColor Green
                        Write-Host "  Service root search returned $($recursiveSearchResponse.Count) listings" -ForegroundColor Gray
                        Write-Host "  Created listing (ID: $listingId) found in results" -ForegroundColor Gray
                    } else {
                        Write-Host "FAIL: Recursive category search failed - wedding-hall listing NOT found under service root" -ForegroundColor Red
                        Write-Host "  Service root search returned $($recursiveSearchResponse.Count) listings" -ForegroundColor Yellow
                        Write-Host "  Expected listing ID: $listingId" -ForegroundColor Yellow
                        $hasFailures = $true
                    }
                }
            } catch {
                Write-Host "FAIL: Recursive search request failed: $($_.Exception.Message)" -ForegroundColor Red
                $hasFailures = $true
            }
        }
    } catch {
        Write-Host "  WARN: Could not get categories tree for recursive test: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== LISTING CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    # Always use hard exit (not Invoke-OpsExit) to ensure exit code propagation
    exit 1
} else {
    Write-Host "=== LISTING CONTRACT CHECK: PASS ===" -ForegroundColor Green
    # Always use hard exit (not Invoke-OpsExit) to ensure exit code propagation
    exit 0
}

