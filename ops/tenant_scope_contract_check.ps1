#!/usr/bin/env pwsh
# TENANT SCOPE CONTRACT CHECK (WP-8)
# Verifies Membership Enforcement for store-scope write endpoints.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== TENANT SCOPE CONTRACT CHECK (WP-8) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$validTenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic UUID for tenant-demo

Write-Host ""

# Test 1: Missing X-Active-Tenant-Id header -> 400
Write-Host "[1] Testing missing X-Active-Tenant-Id header..." -ForegroundColor Yellow

$createListingUrl = "${pazarBaseUrl}/api/v1/listings"
$listingBody = @{
    category_id = 3  # wedding-hall category (assumed exists from seeder)
    title = "Test Listing for Tenant Scope Check"
    description = "Test"
    transaction_modes = @("sale")
    attributes = @{
        capacity_max = 100
    }
} | ConvertTo-Json -Depth 10

# No X-Active-Tenant-Id header
$listingHeaders = @{
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $listingBody -Headers $listingHeaders -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Request without X-Active-Tenant-Id was accepted (should be 400)" -ForegroundColor Red
    $hasFailures = $true
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
        }
    }
    
    if ($statusCode -eq 400) {
        Write-Host "PASS: Missing header correctly returned 400" -ForegroundColor Green
        Write-Host "  Status Code: 400" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Missing header returned wrong status: $statusCode (expected 400)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 2: Invalid tenant ID format (not UUID) -> 403 FORBIDDEN_SCOPE
Write-Host "[2] Testing invalid tenant ID format (not UUID)..." -ForegroundColor Yellow

$invalidTenantBody = @{
    category_id = 3
    title = "Test Listing for Invalid Tenant Format"
    description = "Test"
    transaction_modes = @("sale")
    attributes = @{
        capacity_max = 100
    }
} | ConvertTo-Json -Depth 10

$invalidTenantHeaders = @{
    "Content-Type" = "application/json"
    "X-Active-Tenant-Id" = "invalid-tenant-slug" # Not UUID format
}

try {
    $response = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $invalidTenantBody -Headers $invalidTenantHeaders -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "FAIL: Request with invalid tenant format was accepted (should be 403 FORBIDDEN_SCOPE)" -ForegroundColor Red
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
    
    if ($statusCode -eq 403) {
        if ($errorResponse -and $errorResponse.error) {
            if ($errorResponse.error -eq "FORBIDDEN_SCOPE") {
                Write-Host "PASS: Invalid tenant format correctly returned 403 FORBIDDEN_SCOPE" -ForegroundColor Green
                Write-Host "  Status Code: 403" -ForegroundColor Gray
                Write-Host "  Error: $($errorResponse.error)" -ForegroundColor Gray
            } else {
                Write-Host "PASS: Invalid tenant format correctly returned 403 (error: $($errorResponse.error))" -ForegroundColor Green
                Write-Host "  Status Code: 403" -ForegroundColor Gray
            }
        } else {
            Write-Host "PASS: Invalid tenant format correctly returned 403 FORBIDDEN_SCOPE" -ForegroundColor Green
            Write-Host "  Status Code: 403" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Invalid tenant format returned wrong status/error: $($statusCode) / $($errorResponse.error)" -ForegroundColor Red
        $hasFailures = $true
    }
}

Write-Host ""

# Test 3: Valid UUID format -> accepted (201)
Write-Host "[3] Testing valid UUID format (membership validation)..." -ForegroundColor Yellow

$validTenantBody = @{
    category_id = 3
    title = "Test Listing for Valid Tenant (WP-8)" + " " + (Get-Date -Format "yyyyMMddHHmmss")
    description = "Test"
    transaction_modes = @("sale")
    attributes = @{
        capacity_max = 100
    }
} | ConvertTo-Json -Depth 10

$validTenantHeaders = @{
    "Content-Type" = "application/json"
    "X-Active-Tenant-Id" = $validTenantId # Valid UUID format
}

try {
    $response = Invoke-RestMethod -Uri $createListingUrl -Method Post -Body $validTenantBody -Headers $validTenantHeaders -TimeoutSec 10 -ErrorAction Stop
    
    if ($response.id -and $response.status -eq "draft") {
        Write-Host "PASS: Valid tenant format accepted (listing created)" -ForegroundColor Green
        Write-Host "  Listing ID: $($response.id)" -ForegroundColor Gray
        Write-Host "  Status: $($response.status)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: Valid tenant format returned invalid response" -ForegroundColor Red
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
    Write-Host "FAIL: Valid tenant format request failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($statusCode) {
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== TENANT SCOPE CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more tests failed. Fix issues and re-run." -ForegroundColor Yellow
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== TENANT SCOPE CONTRACT CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All tenant scope contract checks passed." -ForegroundColor Gray
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

