# observability_status.ps1 - Observability Status Check
# Validates observability stack health (Pazar metrics, H-OS health, Prometheus, Alertmanager)
# PowerShell 5.1 compatible, ASCII-only output, safe-exit behavior

param(
    [string]$BaseUrl = $null,
    [string]$HosUrl = $null,
    [string]$PrometheusUrl = $null,
    [string]$AlertmanagerUrl = $null
)

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_env.ps1") {
    . "${scriptDir}\_lib\ops_env.ps1"
    Initialize-OpsEnv
}
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

# Initialize URLs from env vars with defaults (never null/empty)
if ([string]::IsNullOrEmpty($BaseUrl)) {
    $BaseUrl = Get-PazarBaseUrl
}
if ([string]::IsNullOrEmpty($HosUrl)) {
    $HosUrl = Get-HosBaseUrl
}
if ([string]::IsNullOrEmpty($PrometheusUrl)) {
    $PrometheusUrl = Get-PrometheusUrl
}
if ([string]::IsNullOrEmpty($AlertmanagerUrl)) {
    $AlertmanagerUrl = Get-AlertmanagerUrl
}

Write-Host "=== OBSERVABILITY STATUS CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Pazar URL: $BaseUrl" -ForegroundColor Gray
Write-Host "H-OS URL: $HosUrl" -ForegroundColor Gray
Write-Host "Prometheus URL: $PrometheusUrl" -ForegroundColor Gray
Write-Host "Alertmanager URL: $AlertmanagerUrl" -ForegroundColor Gray
Write-Host ""

