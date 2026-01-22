#!/usr/bin/env pwsh
# CORE PERSONA CONTRACT CHECK (WP-8)
# Verifies Core (HOS) Persona Switch + Membership endpoints.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== CORE PERSONA CONTRACT CHECK (WP-8) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$hosBaseUrl = "http://localhost:3000"
$authToken = $null
$testTenantSlug = "test-wp8-" + (Get-Date -Format "yyyyMMddHHmmss")
$testUserEmail = "test-wp8@example.com"
$testUserPassword = "TestPassword123!"

# Step 0: Create tenant and user via admin API, then get auth token
Write-Host "[0] Creating test tenant and user via admin API..." -ForegroundColor Yellow

$adminApiKey = "dev-api-key"  # Default dev API key
$registerTenantSlug = "test-tenant-wp8-" + (Get-Date -Format "yyyyMMddHHmmss")

# Step 0a: Create tenant and user via admin API
$adminUpsertBody = @{
    tenantSlug = $registerTenantSlug
    tenantName = "Test Tenant WP-8"
    email = $testUserEmail
    password = $testUserPassword
    role = "owner"
} | ConvertTo-Json

try {
    $adminResponse = Invoke-RestMethod -Uri "${hosBaseUrl}/v1/admin/users/upsert" -Method Post -Body $adminUpsertBody -Headers @{
        "Content-Type" = "application/json"
        "x-hos-api-key" = $adminApiKey
    } -TimeoutSec 10 -ErrorAction Stop
    
    if ($adminResponse.id -and $adminResponse.tenantId) {
        Write-Host "PASS: Test tenant and user created via admin API" -ForegroundColor Green
        Write-Host "  User ID: $($adminResponse.id)" -ForegroundColor Gray
        Write-Host "  Tenant ID: $($adminResponse.tenantId)" -ForegroundColor Gray
        Write-Host "  Tenant Slug: $($adminResponse.tenantSlug)" -ForegroundColor Gray
        
        # Step 0b: Login to get auth token
        Write-Host "  Logging in to obtain auth token..." -ForegroundColor Yellow
        $loginBody = @{
            tenantSlug = $registerTenantSlug
            email = $testUserEmail
            password = $testUserPassword
        } | ConvertTo-Json
        
        try {
            $loginResponse = Invoke-RestMethod -Uri "${hosBaseUrl}/v1/auth/login" -Method Post -Body $loginBody -Headers @{"Content-Type" = "application/json"} -TimeoutSec 10 -ErrorAction Stop
            if ($loginResponse.token) {
                $authToken = "Bearer " + $loginResponse.token
                Write-Host "PASS: Auth token obtained" -ForegroundColor Green
            } else {
                Write-Host "FAIL: Login response missing token" -ForegroundColor Red
                $hasFailures = $true
            }
        } catch {
            Write-Host "FAIL: Login failed: $($_.Exception.Message)" -ForegroundColor Red
            $hasFailures = $true
        }
    } else {
        Write-Host "FAIL: Admin upsert response missing required fields" -ForegroundColor Red
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
    Write-Host "FAIL: Admin upsert failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($statusCode) {
        Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
    }
    Write-Host "  Note: Auth tests will be skipped" -ForegroundColor Yellow
}

Write-Host ""

Write-Host ""

