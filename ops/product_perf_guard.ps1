# product_perf_guard.ps1 - Product API Performance Guardrail
# Lightweight perf guardrail for listings index endpoint (p95 latency)
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$TestTenantId = $env:PRODUCT_TEST_TENANT_ID,
    [string]$TestAuth = $env:PRODUCT_TEST_AUTH,
    [int]$Iterations = 10,
    [int]$Warmup = 3,
    [int]$Limit = 20,
    [string]$WorldsConfigPath = "work\pazar\config\worlds.php"
)

# Dot-source shared helpers
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\_lib\ops_output.ps1"
. "$ScriptDir\_lib\ops_exit.ps1"

# Result tracking
$checkResults = @()

function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$Notes = ""
    )
    $script:checkResults += @{
        CheckName = $CheckName
        Status = $Status
        Notes = $Notes
    }
}

Write-Info "Product API Performance Guardrail"
Write-Info "Base URL: ${BaseUrl}"
Write-Info "Iterations: ${Iterations} (warmup: ${Warmup}, measured: $($Iterations - $Warmup))"
Write-Info ""

# Check 1: Parse enabled worlds from config
$enabledWorlds = @()
if (Test-Path $WorldsConfigPath) {
    $content = Get-Content $WorldsConfigPath -Raw
    if ($content -match "'enabled'\s*=>\s*\[(.*?)\]") {
        $enabledStr = $matches[1]
        if ($enabledStr -match "'commerce'") { $enabledWorlds += "commerce" }
        if ($enabledStr -match "'food'") { $enabledWorlds += "food" }
        if ($enabledStr -match "'rentals'") { $enabledWorlds += "rentals" }
    }
}

if ($enabledWorlds.Count -eq 0) {
    Write-Warn "No enabled worlds found in config. Using defaults: commerce, food, rentals"
    $enabledWorlds = @("commerce", "food", "rentals")
}

Write-Pass "Enabled worlds: $($enabledWorlds -join ', ')"
Add-CheckResult -CheckName "Worlds Config" -Status "PASS" -Notes "Found $($enabledWorlds.Count) enabled world(s)"

# Check 2: Verify credentials
if (-not $TestTenantId -or -not $TestAuth) {
    Write-Warn "PRODUCT_TEST_TENANT_ID or PRODUCT_TEST_AUTH not provided. Skipping perf checks."
    Add-CheckResult -CheckName "Credentials Check" -Status "WARN" -Notes "Skipped (credentials missing)"
    Invoke-OpsExit 2
    return
}
Write-Pass "Credentials provided. Proceeding with perf checks."
Add-CheckResult -CheckName "Credentials Check" -Status "PASS" -Notes "Credentials provided"

# Check 3: Docker reachable (optional check)
try {
    $dockerPs = docker compose ps --format json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($dockerPs) {
        Write-Pass "Docker compose reachable"
        Add-CheckResult -CheckName "Docker Reachable" -Status "PASS" -Notes "Docker compose running"
    } else {
        Write-Warn "Docker compose not reachable (may not be running)"
        Add-CheckResult -CheckName "Docker Reachable" -Status "WARN" -Notes "Docker compose not running"
    }
} catch {
    Write-Warn "Docker compose check failed: $($_.Exception.Message)"
    Add-CheckResult -CheckName "Docker Reachable" -Status "WARN" -Notes "Docker check failed"
}

# Helper: Measure request latency
function Measure-RequestLatency {
    param(
        [string]$Url,
        [hashtable]$Headers
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $Url -Headers $Headers -Method GET -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        $stopwatch.Stop()
        $latencyMs = $stopwatch.ElapsedMilliseconds
        return @{
            Success = $true
            LatencyMs = $latencyMs
            StatusCode = $response.StatusCode
        }
    } catch {
        $stopwatch.Stop()
        return @{
            Success = $false
            LatencyMs = $stopwatch.ElapsedMilliseconds
            Error = $_.Exception.Message
        }
    }
}

# Check 4: Run perf tests for each enabled world
$overallPass = $true
foreach ($world in $enabledWorlds) {
    Write-Info "Running perf checks for world: ${world}"
    
    $headers = @{
        "Authorization" = "Bearer $TestAuth"
        "X-Tenant-Id" = $TestTenantId
        "Accept" = "application/json"
    }
    
    $url = "${BaseUrl}/api/v1/${world}/listings?limit=${Limit}"
    
    # Warmup (not measured)
    for ($i = 1; $i -le $Warmup; $i++) {
        $null = Measure-RequestLatency -Url $url -Headers $headers
        Start-Sleep -Milliseconds 100
    }
    
    # Measured iterations
    $latencies = @()
    for ($i = 1; $i -le $Iterations; $i++) {
        $result = Measure-RequestLatency -Url $url -Headers $headers
        if ($result.Success) {
            $latencies += $result.LatencyMs
        } else {
            Write-Fail "Request failed for ${world} (iteration ${i}): $($result.Error)"
            $overallPass = $false
        }
        Start-Sleep -Milliseconds 100
    }
    
    if ($latencies.Count -eq 0) {
        Write-Fail "No successful requests for ${world}"
        Add-CheckResult -CheckName "Perf: ${world}" -Status "FAIL" -Notes "No successful requests"
        $overallPass = $false
        continue
    }
    
    # Calculate p95
    $sorted = $latencies | Sort-Object
    $p95Index = [Math]::Floor($sorted.Count * 0.95)
    if ($p95Index -ge $sorted.Count) { $p95Index = $sorted.Count - 1 }
    $p95 = $sorted[$p95Index]
    $avg = ($latencies | Measure-Object -Average).Average
    $min = ($latencies | Measure-Object -Minimum).Minimum
    $max = ($latencies | Measure-Object -Maximum).Maximum
    
    # Thresholds: WARN if p95 > 400ms, FAIL if p95 > 1000ms
    $status = "PASS"
    $notes = "p95: ${p95}ms (avg: $([Math]::Round($avg, 1))ms, min: ${min}ms, max: ${max}ms)"
    if ($p95 -gt 1000) {
        $status = "FAIL"
        $notes += " (p95 > 1000ms threshold)"
        $overallPass = $false
    } elseif ($p95 -gt 400) {
        $status = "WARN"
        $notes += " (p95 > 400ms threshold)"
    }
    
    if ($status -eq "PASS") {
        Write-Pass "Perf check for ${world}: ${status} - ${notes}"
    } elseif ($status -eq "WARN") {
        Write-Warn "Perf check for ${world}: ${status} - ${notes}"
    } else {
        Write-Fail "Perf check for ${world}: ${status} - ${notes}"
    }
    
    Add-CheckResult -CheckName "Perf: ${world}" -Status $status -Notes $notes
}

# Summary
Write-Info ""
Write-Info "=== Summary ==="
$passCount = ($checkResults | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($checkResults | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($checkResults | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Info "PASS: ${passCount}, WARN: ${warnCount}, FAIL: ${failCount}"

if ($failCount -gt 0) {
    Write-Info ""
    Write-Fail "Performance guardrail FAILED (${failCount} failure(s))"
    Invoke-OpsExit 1
    return
}

if ($warnCount -gt 0) {
    Write-Info ""
    Write-Warn "Performance guardrail passed with warnings (${warnCount} warning(s))"
    Invoke-OpsExit 2
    return
}

Write-Info ""
Write-Pass "Performance guardrail PASSED"
Invoke-OpsExit 0