# Results tracking
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
        [bool]$Blocking = $false
    )
    
    $exitCode = 0
    if ($Status -eq "FAIL") {
        $exitCode = 1
        $script:hasFail = $true
        if ($Blocking) {
            $script:overallStatus = "FAIL"
            $script:overallExitCode = 1
        }
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

# Check A: Pazar /metrics (token-aware if METRICS_TOKEN set; supports header X-Metrics-Token and query token)
Write-Host "Check A: Pazar /metrics endpoint" -ForegroundColor Cyan

try {
    $metricsToken = $env:METRICS_TOKEN
    $metricsHeaders = @{
        "Accept" = "text/plain"
    }
    $metricsUri = "$BaseUrl/api/metrics"
    
    # Add token if available (header X-Metrics-Token or query ?token=)
    if ($metricsToken) {
        $metricsHeaders["X-Metrics-Token"] = $metricsToken
        $metricsUri = "$BaseUrl/api/metrics?token=$metricsToken"
    }
    
    $response = Invoke-WebRequest -Uri $metricsUri -Method GET -Headers $metricsHeaders -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        $body = $response.Content
        if ($body -match "pazar_\w+") {
            Add-CheckResult -CheckName "Pazar /metrics" -Status "PASS" -Notes "HTTP 200, body contains pazar_ metric" -Blocking $true
            Write-Host "  [PASS] Pazar /metrics: HTTP 200, body contains pazar_ metric" -ForegroundColor Green
        } else {
            Add-CheckResult -CheckName "Pazar /metrics" -Status "WARN" -Notes "HTTP 200 but body does not contain pazar_ metric" -Blocking $false
            Write-Host "  [WARN] Pazar /metrics: HTTP 200 but body does not contain pazar_ metric" -ForegroundColor Yellow
        }
    } else {
        Add-CheckResult -CheckName "Pazar /metrics" -Status "FAIL" -Notes "Expected HTTP 200, got $($response.StatusCode)" -Blocking $true
        Write-Host "  [FAIL] Pazar /metrics: Expected HTTP 200, got $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        Add-CheckResult -CheckName "Pazar /metrics" -Status "FAIL" -Notes "HTTP $statusCode - $($_.Exception.Message)" -Blocking $true
        Write-Host "  [FAIL] Pazar /metrics: HTTP $statusCode - $($_.Exception.Message)" -ForegroundColor Red
    } else {
        Add-CheckResult -CheckName "Pazar /metrics" -Status "FAIL" -Notes "Connection error: $($_.Exception.Message)" -Blocking $true
        Write-Host "  [FAIL] Pazar /metrics: Connection error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Check B: H-OS /v1/health
Write-Host "Check B: H-OS /v1/health endpoint" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$HosUrl/v1/health" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        $body = $response.Content | ConvertFrom-Json
        if ($body.ok -eq $true) {
            Add-CheckResult -CheckName "H-OS /v1/health" -Status "PASS" -Notes "HTTP 200, ok:true" -Blocking $true
            Write-Host "  [PASS] H-OS /v1/health: HTTP 200, ok:true" -ForegroundColor Green
        } else {
            Add-CheckResult -CheckName "H-OS /v1/health" -Status "WARN" -Notes "HTTP 200 but ok:false" -Blocking $false
            Write-Host "  [WARN] H-OS /v1/health: HTTP 200 but ok:false" -ForegroundColor Yellow
        }
    } else {
        Add-CheckResult -CheckName "H-OS /v1/health" -Status "FAIL" -Notes "Expected HTTP 200, got $($response.StatusCode)" -Blocking $true
        Write-Host "  [FAIL] H-OS /v1/health: Expected HTTP 200, got $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        Add-CheckResult -CheckName "H-OS /v1/health" -Status "FAIL" -Notes "HTTP $statusCode - $($_.Exception.Message)" -Blocking $true
        Write-Host "  [FAIL] H-OS /v1/health: HTTP $statusCode - $($_.Exception.Message)" -ForegroundColor Red
    } else {
        Add-CheckResult -CheckName "H-OS /v1/health" -Status "FAIL" -Notes "Connection error: $($_.Exception.Message)" -Blocking $true
        Write-Host "  [FAIL] H-OS /v1/health: Connection error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Check C: Prometheus ready + targets (optional: WARN if unreachable)
Write-Host "Check C: Prometheus ready + targets" -ForegroundColor Cyan

try {
    $prometheusReadyResponse = Invoke-WebRequest -Uri "$PrometheusUrl/-/ready" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($prometheusReadyResponse.StatusCode -eq 200) {
        Write-Host "  [OK] Prometheus ready" -ForegroundColor Green
        
        # Check targets
        try {
            $targetsResponse = Invoke-WebRequest -Uri "$PrometheusUrl/api/v1/targets" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            
            if ($targetsResponse.StatusCode -eq 200) {
                $targetsJson = $targetsResponse.Content | ConvertFrom-Json
                $activeTargets = $targetsJson.data.activeTargets | Where-Object { $_.health -eq "up" }
                $totalTargets = $targetsJson.data.activeTargets.Count
                
                Add-CheckResult -CheckName "Prometheus targets" -Status "PASS" -Notes "$($activeTargets.Count)/$totalTargets targets up" -Blocking $false
                Write-Host "  [PASS] Prometheus targets: $($activeTargets.Count)/$totalTargets targets up" -ForegroundColor Green
            } else {
                Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Prometheus ready but targets API returned $($targetsResponse.StatusCode)" -Blocking $false
                Write-Host "  [WARN] Prometheus targets: API returned $($targetsResponse.StatusCode)" -ForegroundColor Yellow
            }
        } catch {
            Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Prometheus ready but targets API unreachable: $($_.Exception.Message)" -Blocking $false
            Write-Host "  [WARN] Prometheus targets: API unreachable: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Add-CheckResult -CheckName "Prometheus ready" -Status "WARN" -Notes "Prometheus /-/ready returned $($prometheusReadyResponse.StatusCode)" -Blocking $false
        Write-Host "  [WARN] Prometheus ready: HTTP $($prometheusReadyResponse.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Add-CheckResult -CheckName "Prometheus ready" -Status "WARN" -Notes "Prometheus unreachable: $($_.Exception.Message)" -Blocking $false
    Write-Host "  [WARN] Prometheus unreachable: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Check D: Alertmanager ready (optional: WARN if unreachable)
Write-Host "Check D: Alertmanager ready" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$AlertmanagerUrl/-/ready" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        Add-CheckResult -CheckName "Alertmanager ready" -Status "PASS" -Notes "HTTP 200" -Blocking $false
        Write-Host "  [PASS] Alertmanager ready: HTTP 200" -ForegroundColor Green
    } else {
        Add-CheckResult -CheckName "Alertmanager ready" -Status "WARN" -Notes "HTTP $($response.StatusCode)" -Blocking $false
        Write-Host "  [WARN] Alertmanager ready: HTTP $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Add-CheckResult -CheckName "Alertmanager ready" -Status "WARN" -Notes "Alertmanager unreachable: $($_.Exception.Message)" -Blocking $false
    Write-Host "  [WARN] Alertmanager unreachable: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Check E: Prometheus rules group "pazar_baseline" present (optional: WARN if Prometheus unreachable)
Write-Host "Check E: Prometheus rules group 'pazar_baseline'" -ForegroundColor Cyan

try {
    $rulesResponse = Invoke-WebRequest -Uri "$PrometheusUrl/api/v1/rules" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($rulesResponse.StatusCode -eq 200) {
        $rulesJson = $rulesResponse.Content | ConvertFrom-Json
        $pazarBaselineGroup = $null
        
        # Search for pazar_baseline group in rules data
        if ($rulesJson.data -and $rulesJson.data.groups) {
            foreach ($group in $rulesJson.data.groups) {
                if ($group.name -eq "pazar_baseline") {
                    $pazarBaselineGroup = $group
                    break
                }
            }
        }
        
        if ($pazarBaselineGroup) {
            Add-CheckResult -CheckName "Prometheus rules 'pazar_baseline'" -Status "PASS" -Notes "Rules group 'pazar_baseline' found" -Blocking $false
            Write-Host "  [PASS] Prometheus rules 'pazar_baseline': Found" -ForegroundColor Green
        } else {
            Add-CheckResult -CheckName "Prometheus rules 'pazar_baseline'" -Status "WARN" -Notes "Rules group 'pazar_baseline' not found" -Blocking $false
            Write-Host "  [WARN] Prometheus rules 'pazar_baseline': Not found" -ForegroundColor Yellow
        }
    } else {
        Add-CheckResult -CheckName "Prometheus rules 'pazar_baseline'" -Status "WARN" -Notes "Prometheus rules API returned $($rulesResponse.StatusCode)" -Blocking $false
        Write-Host "  [WARN] Prometheus rules API: HTTP $($rulesResponse.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Add-CheckResult -CheckName "Prometheus rules 'pazar_baseline'" -Status "WARN" -Notes "Prometheus unreachable: $($_.Exception.Message)" -Blocking $false
    Write-Host "  [WARN] Prometheus rules API unreachable: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "=== OBSERVABILITY STATUS SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

foreach ($result in $results) {
    $color = if ($result.Status -eq "PASS") { "Green" } elseif ($result.Status -eq "WARN") { "Yellow" } else { "Red" }
    Write-Host "[$($result.Status)] $($result.Check): $($result.Notes)" -ForegroundColor $color
}

Write-Host ""

if ($overallStatus -eq "PASS") {
    Write-Host "Overall Status: PASS" -ForegroundColor Green
} elseif ($overallStatus -eq "WARN") {
    Write-Host "Overall Status: WARN" -ForegroundColor Yellow
} else {
    Write-Host "Overall Status: FAIL" -ForegroundColor Red
}

Write-Host "Exit Code: $overallExitCode" -ForegroundColor Gray
Write-Host ""

# Exit with appropriate code
Invoke-OpsExit $overallExitCode
return $overallExitCode



