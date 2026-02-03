# product_spine_check.ps1 - Marketplace Product Spine Wrapper
# Backward-compatible wrapper that measures the CURRENT repository reality:
# - Pazar declares only marketplace in work/pazar/config/worlds.php
# - Listings API is /api/v1/listings (not world-prefixed)
#
# Exit codes: 0 PASS, 1 FAIL, 2 WARN (same convention as other ops scripts).

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") { . "${scriptDir}\_lib\ops_output.ps1"; Initialize-OpsOutput }
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") { . "${scriptDir}\_lib\ops_exit.ps1"; Initialize-OpsExit }

Write-Host "=== PRODUCT SPINE CHECK (MARKETPLACE) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

function Invoke-ChildCheck {
    param([string]$ScriptPath, [string[]]$Args = @())

    $oldCI = $env:CI
    $oldGA = $env:GITHUB_ACTIONS
    $env:CI = ""
    $env:GITHUB_ACTIONS = ""
    try {
        & $ScriptPath @Args | Out-Host
        return [int]($global:LASTEXITCODE)
    } catch {
        Write-Fail "Child check failed: $ScriptPath ($($_.Exception.Message))"
        return 1
    } finally {
        $env:CI = $oldCI
        $env:GITHUB_ACTIONS = $oldGA
    }
}

$exit = 0

Write-Info "1) World spine governance"
$code = Invoke-ChildCheck -ScriptPath (Join-Path $scriptDir "world_spine_check.ps1")
if ($code -eq 1) { $exit = 1 } elseif ($code -eq 2 -and $exit -eq 0) { $exit = 2 }

Write-Info ""
Write-Info "2) Listings read-path"
$code = Invoke-ChildCheck -ScriptPath (Join-Path $scriptDir "product_read_path_check.ps1") -Args @("-BaseUrl", $BaseUrl)
if ($code -eq 1) { $exit = 1 } elseif ($code -eq 2 -and $exit -eq 0) { $exit = 2 }

Write-Info ""
Write-Info "3) Listings write smoke (optional if credentials missing)"
$code = Invoke-ChildCheck -ScriptPath (Join-Path $scriptDir "product_api_smoke.ps1") -Args @("-BaseUrl", $BaseUrl)
if ($code -eq 1) { $exit = 1 } elseif ($code -eq 2 -and $exit -eq 0) { $exit = 2 }

Write-Host ""
if ($exit -eq 0) { Write-Pass "OVERALL STATUS: PASS" }
elseif ($exit -eq 2) { Write-Warn "OVERALL STATUS: WARN" }
else { Write-Fail "OVERALL STATUS: FAIL" }

Invoke-OpsExit $exit

