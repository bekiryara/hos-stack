#!/usr/bin/env pwsh
# MESSAGING WRITE CONTRACT CHECK (WP-16)
# Verifies WP-16 messaging write endpoints with authorization, idempotency, and validation.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== MESSAGING WRITE CONTRACT CHECK (WP-19) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Base URL: MESSAGING_BASE_URL env (highest priority) or default localhost:8090
$messagingBaseUrl = $env:MESSAGING_BASE_URL
if (-not $messagingBaseUrl) {
    $messagingBaseUrl = "http://localhost:8090"
}

$testUserId = "fd08f7f8-8c8a-95de-4a3d-28dbb7aee839" # Deterministic test user ID
$testTenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic test tenant ID

# Get test auth token from env - FAIL FAST if missing (WP-19)
$authToken = $env:PRODUCT_TEST_AUTH
if (-not $authToken) {
    $authToken = $env:HOS_TEST_AUTH
}
if (-not $authToken) {
    Write-Host "FAIL: PRODUCT_TEST_AUTH or HOS_TEST_AUTH environment variable is required" -ForegroundColor Red
    Write-Host "Set PRODUCT_TEST_AUTH='Bearer <token>' and rerun." -ForegroundColor Yellow
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
}

$threadId = $null
$messageId = $null

# Generate deterministic idempotency keys
$now = Get-Date
$threadIdempotencyKey = "test-thread-key-" + $now.ToString("yyyyMMddHHmmss") + "-" + $now.Millisecond.ToString("D3")
$messageIdempotencyKey = "test-message-key-" + $now.ToString("yyyyMMddHHmmss") + "-" + ($now.Millisecond + 1).ToString("D3")

# Test 1: POST /api/v1/threads - Valid request (201 Created)
Write-Host "[1] Testing POST /api/v1/threads (valid request)..." -ForegroundColor Yellow
try {
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "Idempotency-Key" = $threadIdempotencyKey
    }
    $threadBody = @{
        context_type = "order"
        context_id = [guid]::NewGuid().ToString()
        participants = @(
            @{ type = "user"; id = $testUserId },
            @{ type = "tenant"; id = $testTenantId }
        )
    } | ConvertTo-Json -Depth 10
    
    $createThreadUrl = "${messagingBaseUrl}/api/v1/threads"
    $createResponse = Invoke-RestMethod -Uri $createThreadUrl -Method Post -Body $threadBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if (-not $createResponse.thread_id) {
        Write-Host "FAIL: Create thread response missing 'thread_id'" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $threadId = $createResponse.thread_id
        Write-Host "PASS: Thread created successfully" -ForegroundColor Green
        Write-Host "  Thread ID: $threadId" -ForegroundColor Gray
        Write-Host "  Context Type: $($createResponse.context_type)" -ForegroundColor Gray
        Write-Host "  Context ID: $($createResponse.context_id)" -ForegroundColor Gray
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    Write-Host "FAIL: Create thread request failed" -ForegroundColor Red
    Write-Host "  Endpoint: $createThreadUrl" -ForegroundColor Yellow
    if ($statusCode) {
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
    }
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    $errorBody = $null
    try {
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            if ($errorBody) {
                $errorSnippet = if ($errorBody.Length -gt 200) { $errorBody.Substring(0, 200) + "..." } else { $errorBody }
                Write-Host "  Response: $errorSnippet" -ForegroundColor Yellow
            }
        }
    } catch {
    }
    $hasFailures = $true
}

Write-Host ""

