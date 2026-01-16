#!/usr/bin/env pwsh
# MESSAGING CONTRACT CHECK (WP-5)
# Verifies Messaging API endpoints (thread upsert, message post, by-context lookup).

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== MESSAGING CONTRACT CHECK (WP-5) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$messagingBaseUrl = "http://localhost:8090"
$apiKey = "dev-messaging-key"
$testContextType = "reservation"
$testContextId = "test-" + (Get-Date -Format 'yyyyMMddHHmmss')
$threadId = $null

# Test 1: World status endpoint
Write-Host "[1] Testing GET /api/world/status..." -ForegroundColor Yellow
try {
    $statusResponse = Invoke-RestMethod -Uri "${messagingBaseUrl}/api/world/status" -Method Get -TimeoutSec 5 -ErrorAction Stop
    
    if ($statusResponse.world_key -eq "messaging" -and $statusResponse.availability -eq "ONLINE") {
        Write-Host "PASS: World status returns valid response" -ForegroundColor Green
        Write-Host "  world_key: $($statusResponse.world_key)" -ForegroundColor Gray
        Write-Host "  availability: $($statusResponse.availability)" -ForegroundColor Gray
        Write-Host "  phase: $($statusResponse.phase)" -ForegroundColor Gray
        Write-Host "  version: $($statusResponse.version)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Invalid world status response" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Could not get world status: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

if ($hasFailures) {
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
}

# Test 2: Upsert thread
Write-Host "[2] Testing POST /api/v1/threads/upsert..." -ForegroundColor Yellow
try {
    $upsertBody = @{
        context_type = $testContextType
        context_id = $testContextId
        participants = @(
            @{ type = "user"; id = "test-user-123" },
            @{ type = "tenant"; id = "test-tenant-456" }
        )
    } | ConvertTo-Json -Depth 10
    
    $upsertHeaders = @{
        "messaging-api-key" = $apiKey
        "Content-Type" = "application/json"
    }
    
    $upsertResponse = Invoke-RestMethod -Uri "${messagingBaseUrl}/api/v1/threads/upsert" -Method Post -Body $upsertBody -Headers $upsertHeaders -TimeoutSec 5 -ErrorAction Stop
    
    if ($upsertResponse.thread_id) {
        $threadId = $upsertResponse.thread_id
        Write-Host "PASS: Thread upserted successfully" -ForegroundColor Green
        Write-Host "  Thread ID: $threadId" -ForegroundColor Gray
        Write-Host "  Context: $testContextType / $testContextId" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Thread upsert did not return thread_id" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Could not upsert thread: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

if ($hasFailures -or -not $threadId) {
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
}

# Test 3: Post message
Write-Host "[3] Testing POST /api/v1/threads/$threadId/messages..." -ForegroundColor Yellow
try {
    $messageBody = @{
        sender_type = "user"
        sender_id = "test-user-123"
        body = "Test message from contract check"
    } | ConvertTo-Json
    
    $messageHeaders = @{
        "messaging-api-key" = $apiKey
        "Content-Type" = "application/json"
    }
    
    $messageResponse = Invoke-RestMethod -Uri "${messagingBaseUrl}/api/v1/threads/$threadId/messages" -Method Post -Body $messageBody -Headers $messageHeaders -TimeoutSec 5 -ErrorAction Stop
    
    if ($messageResponse.message_id) {
        Write-Host "PASS: Message posted successfully" -ForegroundColor Green
        Write-Host "  Message ID: $($messageResponse.message_id)" -ForegroundColor Gray
        Write-Host "  Body: $($messageResponse.body)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Message post did not return message_id" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Could not post message: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# Test 4: Get thread by context
Write-Host "[4] Testing GET /api/v1/threads/by-context?context_type=$testContextType&context_id=$testContextId..." -ForegroundColor Yellow
try {
        $byContextHeaders = @{
            "messaging-api-key" = $apiKey
        }
    
    $byContextUrl = "${messagingBaseUrl}/api/v1/threads/by-context?context_type=$testContextType&context_id=$testContextId"
    $byContextResponse = Invoke-RestMethod -Uri $byContextUrl -Method Get -Headers $byContextHeaders -TimeoutSec 5 -ErrorAction Stop
    
    if ($byContextResponse.thread_id -eq $threadId -and $byContextResponse.messages.Count -gt 0) {
        Write-Host "PASS: Thread by-context lookup successful" -ForegroundColor Green
        Write-Host "  Thread ID: $($byContextResponse.thread_id)" -ForegroundColor Gray
        Write-Host "  Participants: $($byContextResponse.participants.Count)" -ForegroundColor Gray
        Write-Host "  Messages: $($byContextResponse.messages.Count)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Thread by-context lookup did not return expected thread or messages" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Could not get thread by context: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# Summary
Write-Host "=== MESSAGING CONTRACT CHECK: $(if ($hasFailures) { 'FAIL' } else { 'PASS' }) ===" -ForegroundColor $(if ($hasFailures) { 'Red' } else { 'Green' })
Write-Host ""

if ($hasFailures) {
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
}

exit 0

