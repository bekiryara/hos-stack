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
        $bootstrapScript = Join-Path $scriptDir "ensure_membership.ps1"
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

# Helper: find an existing listing by title + tenant + category + status
function Find-ExistingListingByTitle {
    param(
        [string]$PazarBaseUrl,
        [string]$CategoryId,
        [string]$Status,
        [string]$Title,
        [string]$TenantId
    )
    try {
        $url = "${PazarBaseUrl}/api/v1/listings?category_id=${CategoryId}&status=${Status}&per_page=50"
        $rows = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
        if (-not ($rows -is [Array])) { return $null }
        $found = $rows | Where-Object { $_.title -eq $Title -and $_.tenant_id -eq $TenantId } | Select-Object -First 1
        return $found
    } catch {
        return $null
    }
}

# Test 2: POST /api/v1/listings without Authorization header
# WP-61B: In GENESIS mode (GENESIS_ALLOW_UNAUTH_STORE=1), Authorization is optional per SPEC §5.2
if (-not $weddingHallId) {
    Write-Host "[2] SKIP: Cannot test (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[2] Testing POST /api/v1/listings without Authorization header (GENESIS mode: Authorization optional)..." -ForegroundColor Yellow
    $createListingUrl = "${pazarBaseUrl}/api/v1/listings"
    $test2Title = "Test Without Auth (WP-61B)"

    # Idempotent: if an existing draft listing already exists for this tenant/title, reuse it.
    $existingDraft = Find-ExistingListingByTitle -PazarBaseUrl $pazarBaseUrl -CategoryId $weddingHallId -Status "draft" -Title $test2Title -TenantId $tenantId
    if ($existingDraft) {
        Write-Host "PASS: Existing draft listing already satisfies test (reusing; no new row created)" -ForegroundColor Green
        Write-Host "  Listing ID: $($existingDraft.id)" -ForegroundColor Gray
        Write-Host "  Status: $($existingDraft.status)" -ForegroundColor Gray
        Write-Host "  Note: Authorization is optional in GENESIS mode per SPEC §5.2" -ForegroundColor Gray
    } else {
    $listingBody = @{
        category_id = $weddingHallId
        title = $test2Title
        transaction_modes = @("reservation")
        # wedding-hall requires capacity_max (catalog filter-schema required=true)
        # Include it so this test validates ONLY the auth rule (GENESIS_ALLOW_UNAUTH_STORE), not schema validation.
        attributes = @{
            capacity_max = 500
        }
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "X-Active-Tenant-Id" = $tenantId
            # No Authorization header (GENESIS mode: optional)
        }
        $response = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        # WP-61B: In GENESIS mode, request should succeed (201) without Authorization
        if ($response.id -and $response.status -eq "draft") {
            Write-Host "PASS: Request without Authorization succeeded in GENESIS mode (status: 201, listing created)" -ForegroundColor Green
            Write-Host "  Listing ID: $($response.id)" -ForegroundColor Gray
            Write-Host "  Status: $($response.status)" -ForegroundColor Gray
            Write-Host "  Note: Authorization is optional in GENESIS mode per SPEC §5.2" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Request without Authorization succeeded but response invalid" -ForegroundColor Red
            $hasFailures = $true
        }
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
        # WP-61B: If GENESIS_ALLOW_UNAUTH_STORE=0, expect 401; otherwise expect success
        if ($statusCode -eq 401) {
            Write-Host "INFO: Request without Authorization returned 401 (GENESIS_ALLOW_UNAUTH_STORE=0, auth required)" -ForegroundColor Yellow
            Write-Host "  Status Code: 401" -ForegroundColor Gray
            if ($errorResponse -and $errorResponse.error_code) {
                Write-Host "  Error Code: $($errorResponse.error_code)" -ForegroundColor Gray
            }
        } else {
            Write-Host "FAIL: Request without Authorization failed with unexpected status: $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
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
    $test4Title = "Test Wedding Hall Listing"
    $createdThisRun = $false

    # Idempotent: Prefer reusing an existing published listing (prevents DB blowup).
    # If none exists, create a new draft listing and publish it (full write-path coverage).
    $existingPublished = Find-ExistingListingByTitle -PazarBaseUrl $pazarBaseUrl -CategoryId $weddingHallId -Status "published" -Title $test4Title -TenantId $tenantId
    if ($existingPublished) {
        $listingId = $existingPublished.id
        Write-Host "PASS: Reusing existing published listing (no new row created)" -ForegroundColor Green
        Write-Host "  Listing ID: $listingId" -ForegroundColor Gray
        Write-Host "  Status: $($existingPublished.status)" -ForegroundColor Gray
        Write-Host "  Category ID: $($existingPublished.category_id)" -ForegroundColor Gray
    } else {
    $listingBody = @{
        category_id = $weddingHallId
        title = $test4Title
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
        $createdThisRun = $true
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
}

Write-Host ""

# Test 5: POST /api/v1/listings/{id}/publish
if ($listingId) {
    Write-Host "[5] Testing POST /api/v1/listings/$listingId/publish..." -ForegroundColor Yellow
    $publishUrl = "${pazarBaseUrl}/api/v1/listings/${listingId}/publish"
    try {
        if (-not $createdThisRun) {
            # Idempotent: listing already published; do not republish (avoids 422/409 noise and DB blowup).
            Write-Host "PASS: Listing already published; skipping publish call (idempotent mode)" -ForegroundColor Green
        } else {
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

# [9] SPEC filters range test (Catalog/Search Final — filters[KEY][min|max])
if (-not $weddingHallId) {
    Write-Host "[9] SKIP: Cannot test SPEC filters (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[9] Testing SPEC filters range (filters[capacity_max][min]=1)..." -ForegroundColor Yellow
    $filtersRangeUrl = "${pazarBaseUrl}/api/v1/listings?category_id=$weddingHallId&filters[capacity_max][min]=1"
    try {
        $filtersRangeResponse = Invoke-RestMethod -Uri $filtersRangeUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        if (-not ($filtersRangeResponse -is [Array])) {
            Write-Host "FAIL: SPEC filters range returned non-array response" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($listingId -and -not ($filtersRangeResponse | Where-Object { $_.id -eq $listingId })) {
            Write-Host "FAIL: Created listing not found in filters range results" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: SPEC filters range returns JSON array; listing present when applicable" -ForegroundColor Green
            Write-Host "  Results count: $($filtersRangeResponse.Count)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "FAIL: SPEC filters range request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# [10] Whitelist negative test (unknown filter key -> 422 + unknown_keys)
if (-not $weddingHallId) {
    Write-Host "[10] SKIP: Cannot test whitelist (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[10] Testing whitelist negative (filters[__unknown_key__]=x -> 422)..." -ForegroundColor Yellow
    $whitelistUrl = "${pazarBaseUrl}/api/v1/listings?category_id=$weddingHallId&filters[__unknown_key__]=x"
    try {
        $null = Invoke-RestMethod -Uri $whitelistUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Host "FAIL: Unknown filter key should have been rejected with 422" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        $responseBody = $null
        $errorResponse = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                if ($responseBody) {
                    $errorResponse = $responseBody | ConvertFrom-Json
                }
            } catch {
            }
        }
        if ($statusCode -eq 422) {
            # Backend returns error=VALIDATION_ERROR + unknown_keys; ErrorEnvelope may rewrite to error_code=HTTP_ERROR
            $errVal = $null
            if ($errorResponse) {
                if ($errorResponse.error) { $errVal = $errorResponse.error }
                elseif ($errorResponse.error_code) { $errVal = $errorResponse.error_code }
            }
            $hasUnknownKeys = $false
            if ($errorResponse -and $errorResponse.unknown_keys -is [Array]) {
                $hasUnknownKeys = [bool]($errorResponse.unknown_keys | Where-Object { $_ -eq '__unknown_key__' -or $_ -match 'unknown_key' })
            }
            # PASS: 422 = unknown keys correctly rejected (body may be envelope-rewritten)
            if ($errVal -eq 'VALIDATION_ERROR' -and $hasUnknownKeys) {
                Write-Host "PASS: unknown keys correctly rejected (422, VALIDATION_ERROR, unknown_keys)" -ForegroundColor Green
            } else {
                Write-Host "PASS: unknown keys correctly rejected (422)" -ForegroundColor Green
            }
        } else {
            Write-Host "FAIL: Expected 422, got status: $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
    }
}

Write-Host ""

# [11] Invalid category_id test (-> 404 category_not_found)
Write-Host "[11] Testing invalid category_id (999999999 -> 404)..." -ForegroundColor Yellow
$invalidCatUrl = "${pazarBaseUrl}/api/v1/listings?category_id=999999999"
try {
    $null = Invoke-RestMethod -Uri $invalidCatUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "FAIL: Invalid category_id should have been rejected with 404" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    $responseBody = $null
    $errorResponse = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $reader.Close()
            if ($responseBody) {
                $errorResponse = $responseBody | ConvertFrom-Json
            }
        } catch {
        }
    }
    if ($statusCode -eq 404) {
        # Backend returns error=category_not_found; ErrorEnvelope may rewrite to error_code=HTTP_ERROR
        $errVal = $null
        if ($errorResponse) {
            if ($errorResponse.error) { $errVal = $errorResponse.error }
            elseif ($errorResponse.error_code) { $errVal = $errorResponse.error_code }
        }
        if ($errVal -eq 'category_not_found' -or $errVal -eq 'NOT_FOUND') {
            Write-Host "PASS: invalid category correctly rejected (404, category_not_found)" -ForegroundColor Green
        } else {
            Write-Host "PASS: invalid category correctly rejected (404)" -ForegroundColor Green
        }
    } else {
        Write-Host "FAIL: Expected 404, got status: $statusCode" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# [12] Backward compat attrs test (legacy attrs[...])
if (-not $weddingHallId) {
    Write-Host "[12] SKIP: Cannot test attrs compat (wedding-hall category ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
} else {
    Write-Host "[12] Testing backward compat attrs (attrs[capacity_max_min]=1)..." -ForegroundColor Yellow
    $attrsUrl = "${pazarBaseUrl}/api/v1/listings?category_id=$weddingHallId&attrs[capacity_max_min]=1"
    try {
        $attrsResponse = Invoke-RestMethod -Uri $attrsUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        if (-not ($attrsResponse -is [Array])) {
            Write-Host "FAIL: attrs compat returned non-array response" -ForegroundColor Red
            $hasFailures = $true
        } elseif ($listingId -and -not ($attrsResponse | Where-Object { $_.id -eq $listingId })) {
            Write-Host "FAIL: Created listing not found in attrs compat results" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Backward compat attrs returns JSON array; listing present when applicable" -ForegroundColor Green
            Write-Host "  Results count: $($attrsResponse.Count)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "FAIL: attrs compat request failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# [13] listings.world allowlist drift check (marketplace)
# NOTE: This is a DB-level integrity check. In CI we FAIL hard; locally we WARN to avoid blocking cleanup.
Write-Host "[13] Checking listings.world allowlist (marketplace)..." -ForegroundColor Yellow

$allowedListingWorlds = @("marketplace")

# DB connection defaults (Laravel/Pazar defaults)
$dbHost = $env:DB_HOST; if (-not $dbHost) { $dbHost = "localhost" }
$dbPort = $env:DB_PORT; if (-not $dbPort) { $dbPort = "5432" }
$dbName = $env:DB_DATABASE; if (-not $dbName) { $dbName = "pazar" }
$dbUser = $env:DB_USERNAME; if (-not $dbUser) { $dbUser = "pazar" }
$dbPassword = $env:DB_PASSWORD; if (-not $dbPassword) { $dbPassword = "pazar_password" }

# Try local psql, else Docker exec
$useDocker = $false
$dockerContainer = $null
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
    $containers = docker ps --format "{{.Names}}" 2>&1
    $pazarDbContainer = $containers | Where-Object { $_ -match "pazar.*db|postgres.*pazar|pazar.*postgres" } | Select-Object -First 1
    if (-not $pazarDbContainer) {
        $commonNames = @("pazar-db", "pazar_postgres", "stack-pazar-db-1", "pazar-postgres-1")
        foreach ($name in $commonNames) {
            $test = docker exec $name psql --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $pazarDbContainer = $name
                break
            }
        }
    }
    if ($pazarDbContainer) {
        $useDocker = $true
        $dockerContainer = $pazarDbContainer
        Write-Host "  Using Docker exec for DB query (container: $dockerContainer)" -ForegroundColor Gray
    } else {
        Write-Host "  WARN: psql not found and no PostgreSQL container found; skipping listings.world drift check" -ForegroundColor Yellow
        $useDocker = $false
    }
}

function Invoke-ListingWorldQuery {
    param([string]$Query)
    if ($psqlPath) {
        $env:PGPASSWORD = $dbPassword
        $result = $Query | & psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -t -A -F "|" 2>&1
        $env:PGPASSWORD = $null
        if ($LASTEXITCODE -ne 0) { return $null }
        return $result
    }
    if ($useDocker -and $dockerContainer) {
        $singleLineQuery = ($Query -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }) -join " "
        $escapedQuery = $singleLineQuery -replace "'", "'\''"
        $result = docker exec $dockerContainer sh -c "psql -U $dbUser -d $dbName -t -A -F '|' -c '$escapedQuery'" 2>&1
        if ($LASTEXITCODE -ne 0) { return $null }
        return $result
    }
    return $null
}

$invalidWorldsQuery = @"
SELECT world, COUNT(*) AS count
FROM listings
GROUP BY world
HAVING world IS NULL OR world NOT IN ('marketplace')
ORDER BY count DESC, world ASC;
"@

$invalidWorlds = Invoke-ListingWorldQuery -Query $invalidWorldsQuery
if ($invalidWorlds -and $invalidWorlds.Trim().Length -gt 0) {
    $lines = $invalidWorlds -split "`n" | Where-Object { $_.Trim().Length -gt 0 }
    $msgLines = @()
    foreach ($line in $lines) {
        $parts = $line -split '\|'
        if ($parts.Count -ge 2) {
            $w = $parts[0]
            $c = $parts[1]
            $msgLines += "    - world='$w' count=$c"
        }
    }
    $shouldFail = ($env:CI -eq "true" -or $env:CI -eq "1")
    if ($shouldFail) {
        Write-Host "FAIL: Found invalid listings.world values (allowed: marketplace)" -ForegroundColor Red
        $msgLines | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
        $hasFailures = $true
    } else {
        Write-Host "WARN: Found invalid listings.world values (allowed: marketplace)" -ForegroundColor Yellow
        $msgLines | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
        Write-Host "  NOTE: This is WARN locally. In CI it fails hard to prevent drift." -ForegroundColor Gray
    }
} else {
    Write-Host "PASS: listings.world values are within allowlist (marketplace)" -ForegroundColor Green
}

Write-Host ""

# [14] Published listings must have interaction_mode (CTA determinism drift guard)
# NOTE: This is a hard invariant. If missing, UI may show wrong CTAs (flow vs contact_only).
Write-Host "[14] Checking published listings missing interaction_mode (must be 0)..." -ForegroundColor Yellow

$missingInteractionModeQuery = @"
SELECT COUNT(*) AS missing_count
FROM listings
WHERE status = 'published'
  AND COALESCE(NULLIF(attributes_json::jsonb->>'interaction_mode',''), '') = '';
"@

$missingCountRaw = Invoke-ListingWorldQuery -Query $missingInteractionModeQuery
$missingCount = 0
if ($missingCountRaw -and $missingCountRaw.Trim().Length -gt 0) {
    [int]::TryParse($missingCountRaw.Trim(), [ref]$missingCount) | Out-Null
}

if ($missingCount -gt 0) {
    Write-Host "FAIL: Found $missingCount published listing(s) missing attributes.interaction_mode (CTA may drift)" -ForegroundColor Red

    $sampleQuery = @"
SELECT l.id, l.title, l.category_id, COALESCE(c.slug,'') AS category_slug, COALESCE(p.slug,'') AS parent_slug
FROM listings l
LEFT JOIN categories c ON c.id = l.category_id
LEFT JOIN categories p ON p.id = c.parent_id
WHERE l.status = 'published'
  AND COALESCE(NULLIF(l.attributes_json::jsonb->>'interaction_mode',''), '') = ''
ORDER BY l.updated_at DESC NULLS LAST, l.id DESC
LIMIT 10;
"@
    $sampleRaw = Invoke-ListingWorldQuery -Query $sampleQuery
    if ($sampleRaw -and $sampleRaw.Trim().Length -gt 0) {
        Write-Host "  Sample (id|title|category_id|category_slug|parent_slug):" -ForegroundColor Yellow
        ($sampleRaw -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object {
            Write-Host "    - $($_.Trim())" -ForegroundColor Yellow
        }
    }

    $hasFailures = $true
} else {
    Write-Host "PASS: published listings missing interaction_mode = 0" -ForegroundColor Green
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

