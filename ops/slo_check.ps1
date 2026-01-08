#!/usr/bin/env pwsh
# SLO Check Script
# Lightweight benchmark to validate SLOs for H-OS and Pazar

param(
    [int]$N = 30,  # Number of requests per endpoint
    [int]$Concurrency = 1  # Sequential requests (v1: always 1)
)

$ErrorActionPreference = "Continue"

Write-Host "=== SLO CHECK ===" -ForegroundColor Cyan
Write-Host "Sample size: $N requests per endpoint" -ForegroundColor Gray
Write-Host "Concurrency: $Concurrency (sequential)" -ForegroundColor Gray
Write-Host ""

# SLO Thresholds (from docs/ops/SLO.md)
$sloThresholds = @{
    'pazar' = @{
        'availability_target' = 0.995  # 99.5%
        'p50_target' = 50  # ms
        'p95_target' = 200  # ms
        'error_rate_threshold' = 0.01  # 1%
    }
    'hos' = @{
        'availability_target' = 0.995  # 99.5%
        'p50_target' = 100  # ms
        'p95_target' = 500  # ms
        'error_rate_threshold' = 0.01  # 1%
    }
}

# Helper: Calculate percentile
function Get-Percentile {
    param([double[]]$Values, [int]$Percentile)
    $sorted = $Values | Sort-Object
    $index = [Math]::Floor($sorted.Count * ($Percentile / 100.0))
    if ($index -ge $sorted.Count) { $index = $sorted.Count - 1 }
    return $sorted[$index]
}

# Test endpoint function
function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [bool]$ExpectJson = $false,
        [int]$RequestCount
    )
    
    Write-Host "Testing $Name ($Url)..." -ForegroundColor Yellow
    
    # Warm-up phase (5 requests, not measured)
    $warmUpCount = 5
    Write-Host "  Warm-up phase ($warmUpCount requests)..." -ForegroundColor DarkGray
    for ($i = 1; $i -le $warmUpCount; $i++) {
        try {
            $null = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        } catch {
            # Ignore warm-up errors
        }
    }
    
    $responseTimes = @()
    $successCount = 0
    $errorCount = 0
    
    # Measurement phase
    Write-Host "  Measurement phase ($RequestCount requests)..." -ForegroundColor DarkGray
    for ($i = 1; $i -le $RequestCount; $i++) {
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
                $responseTimes += $responseTime
            } else {
                $errorCount++
            }
        } catch {
            $stopwatch.Stop()
            $errorCount++
        }
        
        # Progress indicator
        if ($i % 10 -eq 0) {
            Write-Host "  Progress: $i/$RequestCount" -ForegroundColor Gray
        }
    }
    
    # Calculate metrics
    $totalRequests = $RequestCount
    $availability = if ($totalRequests -gt 0) { $successCount / $totalRequests } else { 0 }
    $errorRate = if ($totalRequests -gt 0) { $errorCount / $totalRequests } else { 1 }
    
    $p50 = if ($responseTimes.Count -gt 0) { Get-Percentile -Values $responseTimes -Percentile 50 } else { 0 }
    $p95 = if ($responseTimes.Count -gt 0) { Get-Percentile -Values $responseTimes -Percentile 95 } else { 0 }
    
    return @{
        Name = $Name
        Availability = $availability
        ErrorRate = $errorRate
        P50 = $p50
        P95 = $p95
        SuccessCount = $successCount
        ErrorCount = $errorCount
        TotalRequests = $totalRequests
    }
}

# Test Pazar /up
Write-Host "[1] Testing Pazar /up endpoint..." -ForegroundColor Yellow
$pazarResults = Test-Endpoint -Name "Pazar /up" -Url "http://localhost:8080/up" -ExpectJson $false -RequestCount $N

Write-Host ""

# Test H-OS /v1/health
Write-Host "[2] Testing H-OS /v1/health endpoint..." -ForegroundColor Yellow
$hosResults = Test-Endpoint -Name "H-OS /v1/health" -Url "http://localhost:3000/v1/health" -ExpectJson $true -RequestCount $N

Write-Host ""

# Evaluate against SLOs
$results = @()

# Pazar evaluation
$pazarThresholds = $sloThresholds['pazar']
$pazarAvailabilityStatus = if ($pazarResults.Availability -ge $pazarThresholds.availability_target) { "PASS" } elseif ($pazarResults.Availability -ge ($pazarThresholds.availability_target * 0.95)) { "WARN" } else { "FAIL" }
$pazarP50Status = if ($pazarResults.P50 -le $pazarThresholds.p50_target) { "PASS" } elseif ($pazarResults.P50 -le ($pazarThresholds.p50_target * 1.5)) { "WARN" } else { "FAIL" }
$pazarP95Status = if ($pazarResults.P95 -le $pazarThresholds.p95_target) { "PASS" } elseif ($pazarResults.P95 -le ($pazarThresholds.p95_target * 1.5)) { "WARN" } else { "FAIL" }
$pazarErrorRateStatus = if ($pazarResults.ErrorRate -lt $pazarThresholds.error_rate_threshold) { "PASS" } elseif ($pazarResults.ErrorRate -lt ($pazarThresholds.error_rate_threshold * 5)) { "WARN" } else { "FAIL" }

