#!/usr/bin/env pwsh
# READ LATENCY P95 CHECK (WP-24)
# Measures P95 latency for read-only endpoints (WARN only, does not fail).

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== READ LATENCY P95 CHECK (WP-24) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$repoRoot = Split-Path -Parent $scriptDir
$pazarBaseUrl = "http://localhost:8080"

# P95 latency threshold (milliseconds) - WARN if exceeded
$p95ThresholdMs = 500  # 500ms P95 threshold (adjust as needed)

# Read snapshot files
$accountPortalSnapshot = Join-Path $repoRoot "contracts\api\account_portal.read.snapshot.json"
$marketplaceSnapshot = Join-Path $repoRoot "contracts\api\marketplace.read.snapshot.json"

# Load snapshots
$readEndpoints = @()
if (Test-Path $accountPortalSnapshot) {
    try {
        $accountPortalSnap = Get-Content $accountPortalSnapshot -Raw | ConvertFrom-Json
        $readEndpoints += $accountPortalSnap
    } catch {
        Write-Host "WARN: Error loading account portal snapshot: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (Test-Path $marketplaceSnapshot) {
    try {
        $marketplaceSnap = Get-Content $marketplaceSnapshot -Raw | ConvertFrom-Json
        $readEndpoints += $marketplaceSnap
    } catch {
        Write-Host "WARN: Error loading marketplace snapshot: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($readEndpoints.Count -eq 0) {
    Write-Host "WARN: No read endpoints found in snapshots" -ForegroundColor Yellow
    Write-Host "=== READ LATENCY P95 CHECK: SKIP ===" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($readEndpoints.Count) read endpoints to test" -ForegroundColor Gray
Write-Host "P95 latency threshold: $p95ThresholdMs ms" -ForegroundColor Gray
Write-Host ""

# Test each read endpoint
$results = @()

foreach ($endpoint in $readEndpoints) {
    $method = $endpoint.method
    $path = $endpoint.path
    
    # Only test GET endpoints
    if ($method -ne "GET") {
        continue
    }
    
    # Build full URL
    $url = "$pazarBaseUrl$path"
    
    # Handle path parameters (replace {id} with dummy values for testing)
    $url = $url -replace '\{id\}', '00000000-0000-0000-0000-000000000000'
    
    Write-Host "Testing: GET $path..." -ForegroundColor Yellow -NoNewline
    
    # Perform multiple requests to calculate P95
    $requestCount = 10
    $latencies = @()
    
    for ($i = 1; $i -le $requestCount; $i++) {
        try {
            $startTime = Get-Date
            $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 5 -ErrorAction Stop -UseBasicParsing
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds
            $latencies += $duration
        } catch {
            # Skip failed requests (endpoint may require auth or specific params)
            continue
        }
    }
    
    if ($latencies.Count -eq 0) {
        Write-Host " SKIP (requests failed or endpoint requires auth/params)" -ForegroundColor Gray
        continue
    }
    
    # Sort latencies and calculate P95
    $sortedLatencies = $latencies | Sort-Object
    $p95Index = [Math]::Ceiling($sortedLatencies.Count * 0.95) - 1
    if ($p95Index -lt 0) { $p95Index = 0 }
    $p95Latency = $sortedLatencies[$p95Index]
    
    # Calculate average latency
    $avgLatency = ($latencies | Measure-Object -Average).Average
    
    $results += [PSCustomObject]@{
        Path = $path
        P95Ms = [Math]::Round($p95Latency, 2)
        AvgMs = [Math]::Round($avgLatency, 2)
        RequestCount = $latencies.Count
    }
    
    # WARN if P95 exceeds threshold
    if ($p95Latency -gt $p95ThresholdMs) {
        Write-Host " WARN (P95: $([Math]::Round($p95Latency, 2)) ms > $p95ThresholdMs ms)" -ForegroundColor Yellow
    } else {
        Write-Host " OK (P95: $([Math]::Round($p95Latency, 2)) ms, Avg: $([Math]::Round($avgLatency, 2)) ms)" -ForegroundColor Green
    }
}

Write-Host ""

# Summary
if ($results.Count -eq 0) {
    Write-Host "=== READ LATENCY P95 CHECK: SKIP ===" -ForegroundColor Yellow
    Write-Host "No endpoints were successfully tested" -ForegroundColor Gray
    exit 0
}

$warnings = $results | Where-Object { $_.P95Ms -gt $p95ThresholdMs }

if ($warnings.Count -gt 0) {
    Write-Host "=== READ LATENCY P95 CHECK: WARN ===" -ForegroundColor Yellow
    Write-Host "P95 latency exceeded threshold ($p95ThresholdMs ms) for $($warnings.Count) endpoint(s):" -ForegroundColor Yellow
    foreach ($warn in $warnings) {
        Write-Host "  - GET $($warn.Path): P95=$($warn.P95Ms) ms, Avg=$($warn.AvgMs) ms" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Note: This is a WARN only. Consider optimizing slow endpoints." -ForegroundColor Gray
    exit 0  # WARN only, does not fail
} else {
    Write-Host "=== READ LATENCY P95 CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All tested endpoints meet P95 latency threshold ($p95ThresholdMs ms)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Gray
    foreach ($result in $results) {
        Write-Host "  - GET $($result.Path): P95=$($result.P95Ms) ms, Avg=$($result.AvgMs) ms ($($result.RequestCount) requests)" -ForegroundColor Gray
    }
    exit 0
}

