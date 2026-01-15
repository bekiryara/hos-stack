# alert_pipeline_proof.ps1 - Verify Alertmanager -> Webhook pipeline end-to-end
# PowerShell 5.1 compatible, ASCII-only output

param(
    [switch]$Ci,
    [int]$TimeoutSeconds = 60
)

# Load shared output helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

$ErrorActionPreference = "Continue"

# Ensure we're in repo root
$repoRoot = Split-Path -Parent $scriptDir
Push-Location $repoRoot
try {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "=== Alert Pipeline Proof ==="
    } else {
        Write-Host "=== Alert Pipeline Proof ===" -ForegroundColor Cyan
    }
    
    # Step 1: Check if observability stack is running
    Write-Host "Checking observability stack..." -ForegroundColor Gray
    $obsComposeFile = "work\hos\docker-compose.yml"
    if (-not (Test-Path $obsComposeFile)) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Warn "Observability compose file not found: $obsComposeFile (SKIP)"
        } else {
            Write-Host "[WARN] Observability compose file not found: $obsComposeFile (SKIP)" -ForegroundColor Yellow
        }
        Invoke-OpsExit 2
        return
    }
    
    # Check if alertmanager is running
    $alertmanagerRunning = docker compose -f $obsComposeFile ps alertmanager 2>&1 | Select-String -Pattern "Up" -Quiet
    if (-not $alertmanagerRunning) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Warn "Alertmanager not running (obs profile may not be started) (SKIP)"
        } else {
            Write-Host "[WARN] Alertmanager not running (obs profile may not be started) (SKIP)" -ForegroundColor Yellow
        }
        Invoke-OpsExit 2
        return
    }
    
    # Step 2: Check Alertmanager ready
    Write-Host "Checking Alertmanager readiness..." -ForegroundColor Gray
    try {
        $alertmanagerReady = curl.exe -sS -f -m 5 http://localhost:9093/-/ready 2>&1
        if ($LASTEXITCODE -ne 0) {
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Fail "Alertmanager not ready (http://localhost:9093/-/ready failed)"
            } else {
                Write-Host "[FAIL] Alertmanager not ready (http://localhost:9093/-/ready failed)" -ForegroundColor Red
            }
            Invoke-OpsExit 1
            return
        }
        Write-Host "  Alertmanager is ready" -ForegroundColor Gray
    } catch {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "Alertmanager readiness check failed: $($_.Exception.Message)"
        } else {
            Write-Host "[FAIL] Alertmanager readiness check failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Invoke-OpsExit 1
        return
    }
    
    # Step 3: Check webhook reachable (via container exec, no port mapping needed)
    Write-Host "Checking webhook reachability..." -ForegroundColor Gray
    try {
        $webhookContainerOutput = docker compose -f $obsComposeFile ps alert-webhook --format "{{.Names}}" 2>&1
        $webhookContainerName = $webhookContainerOutput | Select-String -Pattern "alert-webhook" | ForEach-Object { $_.Line.Trim() }
        if (-not $webhookContainerName -or $webhookContainerName -eq "") {
            # Try alternative: find container by service name pattern
            $webhookContainerName = docker ps --format "{{.Names}}" | Select-String -Pattern "alert-webhook" | ForEach-Object { $_.Line.Trim() }
            if (-not $webhookContainerName) {
                if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                    Write-Fail "alert-webhook container not found"
                } else {
                    Write-Host "[FAIL] alert-webhook container not found" -ForegroundColor Red
                }
                Invoke-OpsExit 1
                return
            }
        }
        $webhookHealth = docker exec $webhookContainerName python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health').read()" 2>&1
        if ($LASTEXITCODE -ne 0) {
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Fail "Webhook not reachable (health check failed)"
            } else {
                Write-Host "[FAIL] Webhook not reachable (health check failed)" -ForegroundColor Red
            }
            Invoke-OpsExit 1
            return
        }
        Write-Host "  Webhook is reachable" -ForegroundColor Gray
    } catch {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "Webhook reachability check failed: $($_.Exception.Message)"
        } else {
            Write-Host "[FAIL] Webhook reachability check failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Invoke-OpsExit 1
        return
    }
    
    # Step 4: POST test alert to Alertmanager
    Write-Host "Sending test alert to Alertmanager..." -ForegroundColor Gray
    $now = (Get-Date).ToUniversalTime()
    $endsAt = $now.AddMinutes(10)
    $alertPayload = @(
        @{
            labels = @{
                alertname = "ManualTestCritical"
                severity = "critical"
                service = "pazar"
            }
            annotations = @{
                summary = "E2E pipeline test alert"
            }
            startsAt = $now.ToString("o")
            endsAt = $endsAt.ToString("o")
        }
    ) | ConvertTo-Json -Depth 10 -Compress
    
    try {
        $alertResponse = curl.exe -sS -f -m 10 -X POST http://localhost:9093/api/v2/alerts `
            -H "Content-Type: application/json" `
            -d $alertPayload 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Fail "Failed to POST alert to Alertmanager: $alertResponse"
            } else {
                Write-Host "[FAIL] Failed to POST alert to Alertmanager: $alertResponse" -ForegroundColor Red
            }
            Invoke-OpsExit 1
            return
        }
        Write-Host "  Alert posted successfully" -ForegroundColor Gray
    } catch {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "Alert POST failed: $($_.Exception.Message)"
        } else {
            Write-Host "[FAIL] Alert POST failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Invoke-OpsExit 1
        return
    }
    
    # Step 5: Poll webhook /last endpoint for up to 60 seconds (via container exec)
    Write-Host "Polling webhook /last endpoint (max ${TimeoutSeconds}s)..." -ForegroundColor Gray
    $found = $false
    $startTime = Get-Date
    
    while (-not $found -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        Start-Sleep -Seconds 2
        try {
            $lastResponse = docker exec $webhookContainerName python -c "import urllib.request, json; print(json.dumps(json.loads(urllib.request.urlopen('http://localhost:8080/last').read().decode('utf-8'))))" 2>&1
            if ($LASTEXITCODE -eq 0 -and $lastResponse -match '\{') {
                $lastJson = $lastResponse | ConvertFrom-Json
                if ($lastJson.last -ne $null) {
                    # Check if alertname/severity/service match
                    # Alertmanager sends alerts as an array, so last might be an array or a single object
                    $lastPayload = $lastJson.last
                    
                    # Handle array format (Alertmanager webhook payload is an array)
                    if ($lastPayload -is [Array]) {
                        $matchingAlert = $lastPayload | Where-Object { 
                            $_.labels -and
                            $_.labels.alertname -eq "ManualTestCritical" -and 
                            $_.labels.severity -eq "critical" -and 
                            $_.labels.service -eq "pazar"
                        }
                        if ($matchingAlert) {
                            $found = $true
                            Write-Host "  Alert received in webhook: alertname=ManualTestCritical, severity=critical, service=pazar" -ForegroundColor Gray
                            break
                        }
                    } else {
                        # Single alert object (if webhook stores single alert)
                        if ($lastPayload.PSObject.Properties['labels'] -and 
                            $lastPayload.labels.alertname -eq "ManualTestCritical" -and 
                            $lastPayload.labels.severity -eq "critical" -and 
                            $lastPayload.labels.service -eq "pazar") {
                            $found = $true
                            Write-Host "  Alert received in webhook: alertname=ManualTestCritical, severity=critical, service=pazar" -ForegroundColor Gray
                            break
                        }
                    }
                }
            }
        } catch {
            # Continue polling
        }
    }
    
    # Determine result
    Write-Host ""
    if ($found) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Pass "OVERALL STATUS: PASS (Alert pipeline verified: Alertmanager -> Webhook)"
        } else {
            Write-Host "[PASS] OVERALL STATUS: PASS (Alert pipeline verified: Alertmanager -> Webhook)" -ForegroundColor Green
        }
        Invoke-OpsExit 0
        return
    } else {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "OVERALL STATUS: FAIL (Alert not received in webhook within ${TimeoutSeconds}s)"
        } else {
            Write-Host "[FAIL] OVERALL STATUS: FAIL (Alert not received in webhook within ${TimeoutSeconds}s)" -ForegroundColor Red
        }
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  - Check Alertmanager logs: docker compose -f work/hos/docker-compose.yml logs alertmanager" -ForegroundColor Gray
        Write-Host "  - Check webhook logs: docker compose -f work/hos/docker-compose.yml logs alert-webhook" -ForegroundColor Gray
        Write-Host "  - Check webhook /last manually: docker exec $webhookContainerName python -c \"import urllib.request; print(urllib.request.urlopen('http://localhost:8080/last').read().decode('utf-8'))\"" -ForegroundColor Gray
        Invoke-OpsExit 1
        return
    }
} finally {
    Pop-Location
}

