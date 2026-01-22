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
    $jwtToken = Get-DevTestJwtToken
    if (-not $jwtToken) {
        throw "Failed to obtain JWT token"
    }
    Write-Host "PASS: Token acquired" -ForegroundColor Green
} catch {
    Write-Sanitized "FAIL: JWT token acquisition failed: $($_.Exception.Message)" "Red"
    Write-Host ""
    Write-Host "Hints:" -ForegroundColor Yellow
    Write-Host "  - HOS may be down (check http://localhost:3000/v1/world/status)" -ForegroundColor Gray
    Write-Host "  - Dev auth helper may fail; verify ops/_lib/test_auth.ps1 config" -ForegroundColor Gray
    Write-Host "  - If docker not running, start stack: docker compose up -d" -ForegroundColor Gray
    $hasFailures = $true
    exit 1
}

if ($hasFailures) {
    Write-Host ""
    Write-Host "=== PROTOTYPE FLOW SMOKE: FAIL ===" -ForegroundColor Red
    exit 1
}

# Step 2: Get tenant_id from memberships
Write-Host ""
Write-Host "[2] Getting tenant_id from memberships..." -ForegroundColor Yellow
try {
    $membershipsResponse = Invoke-RestMethod -Uri "http://localhost:3000/v1/me/memberships" `
        -Headers @{ "Authorization" = "Bearer $jwtToken" } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    if (-not $membershipsResponse -or $membershipsResponse.Count -eq 0) {
        Write-Host "FAIL: No memberships found" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $tenantId = $membershipsResponse[0].tenant_id
        if (-not $tenantId) {
            Write-Host "FAIL: First membership missing tenant_id" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: tenant_id acquired: $tenantId" -ForegroundColor Green
        }
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

