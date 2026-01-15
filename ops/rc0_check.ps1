# rc0_check.ps1 - RC0 Release Readiness Gate
# Single-command RC0 validation: runs all required gates in deterministic order
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [switch]$Ci
)

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}
if (Test-Path "${scriptDir}\_lib\core_availability.ps1") {
    . "${scriptDir}\_lib\core_availability.ps1"
}

# Ensure we're in repo root
$repoRoot = Split-Path -Parent $scriptDir
Push-Location $repoRoot

Write-Info "=== RC0 RELEASE READINESS GATE ==="
Write-Info "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Info ""

# Probe core availability (H-OS + hos-db)
Write-Info "Probing core availability..."
$coreAvailability = Test-CoreAvailability
if ($coreAvailability.Available) {
    Write-Info "Core available: H-OS and hos-db reachable"
} else {
    Write-Warn "Core unavailable: $($coreAvailability.Reason)"
    Write-Info "Core-dependent checks will be SKIP with reason=CORE_UNAVAILABLE"
}
Write-Info ""

# Results table
$script:results = @()

# Helper: Run script and capture status
function Invoke-RC0Check {
    param(
        [string]$CheckName,
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [bool]$IsOptional = $false,
        [bool]$IsCoreDependent = $false
    )
    
    Write-Info "Running $CheckName..."
    
    $exitCode = 0
    $status = "PASS"
    $notes = ""
    
    # Gate: If core-dependent and core unavailable, SKIP
    if ($IsCoreDependent -and -not $coreAvailability.Available) {
        $status = "SKIP"
        $exitCode = 0
        $notes = "CORE_UNAVAILABLE: $($coreAvailability.Reason)"
        
        $script:results += [PSCustomObject]@{
            Check = $CheckName
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
        }
        
        return @{
            Status = $status
            ExitCode = $exitCode
        }
    }
    
    if (-not (Test-Path $ScriptPath)) {
        if ($IsOptional) {
            $status = "WARN"
            $exitCode = 2
            $notes = "Script not found (optional)"
        } else {
            $status = "FAIL"
            $exitCode = 1
            $notes = "Script not found (required)"
        }
    } else {
        try {
            # Capture output (use splatting for argument array)
            if ($null -eq $Arguments) {
                $Arguments = @()
            }
            $scriptOutput = & $ScriptPath @Arguments 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            
            # Determine status from exit code
            if ($exitCode -eq 0) {
                $status = "PASS"
            } elseif ($exitCode -eq 2) {
                $status = "WARN"
            } else {
                $status = "FAIL"
            }
            
            # Extract key notes from output (last few lines)
            $outputLines = $scriptOutput -split "`n" | Where-Object { $_.Trim() -ne "" }
            if ($outputLines.Count -gt 0) {
                $notes = ($outputLines[-3..-1] | Where-Object { $_ -ne $null }) -join "; "
                if ($notes.Length -gt 80) {
                    $notes = $notes.Substring(0, 77) + "..."
                }
            }
            
        } catch {
            $status = "FAIL"
            $exitCode = 1
            $notes = "Error: $($_.Exception.Message)"
        }
    }
    
    $script:results += [PSCustomObject]@{
        Check = $CheckName
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Define checks in deterministic order
Write-Info "=== Running RC0 Checks ==="
Write-Info ""

# 1) doctor.ps1
$result1 = Invoke-RC0Check -CheckName "Repository Doctor" -ScriptPath ".\ops\doctor.ps1"

# 2) verify.ps1
$result2 = Invoke-RC0Check -CheckName "Stack Verification" -ScriptPath ".\ops\verify.ps1"

# 3) conformance.ps1
$result3 = Invoke-RC0Check -CheckName "Conformance" -ScriptPath ".\ops\conformance.ps1"

# 4) security_audit.ps1
$result4 = Invoke-RC0Check -CheckName "Security Audit" -ScriptPath ".\ops\security_audit.ps1"

# 5) env_contract.ps1
$result5 = Invoke-RC0Check -CheckName "Environment Contract" -ScriptPath ".\ops\env_contract.ps1"

# 6) session_posture_check.ps1 (core-dependent)
$result6 = Invoke-RC0Check -CheckName "Session Posture" -ScriptPath ".\ops\session_posture_check.ps1" -IsCoreDependent $true

# 7) slo_check.ps1 -N 30 (core-dependent)
$result7 = Invoke-RC0Check -CheckName "SLO Check" -ScriptPath ".\ops\slo_check.ps1" -Arguments @("-N", 30) -IsCoreDependent $true

# 8) observability_status.ps1 (optional, core-dependent)
$result8 = Invoke-RC0Check -CheckName "Observability Status" -ScriptPath ".\ops\observability_status.ps1" -IsOptional $true -IsCoreDependent $true

# 9) product_e2e.ps1 (optional, core-dependent)
$result9 = Invoke-RC0Check -CheckName "Product E2E" -ScriptPath ".\ops\product_e2e.ps1" -IsOptional $true -IsCoreDependent $true

# 10) tenant_boundary_check.ps1 (core-dependent)
# Note: If secrets/env missing, cross-tenant part should WARN+SKIP, but unauthorized checks still run
$result10 = Invoke-RC0Check -CheckName "Tenant Boundary" -ScriptPath ".\ops\tenant_boundary_check.ps1" -IsCoreDependent $true

# Print results table
Write-Info ""
Write-Info "=== RC0 Check Results ==="
Write-Info ""

# Print header
Write-Host "Check                                      Status ExitCode Notes" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

# Print rows
foreach ($result in $script:results) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[$($result.Status)]" }
    }
    
    $checkPadded = $result.Check.PadRight(40)
    $statusPadded = $statusMarker.PadRight(8)
    $exitCodePadded = $result.ExitCode.ToString().PadRight(8)
    
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "White" }
    }
    
    Write-Host "$checkPadded $statusPadded $exitCodePadded $($result.Notes)" -ForegroundColor $color
}

