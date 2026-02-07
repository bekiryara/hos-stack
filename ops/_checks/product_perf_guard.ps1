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
if (Test-Path "$ScriptDir\_lib\worlds_config.ps1") {
    . "$ScriptDir\_lib\worlds_config.ps1"
}

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

# Check 1: Parse enabled worlds from config (Pazar expects marketplace only)
$enabledWorlds = @()
$disabledWorlds = @()
try {
    if (-not (Test-Path $WorldsConfigPath)) {
        Write-Fail "Worlds config not found: $WorldsConfigPath"
        Add-CheckResult -CheckName "Worlds Config" -Status "FAIL" -Notes "Missing config"
        Invoke-OpsExit 1
        return
    }

    if (Get-Command Get-WorldsConfig -ErrorAction SilentlyContinue) {
        $wc = Get-WorldsConfig -WorldsConfigPath $WorldsConfigPath
        $enabledWorlds = $wc.Enabled
        $disabledWorlds = $wc.Disabled
    } else {
        $content = Get-Content $WorldsConfigPath -Raw
        if ($content -match "(?s)'enabled'\s*=>\s*\[(.*?)\]") {
            $matchesEnabled = [regex]::Matches($matches[1], "['""]([a-z0-9_]+)['""]")
            foreach ($m in $matchesEnabled) { $enabledWorlds += $m.Groups[1].Value }
        }
        if ($content -match "(?s)'disabled'\s*=>\s*\[(.*?)\]") {
            $matchesDisabled = [regex]::Matches($matches[1], "['""]([a-z0-9_]+)['""]")
            foreach ($m in $matchesDisabled) { $disabledWorlds += $m.Groups[1].Value }
        }
    }

    $enabledWorlds = @($enabledWorlds | Sort-Object -Unique)
    $disabledWorlds = @($disabledWorlds | Sort-Object -Unique)

    if ($enabledWorlds.Count -ne 1 -or $enabledWorlds[0] -ne "marketplace" -or $disabledWorlds.Count -ne 0) {
        $en = if ($enabledWorlds) { $enabledWorlds -join ", " } else { "<empty>" }
        $di = if ($disabledWorlds) { $disabledWorlds -join ", " } else { "<empty>" }
        Write-Fail "Worlds config drift. Expected enabled=[marketplace], disabled=[]. Got enabled=[$en], disabled=[$di]"
        Add-CheckResult -CheckName "Worlds Config" -Status "FAIL" -Notes "Drift detected"
        Invoke-OpsExit 1
        return
    }

    Write-Pass "Enabled worlds: marketplace"
    Add-CheckResult -CheckName "Worlds Config" -Status "PASS" -Notes "enabled=[marketplace]"
} catch {
    Write-Fail "Error parsing worlds config: $($_.Exception.Message)"
    Add-CheckResult -CheckName "Worlds Config" -Status "FAIL" -Notes "Parse error"
    Invoke-OpsExit 1
    return
}

# Check 2: Credentials are optional for guest read path
if (-not $TestTenantId -or -not $TestAuth) {
    Write-Warn "PRODUCT_TEST_TENANT_ID or PRODUCT_TEST_AUTH missing. Using guest read path (no auth)."
    Add-CheckResult -CheckName "Credentials Check" -Status "WARN" -Notes "Missing credentials; guest mode"
} else {
    Write-Pass "Credentials provided (optional)."
    Add-CheckResult -CheckName "Credentials Check" -Status "PASS" -Notes "Credentials provided"
}

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

# Check 4: Run perf tests (guest read path: GET /api/v1/listings)
$overallPass = $true
foreach ($world in $enabledWorlds) {
    Write-Info "Running perf checks for world: ${world}"
    
    $headers = @{
        "Accept" = "application/json"
    }
    if ($TestAuth) {
        $headers["Authorization"] = if ($TestAuth.StartsWith("Bearer ")) { $TestAuth } else { "Bearer $TestAuth" }
    }
    if ($TestTenantId) {
        # Store-scope reads use X-Active-Tenant-Id (optional for this perf gate)
        $headers["X-Active-Tenant-Id"] = $TestTenantId
    }
    
    $url = "${BaseUrl}/api/v1/listings?limit=${Limit}"
    
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