# Test 1: GET /v1/me (200, user_id var)
if ($authToken) {
    Write-Host "[1] Testing GET /v1/me..." -ForegroundColor Yellow
    
    try {
        $headers = @{
            "Authorization" = $authToken
        }
        $response = Invoke-RestMethod -Uri "${hosBaseUrl}/v1/me" -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    # Debug: print response
    Write-Host "  Response: $($response | ConvertTo-Json -Depth 3)" -ForegroundColor Gray
    
    if ($response.user_id -and $response.email) {
        Write-Host "PASS: GET /v1/me returns user info" -ForegroundColor Green
        Write-Host "  User ID: $($response.user_id)" -ForegroundColor Gray
        Write-Host "  Email: $($response.email)" -ForegroundColor Gray
        Write-Host "  Display Name: $($response.display_name)" -ForegroundColor Gray
        Write-Host "  Memberships Count: $($response.memberships_count)" -ForegroundColor Gray
        $userId = $response.user_id
    } else {
        Write-Host "FAIL: GET /v1/me missing required fields" -ForegroundColor Red
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
        Write-Host "FAIL: GET /v1/me failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[1] SKIP: Cannot test GET /v1/me (auth token not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 2: GET /v1/me/memberships (array, empty olabilir)
if ($authToken) {
    Write-Host "[2] Testing GET /v1/me/memberships..." -ForegroundColor Yellow
    
    try {
        $headers = @{
            "Authorization" = $authToken
        }
        $response = Invoke-RestMethod -Uri "${hosBaseUrl}/v1/me/memberships" -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if ($response.items -is [Array]) {
        Write-Host "PASS: GET /v1/me/memberships returns array" -ForegroundColor Green
        Write-Host "  Memberships count: $($response.items.Count)" -ForegroundColor Gray
        if ($response.items.Count -gt 0) {
            foreach ($item in $response.items) {
                Write-Host "    - Tenant: $($item.tenant_slug) (role: $($item.role), status: $($item.status))" -ForegroundColor Gray
            }
            $tenantId = $response.items[0].tenant_id
        } else {
            Write-Host "  Note: No memberships found (empty array is valid)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "FAIL: GET /v1/me/memberships returned invalid format" -ForegroundColor Red
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
        Write-Host "FAIL: GET /v1/me/memberships failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[2] SKIP: Cannot test GET /v1/me/memberships (auth token not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 3: POST /v1/tenants (200/201, tenant_id doner)
if ($authToken) {
    Write-Host "[3] Testing POST /v1/tenants/v2 (create tenant)..." -ForegroundColor Yellow

    $tenantSlug = "test-tenant-" + (Get-Date -Format "yyyyMMddHHmmss") + "-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tenantBody = @{
        slug = $tenantSlug
        display_name = "Test Tenant for WP-8"
    } | ConvertTo-Json

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = $authToken
        }
        $response = Invoke-RestMethod -Uri "${hosBaseUrl}/v1/tenants/v2" -Method Post -Body $tenantBody -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        if ($response.tenant_id -and $response.slug) {
            Write-Host "PASS: POST /v1/tenants/v2 created tenant" -ForegroundColor Green
            Write-Host "  Tenant ID: $($response.tenant_id)" -ForegroundColor Gray
            Write-Host "  Slug: $($response.slug)" -ForegroundColor Gray
            Write-Host "  Status: $($response.status)" -ForegroundColor Gray
            $createdTenantId = $response.tenant_id
        } else {
            Write-Host "FAIL: POST /v1/tenants/v2 missing required fields" -ForegroundColor Red
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
                $errorResponse = $responseBody | ConvertFrom-Json
                $reader.Close()
            } catch {
            }
        }
        
        if ($statusCode -eq 409 -and $errorResponse -and $errorResponse.error -eq "tenant_exists") {
            Write-Host "PASS: POST /v1/tenants/v2 correctly returned 409 (tenant exists)" -ForegroundColor Green
            Write-Host "  Tenant ID: $($errorResponse.tenant_id)" -ForegroundColor Gray
            $createdTenantId = $errorResponse.tenant_id
        } else {
            Write-Host "FAIL: POST /v1/tenants/v2 failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($statusCode) {
                Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
            }
            $hasFailures = $true
        }
    }
} else {
    Write-Host "[3] SKIP: Cannot test POST /v1/tenants/v2 (auth token not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 4: GET /v1/tenants/{tenant_id}/memberships/me (allowed=true)
if ($authToken -and $createdTenantId) {
    Write-Host "[4] Testing GET /v1/tenants/{tenant_id}/memberships/me (allowed=true)..." -ForegroundColor Yellow
    
    try {
        $headers = @{
            "Authorization" = $authToken
        }
        $response = Invoke-RestMethod -Uri "${hosBaseUrl}/v1/tenants/${createdTenantId}/memberships/me" -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        if ($response.allowed -eq $true) {
            Write-Host "PASS: GET /v1/tenants/{id}/memberships/me returns allowed=true" -ForegroundColor Green
            Write-Host "  Tenant ID: $($response.tenant_id)" -ForegroundColor Gray
            Write-Host "  User ID: $($response.user_id)" -ForegroundColor Gray
            Write-Host "  Role: $($response.role)" -ForegroundColor Gray
            Write-Host "  Status: $($response.status)" -ForegroundColor Gray
            Write-Host "  Allowed: $($response.allowed)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: GET /v1/tenants/{id}/memberships/me returned allowed=false" -ForegroundColor Red
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
        Write-Host "FAIL: GET /v1/tenants/{id}/memberships/me failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
        $hasFailures = $true
    }
} else {
    Write-Host "[4] SKIP: Cannot test membership check (auth token or tenant ID not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Test 5: Negatif - farkli/yanlis tenant_id ile allowed=false veya 403
if ($authToken) {
    Write-Host "[5] Testing negative: GET /v1/tenants/{wrong_tenant_id}/memberships/me (should return allowed=false)..." -ForegroundColor Yellow

    $wrongTenantId = "00000000-0000-0000-0000-000000000000" # Non-existent tenant ID

    try {
        $headers = @{
            "Authorization" = $authToken
        }
        $response = Invoke-RestMethod -Uri "${hosBaseUrl}/v1/tenants/${wrongTenantId}/memberships/me" -Method Get -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        if ($response.allowed -eq $false) {
            Write-Host "PASS: Wrong tenant ID correctly returned allowed=false" -ForegroundColor Green
            Write-Host "  Tenant ID: $($response.tenant_id)" -ForegroundColor Gray
            Write-Host "  Allowed: $($response.allowed)" -ForegroundColor Gray
        } else {
            Write-Host "FAIL: Wrong tenant ID returned allowed=true (should be false)" -ForegroundColor Red
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
        # 400 or 403 is also acceptable for wrong tenant
        if ($statusCode -eq 400 -or $statusCode -eq 403) {
            Write-Host "PASS: Wrong tenant ID correctly rejected (status: $statusCode)" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Wrong tenant ID check failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($statusCode) {
                Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
            }
            $hasFailures = $true
        }
    }
} else {
    Write-Host "[5] SKIP: Cannot test negative membership check (auth token not available)" -ForegroundColor Yellow
    $hasFailures = $true
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== CORE PERSONA CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more tests failed. Fix issues and re-run." -ForegroundColor Yellow
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== CORE PERSONA CONTRACT CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All core persona contract checks passed." -ForegroundColor Gray
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