# Test 2: POST /api/v1/threads - Idempotency replay (409 CONFLICT)
if ($threadId) {
    Write-Host "[2] Testing POST /api/v1/threads (idempotency replay)..." -ForegroundColor Yellow
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            "Idempotency-Key" = $threadIdempotencyKey
        }
        $replayResponse = Invoke-RestMethod -Uri $createThreadUrl -Method Post -Body $threadBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        Write-Host "FAIL: Idempotency replay should return 409 CONFLICT" -ForegroundColor Red
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
            Write-Host "PASS: Idempotency replay returned 409 CONFLICT" -ForegroundColor Green
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errorBody = $reader.ReadToEnd() | ConvertFrom-Json
                if ($errorBody.error -eq "CONFLICT" -and $errorBody.thread_id -eq $threadId) {
                    Write-Host "  Thread ID matches: $($errorBody.thread_id)" -ForegroundColor Gray
                } else {
                    Write-Host "  WARN: Error response format unexpected" -ForegroundColor Yellow
                }
            } catch {
            }
        } else {
            Write-Host "FAIL: Expected 409 CONFLICT, got $statusCode" -ForegroundColor Red
            Write-Host "  Endpoint: $createThreadUrl" -ForegroundColor Yellow
            $hasFailures = $true
        }
    }
} else {
    Write-Host "[2] SKIP: Cannot test idempotency (thread ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 3: POST /api/v1/threads - Missing Authorization (401 AUTH_REQUIRED)
Write-Host "[3] Testing POST /api/v1/threads (missing Authorization)..." -ForegroundColor Yellow
try {
    $headers = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = ([guid]::NewGuid().ToString())
    }
    $testBody = @{
        context_type = "order"
        context_id = [guid]::NewGuid().ToString()
        participants = @(
            @{ type = "user"; id = $testUserId }
        )
    } | ConvertTo-Json -Depth 10
    
    Invoke-RestMethod -Uri $createThreadUrl -Method Post -Body $testBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Request without Authorization should return 401" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    if ($statusCode -eq 401) {
        Write-Host "PASS: Missing Authorization returned 401 AUTH_REQUIRED" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Expected 401 AUTH_REQUIRED, got $statusCode" -ForegroundColor Red
        Write-Host "  Endpoint: $createThreadUrl" -ForegroundColor Yellow
        $hasFailures = $true
    }
}

Write-Host ""

# Test 4: POST /api/v1/threads - Invalid participants (422 VALIDATION_ERROR)
Write-Host "[4] Testing POST /api/v1/threads (invalid participants)..." -ForegroundColor Yellow
try {
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "Idempotency-Key" = ([guid]::NewGuid().ToString())
    }
    $invalidBody = @{
        context_type = "order"
        context_id = [guid]::NewGuid().ToString()
        participants = @()  # Empty array
    } | ConvertTo-Json -Depth 10
    
    Invoke-RestMethod -Uri $createThreadUrl -Method Post -Body $invalidBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Invalid participants should return 422 VALIDATION_ERROR" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    if ($statusCode -eq 422 -or $statusCode -eq 400) {
        Write-Host "PASS: Invalid participants returned $statusCode VALIDATION_ERROR" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Expected 422/400 VALIDATION_ERROR, got $statusCode" -ForegroundColor Red
        Write-Host "  Endpoint: $createThreadUrl" -ForegroundColor Yellow
        $hasFailures = $true
    }
}

Write-Host ""

