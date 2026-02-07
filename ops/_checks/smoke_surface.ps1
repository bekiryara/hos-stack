# smoke_surface.ps1 - Smoke Surface Gate
# Validates critical surfaces don't return 500/regression errors.
# NOTE: To avoid duplicate measurements, this script intentionally does NOT check:
# - metrics (owned by observability_status.ps1)
# - error envelope contract (owned by ops_status/rc0_gate)
# - admin UI surface (owned by pazar_ui_smoke.ps1)
# PowerShell 5.1 compatible, ASCII-only output, safe-exit behavior

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$PrometheusUrl = "http://localhost:9090"
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

Write-Host "=== SMOKE SURFACE GATE ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()
$overallStatus = "PASS"
$overallExitCode = 0
$hasWarn = $false
$hasFail = $false

# Helper: Add check result
function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$Notes,
        [bool]$Blocking = $true
    )
    
    $exitCode = 0
    if ($Status -eq "FAIL") {
        $exitCode = 1
        $script:hasFail = $true
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    } elseif ($Status -eq "WARN") {
        $exitCode = 2
        $script:hasWarn = $true
        if ($script:overallStatus -eq "PASS") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    }
    
    $script:results += [PSCustomObject]@{
        Check = $CheckName
        Status = $Status
        Notes = $Notes
        ExitCode = $exitCode
        Blocking = $Blocking
    }
}

# Helper: Check for UTF-8 BOM
function Test-Utf8Bom {
    param([byte[]]$Bytes)
    
    if ($Bytes.Length -lt 3) {
        return $false
    }
    
    # UTF-8 BOM: EF BB BF
    return ($Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF)
}

# Check 1: Pazar /up → 200
Write-Host "Check 1: Pazar /up endpoint" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/up" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        Add-CheckResult -CheckName "Pazar /up" -Status "PASS" -Notes "HTTP 200 OK"
    } else {
        Add-CheckResult -CheckName "Pazar /up" -Status "FAIL" -Notes "Expected HTTP 200, got $($response.StatusCode)"
    }
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        Add-CheckResult -CheckName "Pazar /up" -Status "FAIL" -Notes "HTTP $statusCode - $($_.Exception.Message)"
    } else {
        Add-CheckResult -CheckName "Pazar /up" -Status "FAIL" -Notes "Connection error: $($_.Exception.Message)"
    }
}

Write-Host ""

# Check 2: Pazar core API surface (world status)
Write-Host "Check 2: Pazar /api/world/status" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/api/world/status" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Add-CheckResult -CheckName "Pazar /api/world/status" -Status "PASS" -Notes "HTTP 200"
    } else {
        Add-CheckResult -CheckName "Pazar /api/world/status" -Status "FAIL" -Notes "Expected HTTP 200, got $($response.StatusCode)"
    }
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        Add-CheckResult -CheckName "Pazar /api/world/status" -Status "FAIL" -Notes "HTTP $statusCode - $($_.Exception.Message)"
    } else {
        Add-CheckResult -CheckName "Pazar /api/world/status" -Status "FAIL" -Notes "Connection error: $($_.Exception.Message)"
    }
}

Write-Host ""

# Check 3: Pazar categories surface (guest browse)
Write-Host "Check 3: Pazar /api/v1/categories" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/categories" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Add-CheckResult -CheckName "Pazar /api/v1/categories" -Status "PASS" -Notes "HTTP 200"
    } else {
        Add-CheckResult -CheckName "Pazar /api/v1/categories" -Status "FAIL" -Notes "Expected HTTP 200, got $($response.StatusCode)"
    }
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        Add-CheckResult -CheckName "Pazar /api/v1/categories" -Status "FAIL" -Notes "HTTP $statusCode - $($_.Exception.Message)"
    } else {
        Add-CheckResult -CheckName "Pazar /api/v1/categories" -Status "FAIL" -Notes "Connection error: $($_.Exception.Message)"
    }
}

Write-Host ""

# Check 4: Optional (WARN-only) - If Prometheus reachable (9090), verify /api/v1/targets has pazar job up; else WARN
Write-Host "Check 4: Prometheus targets (optional)" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$PrometheusUrl/api/v1/targets" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        try {
            $json = $response.Content | ConvertFrom-Json
            
            # Check if pazar job is in targets
            $pazarJobFound = $false
            $pazarJobUp = $false
            
            if ($json.data -and $json.data.activeTargets) {
                foreach ($target in $json.data.activeTargets) {
                    if ($target.labels -and $target.labels.job -and $target.labels.job -match "pazar") {
                        $pazarJobFound = $true
                        if ($target.health -eq "up") {
                            $pazarJobUp = $true
                            break
                        }
                    }
                }
            }
            
            if ($pazarJobUp) {
                Add-CheckResult -CheckName "Prometheus targets" -Status "PASS" -Notes "Pazar job found and UP" -Blocking $false
            } elseif ($pazarJobFound) {
                Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Pazar job found but not UP" -Blocking $false
            } else {
                Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Pazar job not found in targets" -Blocking $false
            }
        } catch {
            Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Prometheus reachable but response is not valid JSON: $($_.Exception.Message)" -Blocking $false
        }
    } else {
        Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Prometheus returned HTTP $($response.StatusCode)" -Blocking $false
    }
} catch {
    Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Prometheus not reachable at $PrometheusUrl (optional check)" -Blocking $false
}

Write-Host ""

# Print results table
Write-Host "=== SMOKE SURFACE GATE RESULTS ===" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table -Property Check, Status, Notes -AutoSize
Write-Host ""

# Overall status
Write-Host "OVERALL STATUS: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
Write-Host ""

# Exit
Invoke-OpsExit $overallExitCode

