# release_check.ps1 - RC0 Release Checklist Enforcement
# Validates all prerequisites for RC0 release
# PowerShell 5.1 compatible

param(
    [switch]$Ci
)

# Load shared helpers if available
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

if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== RC0 RELEASE CHECK ==="
} else {
    Write-Host "=== RC0 RELEASE CHECK ===" -ForegroundColor Cyan
}
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()

# Helper: Add check result
function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [int]$ExitCode,
        [string]$Notes = ""
    )
    
    $results += [PSCustomObject]@{
        Check = $CheckName
        Status = $Status
        ExitCode = $ExitCode
        Notes = $Notes
    }
}

# A) Git status clean
Write-Host "A) Checking git status..." -ForegroundColor Yellow
try {
    $gitStatus = & git status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) {
        Add-CheckResult -CheckName "A) Git Status Clean" -Status "FAIL" -ExitCode 1 -Notes "Git command failed: $gitStatus"
    } elseif ($gitStatus) {
        $uncommittedFiles = ($gitStatus | Measure-Object -Line).Lines
        Add-CheckResult -CheckName "A) Git Status Clean" -Status "FAIL" -ExitCode 1 -Notes "$uncommittedFiles uncommitted change(s) found. Commit or stash changes before release."
    } else {
        Add-CheckResult -CheckName "A) Git Status Clean" -Status "PASS" -ExitCode 0 -Notes "Working tree is clean"
    }
} catch {
    Add-CheckResult -CheckName "A) Git Status Clean" -Status "FAIL" -ExitCode 1 -Notes "Error: $($_.Exception.Message)"
}

# B) RC0 gate result
Write-Host "B) Running RC0 gate..." -ForegroundColor Yellow
try {
    $rc0GatePath = "${scriptDir}\rc0_gate.ps1"
    if (-not (Test-Path $rc0GatePath)) {
        Add-CheckResult -CheckName "B) RC0 Gate" -Status "FAIL" -ExitCode 1 -Notes "rc0_gate.ps1 not found"
    } else {
        $rc0Output = & $rc0GatePath 2>&1 | Out-String
        $rc0ExitCode = $LASTEXITCODE
        
        if ($rc0ExitCode -eq 0) {
            $status = "PASS"
            $notes = "All blocking checks passed"
        } elseif ($rc0ExitCode -eq 2) {
            $status = "WARN"
            $notes = "Warnings present (non-blocking)"
        } else {
            $status = "FAIL"
            $notes = "Blocking failures detected"
        }
        
        Add-CheckResult -CheckName "B) RC0 Gate" -Status $status -ExitCode $rc0ExitCode -Notes $notes
    }
} catch {
    Add-CheckResult -CheckName "B) RC0 Gate" -Status "FAIL" -ExitCode 1 -Notes "Error: $($_.Exception.Message)"
}

# C) Required docs present
Write-Host "C) Checking required documentation..." -ForegroundColor Yellow
$requiredDocs = @(
    @{ Path = "docs\ARCHITECTURE.md"; Name = "Architecture Overview" },
    @{ Path = "docs\REPO_LAYOUT.md"; Name = "Repository Layout" },
    @{ Path = "docs\runbooks\incident.md"; Name = "Incident Runbook" }
)

$missingDocs = @()
foreach ($doc in $requiredDocs) {
    if (-not (Test-Path $doc.Path)) {
        $missingDocs += $doc.Name
    }
}

if ($missingDocs.Count -gt 0) {
    Add-CheckResult -CheckName "C) Required Documentation" -Status "FAIL" -ExitCode 1 -Notes "Missing: $($missingDocs -join ', ')"
} else {
    Add-CheckResult -CheckName "C) Required Documentation" -Status "PASS" -ExitCode 0 -Notes "All required docs present"
}

# D) Snapshots present
Write-Host "D) Checking contract snapshots..." -ForegroundColor Yellow
$requiredSnapshots = @(
    @{ Path = "ops\snapshots\routes.pazar.json"; Name = "Routes Snapshot" },
    @{ Path = "ops\snapshots\schema.pazar.sql"; Name = "Schema Snapshot" }
)

$missingSnapshots = @()
foreach ($snapshot in $requiredSnapshots) {
    if (-not (Test-Path $snapshot.Path)) {
        $missingSnapshots += $snapshot.Name
    }
}

if ($missingSnapshots.Count -gt 0) {
    Add-CheckResult -CheckName "D) Contract Snapshots" -Status "FAIL" -ExitCode 1 -Notes "Missing: $($missingSnapshots -join ', ')"
} else {
    Add-CheckResult -CheckName "D) Contract Snapshots" -Status "PASS" -ExitCode 0 -Notes "All snapshots present"
}

# E) VERSION present and non-empty
Write-Host "E) Checking VERSION file..." -ForegroundColor Yellow
$versionPath = "VERSION"
if (-not (Test-Path $versionPath)) {
    Add-CheckResult -CheckName "E) VERSION File" -Status "FAIL" -ExitCode 1 -Notes "VERSION file not found"
} else {
    try {
        $versionContent = Get-Content $versionPath -Raw
        $versionContent = $versionContent.Trim()
        
        if ([string]::IsNullOrWhiteSpace($versionContent)) {
            Add-CheckResult -CheckName "E) VERSION File" -Status "FAIL" -ExitCode 1 -Notes "VERSION file is empty"
        } elseif ($versionContent -match '^(\d+\.\d+\.\d+)(-rc\d+)?$') {
            Add-CheckResult -CheckName "E) VERSION File" -Status "PASS" -ExitCode 0 -Notes "Version: $versionContent (format valid)"
        } else {
            Add-CheckResult -CheckName "E) VERSION File" -Status "FAIL" -ExitCode 1 -Notes "Invalid version format: $versionContent (expected: X.Y.Z or X.Y.Z-rcN)"
        }
    } catch {
        Add-CheckResult -CheckName "E) VERSION File" -Status "FAIL" -ExitCode 1 -Notes "Error reading VERSION: $($_.Exception.Message)"
    }
}

# Print results table
Write-Host ""
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== RELEASE CHECK RESULTS ==="
} else {
    Write-Host "=== RELEASE CHECK RESULTS ===" -ForegroundColor Cyan
}
Write-Host ""

$results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

# Determine overall status
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" }).Count
$passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count

Write-Host ""
Write-Host "Summary: $passCount PASS, $warnCount WARN, $failCount FAIL" -ForegroundColor Gray
Write-Host ""

# Overall status: FAIL if any FAIL, WARN if no FAIL and at least one WARN, PASS otherwise
if ($failCount -gt 0) {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "RELEASE CHECK: FAIL ($failCount blocking failures)"
    } else {
        Write-Host "RELEASE CHECK: FAIL ($failCount blocking failures)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "RC0 release cannot proceed. Fix blocking failures before proceeding." -ForegroundColor Gray
    Pop-Location
    Invoke-OpsExit 1
    return 1
} elseif ($warnCount -gt 0) {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Warn "RELEASE CHECK: WARN ($warnCount warnings, no blocking failures)"
    } else {
        Write-Host "RELEASE CHECK: WARN ($warnCount warnings, no blocking failures)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "RC0 release can proceed with warnings. Review warnings before tagging." -ForegroundColor Gray
    Pop-Location
    Invoke-OpsExit 2
    return 2
} else {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Pass "RELEASE CHECK: PASS (All checks passed)"
    } else {
        Write-Host "RELEASE CHECK: PASS (All checks passed)" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "RC0 release is ready. Proceed with release bundle generation and tagging." -ForegroundColor Gray
    Pop-Location
    Invoke-OpsExit 0
    return 0
}








