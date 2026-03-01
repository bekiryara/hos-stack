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
$hosBaseUrl = "http://localhost:3000"
$tenantId = $null

if (Test-Path "${scriptDir}\_lib\test_auth.ps1") {
    . "${scriptDir}\_lib\test_auth.ps1"
}

function Get-TenantIdFromMemberships {
    param([object]$Memberships)

    if (-not $Memberships) {
        return $null
    }

    $membershipsArray = $null
    if ($Memberships -is [Array]) {
        $membershipsArray = $Memberships
    } elseif ($Memberships -is [PSCustomObject]) {
        if ($Memberships.PSObject.Properties['items'] -and $Memberships.items -is [Array]) {
            $membershipsArray = $Memberships.items
        } elseif ($Memberships.PSObject.Properties['data'] -and $Memberships.data -is [Array]) {
            $membershipsArray = $Memberships.data
        }
    } elseif ($Memberships.items -is [Array]) {
        $membershipsArray = $Memberships.items
    } elseif ($Memberships.data -is [Array]) {
        $membershipsArray = $Memberships.data
    }

    if (-not $membershipsArray) {
        $membershipsArray = @()
    }

    foreach ($membership in $membershipsArray) {
        $candidate = $membership.tenant_id
        if (-not $candidate -and $membership.tenant -and $membership.tenant.id) { $candidate = $membership.tenant.id }
        if (-not $candidate -and $membership.tenantId) { $candidate = $membership.tenantId }
        if (-not $candidate -and $membership.store_tenant_id) { $candidate = $membership.store_tenant_id }
        $parsed = [System.Guid]::Empty
        if ($candidate -and [System.Guid]::TryParse([string]$candidate, [ref]$parsed)) {
            return [string]$candidate
        }
    }

    return $null
}

# A) Get auth token from env (PRODUCT_TEST_AUTH or HOS_TEST_AUTH)
$authHeader = $env:PRODUCT_TEST_AUTH
if (-not $authHeader) {
    $authHeader = $env:HOS_TEST_AUTH
}
if (-not $authHeader) {
    try {
        $apiKey = $env:HOS_API_KEY
        if (-not $apiKey) { $apiKey = "dev-api-key" }
        $jwtToken = Get-DevTestJwtToken -HosBaseUrl $hosBaseUrl -HosApiKey $apiKey
        if (-not $jwtToken) { throw "Failed to obtain JWT token" }
        $authHeader = "Bearer $jwtToken"
        $env:PRODUCT_TEST_AUTH = $authHeader
        $env:HOS_TEST_AUTH = $authHeader
    } catch {
        Write-Host "FAIL: Auth token not found in environment and bootstrap failed" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        exit 1
    }
}

# Extract token (remove "Bearer " prefix if present)
$token = $authHeader
if ($token -like "Bearer *") {
    $token = $token.Substring(7)
}

