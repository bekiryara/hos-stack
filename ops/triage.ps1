#!/usr/bin/env pwsh
# Incident Triage Script
# Quick health check for all services

param(
    [string]$RequestId = ""
)

$ErrorActionPreference = "Continue"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== INCIDENT TRIAGE ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()

# 1. Docker Compose Services Status
Write-Host "[1] Checking Docker Compose services..." -ForegroundColor Yellow
$composeStatus = docker compose ps --format json 2>&1 | ConvertFrom-Json
$allUp = $true

foreach ($service in $composeStatus) {
    $isUp = $service.State -eq "running" -or $service.State -eq "Up"
    $allUp = $allUp -and $isUp
    $status = if ($isUp) { "PASS" } else { "FAIL" }
    $results += @{
        Check = "Service: $($service.Service)"
        Status = $status
        Details = "$($service.State) - $($service.Name)"
    }
}

if ($allUp) {
    $results += @{
        Check = "Docker Compose Services"
        Status = "PASS"
        Details = "All services running"
    }
} else {
    $results += @{
        Check = "Docker Compose Services"
        Status = "FAIL"
        Details = "One or more services not running"
    }
}

Write-Host ""

# 2. H-OS Health Check
Write-Host "[2] Checking H-OS health endpoint..." -ForegroundColor Yellow
try {
    $hosResponse = Invoke-WebRequest -Uri "http://localhost:3000/v1/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($hosResponse.StatusCode -eq 200) {
        $hosBody = $hosResponse.Content | ConvertFrom-Json
        $hosOk = $hosBody.ok -eq $true
        $results += @{
            Check = "H-OS Health (/v1/health)"
            Status = if ($hosOk) { "PASS" } else { "FAIL" }
            Details = "HTTP $($hosResponse.StatusCode) - ok: $($hosBody.ok)"
        }
    } else {
        $results += @{
            Check = "H-OS Health (/v1/health)"
            Status = "FAIL"
            Details = "HTTP $($hosResponse.StatusCode)"
        }
    }
} catch {
    $results += @{
        Check = "H-OS Health (/v1/health)"
        Status = "FAIL"
        Details = "Error: $($_.Exception.Message)"
    }
}

Write-Host ""

# 3. Pazar Up Check
Write-Host "[3] Checking Pazar up endpoint..." -ForegroundColor Yellow
try {
    $pazarResponse = Invoke-WebRequest -Uri "http://localhost:8080/up" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($pazarResponse.StatusCode -eq 200) {
        $results += @{
            Check = "Pazar Up (/up)"
            Status = "PASS"
            Details = "HTTP $($pazarResponse.StatusCode)"
        }
    } else {
        $results += @{
            Check = "Pazar Up (/up)"
            Status = "FAIL"
            Details = "HTTP $($pazarResponse.StatusCode)"
        }
    }
} catch {
    $results += @{
        Check = "Pazar Up (/up)"
        Status = "FAIL"
        Details = "Error: $($_.Exception.Message)"
    }
}

Write-Host ""

# 4. Recent Logs Summary
Write-Host "[4] Fetching recent logs..." -ForegroundColor Yellow

Write-Host "`n--- Pazar App Logs (last 120 lines) ---" -ForegroundColor Cyan
$pazarLogs = docker compose logs --tail 120 pazar-app 2>&1
$pazarLogs | Select-Object -Last 50 | Write-Host -ForegroundColor Gray

Write-Host "`n--- H-OS API Logs (last 120 lines) ---" -ForegroundColor Cyan
$hosLogs = docker compose logs --tail 120 hos-api 2>&1
$hosLogs | Select-Object -Last 50 | Write-Host -ForegroundColor Gray

# Check for errors in recent logs
$pazarErrors = $pazarLogs | Select-String -Pattern "error|ERROR|Error|exception|Exception|EXCEPTION|fatal|FATAL" -CaseSensitive:$false
$hosErrors = $hosLogs | Select-String -Pattern "error|ERROR|Error|exception|Exception|EXCEPTION|fatal|FATAL" -CaseSensitive:$false

if ($pazarErrors) {
    $errorCount = ($pazarErrors | Measure-Object).Count
    $results += @{
        Check = "Pazar App Logs (Errors)"
        Status = "WARN"
        Details = "$errorCount error/exception entries in last 120 lines"
    }
} else {
    $results += @{
        Check = "Pazar App Logs (Errors)"
        Status = "PASS"
        Details = "No errors in last 120 lines"
    }
}

if ($hosErrors) {
    $errorCount = ($hosErrors | Measure-Object).Count
    $results += @{
        Check = "H-OS API Logs (Errors)"
        Status = "WARN"
        Details = "$errorCount error/exception entries in last 120 lines"
    }
} else {
    $results += @{
        Check = "H-OS API Logs (Errors)"
        Status = "PASS"
        Details = "No errors in last 120 lines"
    }
}

Write-Host ""

# Summary Table
Write-Host "=== TRIAGE SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host ("{0,-40} {1,-10} {2}" -f "Check", "Status", "Details")
Write-Host ("-" * 80)
foreach ($result in $results) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "Gray" }
    }
    Write-Host ("{0,-40} {1,-10} {2}" -f $result.Check, $result.Status, $result.Details) -ForegroundColor $color
}

Write-Host ""

# Overall Status
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" } | Measure-Object).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" } | Measure-Object).Count

if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    $overallExitCode = 1
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    $overallExitCode = 0
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    $overallExitCode = 0
}

# If RequestId provided, run request trace
if (-not [string]::IsNullOrEmpty($RequestId)) {
    Write-Host ""
    Write-Host "=== REQUEST TRACE (Request ID: $RequestId) ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        & .\ops\request_trace.ps1 -RequestId $RequestId -Tail 2000 -Context 2
        $traceExitCode = $LASTEXITCODE
    } catch {
        Write-Host "WARN: Could not run request trace: $($_.Exception.Message)" -ForegroundColor Yellow
        $traceExitCode = 2
    }
    
    # Use the worst exit code
    if ($traceExitCode -gt $overallExitCode) {
        $overallExitCode = $traceExitCode
    }
}

Invoke-OpsExit $overallExitCode
return
