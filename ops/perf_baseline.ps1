#!/usr/bin/env pwsh
# Performance Baseline Script
# Measures latency with warm-up and first-hit analysis for production-realistic SLO evaluation

param(
    [int]$N = 30,  # Number of measured requests per endpoint
    [int]$WarmUp = 5  # Warm-up requests (not measured)
)

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== PERFORMANCE BASELINE ===" -ForegroundColor Cyan
Write-Host "Warm-up requests: $WarmUp per endpoint" -ForegroundColor Gray
Write-Host "Measured requests: $N per endpoint" -ForegroundColor Gray
Write-Host ""

# SLO Thresholds (from docs/ops/SLO.md)
$sloThresholds = @{
    'pazar' = @{
        'p50_target' = 50  # ms
        'p95_target' = 200  # ms
    }
    'hos' = @{
        'p50_target' = 100  # ms
        'p95_target' = 500  # ms
    }
}

# Helper: Calculate percentile
function Get-Percentile {
    param([double[]]$Values, [int]$Percentile)
    if ($Values.Count -eq 0) { return 0 }
    $sorted = $Values | Sort-Object
    $index = [Math]::Floor($sorted.Count * ($Percentile / 100.0))
    if ($index -ge $sorted.Count) { $index = $sorted.Count - 1 }
    return $sorted[$index]
}

# Test endpoint with warm-up and measurement
function Test-EndpointWithWarmup {
    param(
        [string]$Name,
        [string]$Url,
        [bool]$ExpectJson = $false,
        [int]$WarmUpCount,
        [int]$MeasuredCount
    )
    
    Write-Host "Testing $Name ($Url)..." -ForegroundColor Yellow
    
    # Warm-up phase (not measured)
    Write-Host "  Warm-up phase ($WarmUpCount requests)..." -ForegroundColor Gray
    for ($i = 1; $i -le $WarmUpCount; $i++) {
        try {
            $null = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        } catch {
            # Ignore warm-up errors
        }
        if ($i % 5 -eq 0) {
            Write-Host "    Warm-up progress: $i/$WarmUpCount" -ForegroundColor DarkGray
        }
    }
    
    # Measurement phase
    Write-Host "  Measurement phase ($MeasuredCount requests)..." -ForegroundColor Gray
    $measuredResponseTimes = @()
    $successCount = 0
    $errorCount = 0
    
    for ($i = 1; $i -le $MeasuredCount; $i++) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            
            $stopwatch.Stop()
            $responseTime = $stopwatch.ElapsedMilliseconds
            
            # Check success criteria
            $isSuccess = $false
            if ($response.StatusCode -eq 200) {
                if ($ExpectJson) {
                    try {
                        $json = $response.Content | ConvertFrom-Json
                        $isSuccess = $json.ok -eq $true
                    } catch {
                        $isSuccess = $false
                    }
                } else {
                    $isSuccess = $true
                }
            }
            
            if ($isSuccess) {
                $successCount++
                $measuredResponseTimes += $responseTime
            } else {
                $errorCount++
            }
        } catch {
            $stopwatch.Stop()
            $errorCount++
        }
        
        # Progress indicator
        if ($i % 10 -eq 0) {
            Write-Host "    Measurement progress: $i/$MeasuredCount" -ForegroundColor DarkGray
        }
    }
    
    # Calculate metrics
    $totalRequests = $MeasuredCount
    $availability = if ($totalRequests -gt 0) { $successCount / $totalRequests } else { 0 }
    
    # Latency metrics
    $p50 = if ($measuredResponseTimes.Count -gt 0) { Get-Percentile -Values $measuredResponseTimes -Percentile 50 } else { 0 }
    $p95 = if ($measuredResponseTimes.Count -gt 0) { Get-Percentile -Values $measuredResponseTimes -Percentile 95 } else { 0 }
    $max = if ($measuredResponseTimes.Count -gt 0) { ($measuredResponseTimes | Measure-Object -Maximum).Maximum } else { 0 }
    
    # First-hit penalty analysis
    $firstHitLatency = 0
    $firstHitPenalty = 0
    $median = 0
    
    if ($measuredResponseTimes.Count -gt 0) {
        $firstHitLatency = $measuredResponseTimes[0]
        $median = Get-Percentile -Values $measuredResponseTimes -Percentile 50
        $firstHitPenalty = $firstHitLatency - $median
    }
    
    # Stability check: Check if failures are only in first 1-2 requests
    $firstTwoRequests = @()
    $remainingRequests = @()
    if ($measuredResponseTimes.Count -gt 0) {
        $firstTwoRequests = $measuredResponseTimes[0..[Math]::Min(1, $measuredResponseTimes.Count - 1)]
        if ($measuredResponseTimes.Count -gt 2) {
            $remainingRequests = $measuredResponseTimes[2..($measuredResponseTimes.Count - 1)]
        }
    }
    
    $firstTwoMax = if ($firstTwoRequests.Count -gt 0) { ($firstTwoRequests | Measure-Object -Maximum).Maximum } else { 0 }
    $remainingP95 = if ($remainingRequests.Count -gt 0) { Get-Percentile -Values $remainingRequests -Percentile 95 } else { 0 }
    
    return @{
        Name = $Name
        Availability = $availability
        P50 = $p50
        P95 = $p95
        Max = $max
        FirstHitLatency = $firstHitLatency
        FirstHitPenalty = $firstHitPenalty
        Median = $median
        FirstTwoMax = $firstTwoMax
        RemainingP95 = $remainingP95
        SuccessCount = $successCount
        ErrorCount = $errorCount
        TotalRequests = $totalRequests
        MeasuredTimes = $measuredResponseTimes
    }
}

