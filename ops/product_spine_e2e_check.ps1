# product_spine_e2e_check.ps1 - Marketplace Spine E2E (Wrapper)
# Historical multiworld E2E is retired; current end-to-end flow is exercised by:
# - ops/product_api_smoke.ps1 (create + publish + show)
#
# Exit codes: 0 PASS, 1 FAIL, 2 WARN

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") { . "${scriptDir}\_lib\ops_output.ps1"; Initialize-OpsOutput }
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") { . "${scriptDir}\_lib\ops_exit.ps1"; Initialize-OpsExit }

Write-Host "=== PRODUCT SPINE E2E CHECK (MARKETPLACE WRAPPER) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$oldCI = $env:CI; $oldGA = $env:GITHUB_ACTIONS
$env:CI = ""; $env:GITHUB_ACTIONS = ""
try {
    & (Join-Path $scriptDir "product_api_smoke.ps1") -BaseUrl $BaseUrl | Out-Host
    $code = [int]$global:LASTEXITCODE
} catch {
    Write-Fail "E2E wrapper failed: $($_.Exception.Message)"
    $code = 1
} finally {
    $env:CI = $oldCI; $env:GITHUB_ACTIONS = $oldGA
}

Invoke-OpsExit $code