$results += @{
    Service = "Pazar"
    Endpoint = "/up"
    Metric = "Availability"
    Value = "{0:P2}" -f $pazarResults.Availability
    Target = "{0:P2}" -f $pazarThresholds.availability_target
    Status = $pazarAvailabilityStatus
}
$results += @{
    Service = "Pazar"
    Endpoint = "/up"
    Metric = "p50 Latency"
    Value = "{0:F0}ms" -f $pazarResults.P50
    Target = "< $($pazarThresholds.p50_target)ms"
    Status = $pazarP50Status
}
$results += @{
    Service = "Pazar"
    Endpoint = "/up"
    Metric = "p95 Latency"
    Value = "{0:F0}ms" -f $pazarResults.P95
    Target = "< $($pazarThresholds.p95_target)ms"
    Status = $pazarP95Status
}
$results += @{
    Service = "Pazar"
    Endpoint = "/up"
    Metric = "Error Rate"
    Value = "{0:P2}" -f $pazarResults.ErrorRate
    Target = "< {0:P2}" -f $pazarThresholds.error_rate_threshold
    Status = $pazarErrorRateStatus
}

# H-OS evaluation
$hosThresholds = $sloThresholds['hos']
$hosAvailabilityStatus = if ($hosResults.Availability -ge $hosThresholds.availability_target) { "PASS" } elseif ($hosResults.Availability -ge ($hosThresholds.availability_target * 0.95)) { "WARN" } else { "FAIL" }
$hosP50Status = if ($hosResults.P50 -le $hosThresholds.p50_target) { "PASS" } elseif ($hosResults.P50 -le ($hosThresholds.p50_target * 1.5)) { "WARN" } else { "FAIL" }
$hosP95Status = if ($hosResults.P95 -le $hosThresholds.p95_target) { "PASS" } elseif ($hosResults.P95 -le ($hosThresholds.p95_target * 1.5)) { "WARN" } else { "FAIL" }
$hosErrorRateStatus = if ($hosResults.ErrorRate -lt $hosThresholds.error_rate_threshold) { "PASS" } elseif ($hosResults.ErrorRate -lt ($hosThresholds.error_rate_threshold * 5)) { "WARN" } else { "FAIL" }

$results += @{
    Service = "H-OS"
    Endpoint = "/v1/health"
    Metric = "Availability"
    Value = "{0:P2}" -f $hosResults.Availability
    Target = "{0:P2}" -f $hosThresholds.availability_target
    Status = $hosAvailabilityStatus
}
$results += @{
    Service = "H-OS"
    Endpoint = "/v1/health"
    Metric = "p50 Latency"
    Value = "{0:F0}ms" -f $hosResults.P50
    Target = "< $($hosThresholds.p50_target)ms"
    Status = $hosP50Status
}
$results += @{
    Service = "H-OS"
    Endpoint = "/v1/health"
    Metric = "p95 Latency"
    Value = "{0:F0}ms" -f $hosResults.P95
    Target = "< $($hosThresholds.p95_target)ms"
    Status = $hosP95Status
}
$results += @{
    Service = "H-OS"
    Endpoint = "/v1/health"
    Metric = "Error Rate"
    Value = "{0:P2}" -f $hosResults.ErrorRate
    Target = "< {0:P2}" -f $hosThresholds.error_rate_threshold
    Status = $hosErrorRateStatus
}

# Summary Table
Write-Host "=== SLO CHECK SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host ("{0,-12} {1,-15} {2,-15} {3,-15} {4,-15} {5,-10}" -f "Service", "Endpoint", "Metric", "Value", "Target", "Status")
Write-Host ("-" * 90)
foreach ($result in $results) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "Gray" }
    }
    Write-Host ("{0,-12} {1,-15} {2,-15} {3,-15} {4,-15} {5,-10}" -f $result.Service, $result.Endpoint, $result.Metric, $result.Value, $result.Target, $result.Status) -ForegroundColor $color
}

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
    Write-Host "  3. Investigate root cause" -ForegroundColor Gray
    exit 1
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: SLOs approaching limits - monitor closely" -ForegroundColor Gray
    exit 2
} else {
    Write-Host "OVERALL STATUS: PASS (All SLOs met)" -ForegroundColor Green
    exit 0
}

