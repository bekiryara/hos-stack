# product_contract_check.ps1 - Marketplace Contract Check (Live)
# Backward-compatible contract check aligned to CURRENT repo reality.
#
# Checks:
# - GET /api/world/status returns marketplace key
# - GET /api/v1/categories returns 200
# - GET /api/v1/listings returns 200
#
# Exit codes: 0 PASS, 1 FAIL, 2 WARN

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") { . "${scriptDir}\_lib\ops_output.ps1"; Initialize-OpsOutput }
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") { . "${scriptDir}\_lib\ops_exit.ps1"; Initialize-OpsExit }

Write-Host "=== PRODUCT CONTRACT CHECK (MARKETPLACE) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host ""

$exit = 0

function Fail($msg) { Write-Fail $msg; $script:exit = 1 }
function Warn($msg) { if ($script:exit -eq 0) { $script:exit = 2 }; Write-Warn $msg }

try {
    $ws = Invoke-WebRequest -Uri "$BaseUrl/api/world/status" -Method GET -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($ws.StatusCode -ne 200) { Fail "GET /api/world/status expected 200, got $($ws.StatusCode)" }
    else {
        $json = $ws.Content | ConvertFrom-Json
        if ($json.world_key -ne "marketplace") { Fail "world/status world_key mismatch (expected marketplace, got $($json.world_key))" }
        else { Write-Pass "GET /api/world/status OK (marketplace)" }
    }
} catch {
    Fail "GET /api/world/status failed: $($_.Exception.Message)"
}

try {
    $cat = Invoke-WebRequest -Uri "$BaseUrl/api/v1/categories" -Method GET -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($cat.StatusCode -ne 200) { Fail "GET /api/v1/categories expected 200, got $($cat.StatusCode)" }
    else { Write-Pass "GET /api/v1/categories OK" }
} catch {
    Fail "GET /api/v1/categories failed: $($_.Exception.Message)"
}

try {
    $list = Invoke-WebRequest -Uri "$BaseUrl/api/v1/listings" -Method GET -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($list.StatusCode -ne 200) { Fail "GET /api/v1/listings expected 200, got $($list.StatusCode)" }
    else { Write-Pass "GET /api/v1/listings OK" }
} catch {
    Fail "GET /api/v1/listings failed: $($_.Exception.Message)"
}

Write-Host ""
if ($exit -eq 0) { Write-Pass "OVERALL STATUS: PASS" }
elseif ($exit -eq 2) { Write-Warn "OVERALL STATUS: WARN" }
else { Write-Fail "OVERALL STATUS: FAIL" }

Invoke-OpsExit $exit

