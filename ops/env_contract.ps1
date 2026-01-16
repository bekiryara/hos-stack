# env_contract.ps1 - Environment & Secrets Contract Check
# Validates required env vars and production guardrails

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== ENVIRONMENT & SECRETS CONTRACT CHECK ===" -ForegroundColor Cyan
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

# Helper: Get environment variable value (PS5.1-safe)
function Get-EnvValue {
    param([string]$Name)
    $item = Get-Item -Path ("Env:" + $Name) -ErrorAction SilentlyContinue
    if ($item) {
        return $item.Value
    }
    return ""
}

# Helper: Check if env var exists
function Test-EnvVar {
    param(
        [string]$VarName,
        [bool]$Required = $true,
        [string[]]$WeakValues = @()
    )
    
    $value = Get-EnvValue -Name $VarName
    $exists = -not [string]::IsNullOrEmpty($value)
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    
    if (-not $exists) {
        if ($Required) {
            $status = "FAIL"
            $notes = "Missing required environment variable"
            $exitCode = 1
        } else {
            $status = "WARN"
            $notes = "Optional environment variable not set"
            $exitCode = 2
        }
    } else {
        # Check for weak/default values
        if ($WeakValues.Count -gt 0) {
            $isWeak = $false
            foreach ($weak in $WeakValues) {
                if ($value -eq $weak -or $value -like "*$weak*") {
                    $isWeak = $true
                    break
                }
            }
            
            if ($isWeak) {
                $status = "FAIL"
                $notes = "Weak or default value detected (security risk)"
                $exitCode = 1
            } else {
                $notes = "Set (value hidden for security)"
            }
        } else {
            $notes = "Set (value hidden for security)"
        }
    }
    
    $results += [PSCustomObject]@{
        Check = $VarName
        Status = $status
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Helper: Check env var value
function Test-EnvVarValue {
    param(
        [string]$VarName,
        [string]$ExpectedValue,
        [bool]$CaseSensitive = $false
    )
    
    $value = Get-EnvValue -Name $VarName
    $exists = -not [string]::IsNullOrEmpty($value)
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    
    if (-not $exists) {
        $status = "FAIL"
        $notes = "Missing environment variable"
        $exitCode = 1
    } else {
        if ($CaseSensitive) {
            $matches = $value -eq $ExpectedValue
        } else {
            $matches = $value -ieq $ExpectedValue
        }
        
        if ($matches) {
            $notes = "Value correct"
        } else {
            $status = "FAIL"
            $notes = "Value mismatch (expected: $ExpectedValue, got: $value)"
            $exitCode = 1
        }
    }
    
    $results += [PSCustomObject]@{
        Check = "$VarName = $ExpectedValue"
        Status = $status
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Required env vars (always)
Write-Host "=== Checking Required Environment Variables ===" -ForegroundColor Cyan
Write-Host ""

Test-EnvVar -VarName "APP_ENV" -Required $true
Test-EnvVar -VarName "APP_KEY" -Required $true -WeakValues @("", "base64:", "changeme", "secret", "password")

# Database env vars
Test-EnvVar -VarName "DB_HOST" -Required $true
Test-EnvVar -VarName "DB_DATABASE" -Required $true
Test-EnvVar -VarName "DB_USERNAME" -Required $true
Test-EnvVar -VarName "DB_PASSWORD" -Required $true -WeakValues @("", "password", "changeme", "secret", "root")

# Production guardrails
if ($isProduction) {
    Write-Host ""
    Write-Host "=== Checking Production Guardrails ===" -ForegroundColor Cyan
    Write-Host ""
    
    # CORS_ALLOWED_ORIGINS must NOT contain '*'
    $corsOrigins = $env:CORS_ALLOWED_ORIGINS
    if ([string]::IsNullOrEmpty($corsOrigins)) {
        $results += [PSCustomObject]@{
            Check = "CORS_ALLOWED_ORIGINS (PROD)"
            Status = "FAIL"
            Notes = "Missing in production (required for CORS policy)"
        }
    } elseif ($corsOrigins -like "*`**") {
        $results += [PSCustomObject]@{
            Check = "CORS_ALLOWED_ORIGINS (PROD)"
            Status = "FAIL"
            Notes = "Contains wildcard '*' (security risk in production)"
        }
    } else {
        $results += [PSCustomObject]@{
            Check = "CORS_ALLOWED_ORIGINS (PROD)"
            Status = "PASS"
            Notes = "Set with strict allowlist (no wildcard)"
        }
    }
    
    # SESSION_SECURE_COOKIE must be true
    $sessionSecure = $env:SESSION_SECURE_COOKIE
    if ([string]::IsNullOrEmpty($sessionSecure)) {
        $results += [PSCustomObject]@{
            Check = "SESSION_SECURE_COOKIE (PROD)"
            Status = "FAIL"
            Notes = "Missing in production (should be 'true' for HTTPS-only cookies)"
        }
    } elseif ($sessionSecure -ieq "true") {
        $results += [PSCustomObject]@{
            Check = "SESSION_SECURE_COOKIE (PROD)"
            Status = "PASS"
            Notes = "Set to 'true' (HTTPS-only cookies)"
        }
    } else {
        $results += [PSCustomObject]@{
            Check = "SESSION_SECURE_COOKIE (PROD)"
            Status = "FAIL"
            Notes = "Must be 'true' in production (current: $sessionSecure)"
        }
    }
    
    # SESSION_SAME_SITE must be 'lax' or 'strict' (WARN if missing, FAIL if 'none' without Secure)
    $sessionSameSite = $env:SESSION_SAME_SITE
    if ([string]::IsNullOrEmpty($sessionSameSite)) {
        $results += [PSCustomObject]@{
            Check = "SESSION_SAME_SITE (PROD)"
            Status = "WARN"
            Notes = "Missing in production (recommended: 'lax' or 'strict')"
        }
    } elseif ($sessionSameSite -ieq "lax" -or $sessionSameSite -ieq "strict") {
        $results += [PSCustomObject]@{
            Check = "SESSION_SAME_SITE (PROD)"
            Status = "PASS"
            Notes = "Set to '$sessionSameSite' (CSRF protection)"
        }
    } elseif ($sessionSameSite -ieq "none") {
        # Check if SESSION_SECURE_COOKIE is true
        if ($sessionSecure -ieq "true") {
            $results += [PSCustomObject]@{
                Check = "SESSION_SAME_SITE (PROD)"
                Status = "PASS"
                Notes = "Set to 'none' with SESSION_SECURE_COOKIE=true (acceptable)"
            }
        } else {
            $results += [PSCustomObject]@{
                Check = "SESSION_SAME_SITE (PROD)"
                Status = "FAIL"
                Notes = "Set to 'none' but SESSION_SECURE_COOKIE is not 'true' (security risk)"
            }
        }
    } else {
        $results += [PSCustomObject]@{
            Check = "SESSION_SAME_SITE (PROD)"
            Status = "WARN"
            Notes = "Unexpected value: $sessionSameSite (recommended: 'lax' or 'strict')"
        }
    }
}

# Optional OIDC/JWT secrets (check if OIDC is enabled)
Write-Host ""
Write-Host "=== Checking Optional Secrets (OIDC/JWT) ===" -ForegroundColor Cyan
Write-Host ""

$oidcIssuer = $env:HOS_OIDC_ISSUER
$oidcEnabled = -not [string]::IsNullOrEmpty($oidcIssuer)

if ($oidcEnabled) {
    Test-EnvVar -VarName "HOS_OIDC_ISSUER" -Required $true
    Test-EnvVar -VarName "HOS_OIDC_CLIENT_ID" -Required $false
    Test-EnvVar -VarName "HOS_OIDC_API_KEY" -Required $false -WeakValues @("", "changeme", "secret", "password")
} else {
    $results += [PSCustomObject]@{
        Check = "HOS_OIDC_ISSUER"
        Status = "PASS"
        Notes = "OIDC not enabled (optional)"
    }
}

# Print results table
Write-Host ""
Write-Host "=== ENVIRONMENT CONTRACT CHECK RESULTS ===" -ForegroundColor Cyan
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
    Write-Host "  - Set missing required environment variables" -ForegroundColor Gray
    if ($isProduction) {
        Write-Host "  - PROD: Set CORS_ALLOWED_ORIGINS with strict allowlist (no wildcard)" -ForegroundColor Gray
        Write-Host "  - PROD: Set SESSION_SECURE_COOKIE=true for HTTPS-only cookies" -ForegroundColor Gray
        Write-Host "  - PROD: Set SESSION_SAME_SITE='lax' or 'strict' for CSRF protection" -ForegroundColor Gray
    }
    Write-Host "  - Replace weak/default secrets with strong values" -ForegroundColor Gray
    Write-Host "  - Review docs/runbooks/env_contract.md for examples" -ForegroundColor Gray
    Invoke-OpsExit 1
    return
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($result in ($results | Where-Object { $_.Status -eq "WARN" })) {
        Write-Host "  - $($result.Check): $($result.Notes)" -ForegroundColor Yellow
    }
    Invoke-OpsExit 2
    return
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    Invoke-OpsExit 0
    return
}

