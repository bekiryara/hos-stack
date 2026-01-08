# session_posture_check.ps1 - Identity & Session Posture Check
# Validates session security posture and auth endpoint security

$ErrorActionPreference = "Continue"

Write-Host "=== IDENTITY & SESSION POSTURE CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()

# Get APP_ENV (default: local)
$appEnv = $env:APP_ENV
if ([string]::IsNullOrEmpty($appEnv)) {
    $appEnv = "local"
    Write-Host "APP_ENV not set, defaulting to: local" -ForegroundColor Yellow
}

Write-Host "APP_ENV: $appEnv" -ForegroundColor Gray
$isProduction = $appEnv -eq "production" -or $appEnv -eq "prod"
Write-Host ""

# Helper: Check session cookie configuration
function Test-SessionCookieConfig {
    param([bool]$IsProduction)
    
    Write-Host "Checking session cookie configuration..." -ForegroundColor Yellow
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    $failures = @()
    $warnings = @()
    
    if ($IsProduction) {
        # Check SESSION_SECURE_COOKIE
        $sessionSecure = $env:SESSION_SECURE_COOKIE
        if ([string]::IsNullOrEmpty($sessionSecure) -or $sessionSecure -ine "true") {
            $failures += "SESSION_SECURE_COOKIE must be 'true' in production (current: $sessionSecure)"
        }
        
        # Check SESSION_HTTP_ONLY
        $sessionHttpOnly = $env:SESSION_HTTP_ONLY
        if ([string]::IsNullOrEmpty($sessionHttpOnly) -or $sessionHttpOnly -ine "true") {
            $failures += "SESSION_HTTP_ONLY must be 'true' in production (current: $sessionHttpOnly)"
        }
        
        # Check SESSION_SAME_SITE
        $sessionSameSite = $env:SESSION_SAME_SITE
        if ([string]::IsNullOrEmpty($sessionSameSite)) {
            $warnings += "SESSION_SAME_SITE missing in production (recommended: 'lax' or 'strict')"
        } elseif ($sessionSameSite -ieq "none") {
            if ($sessionSecure -ieq "true") {
                $warnings += "SESSION_SAME_SITE='none' with Secure=true (acceptable but not recommended)"
            } else {
                $failures += "SESSION_SAME_SITE='none' requires SESSION_SECURE_COOKIE=true (security risk)"
            }
        } elseif ($sessionSameSite -ine "lax" -and $sessionSameSite -ine "strict") {
            $warnings += "SESSION_SAME_SITE has unexpected value: $sessionSameSite (recommended: 'lax' or 'strict')"
        }
        
        # Check CORS_ALLOWED_ORIGINS (report only, already enforced by env-contract)
        $corsOrigins = $env:CORS_ALLOWED_ORIGINS
        if ([string]::IsNullOrEmpty($corsOrigins)) {
            $warnings += "CORS_ALLOWED_ORIGINS missing in production (enforced by env-contract gate)"
        } elseif ($corsOrigins -like "*`**") {
            $failures += "CORS_ALLOWED_ORIGINS contains wildcard '*' (enforced by env-contract gate)"
        }
    } else {
        $notes = "Local/dev mode: Session cookie checks are recommendations only"
    }
    
    if ($failures.Count -gt 0) {
        $status = "FAIL"
        $notes = $failures -join "; "
        $exitCode = 1
    } elseif ($warnings.Count -gt 0) {
        $status = "WARN"
        $notes = $warnings -join "; "
        $exitCode = 2
    } else {
        if ($IsProduction) {
            $notes = "All session cookie flags correct (Secure, HttpOnly, SameSite)"
        } else {
            $notes = "Local/dev mode: Checks are recommendations"
        }
    }
    
    $results += [PSCustomObject]@{
        Check = "Session Cookie Configuration"
        Status = $status
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Helper: Check auth endpoint response
function Test-AuthEndpointResponse {
    param([string]$Url)
    
    Write-Host "Checking auth endpoint response..." -ForegroundColor Yellow
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    $failures = @()
    $warnings = @()
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        
        $body = @{} | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri $Url -Method "POST" -Headers $headers -Body $body -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        
        # Check JSON envelope
        try {
            $json = $response.Content | ConvertFrom-Json
            if ($json.ok -eq $false -and $json.error_code -and $json.request_id) {
                # JSON envelope correct
            } else {
                $failures += "JSON envelope incomplete (missing ok/error_code/request_id)"
            }
        } catch {
            $failures += "Response is not valid JSON"
        }
        
        # Check security headers
        $securityHeaders = @{
            "X-Content-Type-Options" = "nosniff"
            "X-Frame-Options" = "DENY"
            "Referrer-Policy" = "no-referrer"
        }
        
        foreach ($headerName in $securityHeaders.Keys) {
            $expectedValue = $securityHeaders[$headerName]
            $actualValue = $response.Headers[$headerName]
            
            if ([string]::IsNullOrEmpty($actualValue)) {
                $warnings += "Missing security header: $headerName"
            } elseif ($actualValue -ne $expectedValue) {
                $warnings += "Security header $headerName has unexpected value: $actualValue (expected: $expectedValue)"
            }
        }
        
        # Check rate limit headers (may not be present if not throttled)
        $rateLimitHeaders = @("X-RateLimit-Limit", "X-RateLimit-Remaining")
        $hasRateLimitHeaders = $false
        foreach ($headerName in $rateLimitHeaders) {
            if ($response.Headers[$headerName]) {
                $hasRateLimitHeaders = $true
                break
            }
        }
        
        if (-not $hasRateLimitHeaders) {
            $warnings += "Rate limit headers not present (may not be throttled yet)"
        }
        
    } catch {
        $errorResponse = $_.Exception.Response
        if ($errorResponse) {
            $statusCode = [int]$errorResponse.StatusCode.value__
            
            # Check JSON envelope in error response
            try {
                $stream = $errorResponse.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                $json = $body | ConvertFrom-Json
                if ($json.ok -eq $false -and $json.error_code -and $json.request_id) {
                    # JSON envelope correct
                } else {
                    $failures += "Error response JSON envelope incomplete"
                }
            } catch {
                $failures += "Error response is not valid JSON"
            }
            
            # Check security headers in error response
            $securityHeaders = @{
                "X-Content-Type-Options" = "nosniff"
                "X-Frame-Options" = "DENY"
                "Referrer-Policy" = "no-referrer"
            }
            
            foreach ($headerName in $securityHeaders.Keys) {
                $expectedValue = $securityHeaders[$headerName]
                $actualValue = $errorResponse.Headers[$headerName]
                
                if ([string]::IsNullOrEmpty($actualValue)) {
                    $warnings += "Missing security header: $headerName"
                }
            }
            
            # Rate limit headers on 429
            if ($statusCode -eq 429) {
                $rateLimitHeaders = @("X-RateLimit-Limit", "X-RateLimit-Remaining", "Retry-After")
                $hasRateLimitHeaders = $false
                foreach ($headerName in $rateLimitHeaders) {
                    if ($errorResponse.Headers[$headerName]) {
                        $hasRateLimitHeaders = $true
                        break
                    }
                }
                
                if (-not $hasRateLimitHeaders) {
                    $warnings += "Rate limit headers not present on 429 response"
                }
            }
        } else {
            $failures += "Request failed: $($_.Exception.Message)"
        }
    }
    
    if ($failures.Count -gt 0) {
        $status = "FAIL"
        $notes = $failures -join "; "
        $exitCode = 1
    } elseif ($warnings.Count -gt 0) {
        $status = "WARN"
        $notes = $warnings -join "; "
        $exitCode = 2
    } else {
        $notes = "JSON envelope, security headers, and rate limit headers present"
    }
    
    $results += [PSCustomObject]@{
        Check = "Auth Endpoint Response (/auth/login)"
        Status = $status
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Check session cookie configuration
Write-Host "=== Checking Session Cookie Configuration ===" -ForegroundColor Cyan
Write-Host ""

Test-SessionCookieConfig -IsProduction $isProduction

# Check auth endpoint response (if docker is available)
Write-Host ""
Write-Host "=== Checking Auth Endpoint Response ===" -ForegroundColor Cyan
Write-Host ""

# Try to check if services are running
$servicesRunning = $false
try {
    $composeStatus = docker compose ps --format json 2>&1 | ConvertFrom-Json
    $servicesRunning = ($composeStatus | Where-Object { $_.State -eq "running" -or $_.State -eq "Up" }).Count -gt 0
} catch {
    # Docker not available or not running
}

if ($servicesRunning) {
    Test-AuthEndpointResponse -Url "http://localhost:8080/auth/login"
} else {
    Write-Host "Docker services not running, skipping endpoint checks" -ForegroundColor Yellow
    $results += [PSCustomObject]@{
        Check = "Auth Endpoint Response (/auth/login)"
        Status = "WARN"
        Notes = "Docker services not running, endpoint checks skipped"
    }
}

# Print results table
Write-Host ""
Write-Host "=== SESSION POSTURE CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property Check, Status, Notes -AutoSize

# Determine overall status
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" }).Count

Write-Host ""
if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Remediation Hints:" -ForegroundColor Yellow
    if ($isProduction) {
        Write-Host "  - Set SESSION_SECURE_COOKIE=true in production" -ForegroundColor Gray
        Write-Host "  - Set SESSION_HTTP_ONLY=true in production" -ForegroundColor Gray
        Write-Host "  - Set SESSION_SAME_SITE='lax' or 'strict' in production" -ForegroundColor Gray
        Write-Host "  - Ensure CORS_ALLOWED_ORIGINS has strict allowlist (no wildcard)" -ForegroundColor Gray
    }
    Write-Host "  - Verify security headers are present on auth endpoints" -ForegroundColor Gray
    Write-Host "  - Verify rate limit headers are present on throttled endpoints" -ForegroundColor Gray
    Write-Host "  - Review docs/runbooks/session_posture.md for examples" -ForegroundColor Gray
    exit 1
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($result in ($results | Where-Object { $_.Status -eq "WARN" })) {
        Write-Host "  - $($result.Check): $($result.Notes)" -ForegroundColor Yellow
    }
    exit 2
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    exit 0
}

