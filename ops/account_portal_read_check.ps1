#!/usr/bin/env pwsh
# ACCOUNT PORTAL READ CHECK (WP-12)
# Verifies Account Portal read-only GET endpoints with filters.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== ACCOUNT PORTAL READ CHECK (WP-12) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$pazarBaseUrl = "http://localhost:8080"
$tenantId = "951ba4eb-9062-40c4-9228-f8d2cfc2f426" # Deterministic UUID for tenant-demo

# Generate deterministic UUID for test user (matching generate_tenant_uuid in api.php)
function Generate-TestUserId {
    $testString = "test-user-id-wp12"
    $md5Hash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes("tenant-namespace-$testString"))
    $hashHex = [System.BitConverter]::ToString($md5Hash).Replace("-", "").ToLower()
    return "$($hashHex.Substring(0,8))-$($hashHex.Substring(8,4))-$($hashHex.Substring(12,4))-$($hashHex.Substring(16,4))-$($hashHex.Substring(20,12))"
}
$testUserId = Generate-TestUserId

Write-Host "Testing 7 Account Portal read endpoints:" -ForegroundColor Yellow
Write-Host "  1. GET /v1/orders?buyer_user_id=... (Personal)" -ForegroundColor Gray
Write-Host "  2. GET /v1/orders?seller_tenant_id=... (Store)" -ForegroundColor Gray
Write-Host "  3. GET /v1/rentals?renter_user_id=... (Personal)" -ForegroundColor Gray
Write-Host "  4. GET /v1/rentals?provider_tenant_id=... (Store)" -ForegroundColor Gray
Write-Host "  5. GET /v1/reservations?requester_user_id=... (Personal)" -ForegroundColor Gray
Write-Host "  6. GET /v1/reservations?provider_tenant_id=... (Store)" -ForegroundColor Gray
Write-Host "  7. GET /v1/listings?tenant_id=... (Store)" -ForegroundColor Gray
Write-Host ""

# Test 1: GET /v1/orders?buyer_user_id=... (Personal)
Write-Host "[1] Testing GET /v1/orders?buyer_user_id=${testUserId}..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/orders?buyer_user_id=${testUserId}"
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if ($null -eq $response -or ($response -is [array])) {
        Write-Host "PASS: GET /v1/orders?buyer_user_id=... returns array" -ForegroundColor Green
        if ($response.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Expected array response, got: $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Write-Host "FAIL: Endpoint not found (404)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message) (Status: $statusCode)" -ForegroundColor Red
    }
    $hasFailures = $true
}

# Test 2: GET /v1/orders?seller_tenant_id=... (Store with X-Active-Tenant-Id)
Write-Host "[2] Testing GET /v1/orders?seller_tenant_id=${tenantId} (with X-Active-Tenant-Id)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/orders?seller_tenant_id=${tenantId}"
    $headers = @{ "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if ($null -eq $response -or ($response -is [array])) {
        Write-Host "PASS: GET /v1/orders?seller_tenant_id=... returns array" -ForegroundColor Green
        if ($response.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Expected array response, got: $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "FAIL: FORBIDDEN_SCOPE (403) - Check X-Active-Tenant-Id header matching" -ForegroundColor Red
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Endpoint not found (404)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message) (Status: $statusCode)" -ForegroundColor Red
    }
    $hasFailures = $true
}

# Test 3: GET /v1/rentals?renter_user_id=... (Personal)
Write-Host "[3] Testing GET /v1/rentals?renter_user_id=${testUserId}..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/rentals?renter_user_id=${testUserId}"
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if ($null -eq $response -or ($response -is [array])) {
        Write-Host "PASS: GET /v1/rentals?renter_user_id=... returns array" -ForegroundColor Green
        if ($response.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Expected array response, got: $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Write-Host "FAIL: Endpoint not found (404)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message) (Status: $statusCode)" -ForegroundColor Red
    }
    $hasFailures = $true
}

# Test 4: GET /v1/rentals?provider_tenant_id=... (Store with X-Active-Tenant-Id)
Write-Host "[4] Testing GET /v1/rentals?provider_tenant_id=${tenantId} (with X-Active-Tenant-Id)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/rentals?provider_tenant_id=${tenantId}"
    $headers = @{ "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if ($null -eq $response -or ($response -is [array])) {
        Write-Host "PASS: GET /v1/rentals?provider_tenant_id=... returns array" -ForegroundColor Green
        if ($response.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Expected array response, got: $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "FAIL: FORBIDDEN_SCOPE (403) - Check X-Active-Tenant-Id header matching" -ForegroundColor Red
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Endpoint not found (404)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message) (Status: $statusCode)" -ForegroundColor Red
    }
    $hasFailures = $true
}

# Test 5: GET /v1/reservations?requester_user_id=... (Personal)
Write-Host "[5] Testing GET /v1/reservations?requester_user_id=${testUserId}..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/reservations?requester_user_id=${testUserId}"
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if ($null -eq $response -or ($response -is [array])) {
        Write-Host "PASS: GET /v1/reservations?requester_user_id=... returns array" -ForegroundColor Green
        if ($response.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Expected array response, got: $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Write-Host "FAIL: Endpoint not found (404)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message) (Status: $statusCode)" -ForegroundColor Red
    }
    $hasFailures = $true
}

# Test 6: GET /v1/reservations?provider_tenant_id=... (Store with X-Active-Tenant-Id)
Write-Host "[6] Testing GET /v1/reservations?provider_tenant_id=${tenantId} (with X-Active-Tenant-Id)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/reservations?provider_tenant_id=${tenantId}"
    $headers = @{ "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if ($null -eq $response -or ($response -is [array])) {
        Write-Host "PASS: GET /v1/reservations?provider_tenant_id=... returns array" -ForegroundColor Green
        if ($response.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Expected array response, got: $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "FAIL: FORBIDDEN_SCOPE (403) - Check X-Active-Tenant-Id header matching" -ForegroundColor Red
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Endpoint not found (404)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message) (Status: $statusCode)" -ForegroundColor Red
    }
    $hasFailures = $true
}

# Test 7: GET /v1/listings?tenant_id=... (Store)
Write-Host "[7] Testing GET /v1/listings?tenant_id=${tenantId}..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/listings?tenant_id=${tenantId}&status=all"
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
    
    if ($null -eq $response -or ($response -is [array])) {
        Write-Host "PASS: GET /v1/listings?tenant_id=... returns array" -ForegroundColor Green
        if ($response.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FAIL: Expected array response, got: $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Write-Host "FAIL: Endpoint not found (404)" -ForegroundColor Red
    } else {
        Write-Host "FAIL: $($_.Exception.Message) (Status: $statusCode)" -ForegroundColor Red
    }
    $hasFailures = $true
}

Write-Host ""

if ($hasFailures) {
    Write-Host "=== ACCOUNT PORTAL READ CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more endpoint checks failed." -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== ACCOUNT PORTAL READ CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All 7 Account Portal read endpoints are working correctly." -ForegroundColor Green
    exit 0
}

