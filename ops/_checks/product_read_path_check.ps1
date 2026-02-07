# product_read_path_check.ps1 - Marketplace Listings Read Path Check
# Validates that Pazar exposes listing read endpoints:
# - GET /api/v1/listings
# - GET /api/v1/listings/{id} (best-effort if list is non-empty)
#
# Reality lock:
# - Pazar declares only marketplace in work/pazar/config/worlds.php
# - API routes are NOT namespaced as /api/v1/{world}/...
#
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern.

param(
    [string]$WorldsConfigPath = "work\pazar\config\worlds.php",
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}
if (Test-Path "${scriptDir}\_lib\worlds_config.ps1") {
    . "${scriptDir}\_lib\worlds_config.ps1"
}

Write-Host "=== MARKETPLACE LISTINGS READ PATH CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$results = @()
$overallStatus = "PASS"
$overallExitCode = 0

function Add-CheckResult {
    param([string]$CheckName, [string]$Status, [string]$Notes = "")
    $script:results += [PSCustomObject]@{ Check = $CheckName; Status = $Status; Notes = $Notes }
    if ($Status -eq "FAIL") {
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    } elseif ($Status -eq "WARN") {
        if ($script:overallStatus -ne "FAIL") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    }
}

# Check 1: Worlds config sanity (enabled=[marketplace], disabled=[])
Write-Info "Check 1: Worlds config sanity (expect enabled=[marketplace], disabled=[])"
try {
    if (-not (Test-Path $WorldsConfigPath)) {
        Write-Fail "Worlds config not found: $WorldsConfigPath"
        Add-CheckResult -CheckName "Worlds Config Exists" -Status "FAIL" -Notes "Missing config"
        Invoke-OpsExit 1
        return
    }

    $enabled = @()
    $disabled = @()

    if (Get-Command Get-WorldsConfig -ErrorAction SilentlyContinue) {
        $wc = Get-WorldsConfig -WorldsConfigPath $WorldsConfigPath
        $enabled = $wc.Enabled
        $disabled = $wc.Disabled
    } else {
        $content = Get-Content $WorldsConfigPath -Raw
        if ($content -match "(?s)'enabled'\s*=>\s*\[(.*?)\]") {
            $m = [regex]::Matches($matches[1], "['""]([a-z0-9_]+)['""]")
            foreach ($x in $m) { $enabled += $x.Groups[1].Value }
        }
        if ($content -match "(?s)'disabled'\s*=>\s*\[(.*?)\]") {
            $m = [regex]::Matches($matches[1], "['""]([a-z0-9_]+)['""]")
            foreach ($x in $m) { $disabled += $x.Groups[1].Value }
        }
    }

    $enabled = @($enabled | Sort-Object -Unique)
    $disabled = @($disabled | Sort-Object -Unique)

    if ($enabled.Count -ne 1 -or $enabled[0] -ne "marketplace" -or $disabled.Count -ne 0) {
        $en = if ($enabled) { $enabled -join ", " } else { "<empty>" }
        $di = if ($disabled) { $disabled -join ", " } else { "<empty>" }
        Write-Fail "Worlds config drift. Expected enabled=[marketplace], disabled=[]. Got enabled=[$en], disabled=[$di]"
        Add-CheckResult -CheckName "Worlds Config" -Status "FAIL" -Notes "Drift detected"
        Invoke-OpsExit 1
        return
    }

    Write-Pass "Worlds config OK (marketplace)"
    Add-CheckResult -CheckName "Worlds Config" -Status "PASS" -Notes "enabled=[marketplace]"
} catch {
    Write-Fail "Error parsing worlds config: $($_.Exception.Message)"
    Add-CheckResult -CheckName "Worlds Config" -Status "FAIL" -Notes "Parse error"
    Invoke-OpsExit 1
    return
}

# Check 2: Live list endpoint
Write-Info "Check 2: Live GET /api/v1/listings"
$items = @()
try {
    $res = Invoke-WebRequest -Uri "$BaseUrl/api/v1/listings" -Method GET -Headers @{ "Accept" = "application/json" } -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($res.StatusCode -ne 200) {
        Write-Fail "Expected 200, got $($res.StatusCode)"
        Add-CheckResult -CheckName "GET /api/v1/listings" -Status "FAIL" -Notes "HTTP $($res.StatusCode)"
        Invoke-OpsExit 1
        return
    }

    $json = $res.Content | ConvertFrom-Json
    if ($null -eq $json) {
        Write-Fail "Invalid JSON response"
        Add-CheckResult -CheckName "GET /api/v1/listings" -Status "FAIL" -Notes "Invalid JSON"
        Invoke-OpsExit 1
        return
    }

    if ($json -is [System.Array]) {
        $items = $json
        Write-Pass "GET /api/v1/listings OK (items: $($items.Count))"
        Add-CheckResult -CheckName "GET /api/v1/listings" -Status "PASS" -Notes "items=$($items.Count)"
    } else {
        Write-Warn "GET /api/v1/listings returned non-array JSON (still 200)"
        Add-CheckResult -CheckName "GET /api/v1/listings" -Status "WARN" -Notes "Expected array; got $($json.GetType().Name)"
    }
} catch {
    Write-Fail "GET /api/v1/listings failed: $($_.Exception.Message)"
    Add-CheckResult -CheckName "GET /api/v1/listings" -Status "FAIL" -Notes "Request failed"
    Invoke-OpsExit 1
    return
}

# Check 3: Live show endpoint (best-effort if list non-empty)
Write-Info "Check 3: Live GET /api/v1/listings/{id} (best-effort)"
try {
    if ($items -and $items.Count -gt 0 -and $items[0].id) {
        $id = [string]$items[0].id
        $show = Invoke-WebRequest -Uri "$BaseUrl/api/v1/listings/$id" -Method GET -Headers @{ "Accept" = "application/json" } -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($show.StatusCode -ne 200) {
            Write-Fail "Expected 200, got $($show.StatusCode)"
            Add-CheckResult -CheckName "GET /api/v1/listings/{id}" -Status "FAIL" -Notes "HTTP $($show.StatusCode)"
            Invoke-OpsExit 1
            return
        }
        $showJson = $show.Content | ConvertFrom-Json
        if ($showJson.id -ne $id) {
            Write-Fail "ID mismatch (expected $id, got $($showJson.id))"
            Add-CheckResult -CheckName "GET /api/v1/listings/{id}" -Status "FAIL" -Notes "ID mismatch"
            Invoke-OpsExit 1
            return
        }
        Write-Pass "GET /api/v1/listings/{id} OK"
        Add-CheckResult -CheckName "GET /api/v1/listings/{id}" -Status "PASS" -Notes "id=$id"
    } else {
        Write-Warn "List is empty (or missing id). Skipping show check."
        Add-CheckResult -CheckName "GET /api/v1/listings/{id}" -Status "WARN" -Notes "Skipped (no sample id)"
    }
} catch {
    Write-Fail "GET /api/v1/listings/{id} failed: $($_.Exception.Message)"
    Add-CheckResult -CheckName "GET /api/v1/listings/{id}" -Status "FAIL" -Notes "Request failed"
    Invoke-OpsExit 1
    return
}

# Summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize
Write-Host ""
if ($overallStatus -eq "PASS") {
    Write-Pass "OVERALL STATUS: PASS"
} elseif ($overallStatus -eq "WARN") {
    Write-Warn "OVERALL STATUS: WARN"
} else {
    Write-Fail "OVERALL STATUS: FAIL"
}
Invoke-OpsExit $overallExitCode

