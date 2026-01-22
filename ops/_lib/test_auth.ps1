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
    Test user email (default: testuser@example.com)
    
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
        [string]$Email = "testuser@example.com",
        [string]$Password = "Passw0rd!",
        [string]$HosApiKey = $null
    )
    
    # Get HosApiKey from env if not provided (default: dev-api-key)
    if (-not $HosApiKey) {
        $HosApiKey = $env:HOS_API_KEY
        if (-not $HosApiKey) {
            $HosApiKey = "dev-api-key"
        }
    }
    
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
        # Use Invoke-WebRequest for better error handling (PowerShell 5.1)
        $upsertRequest = Invoke-WebRequest -Uri "$HosBaseUrl/v1/admin/users/upsert" `
            -Method Post `
            -Body $upsertBody `
            -ContentType "application/json" `
            -Headers @{
                "x-hos-api-key" = $HosApiKey
            } `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        $upsertResponse = $upsertRequest.Content | ConvertFrom-Json
        
        if (-not $upsertResponse.id) {
            throw "Admin upsert response missing user ID"
        }
        
        Write-Host "  PASS: User upserted successfully (ID: $($upsertResponse.id))" -ForegroundColor Green
    } catch {
        $statusCode = $null
        $responseBody = $null
        
        # PowerShell 5.1: Invoke-WebRequest provides response in ErrorDetails or Response
        # Try ErrorDetails first (Invoke-WebRequest specific)
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $responseBody = $_.ErrorDetails.Message
        }
        
        # Get status code from exception
        $webException = $_.Exception
        if ($webException -is [System.Net.WebException] -and $webException.Response) {
            $statusCode = [int]$webException.Response.StatusCode.value__
            
            # If ErrorDetails didn't work, try reading from response stream
            if (-not $responseBody) {
                try {
                    $responseStream = $webException.Response.GetResponseStream()
                    if ($responseStream) {
                        $reader = New-Object System.IO.StreamReader($responseStream)
                        $responseBody = $reader.ReadToEnd()
                        $reader.Close()
                        $responseStream.Close()
                    }
                } catch {
                    # Ignore if we can't read response body
                }
            }
        } elseif ($webException.Response) {
            $statusCode = [int]$webException.Response.StatusCode.value__
        }
        
        Write-Host "  FAIL: Admin upsert failed" -ForegroundColor Red
        if ($statusCode) {
            Write-Host "    Status: $statusCode" -ForegroundColor Yellow
        }
        
        # Parse and display error details if available
        if ($responseBody) {
            try {
                $errorObj = $responseBody | ConvertFrom-Json
                
                # Handle Zod error format: { error: { fieldErrors: {...}, formErrors: [...] } }
                if ($errorObj.error) {
                    $errorData = $errorObj.error
                    if ($errorData.fieldErrors) {
                        Write-Host "    Field Errors:" -ForegroundColor Yellow
                        $errorData.fieldErrors.PSObject.Properties | ForEach-Object {
                            $valueStr = if ($_.Value -is [Array]) { $_.Value -join ', ' } else { $_.Value.ToString() }
                            Write-Host "      $($_.Name): $valueStr" -ForegroundColor Gray
                        }
                    }
                    if ($errorData.formErrors) {
                        $formErrStr = if ($errorData.formErrors -is [Array]) { $errorData.formErrors -join ', ' } else { $errorData.formErrors.ToString() }
                        Write-Host "    Form Errors: $formErrStr" -ForegroundColor Yellow
                    }
                }
                
                # Handle direct fieldErrors/formErrors
                if ($errorObj.fieldErrors) {
                    Write-Host "    Field Errors:" -ForegroundColor Yellow
                    $errorObj.fieldErrors.PSObject.Properties | ForEach-Object {
                        $valueStr = if ($_.Value -is [Array]) { $_.Value -join ', ' } else { $_.Value.ToString() }
                        Write-Host "      $($_.Name): $valueStr" -ForegroundColor Gray
                    }
                }
                if ($errorObj.formErrors) {
                    $formErrStr = if ($errorObj.formErrors -is [Array]) { $errorObj.formErrors -join ', ' } else { $errorObj.formErrors.ToString() }
                    Write-Host "    Form Errors: $formErrStr" -ForegroundColor Yellow
                }
                if ($errorObj.message) {
                    Write-Host "    Message: $($errorObj.message)" -ForegroundColor Yellow
                }
                if ($errorObj.error -and -not $errorObj.error.fieldErrors -and -not $errorObj.error.formErrors) {
                    Write-Host "    Error: $($errorObj.error)" -ForegroundColor Yellow
                }
            } catch {
                # If not JSON, print raw response (first 200 chars, ASCII-only)
                $sanitized = $responseBody -replace '[^\x00-\x7F]', ''
                $preview = if ($sanitized.Length -gt 200) { $sanitized.Substring(0, 200) + "..." } else { $sanitized }
                Write-Host "    Response: $preview" -ForegroundColor Yellow
            }
        } else {
            $errorMsg = $_.Exception.Message
            $sanitized = $errorMsg -replace '[^\x00-\x7F]', ''
            Write-Host "    Error: $sanitized" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "  Remediation:" -ForegroundColor Yellow
        if ($statusCode -eq 401) {
            Write-Host "    API key mismatch. Set HOS_API_KEY environment variable:" -ForegroundColor Yellow
            Write-Host "      `$env:HOS_API_KEY = 'your-api-key'" -ForegroundColor Gray
            Write-Host "    Or pass -HosApiKey parameter to Get-DevTestJwtToken" -ForegroundColor Gray
        }
        Write-Host "    1. Ensure H-OS service is running: docker compose ps" -ForegroundColor Yellow
        Write-Host "    2. Check H-OS API is accessible: curl $HosBaseUrl/v1/world/status" -ForegroundColor Yellow
        Write-Host "    3. Verify x-hos-api-key matches H-OS configuration" -ForegroundColor Yellow
        $errorMsg = if ($statusCode) { "Status $statusCode" } else { $_.Exception.Message }
        throw "Failed to upsert test user: $errorMsg"
    }
    
    # Step 2: Login to obtain JWT token
    Write-Host "[2] Logging in to obtain JWT token..." -ForegroundColor Yellow
    $loginBody = @{
        tenantSlug = $TenantSlug
        email = $Email
        password = $Password
    } | ConvertTo-Json
    
    try {
        # Use Invoke-WebRequest for better error handling (PowerShell 5.1)
        $loginRequest = Invoke-WebRequest -Uri "$HosBaseUrl/v1/auth/login" `
            -Method Post `
            -Body $loginBody `
            -ContentType "application/json" `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        $loginResponse = $loginRequest.Content | ConvertFrom-Json
        
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
        # Mask token (show last 6 chars)
        $tokenMask = if ($token.Length -gt 6) { "***" + $token.Substring($token.Length - 6) } else { "***" }
        Write-Host "  Token: $tokenMask" -ForegroundColor Gray
        Write-Host ""
        
        # Set script-level and environment variables
        $script:DevJwt = $token
        $env:PRODUCT_TEST_AUTH = "Bearer $token"
        $env:HOS_TEST_AUTH = "Bearer $token"
        
        Write-Host "[INFO] Token set in environment variables:" -ForegroundColor Green
        Write-Host "  PRODUCT_TEST_AUTH = Bearer $tokenMask" -ForegroundColor Gray
        Write-Host "  HOS_TEST_AUTH = Bearer $tokenMask" -ForegroundColor Gray
        Write-Host ""
        
        return $token
    } catch {
        $statusCode = $null
        $responseBody = $null
        
        # PowerShell 5.1: Invoke-WebRequest provides response body in exception
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
            
            # Read response body from WebException
            try {
                $responseStream = $_.Exception.Response.GetResponseStream()
                if ($responseStream) {
                    $reader = New-Object System.IO.StreamReader($responseStream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $responseStream.Close()
                }
            } catch {
                # Fallback: try ErrorDetails.Message
                try {
                    if ($_.ErrorDetails.Message) {
                        $responseBody = $_.ErrorDetails.Message
                    }
                } catch {
                    # Ignore if we can't read response body
                }
            }
        }
        
        Write-Host "  FAIL: Login failed" -ForegroundColor Red
        Write-Host "    Status: $statusCode" -ForegroundColor Yellow
        
        # Parse and display error details if available
        if ($responseBody) {
            try {
                $errorObj = $responseBody | ConvertFrom-Json
                if ($errorObj.fieldErrors) {
                    Write-Host "    Field Errors:" -ForegroundColor Yellow
                    $errorObj.fieldErrors.PSObject.Properties | ForEach-Object {
                        $valueStr = if ($_.Value -is [Array]) { $_.Value -join ', ' } else { $_.Value.ToString() }
                        Write-Host "      $($_.Name): $valueStr" -ForegroundColor Gray
                    }
                }
                if ($errorObj.formErrors) {
                    $formErrStr = if ($errorObj.formErrors -is [Array]) { $errorObj.formErrors -join ', ' } else { $errorObj.formErrors.ToString() }
                    Write-Host "    Form Errors: $formErrStr" -ForegroundColor Yellow
                }
                if ($errorObj.message) {
                    Write-Host "    Message: $($errorObj.message)" -ForegroundColor Yellow
                }
            } catch {
                # If not JSON, print raw response (first 200 chars, ASCII-only)
                $sanitized = $responseBody -replace '[^\x00-\x7F]', ''
                $preview = if ($sanitized.Length -gt 200) { $sanitized.Substring(0, 200) + "..." } else { $sanitized }
                Write-Host "    Response: $preview" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "  Remediation:" -ForegroundColor Yellow
        Write-Host "    1. Ensure H-OS service is running: docker compose ps" -ForegroundColor Yellow
        Write-Host "    2. Check H-OS API is accessible: curl $HosBaseUrl/v1/auth/login" -ForegroundColor Yellow
        Write-Host "    3. Verify tenant slug and credentials are correct" -ForegroundColor Yellow
        throw "Failed to login and obtain JWT: $($_.Exception.Message)"
    }
}


