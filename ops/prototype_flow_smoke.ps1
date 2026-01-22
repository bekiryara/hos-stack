# Prototype Flow Smoke Test (WP-45)
# Validates: HOS → Pazar → Messaging E2E flow (real HTTP flow)

$ErrorActionPreference = "Stop"

Write-Host "=== PROTOTYPE FLOW SMOKE (WP-45) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

# Helper: Print sanitized
function Write-Sanitized {
    param([string]$text, [string]$Color = "White")
    $sanitized = Sanitize-Ascii $text
    Write-Host $sanitized -ForegroundColor $Color
}

# Step 1: Get JWT token
Write-Host "[1] Acquiring JWT token..." -ForegroundColor Yellow
try {
    . "$PSScriptRoot\_lib\test_auth.ps1"
    # Get API key from env or use default
    $apiKey = $env:HOS_API_KEY
    if (-not $apiKey) {
        $apiKey = "dev-api-key"
    }
    $jwtToken = Get-DevTestJwtToken -HosApiKey $apiKey
    if (-not $jwtToken) {
        throw "Failed to obtain JWT token"
    }
    # Mask token (show last 6 chars)
    $tokenMask = if ($jwtToken.Length -gt 6) { "***" + $jwtToken.Substring($jwtToken.Length - 6) } else { "***" }
    Write-Host "PASS: Token acquired ($tokenMask)" -ForegroundColor Green
} catch {
    Write-Sanitized "FAIL: JWT token acquisition failed: $($_.Exception.Message)" "Red"
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    if ($_.Exception.Message -match "401" -or $_.Exception.Message -match "unauthorized" -or $_.Exception.Message -match "api.*key" -or $_.Exception.Message -match "Status 401") {
        Write-Host "  Set HOS_API_KEY environment variable: `$env:HOS_API_KEY = 'your-api-key'" -ForegroundColor Yellow
    } else {
        Write-Host "  - HOS may be down (check http://localhost:3000/v1/world/status)" -ForegroundColor Gray
        Write-Host "  - If docker not running, start stack: docker compose up -d" -ForegroundColor Gray
    }
    $hasFailures = $true
    exit 1
}

if ($hasFailures) {
    Write-Host ""
    Write-Host "=== PROTOTYPE FLOW SMOKE: FAIL ===" -ForegroundColor Red
    exit 1
}

# Helper: Extract tenant_id robustly from memberships
function Get-TenantIdFromMemberships {
    param([object]$Memberships)
    
    if (-not $Memberships) {
        return $null
    }
    
    # Handle array or object with data/items property
    $membershipsArray = $null
    
    # First check if it's a direct array
    if ($Memberships -is [Array]) {
        $membershipsArray = $Memberships
    }
    # Then check for PSCustomObject with data/items properties
    elseif ($Memberships -is [PSCustomObject]) {
        # Try 'items' first (common HOS API response format)
        if ($Memberships.PSObject.Properties['items'] -and $Memberships.items -is [Array]) {
            $membershipsArray = $Memberships.items
        }
        # Then try 'data'
        elseif ($Memberships.PSObject.Properties['data'] -and $Memberships.data -is [Array]) {
            $membershipsArray = $Memberships.data
        }
    }
    # Fallback: try direct property access (for dynamic objects)
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
        # Empty array - no memberships
        return $null
    }
    
    # Iterate all memberships (not just [0])
    foreach ($membership in $membershipsArray) {
        $tenantId = $null
        
        # Try different field paths in order (as specified in requirements)
        # 1) membership.tenant_id
        if ($membership.tenant_id) {
            $tenantId = $membership.tenant_id
        }
        # 2) membership.tenant.id (nested object)
        elseif ($membership.tenant -and $membership.tenant.id) {
            $tenantId = $membership.tenant.id
        }
        # 3) membership.tenant.id (via PSObject.Properties for safety)
        elseif ($membership.tenant -and $membership.tenant.PSObject.Properties['id']) {
            $tenantId = $membership.tenant.id
        }
        # 4) membership.tenantId
        elseif ($membership.tenantId) {
            $tenantId = $membership.tenantId
        }
        # 5) membership.store_tenant_id
        elseif ($membership.store_tenant_id) {
            $tenantId = $membership.store_tenant_id
        }
        
        # Validate UUID format
        if ($tenantId) {
            $guid = $null
            if ([System.Guid]::TryParse($tenantId, [ref]$guid)) {
                return $tenantId
            }
        }
    }
    
    return $null
}

