#!/usr/bin/env pwsh
# ENSURE PRODUCT TEST AUTH (WP-23)
# Entrypoint script to bootstrap and set PRODUCT_TEST_AUTH for local/dev testing
# Prints only redacted token preview (first 12 chars + "...")

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testAuthPath = Join-Path $scriptDir "_lib\test_auth.ps1"

if (-not (Test-Path $testAuthPath)) {
    Write-Host "FAIL: test_auth.ps1 helper not found at: $testAuthPath" -ForegroundColor Red
    exit 1
}

. $testAuthPath

try {
    $token = Get-DevTestJwtToken
    
    Write-Host ""
    Write-Host "OK: PRODUCT_TEST_AUTH set for this process" -ForegroundColor Green
    Write-Host "  Token preview: $($token.Substring(0, [Math]::Min(12, $token.Length)))..." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Note: Token is set in environment variables for this PowerShell session only." -ForegroundColor Yellow
    Write-Host "  To persist across sessions, set in your shell profile or use:" -ForegroundColor Yellow
    Write-Host "  `$env:PRODUCT_TEST_AUTH = 'Bearer $($token.Substring(0, [Math]::Min(12, $token.Length)))...'" -ForegroundColor Gray
    Write-Host ""
    
    exit 0
} catch {
    Write-Host ""
    Write-Host "FAIL: Failed to bootstrap JWT token" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    Write-Host "  1. Ensure H-OS service is running: docker compose ps" -ForegroundColor Yellow
    Write-Host "  2. Check H-OS API is accessible: curl http://localhost:3000/v1/world/status" -ForegroundColor Yellow
    Write-Host "  3. Verify H-OS configuration matches defaults (dev-api-key)" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}


