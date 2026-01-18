#!/usr/bin/env pwsh
# FINAL SANITY RUNNER (WP-NEXT)
# Canonical runner for release-grade checks with evidence logging.

param(
    [switch]$NoPause,
    [switch]$SkipFrontend = $true
)

$ErrorActionPreference = "Stop"

# Get repo root (parent of ops/)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

Write-Host "=== FINAL SANITY RUNNER (WP-NEXT) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Repo Root: $repoRoot" -ForegroundColor Gray
Write-Host ""

# Create evidence folder
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$evidenceDir = Join-Path $repoRoot "docs\PROOFS\_runs\final-sanity-$timestamp"
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
Write-Host "Evidence folder: $evidenceDir" -ForegroundColor Gray
Write-Host ""

$results = @()
$hasFailures = $false

# Helper: Run script and capture output to evidence file
function Run-Check {
    param(
        [string]$Name,
        [string]$ScriptName,
        [string]$EvidenceFileName
    )
    
    $scriptPath = Join-Path $scriptDir $ScriptName
    $evidencePath = Join-Path $evidenceDir $EvidenceFileName
    
    Write-Host "[RUN] $Name..." -ForegroundColor Yellow
    
    if (-not (Test-Path $scriptPath)) {
        $msg = "Script not found: $scriptPath"
        Write-Host "FAIL: $msg" -ForegroundColor Red
        $msg | Out-File -FilePath $evidencePath -Encoding ASCII
        $results += @{ Name = $Name; Status = "FAIL"; Reason = "Script not found" }
        return $false
    }
    
    $startTime = Get-Date
    
    try {
        # Run script as child process and capture all output
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "powershell.exe"
        $processInfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        $processInfo.EnvironmentVariables["CI"] = "true"
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        $duration = (Get-Date) - $startTime
        
        # Write captured output to evidence file
        $output = @"
=== $Name ===
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Exit Code: $exitCode
Duration: $($duration.TotalSeconds.ToString('F2'))s

--- STDOUT ---
$stdout

--- STDERR ---
$stderr
"@
        $output | Out-File -FilePath $evidencePath -Encoding ASCII
        
        # Display script output
        if ($stdout) {
            Write-Host $stdout
        }
        if ($stderr) {
            Write-Host $stderr -ForegroundColor Yellow
        }
        
        # Check for FAIL pattern in output
        $outputText = $stdout + $stderr
        $hasFailInOutput = ($outputText -match "=== .* CHECK: FAIL ===") -or ($outputText -match "=== .* CONTRACT CHECK: FAIL ===")
        $hasPassInOutput = ($outputText -match "=== .* CHECK: PASS ===") -or ($outputText -match "=== .* CONTRACT CHECK: PASS ===")
        
        # Determine status
        $status = if (($exitCode -eq 0) -and (-not $hasFailInOutput) -and ($hasPassInOutput -or $exitCode -eq 0)) {
            "PASS"
        } else {
            "FAIL"
        }
        
        if ($status -eq "PASS") {
            Write-Host "[PASS] $Name - Duration: $($duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
            Write-Host "  Evidence: $evidenceFileName" -ForegroundColor Gray
            $results += @{ Name = $Name; Status = "PASS"; Duration = $duration.TotalSeconds; Evidence = $evidenceFileName }
            return $true
        } else {
            Write-Host "[FAIL] $Name - Exit code: $exitCode" -ForegroundColor Red
            if ($hasFailInOutput) {
                Write-Host "  Script output indicates FAIL status" -ForegroundColor Yellow
            }
            Write-Host "  Evidence: $evidenceFileName" -ForegroundColor Gray
            $results += @{ Name = $Name; Status = "FAIL"; ExitCode = $exitCode; HasFailInOutput = $hasFailInOutput; Evidence = $evidenceFileName }
            return $false
        }
    } catch {
        $msg = "Exception: $($_.Exception.Message)"
        Write-Host "FAIL: $msg" -ForegroundColor Red
        $msg | Out-File -FilePath $evidencePath -Encoding ASCII
        $results += @{ Name = $Name; Status = "FAIL"; Reason = $_.Exception.Message; Evidence = $EvidenceFileName }
        return $false
    }
}

# Step 1: World Status Check
$success = Run-Check -Name "World Status Check" -ScriptName "world_status_check.ps1" -EvidenceFileName "world_status_check.txt"
if (-not $success) { $hasFailures = $true }
Write-Host ""

# Step 2: Pazar Spine Check
$success = Run-Check -Name "Pazar Spine Check" -ScriptName "pazar_spine_check.ps1" -EvidenceFileName "pazar_spine_check.txt"
if (-not $success) { $hasFailures = $true }
Write-Host ""

