#!/usr/bin/env pwsh
# PERSONA & SCOPE CHECK (WP-8)
# Verifies Persona & Scope Lock enforcement for Marketplace endpoints.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== PERSONA & SCOPE CHECK (WP-8) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$tenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic UUID for tenant-demo
$authToken = "Bearer test-token-genesis" # GENESIS: simple test token

Write-Host ""

# Test 1: GUEST read - categories endpoint (should allow without auth)
Write-Host "[1] Testing GUEST read: GET /api/v1/categories (no auth required)..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/categories" -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if ($response -is [Array] -and $response.Count -gt 0) {
        Write-Host "PASS: GUEST read allowed (categories returned)" -ForegroundColor Green
        Write-Host "  Root categories: $($response.Count)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: GUEST read returned empty or invalid response" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    Write-Host "FAIL: GUEST read failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($statusCode) {
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

Write-Host ""

# Test 2: GUEST read - listings search (should allow without auth)
Write-Host "[2] Testing GUEST read: GET /api/v1/listings (no auth required)..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings?status=published" -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if ($response -is [Array]) {
        Write-Host "PASS: GUEST read allowed (listings returned)" -ForegroundColor Green
        Write-Host "  Results count: $($response.Count)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: GUEST read returned invalid response" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    Write-Host "FAIL: GUEST read failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($statusCode) {
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

Write-Host ""

# Test 3: PERSONAL negative - reservation create without Authorization
Write-Host "[3] Testing PERSONAL negative: POST /api/v1/reservations without Authorization (should be 401)..." -ForegroundColor Yellow

$reservationBody = @{
    listing_id = "00000000-0000-0000-0000-000000000000"
    slot_start = "2026-12-25T10:00:00Z"
    slot_end = "2026-12-25T12:00:00Z"
    party_size = 10
} | ConvertTo-Json

$reservationHeaders = @{
    "Content-Type" = "application/json"
    "Idempotency-Key" = "test-no-auth-" + (Get-Date -Format "yyyyMMddHHmmss")
}

try {
    $response = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/reservations" -Method Post -Body $reservationBody -Headers $reservationHeaders -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Reservation create without Authorization was accepted (should be 401)" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    $errorResponse = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $errorResponse = $responseBody | ConvertFrom-Json
            $reader.Close()
        } catch {
        }
    }
    
    if ($statusCode -eq 401) {
        if ($errorResponse -and $errorResponse.error) {
            if ($errorResponse.error -eq "AUTH_REQUIRED") {
                Write-Host "PASS: Missing Authorization correctly returned 401 AUTH_REQUIRED" -ForegroundColor Green
                Write-Host "  Status Code: 401" -ForegroundColor Gray
                Write-Host "  Error: $($errorResponse.error)" -ForegroundColor Gray
            } else {
                Write-Host "PASS: Missing Authorization correctly returned 401 (error: $($errorResponse.error))" -ForegroundColor Green
                Write-Host "  Status Code: 401" -ForegroundColor Gray
            }
        } else {
            # 401 returned but error response parsing failed - still PASS (status code is correct)
            Write-Host "PASS: Missing Authorization correctly returned 401" -ForegroundColor Green
            Write-Host "  Status Code: 401" -ForegroundColor Gray
            Write-Host "  Note: Error response parsing failed, but 401 status is correct" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Missing Authorization returned wrong status: $statusCode (expected 401)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 4: STORE negative - listing create without X-Active-Tenant-Id
Write-Host "[4] Testing STORE negative: POST /api/v1/listings without X-Active-Tenant-Id (should be 400/403)..." -ForegroundColor Yellow

$listingBody = @{
    category_id = 3
    title = "Test Listing for Persona Scope Check"
    description = "Test"
    transaction_modes = @("sale")
    attributes = @{
        capacity_max = 100
    }
} | ConvertTo-Json -Depth 10

$listingHeaders = @{
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings" -Method Post -Body $listingBody -Headers $listingHeaders -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Listing create without X-Active-Tenant-Id was accepted (should be 400/403)" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    $errorResponse = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $errorResponse = $responseBody | ConvertFrom-Json
            $reader.Close()
        } catch {
        }
    }
    
    if ($statusCode -eq 400 -or $statusCode -eq 403) {
        Write-Host "PASS: Missing X-Active-Tenant-Id correctly returned $statusCode" -ForegroundColor Green
        Write-Host "  Status Code: $statusCode" -ForegroundColor Gray
        if ($errorResponse.error) {
            Write-Host "  Error: $($errorResponse.error)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Missing X-Active-Tenant-Id returned wrong status: $statusCode" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 5: STORE positive - listing create with X-Active-Tenant-Id
Write-Host "[5] Testing STORE positive: POST /api/v1/listings with X-Active-Tenant-Id (should be 201)..." -ForegroundColor Yellow

$listingBody = @{
    category_id = 3
    title = "Test Listing for Persona Scope (WP-8)" + " " + (Get-Date -Format "yyyyMMddHHmmss")
    description = "Test"
    transaction_modes = @("sale")
    attributes = @{
        capacity_max = 100
    }
} | ConvertTo-Json -Depth 10

$listingHeaders = @{
    "Content-Type" = "application/json"
    "X-Active-Tenant-Id" = $tenantId
}

try {
    $response = Invoke-RestMethod -Uri "${pazarBaseUrl}/api/v1/listings" -Method Post -Body $listingBody -Headers $listingHeaders -TimeoutSec 10 -ErrorAction Stop
    
    if ($response.id -and $response.status -eq "draft") {
        Write-Host "PASS: STORE operation accepted (listing created)" -ForegroundColor Green
        Write-Host "  Listing ID: $($response.id)" -ForegroundColor Gray
        Write-Host "  Status: $($response.status)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: STORE operation returned invalid response" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    Write-Host "FAIL: STORE operation failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($statusCode) {
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== PERSONA & SCOPE CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more tests failed. Fix issues and re-run." -ForegroundColor Yellow
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== PERSONA & SCOPE CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All persona & scope contract checks passed." -ForegroundColor Gray
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

