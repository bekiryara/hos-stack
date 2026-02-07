# product_e2e_contract.ps1 - Marketplace E2E Contract (Wrapper)
# Historical multiworld E2E contract is retired.
# Current contract probes are provided by:
# - ops/product_contract_check.ps1 (live probes)
#
# Exit codes: 0 PASS, 1 FAIL, 2 WARN

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") { . "${scriptDir}\_lib\ops_output.ps1"; Initialize-OpsOutput }
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") { . "${scriptDir}\_lib\ops_exit.ps1"; Initialize-OpsExit }

Write-Host "=== PRODUCT E2E CONTRACT (MARKETPLACE WRAPPER) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$oldCI = $env:CI; $oldGA = $env:GITHUB_ACTIONS
$env:CI = ""; $env:GITHUB_ACTIONS = ""
try {
    & (Join-Path $scriptDir "product_contract_check.ps1") -BaseUrl $BaseUrl | Out-Host
    $code = [int]$global:LASTEXITCODE
} catch {
    Write-Fail "E2E contract wrapper failed: $($_.Exception.Message)"
    $code = 1
} finally {
    $env:CI = $oldCI; $env:GITHUB_ACTIONS = $oldGA
}

Invoke-OpsExit $code