# Test 5: POST /api/v1/messages - Valid request (201 Created)
if ($threadId) {
    Write-Host "[5] Testing POST /api/v1/messages (valid request)..." -ForegroundColor Yellow
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            "Idempotency-Key" = $messageIdempotencyKey
        }
        $messageBody = @{
            thread_id = $threadId
            body = "Test message from WP-16 contract check"
        } | ConvertTo-Json
        
        $createMessageUrl = "${messagingBaseUrl}/api/v1/messages"
        $createResponse = Invoke-RestMethod -Uri $createMessageUrl -Method Post -Body $messageBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        if (-not $createResponse.message_id) {
            Write-Host "FAIL: Create message response missing 'message_id'" -ForegroundColor Red
            $hasFailures = $true
        } else {
            $messageId = $createResponse.message_id
            Write-Host "PASS: Message created successfully" -ForegroundColor Green
            Write-Host "  Message ID: $messageId" -ForegroundColor Gray
            Write-Host "  Thread ID: $($createResponse.thread_id)" -ForegroundColor Gray
            Write-Host "  Body: $($createResponse.body)" -ForegroundColor Gray
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        Write-Host "FAIL: Create message request failed" -ForegroundColor Red
        Write-Host "  Endpoint: $createMessageUrl" -ForegroundColor Yellow
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        $errorBody = $null
        try {
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errorBody = $reader.ReadToEnd()
                if ($errorBody) {
                    $errorSnippet = if ($errorBody.Length -gt 200) { $errorBody.Substring(0, 200) + "..." } else { $errorBody }
                    Write-Host "  Response: $errorSnippet" -ForegroundColor Yellow
                }
            }
        } catch {
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[5] SKIP: Cannot test message creation (thread ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 6: POST /api/v1/messages - Idempotency replay (409 CONFLICT)
if ($messageId) {
    Write-Host "[6] Testing POST /api/v1/messages (idempotency replay)..." -ForegroundColor Yellow
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            "Idempotency-Key" = $messageIdempotencyKey
        }
        $replayResponse = Invoke-RestMethod -Uri $createMessageUrl -Method Post -Body $messageBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        Write-Host "FAIL: Idempotency replay should return 409 CONFLICT" -ForegroundColor Red
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
            Write-Host "PASS: Idempotency replay returned 409 CONFLICT" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Expected 409 CONFLICT, got $statusCode" -ForegroundColor Red
            Write-Host "  Endpoint: $createThreadUrl" -ForegroundColor Yellow
            $hasFailures = $true
        }
    }
} else {
    Write-Host "[6] SKIP: Cannot test idempotency (message ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 7: POST /api/v1/messages - Missing Authorization (401 AUTH_REQUIRED)
Write-Host "[7] Testing POST /api/v1/messages (missing Authorization)..." -ForegroundColor Yellow
try {
    $headers = @{
        "Content-Type" = "application/json"
        "Idempotency-Key" = ([guid]::NewGuid().ToString())
    }
    $testBody = @{
        thread_id = if ($threadId) { $threadId } else { [guid]::NewGuid().ToString() }
        body = "Test message"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri $createMessageUrl -Method Post -Body $testBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Request without Authorization should return 401" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    if ($statusCode -eq 401) {
        Write-Host "PASS: Missing Authorization returned 401 AUTH_REQUIRED" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Expected 401 AUTH_REQUIRED, got $statusCode" -ForegroundColor Red
        Write-Host "  Endpoint: $createThreadUrl" -ForegroundColor Yellow
        $hasFailures = $true
    }
}

Write-Host ""

# Test 8: POST /api/v1/messages - Thread not found (404 NOT_FOUND)
Write-Host "[8] Testing POST /api/v1/messages (thread not found)..." -ForegroundColor Yellow
try {
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "Idempotency-Key" = ([guid]::NewGuid().ToString())
    }
    $testBody = @{
        thread_id = [guid]::NewGuid().ToString()  # Non-existent thread ID
        body = "Test message"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri $createMessageUrl -Method Post -Body $testBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Non-existent thread should return 404 NOT_FOUND" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    if ($statusCode -eq 404) {
        Write-Host "PASS: Non-existent thread returned 404 NOT_FOUND" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Expected 404 NOT_FOUND, got $statusCode" -ForegroundColor Red
        Write-Host "  Endpoint: $createMessageUrl" -ForegroundColor Yellow
        $hasFailures = $true
    }
}

Write-Host ""

