# product_spine_governance.ps1 - Marketplace Spine Governance (Wrapper)
# Backward-compatible wrapper: the historical multiworld product spine governance
# is retired. Current reality is marketplace-only and measured by:
# - ops/world_spine_check.ps1
# - ops/product_contract.ps1 (doc shape)
#
# Exit codes: 0 PASS, 1 FAIL, 2 WARN

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") { . "${scriptDir}\_lib\ops_output.ps1"; Initialize-OpsOutput }
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") { . "${scriptDir}\_lib\ops_exit.ps1"; Initialize-OpsExit }

Write-Host "=== PRODUCT SPINE GOVERNANCE (MARKETPLACE WRAPPER) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

function Invoke-Child {
    param([string]$ScriptPath, [string[]]$Args = @())
    $oldCI = $env:CI; $oldGA = $env:GITHUB_ACTIONS
    $env:CI = ""; $env:GITHUB_ACTIONS = ""
    try { & $ScriptPath @Args | Out-Host; return [int]$global:LASTEXITCODE }
    catch { Write-Fail "Child failed: $ScriptPath ($($_.Exception.Message))"; return 1 }
    finally { $env:CI = $oldCI; $env:GITHUB_ACTIONS = $oldGA }
}

$exit = 0
$code = Invoke-Child -ScriptPath (Join-Path $scriptDir "world_spine_check.ps1")
if ($code -eq 1) { $exit = 1 } elseif ($code -eq 2 -and $exit -eq 0) { $exit = 2 }

$code = Invoke-Child -ScriptPath (Join-Path $scriptDir "product_contract.ps1")
if ($code -eq 1) { $exit = 1 } elseif ($code -eq 2 -and $exit -eq 0) { $exit = 2 }

Write-Host ""
if ($exit -eq 0) { Write-Pass "OVERALL STATUS: PASS" }
elseif ($exit -eq 2) { Write-Warn "OVERALL STATUS: WARN" }
else { Write-Fail "OVERALL STATUS: FAIL" }

Invoke-OpsExit $exit

