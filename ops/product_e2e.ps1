# product_e2e.ps1 - Marketplace Listings E2E Gate (Canonical)
# Validates: H-OS health + Pazar metrics + marketplace listings smoke/probes.
#
# Reality lock:
# - Pazar world is marketplace
# - Listings API is /api/v1/listings (not world-prefixed)
#
# Exit codes: 0 PASS, 1 FAIL, 2 WARN

param(
    [string]$BaseUrl = $env:BASE_URL,
    [string]$HosBaseUrl = $env:HOS_BASE_URL,
    [string]$TenantId = $env:PRODUCT_TEST_TENANT_ID,
    [string]$AuthToken = $env:PRODUCT_TEST_AUTH_TOKEN,
    [string]$TenantBId = $env:PRODUCT_TEST_TENANT_B_ID,
    [switch]$Verbose
)

if ([string]::IsNullOrEmpty($BaseUrl)) { $BaseUrl = "http://localhost:8080" }
if ([string]::IsNullOrEmpty($HosBaseUrl)) { $HosBaseUrl = "http://localhost:3000" }

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\_lib\ops_output.ps1"
. "$ScriptDir\_lib\ops_exit.ps1"

Initialize-OpsOutput

Write-Info "=== LISTINGS E2E GATE (MARKETPLACE) ==="
Write-Info "Base URL: ${BaseUrl}"
Write-Info "H-OS Base URL: ${HosBaseUrl}"
Write-Info ""

function Invoke-Child {
    param([string]$ScriptPath, [string[]]$Args = @(), [hashtable]$Env = @{})
    $oldCI = $env:CI; $oldGA = $env:GITHUB_ACTIONS
    $env:CI = ""; $env:GITHUB_ACTIONS = ""
    $saved = @{}
    foreach ($k in $Env.Keys) {
        $saved[$k] = [System.Environment]::GetEnvironmentVariable($k, "Process")
        [System.Environment]::SetEnvironmentVariable($k, $Env[$k], "Process")
    }
    try {
        & $ScriptPath @Args | Out-Host
        return [int]($global:LASTEXITCODE)
    } catch {
        Write-Fail "Child failed: $ScriptPath ($($_.Exception.Message))"
        return 1
    } finally {
        foreach ($k in $Env.Keys) {
            [System.Environment]::SetEnvironmentVariable($k, $saved[$k], "Process")
        }
        $env:CI = $oldCI; $env:GITHUB_ACTIONS = $oldGA
    }
}

$exit = 0

# A) H-OS health
Write-Info "A) H-OS health"
try {
    $res = Invoke-WebRequest -Uri "$HosBaseUrl/v1/health" -Method GET -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
    if ($res.StatusCode -eq 200) {
        Write-Pass "H-OS /v1/health OK"
    } else {
        Write-Warn "H-OS /v1/health unexpected status: $($res.StatusCode)"
        if ($exit -eq 0) { $exit = 2 }
    }
} catch {
    Write-Warn "H-OS /v1/health not reachable: $($_.Exception.Message)"
    if ($exit -eq 0) { $exit = 2 }
}

# B) Pazar metrics
Write-Info ""
Write-Info "B) Pazar metrics"
try {
    $m = Invoke-WebRequest -Uri "$BaseUrl/metrics" -Method GET -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
    if ($m.StatusCode -eq 200) {
        Write-Pass "Pazar /metrics OK"
    } else {
        Write-Warn "Pazar /metrics unexpected status: $($m.StatusCode)"
        if ($exit -eq 0) { $exit = 2 }
    }
} catch {
    Write-Warn "Pazar /metrics not reachable: $($_.Exception.Message)"
    if ($exit -eq 0) { $exit = 2 }
}

# C) Live probes (status + categories + listings)
Write-Info ""
Write-Info "C) Live probes (contract check)"
$code = Invoke-Child -ScriptPath (Join-Path $ScriptDir "product_contract_check.ps1") -Args @("-BaseUrl", $BaseUrl)
if ($code -eq 1) { $exit = 1 } elseif ($code -eq 2 -and $exit -eq 0) { $exit = 2 }

# D) Smoke (create -> publish -> show)
Write-Info ""
Write-Info "D) Listings smoke (create -> publish -> show)"
$envMap = @{}
if ($TenantId) { $envMap["PRODUCT_TEST_TENANT_ID"] = $TenantId }
if ($AuthToken) { $envMap["PRODUCT_TEST_AUTH"] = $AuthToken }
if ($TenantBId) { $envMap["PRODUCT_TEST_TENANT_B_ID"] = $TenantBId }
$code = Invoke-Child -ScriptPath (Join-Path $ScriptDir "product_api_smoke.ps1") -Args @("-BaseUrl", $BaseUrl) -Env $envMap
if ($code -eq 1) { $exit = 1 } elseif ($code -eq 2 -and $exit -eq 0) { $exit = 2 }

Write-Host ""
if ($exit -eq 0) { Write-Pass "OVERALL STATUS: PASS" }
elseif ($exit -eq 2) { Write-Warn "OVERALL STATUS: WARN" }
else { Write-Fail "OVERALL STATUS: FAIL" }

Invoke-OpsExit $exit

