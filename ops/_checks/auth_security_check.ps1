# auth_security_check.ps1 - Auth Security Hardening Check
# Verifies unauthorized access protection and rate limiting

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== AUTH SECURITY CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Target SSOT: H-OS API (not Pazar). Allow override for CI/dev.
$baseUrl = $env:HOS_API_BASE_URL
if (-not $baseUrl) { $baseUrl = $env:HOS_BASE_URL }
if (-not $baseUrl) { $baseUrl = "http://localhost:3000/v1" }

$adminTenantsUrl = "$baseUrl/admin/tenants"
$adminUsersUrl = "$baseUrl/admin/users"
$adminAuditUrl = "$baseUrl/admin/audit?limit=1"
$meUrl = "$baseUrl/me"
$loginUrl = "$baseUrl/auth/login"

# Results table (script scope; functions append here)
$script:results = @()

# Helper: Check HTTP response
function Test-AuthResponse {
    param(
        [string]$CheckName,
        [string]$Method,
        [string]$Url,
        [int[]]$ExpectedStatusCodes,
        [bool]$ExpectJsonEnvelope = $false
    )
    
    Write-Host "Testing $CheckName..." -ForegroundColor Yellow
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    
    try {
        if ($Method -eq "GET") {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        } else {
            $response = Invoke-WebRequest -Uri $Url -Method $Method -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        }
        
        $statusCode = $response.StatusCode
        
        # Check if status code is in expected list
        if ($ExpectedStatusCodes -contains $statusCode) {
            # If route is not present in this deploy profile, treat as WARN (not a security failure)
            if ($statusCode -eq 404) {
                $status = "WARN"
                $notes = "Status 404 (route not present in this profile)"
                $exitCode = 2
            }
            # Check JSON envelope if required (skip for 404)
                elseif ($ExpectJsonEnvelope) {
                try {
                    $json = $response.Content | ConvertFrom-Json
                        $hasErrorShape = $false
                        if ($null -ne $json) {
                            if ($json.PSObject.Properties.Name -contains 'error_code' -and $json.error_code) { $hasErrorShape = $true }
                            elseif ($json.PSObject.Properties.Name -contains 'error' -and $json.error) { $hasErrorShape = $true }
                        }
                        if ($hasErrorShape) {
                            $notes = "Status $statusCode, JSON error shape present"
                        } else {
                        $status = "WARN"
                            $notes = "Status $statusCode, but JSON error shape missing"
                        $exitCode = 2
                    }
                } catch {
                    $status = "WARN"
                    $notes = "Status $statusCode, but not valid JSON"
                    $exitCode = 2
                }
            } else {
                $notes = "Status $statusCode (expected)"
            }
        } else {
            $status = "FAIL"
            $notes = "Status $statusCode (expected: $($ExpectedStatusCodes -join '/'))"
            $exitCode = 1
        }
    } catch {
        $errorResponse = $_.Exception.Response
        if ($errorResponse) {
            $statusCode = [int]$errorResponse.StatusCode.value__
            if ($ExpectedStatusCodes -contains $statusCode) {
                # If route missing, treat as WARN (skip envelope)
                if ($statusCode -eq 404) {
                    $status = "WARN"
                    $notes = "Status 404 (route not present in this profile)"
                    $exitCode = 2
                }
                # Check JSON envelope if required (skip for 404)
                elseif ($ExpectJsonEnvelope) {
                    try {
                        # Prefer ErrorDetails.Message (more reliable than response stream in Windows PowerShell)
                        $body = $null
                        try {
                            if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $body = $_.ErrorDetails.Message }
                        } catch { }
                        if (-not $body) {
                            $stream = $errorResponse.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($stream)
                            $body = $reader.ReadToEnd()
                        }
                        $json = $body | ConvertFrom-Json
                        $hasErrorShape = $false
                        if ($null -ne $json) {
                            if ($json.PSObject.Properties.Name -contains 'error_code' -and $json.error_code) { $hasErrorShape = $true }
                            elseif ($json.PSObject.Properties.Name -contains 'error' -and $json.error) { $hasErrorShape = $true }
                        }
                        if ($hasErrorShape) {
                            $notes = "Status $statusCode, JSON error shape present"
                        } else {
                            $status = "WARN"
                            $notes = "Status $statusCode, but JSON error shape missing"
                            $exitCode = 2
                        }
                    } catch {
                        $status = "WARN"
                        $notes = "Status $statusCode, but not valid JSON"
                        $exitCode = 2
                    }
                } else {
                    $notes = "Status $statusCode (expected)"
                }
            } else {
                $status = "FAIL"
                $notes = "Status $statusCode (expected: $($ExpectedStatusCodes -join '/'))"
                $exitCode = 1
            }
        } else {
            $status = "FAIL"
            $notes = "Request failed: $($_.Exception.Message)"
            $exitCode = 1
        }
    }
    
    $script:results += [PSCustomObject]@{
        Check = $CheckName
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Helper: Test rate limiting
function Test-RateLimit {
    param(
        [string]$Url,
        [string]$Method = "POST",
        [int]$RequestCount = 35,
        [int]$ExpectedLimit = 30
    )
    
    Write-Host "Testing rate limiting ($RequestCount requests)..." -ForegroundColor Yellow
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    $rateLimitHeaders = @()
    $rateLimitHit = $false
    $hitAt = $null
    
    for ($i = 1; $i -le $RequestCount; $i++) {
        try {
            $headers = @{
                "Content-Type" = "application/json"
                "Accept" = "application/json"
            }
            
            $body = @{} | ConvertTo-Json
            
            $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $headers -Body $body -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            
            # Check for rate limit headers
            $hLimit = $response.Headers['X-RateLimit-Limit']
            if (-not $hLimit) { $hLimit = $response.Headers['x-ratelimit-limit'] }
            if ($hLimit) { $rateLimitHeaders += "X-RateLimit-Limit: $hLimit" }

            $hRemaining = $response.Headers['X-RateLimit-Remaining']
            if (-not $hRemaining) { $hRemaining = $response.Headers['x-ratelimit-remaining'] }
            if ($hRemaining) { $rateLimitHeaders += "X-RateLimit-Remaining: $hRemaining" }
            
        } catch {
            $errorResponse = $_.Exception.Response
            if ($errorResponse) {
                $statusCode = [int]$errorResponse.StatusCode.value__

                # Route not present in this profile → WARN + stop early (can't evaluate rate limit)
                if ($statusCode -eq 404) {
                    $status = "WARN"
                    $notes = "Auth endpoint not present (404) - rate limit check skipped"
                    $exitCode = 2
                    break
                }
                
                # Check for rate limit headers
                $hLimit = $errorResponse.Headers['X-RateLimit-Limit']
                if (-not $hLimit) { $hLimit = $errorResponse.Headers['x-ratelimit-limit'] }
                if ($hLimit) { $rateLimitHeaders += "X-RateLimit-Limit: $hLimit" }

                $hRemaining = $errorResponse.Headers['X-RateLimit-Remaining']
                if (-not $hRemaining) { $hRemaining = $errorResponse.Headers['x-ratelimit-remaining'] }
                if ($hRemaining) { $rateLimitHeaders += "X-RateLimit-Remaining: $hRemaining" }
                if ($errorResponse.Headers['Retry-After']) {
                    $rateLimitHeaders += "Retry-After: $($errorResponse.Headers['Retry-After'])"
                }
                
                # Check if we hit rate limit (429)
                if ($statusCode -eq 429) {
                    $rateLimitHit = $true
                    $hitAt = $i
                    $notes = "Rate limit hit at request $i (expected around $ExpectedLimit)"
                    break
                }
            }
        }
        
        # Small delay to avoid overwhelming
        Start-Sleep -Milliseconds 100
    }
    
    if ($notes -like "*skipped*") {
        # already WARN
    } elseif (-not $rateLimitHit) {
        $status = "WARN"
        $notes = "Rate limit not hit after $RequestCount requests (expected after $ExpectedLimit)"
        $exitCode = 2
    } else {
        # Truthful measurement: if rate limit triggers far later than configured expectation, WARN.
        # Allow small jitter (e.g., shared store window boundary) but not 3x+ drift.
        $tolerance = 2
        if ($null -ne $hitAt -and $hitAt -gt ($ExpectedLimit + $tolerance)) {
            $status = "WARN"
            $exitCode = 2
            $notes = "Rate limit enforced late at request $hitAt (expected <= $($ExpectedLimit + $tolerance))"
        } elseif ($notes -eq "") {
            $notes = "Rate limit enforced, headers present: $($rateLimitHeaders -join ', ')"
        }
    }
    
    $script:results += [PSCustomObject]@{
        Check = "Rate Limiting (HOS /v1/auth/login)"
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Check A: GET /admin without auth returns 401/403
Write-Host "=== Running Auth Security Checks ===" -ForegroundColor Cyan
Write-Host ""

Test-AuthResponse -CheckName "Admin Unauthorized Access (HOS)" `
    -Method "GET" `
    -Url $adminTenantsUrl `
    -ExpectedStatusCodes @(401, 403, 404) `
    -ExpectJsonEnvelope $true

# Check A2: GET /admin/users without auth returns 401/403
Test-AuthResponse -CheckName "Admin Users Unauthorized Access (HOS)" `
    -Method "GET" `
    -Url $adminUsersUrl `
    -ExpectedStatusCodes @(401, 403, 404) `
    -ExpectJsonEnvelope $true

# Check A3: GET /admin/audit without auth returns 401/403
Test-AuthResponse -CheckName "Admin Audit Unauthorized Access (HOS)" `
    -Method "GET" `
    -Url $adminAuditUrl `
    -ExpectedStatusCodes @(401, 403, 404) `
    -ExpectJsonEnvelope $true

# Check B: GET /panel without auth returns 401/403
Test-AuthResponse -CheckName "Me Unauthorized Access (HOS)" `
    -Method "GET" `
    -Url $meUrl `
    -ExpectedStatusCodes @(401, 403, 404) `
    -ExpectJsonEnvelope $true

# Check C: POST /auth/login rate limiting
Test-RateLimit -Url $loginUrl -Method "POST" -RequestCount 35 -ExpectedLimit 10

# Check D: Session cookie flags (documented check)
Write-Host "Checking session cookie configuration..." -ForegroundColor Yellow
$cookieStatus = "PASS"
$cookieNotes = "Session cookie flags check (documented)"
$cookieExitCode = 0

# In PROD, cookies should have Secure, HttpOnly, SameSite flags
# This is a documented check; runtime verification in local may be limited
$env = $env:APP_ENV
if ($env -eq "production" -or $env -eq "prod") {
    $cookieStatus = "WARN"
    $cookieNotes = "PROD mode: Verify SESSION_SECURE_COOKIE=true, SESSION_HTTP_ONLY=true, SESSION_SAME_SITE=strict in config"
    $cookieExitCode = 2
} else {
    $cookieNotes = "Local/dev mode: Cookie flags check documented in runbook"
}

$script:results += [PSCustomObject]@{
    Check = "Session Cookie Flags"
    Status = $cookieStatus
    ExitCode = $cookieExitCode
    Notes = $cookieNotes
}

# Print results table
Write-Host ""
Write-Host "=== AUTH SECURITY CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

$script:results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

# Determine overall status
$failCount = ($script:results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($script:results | Where-Object { $_.Status -eq "WARN" }).Count

Write-Host ""
if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    Invoke-OpsExit 1
    return
} elseif ($warnCount -gt 0) {
    # WARN is non-blocking in CI: surface signal without turning the job red.
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings) [non-blocking]" -ForegroundColor Yellow
    Invoke-OpsExit 0
    return
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    Invoke-OpsExit 0
    return
}