# Test 9: POST /api/v1/messages - User not participant (403 FORBIDDEN_SCOPE)
# Create a thread with different participants, then try to send message as test user
Write-Host "[9] Testing POST /api/v1/messages (user not participant)..." -ForegroundColor Yellow
try {
    # Create a thread with different user (not test user)
    $otherUserId = [guid]::NewGuid().ToString()
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "Idempotency-Key" = ([guid]::NewGuid().ToString())
    }
    $otherThreadBody = @{
        context_type = "order"
        context_id = [guid]::NewGuid().ToString()
        participants = @(
            @{ type = "user"; id = $otherUserId },
            @{ type = "tenant"; id = $testTenantId }
        )
    } | ConvertTo-Json -Depth 10
    
    $otherThreadResponse = Invoke-RestMethod -Uri $createThreadUrl -Method Post -Body $otherThreadBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    $otherThreadId = $otherThreadResponse.thread_id
    
    # Try to send message as test user (not participant)
    $messageHeaders = @{
        "Content-Type" = "application/json"
        "Authorization" = $authToken
        "Idempotency-Key" = ([guid]::NewGuid().ToString())
    }
    $testMessageBody = @{
        thread_id = $otherThreadId
        body = "Test message"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri $createMessageUrl -Method Post -Body $testMessageBody -Headers $messageHeaders -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: User not participant should return 403 FORBIDDEN_SCOPE" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    if ($statusCode -eq 403) {
        Write-Host "PASS: User not participant returned 403 FORBIDDEN_SCOPE" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Expected 403 FORBIDDEN_SCOPE, got $statusCode" -ForegroundColor Red
        Write-Host "  Endpoint: $createMessageUrl" -ForegroundColor Yellow
        $hasFailures = $true
    }
}

Write-Host ""

# Test 10: POST /api/v1/messages - Invalid body (422 VALIDATION_ERROR)
Write-Host "[10] Testing POST /api/v1/messages (invalid body - too long)..." -ForegroundColor Yellow
if ($threadId) {
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
            "Idempotency-Key" = ([guid]::NewGuid().ToString())
        }
        $invalidBody = @{
            thread_id = $threadId
            body = "x" * 10001  # > 10000 chars
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri $createMessageUrl -Method Post -Body $invalidBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        Write-Host "FAIL: Body too long should return 422 VALIDATION_ERROR" -ForegroundColor Red
        $hasFailures = $true
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
            } catch {
            }
        }
        if ($statusCode -eq 422 -or $statusCode -eq 400) {
            Write-Host "PASS: Body too long returned $statusCode VALIDATION_ERROR" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Expected 422/400 VALIDATION_ERROR, got $statusCode" -ForegroundColor Red
            $hasFailures = $true
        }
    }
} else {
    Write-Host "[10] SKIP: Cannot test invalid body (thread ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Legacy endpoint compatibility check (non-blocking INFO)
Write-Host "[INFO] Testing legacy endpoints for backward compatibility..." -ForegroundColor Cyan
try {
    $legacyHeaders = @{
        "messaging-api-key" = "dev-messaging-key"
        "Content-Type" = "application/json"
    }
    $legacyUpsertBody = @{
        context_type = "test"
        context_id = "legacy-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
        participants = @(
            @{ type = "user"; id = $testUserId }
        )
    } | ConvertTo-Json -Depth 10
    
    $legacyUpsertUrl = "${messagingBaseUrl}/api/v1/threads/upsert"
    $legacyResponse = Invoke-RestMethod -Uri $legacyUpsertUrl -Method Post -Body $legacyUpsertBody -Headers $legacyHeaders -TimeoutSec 5 -ErrorAction Stop
    if ($legacyResponse.thread_id) {
        Write-Host "INFO: Legacy POST /api/v1/threads/upsert endpoint works" -ForegroundColor Gray
        Write-Host "  Thread ID: $($legacyResponse.thread_id)" -ForegroundColor Gray
    }
} catch {
    Write-Host "INFO: Legacy endpoint check skipped (non-blocking)" -ForegroundColor Gray
}

Write-Host ""

# Summary
Write-Host "=== MESSAGING WRITE CONTRACT CHECK SUMMARY ===" -ForegroundColor Cyan
Write-Host "Base URL: $messagingBaseUrl" -ForegroundColor Gray
if ($hasFailures) {
    Write-Host "RESULT: FAIL" -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "RESULT: PASS" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}