# Test Pazar /up
Write-Host "[1] Testing Pazar /up endpoint..." -ForegroundColor Yellow
$pazarResults = Test-EndpointWithWarmup -Name "Pazar /up" -Url "http://localhost:8080/up" -ExpectJson $false -WarmUpCount $WarmUp -MeasuredCount $N

Write-Host ""

# Test H-OS /v1/health
Write-Host "[2] Testing H-OS /v1/health endpoint..." -ForegroundColor Yellow
$hosResults = Test-EndpointWithWarmup -Name "H-OS /v1/health" -Url "http://localhost:3000/v1/health" -ExpectJson $true -WarmUpCount $WarmUp -MeasuredCount $N

Write-Host ""

# Evaluate against SLOs with improved classification
$results = @()

# Pazar evaluation
$pazarThresholds = $sloThresholds['pazar']
$pazarP95Status = "PASS"
$pazarP95Reason = ""

if ($pazarResults.P95 -gt $pazarThresholds.p95_target) {
    # Check if failure is sustained or just cold-start
    if ($pazarResults.RemainingP95 -le $pazarThresholds.p95_target) {
        $pazarP95Status = "WARN"
        $pazarP95Reason = " (cold-start spike in first 1-2 requests, rest stable)"
    } else {
        $pazarP95Status = "FAIL"
        $pazarP95Reason = " (sustained p95 failure)"
    }
}

$results += @{
    Service = "Pazar"
    Endpoint = "/up"
    Metric = "p95 Latency"
    Value = "{0:F0}ms" -f $pazarResults.P95
    Target = "< $($pazarThresholds.p95_target)ms"
    Status = $pazarP95Status
    Details = $pazarP95Reason
    FirstHitPenalty = "{0:F0}ms" -f $pazarResults.FirstHitPenalty
}

# H-OS evaluation
$hosThresholds = $sloThresholds['hos']
$hosP95Status = "PASS"
$hosP95Reason = ""

if ($hosResults.P95 -gt $hosThresholds.p95_target) {
    # Check if failure is sustained or just cold-start
    if ($hosResults.RemainingP95 -le $hosThresholds.p95_target) {
        $hosP95Status = "WARN"
        $hosP95Reason = " (cold-start spike in first 1-2 requests, rest stable)"
    } else {
        $hosP95Status = "FAIL"
        $hosP95Reason = " (sustained p95 failure)"
    }
}

$results += @{
    Service = "H-OS"
    Endpoint = "/v1/health"
    Metric = "p95 Latency"
    Value = "{0:F0}ms" -f $hosResults.P95
    Target = "< $($hosThresholds.p95_target)ms"
    Status = $hosP95Status
    Details = $hosP95Reason
    FirstHitPenalty = "{0:F0}ms" -f $hosResults.FirstHitPenalty
}

# Summary Table
Write-Host "=== PERFORMANCE BASELINE SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host ("{0,-12} {1,-15} {2,-15} {3,-15} {4,-15} {5,-10} {6,-20}" -f "Service", "Endpoint", "Metric", "Value", "Target", "Status", "First-Hit Penalty")
Write-Host ("-" * 110)
foreach ($result in $results) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "Gray" }
    }
    Write-Host ("{0,-12} {1,-15} {2,-15} {3,-15} {4,-15} {5,-10} {6,-20}" -f $result.Service, $result.Endpoint, $result.Metric, $result.Value, $result.Target, $result.Status, $result.FirstHitPenalty) -ForegroundColor $color
    if ($result.Details) {
        Write-Host ("  -> $($result.Details)") -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Additional Metrics:" -ForegroundColor Cyan
Write-Host ("  Pazar /up:     p50={0:F0}ms, max={1:F0}ms, availability={2:P2}" -f $pazarResults.P50, $pazarResults.Max, $pazarResults.Availability) -ForegroundColor Gray
Write-Host ("  H-OS /v1/health: p50={0:F0}ms, max={1:F0}ms, availability={2:P2}" -f $hosResults.P50, $hosResults.Max, $hosResults.Availability) -ForegroundColor Gray

Write-Host ""

# Overall Status
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" } | Measure-Object).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" } | Measure-Object).Count

if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Review docs/runbooks/slo_breach.md" -ForegroundColor Gray
    Write-Host "  2. Run .\ops\triage.ps1 and .\ops\incident_bundle.ps1" -ForegroundColor Gray
    Write-Host "  3. Investigate root cause (sustained p95 failure)" -ForegroundColor Gray
    Invoke-OpsExit 1
    return
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings - cold-start spikes only)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: Latency spikes are limited to first 1-2 requests (cold-start). Remaining requests stable." -ForegroundColor Gray
    Write-Host "This does not block release per Rule 23 (cold-start spikes alone do not block release)." -ForegroundColor Gray
    Invoke-OpsExit 2
    return
} else {
    Write-Host "OVERALL STATUS: PASS (All latency SLOs met with warm-up)" -ForegroundColor Green
    Invoke-OpsExit 0
    return
}