# Step 3: Read Snapshot Check (if exists)
$readSnapshotPath = Join-Path $scriptDir "read_snapshot_check.ps1"
if (Test-Path $readSnapshotPath) {
    $success = Run-Check -Name "Read Snapshot Check" -ScriptName "read_snapshot_check.ps1" -EvidenceFileName "read_snapshot_check.txt"
    if (-not $success) { $hasFailures = $true }
    Write-Host ""
} else {
    $msg = "Read Snapshot Check script not found: $readSnapshotPath"
    Write-Host "FAIL: $msg" -ForegroundColor Red
    $msg | Out-File -FilePath (Join-Path $evidenceDir "read_snapshot_check.txt") -Encoding ASCII
    $results += @{ Name = "Read Snapshot Check"; Status = "FAIL"; Reason = "Script not found" }
    $hasFailures = $true
    Write-Host ""
}

# Step 4: Frontend Build (optional)
$frontendDir = Join-Path $repoRoot "work\marketplace-web"
if ((Test-Path $frontendDir) -and (-not $SkipFrontend)) {
    Write-Host "[RUN] Frontend Build..." -ForegroundColor Yellow
    $evidencePath = Join-Path $evidenceDir "frontend_build.txt"
    $startTime = Get-Date
    
    try {
        Push-Location $frontendDir
        
        # npm ci
        Write-Host "  Running npm ci..." -ForegroundColor Gray
        $npmCiOutput = & npm ci 2>&1 | Out-String
        $npmCiExitCode = $LASTEXITCODE
        
        # npm run build
        Write-Host "  Running npm run build..." -ForegroundColor Gray
        $npmBuildOutput = & npm run build 2>&1 | Out-String
        $npmBuildExitCode = $LASTEXITCODE
        
        $duration = (Get-Date) - $startTime
        
        $output = @"
=== Frontend Build ===
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duration: $($duration.TotalSeconds.ToString('F2'))s

--- npm ci ---
Exit Code: $npmCiExitCode
$npmCiOutput

--- npm run build ---
Exit Code: $npmBuildExitCode
$npmBuildOutput
"@
        $output | Out-File -FilePath $evidencePath -Encoding ASCII
        
        if (($npmCiExitCode -eq 0) -and ($npmBuildExitCode -eq 0)) {
            Write-Host "[PASS] Frontend Build - Duration: $($duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
            Write-Host "  Evidence: frontend_build.txt" -ForegroundColor Gray
            $results += @{ Name = "Frontend Build"; Status = "PASS"; Duration = $duration.TotalSeconds; Evidence = "frontend_build.txt" }
        } else {
            Write-Host "[FAIL] Frontend Build - npm ci: $npmCiExitCode, npm run build: $npmBuildExitCode" -ForegroundColor Red
            Write-Host "  Evidence: frontend_build.txt" -ForegroundColor Gray
            $results += @{ Name = "Frontend Build"; Status = "FAIL"; ExitCode = $npmBuildExitCode; Evidence = "frontend_build.txt" }
            $hasFailures = $true
        }
    } catch {
        $msg = "Exception: $($_.Exception.Message)"
        Write-Host "FAIL: $msg" -ForegroundColor Red
        $msg | Out-File -FilePath $evidencePath -Encoding ASCII
        $results += @{ Name = "Frontend Build"; Status = "FAIL"; Reason = $_.Exception.Message; Evidence = "frontend_build.txt" }
        $hasFailures = $true
    } finally {
        Pop-Location
    }
    Write-Host ""
} elseif ($SkipFrontend) {
    Write-Host "[SKIP] Frontend Build (SkipFrontend=true)" -ForegroundColor Gray
    Write-Host ""
}

# Summary
Write-Host "=== FINAL SANITY RUNNER SUMMARY ===" -ForegroundColor Cyan
Write-Host "Evidence folder: $evidenceDir" -ForegroundColor Gray
Write-Host ""
foreach ($result in $results) {
    $statusColor = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
    $durationText = if ($result.Duration) { " ($($result.Duration.ToString('F2'))s)" } else { "" }
    $evidenceText = if ($result.Evidence) { " -> $($result.Evidence)" } else { "" }
    Write-Host "  $($result.Status): $($result.Name)$durationText$evidenceText" -ForegroundColor $statusColor
}

Write-Host ""

if ($hasFailures) {
    Write-Host "=== FINAL SANITY RUNNER: FAIL ===" -ForegroundColor Red
    Write-Host "One or more checks failed. Check evidence logs in:" -ForegroundColor Yellow
    Write-Host "  $evidenceDir" -ForegroundColor Gray
    if (-not $NoPause) {
        Read-Host "Press Enter to exit"
    }
    exit 1
} else {
    Write-Host "=== FINAL SANITY RUNNER: PASS ===" -ForegroundColor Green
    Write-Host "All checks passed. Evidence logs saved in:" -ForegroundColor Gray
    Write-Host "  $evidenceDir" -ForegroundColor Gray
    if (-not $NoPause) {
        Read-Host "Press Enter to exit"
    }
    exit 0
}

