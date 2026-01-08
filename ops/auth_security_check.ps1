# auth_security_check.ps1 - Auth Security Hardening Check
# Verifies unauthorized access protection and rate limiting

$ErrorActionPreference = "Continue"

Write-Host "=== AUTH SECURITY CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()

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
            # Check JSON envelope if required
            if ($ExpectJsonEnvelope) {
                try {
                    $json = $response.Content | ConvertFrom-Json
                    if ($json.ok -eq $false -and $json.error_code) {
                        $notes = "Status $statusCode, JSON envelope correct"
                    } else {
                        $status = "WARN"
                        $notes = "Status $statusCode, but JSON envelope incomplete"
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
                # Check JSON envelope if required
                if ($ExpectJsonEnvelope) {
                    try {
                        $stream = $errorResponse.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $body = $reader.ReadToEnd()
                        $json = $body | ConvertFrom-Json
                        if ($json.ok -eq $false -and $json.error_code) {
                            $notes = "Status $statusCode, JSON envelope correct"
                        } else {
                            $status = "WARN"
                            $notes = "Status $statusCode, but JSON envelope incomplete"
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
    
    $results += [PSCustomObject]@{
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
    
    for ($i = 1; $i -le $RequestCount; $i++) {
        try {
            $headers = @{
                "Content-Type" = "application/json"
                "Accept" = "application/json"
            }
            
            $body = @{} | ConvertTo-Json
            
            $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $headers -Body $body -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            
            # Check for rate limit headers
            if ($response.Headers['X-RateLimit-Limit']) {
                $rateLimitHeaders += "X-RateLimit-Limit: $($response.Headers['X-RateLimit-Limit'])"
            }
            if ($response.Headers['X-RateLimit-Remaining']) {
                $rateLimitHeaders += "X-RateLimit-Remaining: $($response.Headers['X-RateLimit-Remaining'])"
            }
            
        } catch {
            $errorResponse = $_.Exception.Response
            if ($errorResponse) {
                $statusCode = [int]$errorResponse.StatusCode.value__
                
                # Check for rate limit headers
                if ($errorResponse.Headers['X-RateLimit-Limit']) {
                    $rateLimitHeaders += "X-RateLimit-Limit: $($errorResponse.Headers['X-RateLimit-Limit'])"
                }
                if ($errorResponse.Headers['X-RateLimit-Remaining']) {
                    $rateLimitHeaders += "X-RateLimit-Remaining: $($errorResponse.Headers['X-RateLimit-Remaining'])"
                }
                if ($errorResponse.Headers['Retry-After']) {
                    $rateLimitHeaders += "Retry-After: $($errorResponse.Headers['Retry-After'])"
                }
                
                # Check if we hit rate limit (429)
                if ($statusCode -eq 429) {
                    $rateLimitHit = $true
                    if ($i -le $ExpectedLimit) {
                        $status = "WARN"
                        $notes = "Rate limit hit at request $i (expected after $ExpectedLimit)"
                        $exitCode = 2
                    } else {
                        $notes = "Rate limit hit at request $i (expected after $ExpectedLimit)"
                    }
                }
            }
        }
        
        # Small delay to avoid overwhelming
        Start-Sleep -Milliseconds 100
    }
    
    if (-not $rateLimitHit) {
        $status = "WARN"
        $notes = "Rate limit not hit after $RequestCount requests (expected after $ExpectedLimit)"
        $exitCode = 2
    } elseif ($rateLimitHeaders.Count -eq 0) {
        $status = "WARN"
        $notes = "Rate limit hit, but headers not present"
        $exitCode = 2
    } else {
        if ($notes -eq "") {
            $notes = "Rate limit enforced, headers present: $($rateLimitHeaders -join ', ')"
        }
    }
    
    $results += [PSCustomObject]@{
        Check = "Rate Limiting (/auth/login)"
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

Test-AuthResponse -CheckName "Admin Unauthorized Access" `
    -Method "GET" `
    -Url "http://localhost:8080/admin/tenants" `
    -ExpectedStatusCodes @(401, 403) `
    -ExpectJsonEnvelope $true

# Check B: GET /panel without auth returns 401/403
Test-AuthResponse -CheckName "Panel Unauthorized Access" `
    -Method "GET" `
    -Url "http://localhost:8080/panel/test-tenant/ping" `
    -ExpectedStatusCodes @(401, 403) `
    -ExpectJsonEnvelope $true

# Check C: POST /auth/login rate limiting
Test-RateLimit -Url "http://localhost:8080/auth/login" -Method "POST" -RequestCount 35 -ExpectedLimit 30

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

$results += [PSCustomObject]@{
    Check = "Session Cookie Flags"
    Status = $cookieStatus
    ExitCode = $cookieExitCode
    Notes = $cookieNotes
}

# Print results table
Write-Host ""
Write-Host "=== AUTH SECURITY CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

# Determine overall status
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" }).Count

Write-Host ""
if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    exit 1
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    exit 2
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    exit 0
}