# B) Decode JWT payload to extract sub (PowerShell 5.1 compatible)
function Get-JwtSub {
    param([string]$JwtToken)
    
    try {
        $parts = $JwtToken -split '\.'
        if ($parts.Count -lt 2) {
            throw "Invalid JWT format"
        }
        
        # Decode payload (second part)
        $payloadBase64 = $parts[1]
        
        # Add padding if needed (Base64 padding)
        $padding = 4 - ($payloadBase64.Length % 4)
        if ($padding -ne 4) {
            $payloadBase64 = $payloadBase64 + ("=" * $padding)
        }
        
        # Decode Base64
        $payloadBytes = [System.Convert]::FromBase64String($payloadBase64)
        $payloadJson = [System.Text.Encoding]::UTF8.GetString($payloadBytes)
        
        # Parse JSON and extract sub
        $payload = $payloadJson | ConvertFrom-Json
        return $payload.sub
    } catch {
        Write-Host "WARN: Failed to decode JWT payload: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

$userId = Get-JwtSub -JwtToken $token
if (-not $userId) {
    Write-Host "FAIL: Could not extract user ID (sub) from JWT token" -ForegroundColor Red
    exit 1
}

Write-Host "Using user ID from token: $userId" -ForegroundColor Gray
try {
    $membershipsResponse = Invoke-RestMethod -Uri "$hosBaseUrl/v1/me/memberships" -Headers @{ "Authorization" = $authHeader } -TimeoutSec 10 -ErrorAction Stop
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
} catch {
    Write-Host "FAIL: Could not fetch memberships: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
if (-not $tenantId) {
    Write-Host "FAIL: Could not resolve tenant_id from memberships" -ForegroundColor Red
    exit 1
}
Write-Host "Using tenant ID from memberships: $tenantId" -ForegroundColor Gray
Write-Host ""

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
Write-Host "[1] Testing GET /v1/orders?buyer_user_id=${userId}..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/orders?buyer_user_id=${userId}"
    $headers = @{ "Authorization" = $authHeader }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    # D) Response shape validation: accept both array and {data, meta} envelope
    $dataArray = $null
    if ($response -is [Array]) {
        $dataArray = $response
    } elseif ($response -and $response.data -is [Array]) {
        $dataArray = $response.data
    }
    
    if ($null -ne $dataArray) {
        Write-Host "PASS: GET /v1/orders?buyer_user_id=... returns valid response" -ForegroundColor Green
        if ($dataArray.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        $responseType = if ($response) { $response.GetType().Name } else { "null" }
        Write-Host "FAIL: Expected array or {data: [...]} envelope, got: $responseType" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Write-Host "FAIL: Expected 200 OK, got 401 UNAUTHORIZED" -ForegroundColor Red
        Write-Host "  Reason: Authorization header required for personal scope" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Expected 200 OK, got 404 NOT_FOUND" -ForegroundColor Red
        Write-Host "  Reason: Endpoint not found" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Expected 200 OK, got $statusCode" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

# Test 2: GET /v1/orders?seller_tenant_id=... (Store with X-Active-Tenant-Id)
Write-Host "[2] Testing GET /v1/orders?seller_tenant_id=${tenantId} (with X-Active-Tenant-Id)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/orders?seller_tenant_id=${tenantId}"
    $headers = @{ "Authorization" = $authHeader; "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    # D) Response shape validation: accept both array and {data, meta} envelope
    $dataArray = $null
    if ($response -is [Array]) {
        $dataArray = $response
    } elseif ($response -and $response.data -is [Array]) {
        $dataArray = $response.data
    }
    
    if ($null -ne $dataArray) {
        Write-Host "PASS: GET /v1/orders?seller_tenant_id=... returns valid response" -ForegroundColor Green
        if ($dataArray.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        $responseType = if ($response) { $response.GetType().Name } else { "null" }
        Write-Host "FAIL: Expected array or {data: [...]} envelope, got: $responseType" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "FAIL: Expected 200 OK, got 403 FORBIDDEN_SCOPE" -ForegroundColor Red
        Write-Host "  Reason: Check X-Active-Tenant-Id header matching" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Expected 200 OK, got 404 NOT_FOUND" -ForegroundColor Red
        Write-Host "  Reason: Endpoint not found" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Expected 200 OK, got $statusCode" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

# Test 3: GET /v1/rentals?renter_user_id=... (Personal)
Write-Host "[3] Testing GET /v1/rentals?renter_user_id=${userId}..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/rentals?renter_user_id=${userId}"
    $headers = @{ "Authorization" = $authHeader }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    # D) Response shape validation: accept both array and {data, meta} envelope
    $dataArray = $null
    if ($response -is [Array]) {
        $dataArray = $response
    } elseif ($response -and $response.data -is [Array]) {
        $dataArray = $response.data
    }
    
    if ($null -ne $dataArray) {
        Write-Host "PASS: GET /v1/rentals?renter_user_id=... returns valid response" -ForegroundColor Green
        if ($dataArray.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        $responseType = if ($response) { $response.GetType().Name } else { "null" }
        Write-Host "FAIL: Expected array or {data: [...]} envelope, got: $responseType" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Write-Host "FAIL: Expected 200 OK, got 401 UNAUTHORIZED" -ForegroundColor Red
        Write-Host "  Reason: Authorization header required for personal scope" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Expected 200 OK, got 404 NOT_FOUND" -ForegroundColor Red
        Write-Host "  Reason: Endpoint not found" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Expected 200 OK, got $statusCode" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

# Test 4: GET /v1/rentals?provider_tenant_id=... (Store with X-Active-Tenant-Id)
Write-Host "[4] Testing GET /v1/rentals?provider_tenant_id=${tenantId} (with X-Active-Tenant-Id)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/rentals?provider_tenant_id=${tenantId}"
    $headers = @{ "Authorization" = $authHeader; "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    # D) Response shape validation: accept both array and {data, meta} envelope
    $dataArray = $null
    if ($response -is [Array]) {
        $dataArray = $response
    } elseif ($response -and $response.data -is [Array]) {
        $dataArray = $response.data
    }
    
    if ($null -ne $dataArray) {
        Write-Host "PASS: GET /v1/rentals?provider_tenant_id=... returns valid response" -ForegroundColor Green
        if ($dataArray.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        $responseType = if ($response) { $response.GetType().Name } else { "null" }
        Write-Host "FAIL: Expected array or {data: [...]} envelope, got: $responseType" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "FAIL: Expected 200 OK, got 403 FORBIDDEN_SCOPE" -ForegroundColor Red
        Write-Host "  Reason: Check X-Active-Tenant-Id header matching" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Expected 200 OK, got 404 NOT_FOUND" -ForegroundColor Red
        Write-Host "  Reason: Endpoint not found" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Expected 200 OK, got $statusCode" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

# Test 5: GET /v1/reservations?requester_user_id=... (Personal)
Write-Host "[5] Testing GET /v1/reservations?requester_user_id=${userId}..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/reservations?requester_user_id=${userId}"
    $headers = @{ "Authorization" = $authHeader }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    # D) Response shape validation: accept both array and {data, meta} envelope
    $dataArray = $null
    if ($response -is [Array]) {
        $dataArray = $response
    } elseif ($response -and $response.data -is [Array]) {
        $dataArray = $response.data
    }
    
    if ($null -ne $dataArray) {
        Write-Host "PASS: GET /v1/reservations?requester_user_id=... returns valid response" -ForegroundColor Green
        if ($dataArray.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        $responseType = if ($response) { $response.GetType().Name } else { "null" }
        Write-Host "FAIL: Expected array or {data: [...]} envelope, got: $responseType" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Write-Host "FAIL: Expected 200 OK, got 401 UNAUTHORIZED" -ForegroundColor Red
        Write-Host "  Reason: Authorization header required for personal scope" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Expected 200 OK, got 404 NOT_FOUND" -ForegroundColor Red
        Write-Host "  Reason: Endpoint not found" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Expected 200 OK, got $statusCode" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

# Test 6: GET /v1/reservations?provider_tenant_id=... (Store with X-Active-Tenant-Id)
Write-Host "[6] Testing GET /v1/reservations?provider_tenant_id=${tenantId} (with X-Active-Tenant-Id)..." -ForegroundColor Yellow
try {
    $url = "${pazarBaseUrl}/api/v1/reservations?provider_tenant_id=${tenantId}"
    $headers = @{ "Authorization" = $authHeader; "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    # D) Response shape validation: accept both array and {data, meta} envelope
    $dataArray = $null
    if ($response -is [Array]) {
        $dataArray = $response
    } elseif ($response -and $response.data -is [Array]) {
        $dataArray = $response.data
    }
    
    if ($null -ne $dataArray) {
        Write-Host "PASS: GET /v1/reservations?provider_tenant_id=... returns valid response" -ForegroundColor Green
        if ($dataArray.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        $responseType = if ($response) { $response.GetType().Name } else { "null" }
        Write-Host "FAIL: Expected array or {data: [...]} envelope, got: $responseType" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "FAIL: Expected 200 OK, got 403 FORBIDDEN_SCOPE" -ForegroundColor Red
        Write-Host "  Reason: Check X-Active-Tenant-Id header matching" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Expected 200 OK, got 404 NOT_FOUND" -ForegroundColor Red
        Write-Host "  Reason: Endpoint not found" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Expected 200 OK, got $statusCode" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

# Test 7: GET /v1/listings?tenant_id=... (Store)
Write-Host "[7] Testing GET /v1/listings?tenant_id=${tenantId} (with X-Active-Tenant-Id)..." -ForegroundColor Yellow
try {
    # D) Add X-Active-Tenant-Id header (required for store scope)
    $url = "${pazarBaseUrl}/api/v1/listings?tenant_id=${tenantId}"
    $headers = @{ "Authorization" = $authHeader; "X-Active-Tenant-Id" = $tenantId }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    # D) Response shape validation: accept both array and {data, meta} envelope
    # Note: /v1/listings returns array (WP-3.1 contract), not envelope
    $dataArray = $null
    if ($response -is [Array]) {
        $dataArray = $response
    } elseif ($response -and $response.data -is [Array]) {
        $dataArray = $response.data
    }
    
    if ($null -ne $dataArray) {
        Write-Host "PASS: GET /v1/listings?tenant_id=... returns valid response" -ForegroundColor Green
        if ($dataArray.Count -eq 0) {
            Write-Host "  (empty array - OK for read-only endpoint)" -ForegroundColor Gray
        }
    } else {
        $responseType = if ($response) { $response.GetType().Name } else { "null" }
        Write-Host "FAIL: Expected array or {data: [...]} envelope, got: $responseType" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400) {
        Write-Host "FAIL: Expected 200 OK, got 400 BAD_REQUEST" -ForegroundColor Red
        Write-Host "  Reason: Check X-Active-Tenant-Id header" -ForegroundColor Yellow
    } elseif ($statusCode -eq 403) {
        Write-Host "FAIL: Expected 200 OK, got 403 FORBIDDEN_SCOPE" -ForegroundColor Red
        Write-Host "  Reason: Check X-Active-Tenant-Id header matching" -ForegroundColor Yellow
    } elseif ($statusCode -eq 404) {
        Write-Host "FAIL: Expected 200 OK, got 404 NOT_FOUND" -ForegroundColor Red
        Write-Host "  Reason: Endpoint not found" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Expected 200 OK, got $statusCode" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $hasFailures = $true
}

Write-Host ""

if ($hasFailures) {
    Write-Host "=== ACCOUNT PORTAL READ CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more endpoint checks failed." -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== ACCOUNT PORTAL READ CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All 7 Account Portal read endpoints are working correctly." -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