Write-Info ""

# Determine overall status
$hasFail = ($script:results | Where-Object { $_.Status -eq "FAIL" }).Count -gt 0
$hasWarn = ($script:results | Where-Object { $_.Status -eq "WARN" }).Count -gt 0
$skipCount = ($script:results | Where-Object { $_.Status -eq "SKIP" }).Count
$passCount = ($script:results | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($script:results | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($script:results | Where-Object { $_.Status -eq "FAIL" }).Count

$overallStatus = "PASS"
$overallExitCode = 0

# Root cause analysis
$rootCause = ""
if (-not $coreAvailability.Available) {
    $rootCause = "Core unavailable: $($coreAvailability.Reason). $skipCount core-dependent check(s) SKIP."
} elseif ($hasFail) {
    $rootCause = "$failCount check(s) FAIL"
} elseif ($hasWarn) {
    $rootCause = "$warnCount check(s) WARN"
} else {
    $rootCause = "All checks passed"
}

if ($hasFail) {
    $overallStatus = "FAIL"
    $overallExitCode = 1
} elseif ($hasWarn) {
    $overallStatus = "WARN"
    $overallExitCode = 2
} elseif (-not $coreAvailability.Available -and $skipCount -gt 0) {
    $overallStatus = "WARN"
    $overallExitCode = 2
}

Write-Info "=== Summary ==="
Write-Info "PASS: $passCount, WARN: $warnCount, FAIL: $failCount, SKIP: $skipCount"
if ($rootCause) {
    Write-Info "Root cause: $rootCause"
}
Write-Info ""

$statusColor = switch ($overallStatus) {
    "PASS" { "Green" }
    "WARN" { "Yellow" }
    "FAIL" { "Red" }
    default { "White" }
}

Write-Host "[$overallStatus] OVERALL STATUS: $overallStatus" -ForegroundColor $statusColor
Write-Info ""

# On FAIL: auto-run incident_bundle.ps1 (if exists)
if ($overallStatus -eq "FAIL") {
    $incidentBundlePath = ".\ops\incident_bundle.ps1"
    if (Test-Path $incidentBundlePath) {
        Write-Info "FAIL detected - running incident bundle..."
        try {
            & $incidentBundlePath 2>&1 | Out-Null
            # Extract bundle path from incident_bundle output (if it prints it)
            # For now, we'll use the standard pattern
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $bundlePath = "_archive\incidents\incident-$timestamp"
            if (Test-Path $bundlePath) {
                Write-Info "INCIDENT_BUNDLE_PATH=$bundlePath"
            } else {
                # Try to find the most recent incident bundle
                $incidentDirs = Get-ChildItem -Path "_archive\incidents" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($incidentDirs) {
                    Write-Info "INCIDENT_BUNDLE_PATH=$($incidentDirs.FullName)"
                }
            }
        } catch {
            Write-Warn "Failed to run incident bundle: $($_.Exception.Message)"
        }
    } else {
        Write-Warn "incident_bundle.ps1 not found - skipping automatic bundle generation"
    }
}

# Exit with appropriate code
Invoke-OpsExit $overallExitCode
return $overallExitCode

