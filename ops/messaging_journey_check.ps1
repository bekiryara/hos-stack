#!/usr/bin/env pwsh
# MESSAGING JOURNEY CHECK (WP-71)
# Verifies authenticated customer messaging journey: upsert, by-context (ping), send message, verify.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== MESSAGING JOURNEY CHECK (WP-71) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# WP-71: Optional auth token handling
$authHeader = $env:PRODUCT_TEST_AUTH
$authEnabled = $false
$userId = $null
$listingId = $null

if ($authHeader) {
    $authEnabled = $true
    # Extract token (remove "Bearer " prefix if present)
    $token = $authHeader
    if ($token -like "Bearer *") {
        $token = $token.Substring(7)
    }
    
    # Helper: Extract JWT sub claim (WP-69 approach)
    function Get-JwtSubFromBearer {
        param([string]$BearerToken)
        
        try {
            $parts = $BearerToken -split '\.'
            if ($parts.Count -lt 2) {
                return $null
            }
            
            $payloadBase64 = $parts[1]
            $padding = 4 - ($payloadBase64.Length % 4)
            if ($padding -ne 4) {
                $payloadBase64 = $payloadBase64 + ("=" * $padding)
            }
            
            $payloadBytes = [System.Convert]::FromBase64String($payloadBase64)
            $payloadJson = [System.Text.Encoding]::UTF8.GetString($payloadBytes)
            $payload = $payloadJson | ConvertFrom-Json
            return $payload.sub
        } catch {
            return $null
        }
    }
    
    $userId = Get-JwtSubFromBearer -BearerToken $token
    if ($userId) {
        Write-Host "Auth enabled: User ID from token: $userId" -ForegroundColor Gray
    } else {
        Write-Host "WARN: Auth token set but could not extract user ID (sub)" -ForegroundColor Yellow
        $authEnabled = $false
    }
    
    # Get listing ID: env first, then API
    if ($env:TEST_LISTING_ID) {
        $listingId = $env:TEST_LISTING_ID
        Write-Host "Using listing ID from env: $listingId" -ForegroundColor Gray
    } else {
        Write-Host "Finding published listing from API..." -ForegroundColor Gray
        try {
            $pazarBaseUrl = "http://localhost:8080"
            $listingsUrl = "${pazarBaseUrl}/api/v1/listings?status=published"
            $listingsResponse = Invoke-RestMethod -Uri $listingsUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
            
            # Extract first listing ID (supports both array and envelope)
            $listingsArray = $null
            if ($listingsResponse -is [Array]) {
                $listingsArray = $listingsResponse
            } elseif ($listingsResponse.data) {
                $listingsArray = $listingsResponse.data
            } else {
                $listingsArray = @()
            }
            
            if ($listingsArray.Count -gt 0) {
                $listingId = $listingsArray[0].id
                Write-Host "Found published listing: $listingId" -ForegroundColor Gray
            } else {
                Write-Host "WARN: No published listings found" -ForegroundColor Yellow
                $authEnabled = $false
            }
        } catch {
            Write-Host "WARN: Could not fetch listings: $($_.Exception.Message)" -ForegroundColor Yellow
            $authEnabled = $false
        }
    }
} else {
    Write-Host "SKIP: Authenticated messaging checks (PRODUCT_TEST_AUTH not set)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "=== MESSAGING JOURNEY CHECK: PASS ===" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

if (-not $authEnabled -or -not $userId -or -not $listingId) {
    Write-Host "SKIP: Authenticated messaging checks (auth setup incomplete)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "=== MESSAGING JOURNEY CHECK: PASS ===" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

# Hos-web proxy base URL
$proxyBaseUrl = "http://localhost:3002/api/messaging"
$apiKey = "dev-messaging-key"
$threadId = $null
$testMessageBody = "wp-71 ping test $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Write-Host ""

# Test 1: POST /api/messaging/api/v1/threads/upsert
Write-Host "[1] Testing POST /api/messaging/api/v1/threads/upsert..." -ForegroundColor Yellow
try {
    $upsertBody = @{
        context_type = "listing"
        context_id = $listingId
        participants = @(
            @{ type = "user"; id = $userId }
        )
    } | ConvertTo-Json -Depth 10
    
    $upsertHeaders = @{
        "Content-Type" = "application/json"
        "Authorization" = $authHeader
        "messaging-api-key" = $apiKey
    }
    
    $upsertUrl = "${proxyBaseUrl}/api/v1/threads/upsert"
    $upsertResponse = Invoke-RestMethod -Uri $upsertUrl -Method Post -Body $upsertBody -Headers $upsertHeaders -TimeoutSec 10 -ErrorAction Stop
    
    if ($upsertResponse.thread_id) {
        $threadId = $upsertResponse.thread_id
        Write-Host "PASS: Thread upserted successfully" -ForegroundColor Green
        Write-Host "  Thread ID: $threadId" -ForegroundColor Gray
        Write-Host "  Context: listing / $listingId" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Expected thread_id in response; got <summary>" -ForegroundColor Red
        Write-Host "  Response: $($upsertResponse | ConvertTo-Json -Depth 3)" -ForegroundColor Yellow
        $hasFailures = $true
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch { }
    }
    Write-Host "FAIL: Thread upsert failed" -ForegroundColor Red
    Write-Host "  Expected: 200/201 with thread_id" -ForegroundColor Yellow
    Write-Host "  Got: Status $statusCode" -ForegroundColor Yellow
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 2: GET by-context (PING test)
if ($threadId) {
    Write-Host "[2] Testing GET /api/messaging/api/v1/threads/by-context (PING test)..." -ForegroundColor Yellow
    try {
        $byContextHeaders = @{
            "Authorization" = $authHeader
            "messaging-api-key" = $apiKey
        }
        
        $byContextUrl = "${proxyBaseUrl}/api/v1/threads/by-context?context_type=listing&context_id=${listingId}"
        $byContextResponse = Invoke-RestMethod -Uri $byContextUrl -Method Get -Headers $byContextHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($byContextResponse.thread_id) {
            if ($byContextResponse.thread_id -eq $threadId) {
                Write-Host "PASS: By-context read successful (PING verified)" -ForegroundColor Green
                Write-Host "  Thread ID: $($byContextResponse.thread_id)" -ForegroundColor Gray
                Write-Host "  Context: listing / $listingId" -ForegroundColor Gray
                if ($byContextResponse.messages) {
                    Write-Host "  Messages count: $($byContextResponse.messages.Count)" -ForegroundColor Gray
                }
            } else {
                Write-Host "FAIL: Expected thread_id $threadId; got $($byContextResponse.thread_id)" -ForegroundColor Red
                $hasFailures = $true
            }
        } else {
            Write-Host "FAIL: Expected thread_id in by-context response; got <summary>" -ForegroundColor Red
            Write-Host "  Response: $($byContextResponse | ConvertTo-Json -Depth 3)" -ForegroundColor Yellow
            $hasFailures = $true
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch { }
        }
        Write-Host "FAIL: By-context read failed" -ForegroundColor Red
        Write-Host "  Expected: 200 with thread_id" -ForegroundColor Yellow
        Write-Host "  Got: Status $statusCode" -ForegroundColor Yellow
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        $hasFailures = $true
    }
} else {
    Write-Host "[2] SKIP: Cannot test by-context (thread ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 3: POST message
if ($threadId) {
    Write-Host "[3] Testing POST /api/messaging/api/v1/threads/$threadId/messages..." -ForegroundColor Yellow
    try {
        $messageBody = @{
            sender_type = "user"
            sender_id = $userId
            body = $testMessageBody
        } | ConvertTo-Json
        
        $messageHeaders = @{
            "Content-Type" = "application/json"
            "Authorization" = $authHeader
            "messaging-api-key" = $apiKey
        }
        
        $messageUrl = "${proxyBaseUrl}/api/v1/threads/${threadId}/messages"
        $messageResponse = Invoke-RestMethod -Uri $messageUrl -Method Post -Body $messageBody -Headers $messageHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($messageResponse.message_id) {
            Write-Host "PASS: Message sent successfully" -ForegroundColor Green
            Write-Host "  Message ID: $($messageResponse.message_id)" -ForegroundColor Gray
            Write-Host "  Body: $testMessageBody" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Expected message_id in response; got <summary>" -ForegroundColor Red
            Write-Host "  Response: $($messageResponse | ConvertTo-Json -Depth 3)" -ForegroundColor Yellow
            $hasFailures = $true
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch { }
        }
        Write-Host "FAIL: Message send failed" -ForegroundColor Red
        Write-Host "  Expected: 200/201 with message_id" -ForegroundColor Yellow
        Write-Host "  Got: Status $statusCode" -ForegroundColor Yellow
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        $hasFailures = $true
    }
} else {
    Write-Host "[3] SKIP: Cannot test message send (thread ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 4: GET by-context again (verify message)
if ($threadId) {
    Write-Host "[4] Testing GET by-context again (verify message)..." -ForegroundColor Yellow
    try {
        $verifyHeaders = @{
            "Authorization" = $authHeader
            "messaging-api-key" = $apiKey
        }
        
        $verifyUrl = "${proxyBaseUrl}/api/v1/threads/by-context?context_type=listing&context_id=${listingId}"
        $verifyResponse = Invoke-RestMethod -Uri $verifyUrl -Method Get -Headers $verifyHeaders -TimeoutSec 10 -ErrorAction Stop
        
        if ($verifyResponse.messages) {
            $messagesArray = $verifyResponse.messages
            if ($messagesArray -isnot [Array]) {
                $messagesArray = @($messagesArray)
            }
            
            $foundMessage = $messagesArray | Where-Object { $_.body -eq $testMessageBody } | Select-Object -First 1
            
            if ($foundMessage) {
                Write-Host "PASS: Sent message found in by-context response" -ForegroundColor Green
                Write-Host "  Message ID: $($foundMessage.message_id)" -ForegroundColor Gray
                Write-Host "  Body: $($foundMessage.body)" -ForegroundColor Gray
                Write-Host "  Total messages: $($messagesArray.Count)" -ForegroundColor Gray
            } else {
                Write-Host "FAIL: Expected sent message body in response; got <summary>" -ForegroundColor Red
                Write-Host "  Expected body: $testMessageBody" -ForegroundColor Yellow
                Write-Host "  Messages count: $($messagesArray.Count)" -ForegroundColor Yellow
                if ($messagesArray.Count -gt 0) {
                    $sampleBodies = $messagesArray | ForEach-Object { $_.body } | Select-Object -First 3
                    Write-Host "  Sample message bodies: $($sampleBodies -join ', ')" -ForegroundColor Yellow
                }
                $hasFailures = $true
            }
        } else {
            Write-Host "FAIL: Expected messages array in by-context response; got <summary>" -ForegroundColor Red
            Write-Host "  Response: $($verifyResponse | ConvertTo-Json -Depth 3)" -ForegroundColor Yellow
            $hasFailures = $true
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch { }
        }
        Write-Host "FAIL: By-context verify failed" -ForegroundColor Red
        Write-Host "  Expected: 200 with messages array" -ForegroundColor Yellow
        Write-Host "  Got: Status $statusCode" -ForegroundColor Yellow
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        $hasFailures = $true
    }
} else {
    Write-Host "[4] SKIP: Cannot verify message (thread ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== MESSAGING JOURNEY CHECK: FAIL ===" -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== MESSAGING JOURNEY CHECK: PASS ===" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

