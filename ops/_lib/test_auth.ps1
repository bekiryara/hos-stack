# TEST AUTH HELPER (WP-23)
# Provides Get-DevTestJwtToken function to bootstrap JWT tokens for local/dev testing
# PowerShell 5.1 compatible, ASCII-only outputs

function Get-DevTestJwtToken {
    <#
    .SYNOPSIS
    Bootstraps a valid JWT token for local/dev testing by creating/upserting a test user and logging in.
    
    .PARAMETER HosBaseUrl
    H-OS API base URL (default: http://localhost:3000)
    
    .PARAMETER TenantSlug
    Tenant slug to use (default: tenant-a)
    
    .PARAMETER Email
    Test user email (default: test.user+wp23@local)
    
    .PARAMETER Password
    Test user password (default: Passw0rd!)
    
    .PARAMETER HosApiKey
    H-OS admin API key (default: dev-api-key)
    
    .OUTPUTS
    String: JWT token (without "Bearer " prefix)
    
    .EXAMPLE
    $token = Get-DevTestJwtToken
    $env:PRODUCT_TEST_AUTH = "Bearer $token"
    #>
    param(
        [string]$HosBaseUrl = "http://localhost:3000",
        [string]$TenantSlug = "tenant-a",
        [string]$Email = "test.user+wp23@local",
        [string]$Password = "Passw0rd!",
        [string]$HosApiKey = "dev-api-key"
    )
    
    $ErrorActionPreference = "Stop"
    
    Write-Host "[INFO] Bootstrapping test JWT token..." -ForegroundColor Yellow
    Write-Host "  H-OS URL: $HosBaseUrl" -ForegroundColor Gray
    Write-Host "  Tenant: $TenantSlug" -ForegroundColor Gray
    Write-Host "  Email: $Email" -ForegroundColor Gray
    Write-Host ""
    
    # Step 1: Ensure user exists via admin upsert
    Write-Host "[1] Ensuring test user exists via admin API..." -ForegroundColor Yellow
    $upsertBody = @{
        tenantSlug = $TenantSlug
        email = $Email
        password = $Password
        role = "owner"
    } | ConvertTo-Json
    
    try {
        $upsertResponse = Invoke-RestMethod -Uri "$HosBaseUrl/v1/admin/users/upsert" `
            -Method Post `
            -Body $upsertBody `
            -Headers @{
                "Content-Type" = "application/json"
                "x-hos-api-key" = $HosApiKey
            } `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        if (-not $upsertResponse.id) {
            throw "Admin upsert response missing user ID"
        }
        
        Write-Host "  PASS: User upserted successfully (ID: $($upsertResponse.id))" -ForegroundColor Green
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
        }
        
        Write-Host "  FAIL: Admin upsert failed" -ForegroundColor Red
        Write-Host "    Status: $statusCode" -ForegroundColor Yellow
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Remediation:" -ForegroundColor Yellow
        Write-Host "    1. Ensure H-OS service is running: docker compose ps" -ForegroundColor Yellow
        Write-Host "    2. Check H-OS API is accessible: curl $HosBaseUrl/v1/world/status" -ForegroundColor Yellow
        Write-Host "    3. Verify x-hos-api-key matches H-OS configuration" -ForegroundColor Yellow
        throw "Failed to upsert test user: $($_.Exception.Message)"
    }
    
    # Step 2: Login to obtain JWT token
    Write-Host "[2] Logging in to obtain JWT token..." -ForegroundColor Yellow
    $loginBody = @{
        tenantSlug = $TenantSlug
        email = $Email
        password = $Password
    } | ConvertTo-Json
    
    try {
        $loginResponse = Invoke-RestMethod -Uri "$HosBaseUrl/v1/auth/login" `
            -Method Post `
            -Body $loginBody `
            -Headers @{
                "Content-Type" = "application/json"
            } `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        if (-not $loginResponse.token) {
            throw "Login response missing token"
        }
        
        $token = $loginResponse.token
        
        # Validate JWT format (must contain two dots)
        $tokenParts = $token -split '\.'
        if ($tokenParts.Count -lt 3) {
            throw "Invalid JWT format: token must contain two dots (header.payload.signature)"
        }
        
        Write-Host "  PASS: JWT token obtained successfully" -ForegroundColor Green
        Write-Host "  Token preview: $($token.Substring(0, [Math]::Min(12, $token.Length)))..." -ForegroundColor Gray
        Write-Host ""
        
        # Set script-level and environment variables
        $script:DevJwt = $token
        $env:PRODUCT_TEST_AUTH = "Bearer $token"
        $env:HOS_TEST_AUTH = "Bearer $token"
        
        Write-Host "[INFO] Token set in environment variables:" -ForegroundColor Green
        Write-Host "  PRODUCT_TEST_AUTH = Bearer $($token.Substring(0, [Math]::Min(12, $token.Length)))..." -ForegroundColor Gray
        Write-Host "  HOS_TEST_AUTH = Bearer $($token.Substring(0, [Math]::Min(12, $token.Length)))..." -ForegroundColor Gray
        Write-Host ""
        
        return $token
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
        }
        
        Write-Host "  FAIL: Login failed" -ForegroundColor Red
        Write-Host "    Status: $statusCode" -ForegroundColor Yellow
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Remediation:" -ForegroundColor Yellow
        Write-Host "    1. Ensure H-OS service is running: docker compose ps" -ForegroundColor Yellow
        Write-Host "    2. Check H-OS API is accessible: curl $HosBaseUrl/v1/auth/login" -ForegroundColor Yellow
        Write-Host "    3. Verify tenant slug and credentials are correct" -ForegroundColor Yellow
        throw "Failed to login and obtain JWT: $($_.Exception.Message)"
    }
}


