#!/usr/bin/env pwsh
# PAZAR SPINE CHECK (WP-4.2)
# One-shot script that runs all Marketplace spine contract checks in order.
# Fails fast if any check returns non-zero. Never reports PASS when any script fails.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== PAZAR SPINE CHECK (WP-4.2) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host "Running all Marketplace spine contract checks in order:" -ForegroundColor Yellow
Write-Host "  1. World Status Check (WP-1.2)" -ForegroundColor Gray
Write-Host "  2. Catalog Contract Check (WP-2)" -ForegroundColor Gray
Write-Host "  3. Listing Contract Check (WP-3)" -ForegroundColor Gray
Write-Host "  4. Reservation Contract Check (WP-4)" -ForegroundColor Gray
Write-Host "  5. Rental Contract Check (WP-7)" -ForegroundColor Gray
Write-Host ""

$checks = @(
    @{ Name = "World Status Check"; Script = "world_status_check.ps1"; WP = "WP-1.2" },
    @{ Name = "Catalog Contract Check"; Script = "catalog_contract_check.ps1"; WP = "WP-2" },
    @{ Name = "Listing Contract Check"; Script = "listing_contract_check.ps1"; WP = "WP-3" },
    @{ Name = "Reservation Contract Check"; Script = "reservation_contract_check.ps1"; WP = "WP-4" },
    @{ Name = "Rental Contract Check"; Script = "rental_contract_check.ps1"; WP = "WP-7" }
)

$results = @()
$hasFailures = $false

foreach ($check in $checks) {
    $scriptPath = Join-Path $scriptDir $check.Script
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "[FAIL] $($check.Name) ($($check.WP)): Script not found: $scriptPath" -ForegroundColor Red
        $results += @{ Name = $check.Name; WP = $check.WP; Status = "FAIL"; Reason = "Script not found" }
        $hasFailures = $true
        # Fail fast: stop on first failure
        break
    }
    
    Write-Host "[RUN] $($check.Name) ($($check.WP))..." -ForegroundColor Yellow
    $startTime = Get-Date
    
    try {
        # Run script as child PowerShell process to capture real exit code
        # Use -NoProfile -NonInteractive -ExecutionPolicy Bypass to ensure clean execution
        # Set CI=true to force hard exit (not just LASTEXITCODE) for proper exit code propagation
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "powershell.exe"
        $processInfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        # Force CI mode so Invoke-OpsExit uses hard exit (not just LASTEXITCODE)
        $processInfo.EnvironmentVariables["CI"] = "true"
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        
        # Capture output (we need to check for "FAIL" in output as well)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        $duration = (Get-Date) - $startTime
        
        # Print script output
        if ($stdout) {
            Write-Host $stdout
        }
        if ($stderr) {
            Write-Host $stderr -ForegroundColor Yellow
        }
        
        # Check both exit code AND output for "FAIL" pattern
        # Scripts may print "=== ... CHECK: FAIL ===" even if exit code is 0 (due to ops_exit.ps1 behavior)
        $outputText = $stdout + $stderr
        $hasFailInOutput = ($outputText -match "=== .* CHECK: FAIL ===") -or ($outputText -match "=== .* CONTRACT CHECK: FAIL ===")
        $hasPassInOutput = ($outputText -match "=== .* CHECK: PASS ===") -or ($outputText -match "=== .* CONTRACT CHECK: PASS ===")
        
        # Determine actual status: FAIL if exit code != 0 OR output contains "FAIL" pattern
        $actualStatus = if (($exitCode -eq 0) -and (-not $hasFailInOutput) -and ($hasPassInOutput -or $exitCode -eq 0)) {
            "PASS"
        } else {
            "FAIL"
        }
        
        if ($actualStatus -eq "PASS") {
            Write-Host "[PASS] $($check.Name) ($($check.WP)) - Duration: $($duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
            $results += @{ Name = $check.Name; WP = $check.WP; Status = "PASS"; Duration = $duration.TotalSeconds }
        } else {
            Write-Host "[FAIL] $($check.Name) ($($check.WP)) - Exit code: $exitCode" -ForegroundColor Red
            if ($hasFailInOutput) {
                Write-Host "  Script output indicates FAIL status" -ForegroundColor Yellow
            }
            $results += @{ Name = $check.Name; WP = $check.WP; Status = "FAIL"; ExitCode = $exitCode; HasFailInOutput = $hasFailInOutput }
            $hasFailures = $true
            # Fail fast: stop on first failure
            break
        }
    } catch {
        $duration = (Get-Date) - $startTime
        Write-Host "[FAIL] $($check.Name) ($($check.WP)) - Exception: $($_.Exception.Message)" -ForegroundColor Red
        $results += @{ Name = $check.Name; WP = $check.WP; Status = "FAIL"; Reason = $_.Exception.Message }
        $hasFailures = $true
        # Fail fast: stop on first failure
        break
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== PAZAR SPINE CHECK SUMMARY ===" -ForegroundColor Cyan
foreach ($result in $results) {
    $statusColor = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
    $durationText = if ($result.Duration) { " ($($result.Duration.ToString('F2'))s)" } else { "" }
    Write-Host "  $($result.Status): $($result.Name) ($($result.WP))$durationText" -ForegroundColor $statusColor
}

if ($hasFailures) {
    Write-Host ""
    Write-Host "=== PAZAR SPINE CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "One or more checks failed. Fix issues and re-run." -ForegroundColor Yellow
    # Always use hard exit (not Invoke-OpsExit) to ensure exit code propagation
    # This script is meant to be run in CI or as a gate, not interactively
    exit 1
} else {
    Write-Host ""
    Write-Host "=== PAZAR SPINE CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All Marketplace spine contract checks passed." -ForegroundColor Gray
    # Always use hard exit (not Invoke-OpsExit) to ensure exit code propagation
    exit 0
}