# Step 2: Get tenant_id from memberships
Write-Host ""
Write-Host "[2] Getting tenant_id from memberships..." -ForegroundColor Yellow
try {
    $membershipsResponse = Invoke-RestMethod -Uri "http://localhost:3000/v1/me/memberships" `
        -Headers @{ "Authorization" = "Bearer $jwtToken" } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    
    if (-not $tenantId) {
        Write-Host "FAIL: No valid tenant_id found in memberships" -ForegroundColor Red
        
        # Print schema hint (use same logic as helper function)
        $membershipsArray = $null
        if ($membershipsResponse -is [Array]) {
            $membershipsArray = $membershipsResponse
        }
        elseif ($membershipsResponse -is [PSCustomObject]) {
            if ($membershipsResponse.PSObject.Properties['items']) {
                if ($membershipsResponse.items -is [Array]) {
                    $membershipsArray = $membershipsResponse.items
                } else {
                    Write-Host "  Expected tenant_id or tenant.id; got 'items' property but it is not an array" -ForegroundColor Yellow
                    Write-Host "    items type: $($membershipsResponse.items.GetType().Name)" -ForegroundColor Gray
                }
            }
            if (-not $membershipsArray -and $membershipsResponse.PSObject.Properties['data'] -and $membershipsResponse.data -is [Array]) {
                $membershipsArray = $membershipsResponse.data
            }
        }
        elseif ($membershipsResponse.items -is [Array]) {
            $membershipsArray = $membershipsResponse.items
        }
        elseif ($membershipsResponse.data -is [Array]) {
            $membershipsArray = $membershipsResponse.data
        }
        
        if ($membershipsArray -and $membershipsArray.Count -gt 0) {
            Write-Host "  Schema hint (first 2 items):" -ForegroundColor Yellow
            $maxItems = [Math]::Min(2, $membershipsArray.Count)
            for ($i = 0; $i -lt $maxItems; $i++) {
                $item = $membershipsArray[$i]
                $keys = $item.PSObject.Properties.Name | ForEach-Object { Sanitize-Ascii $_ }
                Write-Host "    Item $($i+1) top-level keys: $($keys -join ', ')" -ForegroundColor Gray
                if ($item.tenant) {
                    $tenantKeys = $item.tenant.PSObject.Properties.Name | ForEach-Object { Sanitize-Ascii $_ }
                    Write-Host "      tenant object keys: $($tenantKeys -join ', ')" -ForegroundColor Gray
                }
            }
            Write-Host "  Expected tenant_id field paths (tried in order):" -ForegroundColor Yellow
            Write-Host "    - membership.tenant_id" -ForegroundColor Gray
            Write-Host "    - membership.tenant.id" -ForegroundColor Gray
            Write-Host "    - membership.tenantId" -ForegroundColor Gray
            Write-Host "    - membership.store_tenant_id" -ForegroundColor Gray
        } elseif ($membershipsArray -and $membershipsArray.Count -eq 0) {
            Write-Host "  Memberships array is empty (user has no memberships)" -ForegroundColor Yellow
            Write-Host "  Remediation: User needs to be added to a tenant via HOS admin API" -ForegroundColor Gray
        } else {
            Write-Host "  No memberships array found in response" -ForegroundColor Yellow
            $responseType = $membershipsResponse.GetType().Name
            Write-Host "  Response type: $responseType" -ForegroundColor Gray
            if ($membershipsResponse -is [PSCustomObject]) {
                $responseKeys = $membershipsResponse.PSObject.Properties.Name | ForEach-Object { Sanitize-Ascii $_ }
                Write-Host "  Response top-level keys: $($responseKeys -join ', ')" -ForegroundColor Gray
                # Check if items exists but is null/not array
                if ($membershipsResponse.PSObject.Properties['items']) {
                    $itemsValue = $membershipsResponse.items
                    if ($null -eq $itemsValue) {
                        Write-Host "    'items' property exists but is null" -ForegroundColor Gray
                    } elseif ($itemsValue -isnot [Array]) {
                        Write-Host "    'items' property exists but is not an array (type: $($itemsValue.GetType().Name))" -ForegroundColor Gray
                    }
                }
            }
        }
        
        $hasFailures = $true
    } else {
        Write-Host "PASS: tenant_id acquired: $tenantId" -ForegroundColor Green
    }
} catch {
    Write-Sanitized "FAIL: Memberships request failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
}

if ($hasFailures) {
    Write-Host ""
    Write-Host "=== PROTOTYPE FLOW SMOKE: FAIL ===" -ForegroundColor Red
    exit 1
}

# Step 3: Ensure Pazar has a usable listing
Write-Host ""
Write-Host "[3] Ensuring Pazar has a usable listing..." -ForegroundColor Yellow
$listingId = $null

try {
    # Try to get existing published listing
    $listingsResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/listings?status=published&per_page=1" `
        -Headers @{ "Authorization" = "Bearer $jwtToken"; "X-Active-Tenant-Id" = $tenantId } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    if ($listingsResponse.data -and $listingsResponse.data.Count -gt 0) {
        $listingId = $listingsResponse.data[0].id
        Write-Host "PASS: Found existing listing: $listingId" -ForegroundColor Green
    } else {
        # Need to create listing
        Write-Host "  No published listing found, creating new one..." -ForegroundColor Gray
        
        # Get category_id
        $categoriesResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/categories" `
            -Headers @{ "Authorization" = "Bearer $jwtToken" } `
            -TimeoutSec 5 `
            -ErrorAction Stop
        
        $categoryId = $null
        if ($categoriesResponse -is [Array] -and $categoriesResponse.Count -gt 0) {
            $categoryId = $categoriesResponse[0].id
        } elseif ($categoriesResponse.data -and $categoriesResponse.data.Count -gt 0) {
            $categoryId = $categoriesResponse.data[0].id
        }
        
        if (-not $categoryId) {
            Write-Host "FAIL: No categories available for listing creation" -ForegroundColor Red
            $hasFailures = $true
        } else {
            # Create listing
            $createBody = @{
                category_id = $categoryId
                title = "WP-45 Prototype Listing"
                description = "Created by prototype_flow_smoke"
                transaction_modes = @("reservation")
                attributes = @{}
            } | ConvertTo-Json
            
            $createResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/listings" `
                -Method Post `
                -Headers @{
                    "Authorization" = "Bearer $jwtToken"
                    "X-Active-Tenant-Id" = $tenantId
                    "Content-Type" = "application/json"
                } `
                -Body $createBody `
                -TimeoutSec 5 `
                -ErrorAction Stop
            
            $listingId = $createResponse.id
            Write-Host "PASS: Listing created: $listingId" -ForegroundColor Green
            
            # Publish listing
            $publishResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/listings/$listingId/publish" `
                -Method Post `
                -Headers @{
                    "Authorization" = "Bearer $jwtToken"
                    "X-Active-Tenant-Id" = $tenantId
                } `
                -TimeoutSec 5 `
                -ErrorAction Stop
            
            Write-Host "PASS: Listing published: $listingId" -ForegroundColor Green
        }
    }
} catch {
    Write-Sanitized "FAIL: Listing operation failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
}

if ($hasFailures -or -not $listingId) {
    Write-Host ""
    Write-Host "=== PROTOTYPE FLOW SMOKE: FAIL ===" -ForegroundColor Red
    exit 1
}

# Step 4: Messaging flow
Write-Host ""
Write-Host "[4] Testing Messaging flow..." -ForegroundColor Yellow

$messagingBaseUrl = if ($env:MESSAGING_PUBLIC_URL) { $env:MESSAGING_PUBLIC_URL } else { "http://localhost:8090" }
$messagingApiKey = if ($env:MESSAGING_API_KEY) { $env:MESSAGING_API_KEY } else { "dev-messaging-key" }

Write-Host "  Messaging base: $messagingBaseUrl" -ForegroundColor Gray
Write-Host "  API key: $($messagingApiKey.Substring(0, [Math]::Min(12, $messagingApiKey.Length)))..." -ForegroundColor Gray

try {
    # 4.1: Upsert thread
    Write-Host "  [4.1] Upserting thread by listing context..." -ForegroundColor Gray
    $upsertBody = @{
        context_type = "listing"
        context_id = $listingId
        participants = @(
            @{ type = "tenant"; id = $tenantId },
            @{ type = "user"; id = "wp45-test-user" }
        )
    } | ConvertTo-Json -Depth 10
    
    $upsertResponse = Invoke-RestMethod -Uri "$messagingBaseUrl/api/v1/threads/upsert" `
        -Method Post `
        -Headers @{
            "messaging-api-key" = $messagingApiKey
            "Content-Type" = "application/json"
        } `
        -Body $upsertBody `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    $threadId = $upsertResponse.thread_id
    if (-not $threadId) {
        Write-Host "FAIL: Thread upsert did not return thread_id" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Thread upserted: $threadId" -ForegroundColor Green
    }
    
    if (-not $hasFailures) {
        # 4.2: Fetch thread by context
        Write-Host "  [4.2] Fetching thread by context..." -ForegroundColor Gray
        $fetchResponse = Invoke-RestMethod -Uri "$messagingBaseUrl/api/v1/threads/by-context?context_type=listing&context_id=$listingId" `
            -Headers @{ "messaging-api-key" = $messagingApiKey } `
            -TimeoutSec 5 `
            -ErrorAction Stop
        
        if ($fetchResponse.thread_id -eq $threadId) {
            Write-Host "PASS: Thread fetched by context: $threadId" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Thread ID mismatch" -ForegroundColor Red
            $hasFailures = $true
        }
        
        # 4.3: Check last message (idempotent message)
        $lastMessage = $null
        if ($fetchResponse.messages -and $fetchResponse.messages.Count -gt 0) {
            $lastMessage = $fetchResponse.messages[0]
        }
        
        if ($lastMessage -and $lastMessage.body -eq "WP-45 smoke ping") {
            Write-Host "PASS: Last message is smoke ping (idempotent)" -ForegroundColor Green
        } else {
            # Post message
            Write-Host "  [4.3] Posting smoke ping message..." -ForegroundColor Gray
            $messageBody = @{
                sender_type = "user"
                sender_id = "wp45-test-user"
                body = "WP-45 smoke ping"
            } | ConvertTo-Json
            
            $messageResponse = Invoke-RestMethod -Uri "$messagingBaseUrl/api/v1/threads/$threadId/messages" `
                -Method Post `
                -Headers @{
                    "messaging-api-key" = $messagingApiKey
                    "Content-Type" = "application/json"
                } `
                -Body $messageBody `
                -TimeoutSec 5 `
                -ErrorAction Stop
            
            if ($messageResponse.message_id) {
                Write-Host "PASS: Message posted: $($messageResponse.message_id)" -ForegroundColor Green
            } else {
                Write-Host "FAIL: Message post did not return message_id" -ForegroundColor Red
                $hasFailures = $true
            }
        }
        
        # 4.4: Re-fetch and assert message exists
        if (-not $hasFailures) {
            Write-Host "  [4.4] Re-fetching thread to assert message..." -ForegroundColor Gray
            $refetchResponse = Invoke-RestMethod -Uri "$messagingBaseUrl/api/v1/threads/by-context?context_type=listing&context_id=$listingId" `
                -Headers @{ "messaging-api-key" = $messagingApiKey } `
                -TimeoutSec 5 `
                -ErrorAction Stop
            
            $hasMessage = $false
            if ($refetchResponse.messages) {
                foreach ($msg in $refetchResponse.messages) {
                    if ($msg.body -eq "WP-45 smoke ping") {
                        $hasMessage = $true
                        break
                    }
                }
            }
            
            if ($hasMessage) {
                Write-Host "PASS: Message found in thread" -ForegroundColor Green
            } else {
                Write-Host "FAIL: Message not found in thread" -ForegroundColor Red
                $hasFailures = $true
            }
        }
    }
} catch {
    Write-Sanitized "FAIL: Messaging flow failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
}

# Summary
Write-Host ""
if ($hasFailures) {
    Write-Host "=== PROTOTYPE FLOW SMOKE: FAIL ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== PROTOTYPE FLOW SMOKE: PASS ===" -ForegroundColor Green
    exit 0
}

