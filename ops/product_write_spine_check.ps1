# product_write_spine_check.ps1 - Marketplace Write Spine (Wrapper)
# Historical multiworld/world-prefixed write spine is retired.
# Current write spine for listings is validated by:
# - ops/product_api_smoke.ps1 (POST /api/v1/listings + publish)
#
# Exit codes: 0 PASS, 1 FAIL, 2 WARN

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") { . "${scriptDir}\_lib\ops_output.ps1"; Initialize-OpsOutput }
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") { . "${scriptDir}\_lib\ops_exit.ps1"; Initialize-OpsExit }

Write-Host "=== PRODUCT WRITE SPINE CHECK (MARKETPLACE WRAPPER) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$oldCI = $env:CI; $oldGA = $env:GITHUB_ACTIONS
$env:CI = ""; $env:GITHUB_ACTIONS = ""
try {
    & (Join-Path $scriptDir "product_api_smoke.ps1") -BaseUrl $BaseUrl | Out-Host
    $code = [int]$global:LASTEXITCODE
} catch {
    Write-Fail "Write wrapper failed: $($_.Exception.Message)"
    $code = 1
} finally {
    $env:CI = $oldCI; $env:GITHUB_ACTIONS = $oldGA
}

Invoke-OpsExit $code

