# rc0_gate.ps1 - RC0 Release Gate
# Single-command RC0 readiness check
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
    Write-Info "=== RC0 RELEASE GATE ==="
} else {
    Write-Host "=== RC0 RELEASE GATE ===" -ForegroundColor Cyan
}
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()

# Helper: Run script and capture status
function Invoke-RC0Check {
    param(
        [string]$CheckName,
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "Running $CheckName..."
    } else {
        Write-Host "Running $CheckName..." -ForegroundColor Yellow
    }
    
    $exitCode = 0
    $status = "PASS"
    $notes = ""
    
    if (-not (Test-Path $ScriptPath)) {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Script not found: $ScriptPath"
        $script:results += [PSCustomObject]@{
            Check = $CheckName
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
        }
        return @{
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
        }
    }
    
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
            if ($notes.Length -gt 100) {
                $notes = $notes.Substring(0, 97) + "..."
            }
        }
        
    } catch {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Error: $($_.Exception.Message)"
    }
    
    $results += [PSCustomObject]@{
        Check = $CheckName
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
}

# Helper: Check error contract (inline, from ops_status.ps1 pattern)
function Test-ErrorContractInline {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "Running Error Contract Check..."
    } else {
        Write-Host "Running Error Contract Check..." -ForegroundColor Yellow
    }
    
    $status = "PASS"
    $exitCode = 0
    $notes = ""
    $failures = @()
    
    try {
        # Test 422 Validation Error
        $response422 = curl.exe -sS -i -X POST http://localhost:8080/auth/login `
            -H "Content-Type: application/json" `
            -H "Accept: application/json" `
            -d "{}" 2>&1
        
        $status422 = ($response422 | Select-String -Pattern "HTTP/\d\.\d\s+(\d+)" | ForEach-Object { $_.Matches.Groups[1].Value })
        $body422 = ($response422 | Select-String -Pattern '\{.*\}' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Last 1)
        
        if ($status422 -ne "422") {
            $failures += "422 status check failed (got $status422)"
        }
        
        if ($body422 -and $body422 -match '"ok"\s*:\s*false' -and 
            $body422 -match '"error_code"\s*:\s*"VALIDATION_ERROR"' -and
            $body422 -match '"request_id"' -and
            $body422 -match '"details"') {
            # PASS
        } else {
            $failures += "422 envelope missing required fields"
        }
        
        # Test 404 Not Found
        $response404 = curl.exe -sS -i -H "Accept: application/json" http://localhost:8080/api/non-existent-endpoint 2>&1
        
        $status404 = ($response404 | Select-String -Pattern "HTTP/\d\.\d\s+(\d+)" | ForEach-Object { $_.Matches.Groups[1].Value })
        $body404 = ($response404 | Select-String -Pattern '\{.*\}' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Last 1)
        
        if ($status404 -ne "404") {
            $failures += "404 status check failed (got $status404)"
        }
        
        if ($body404 -and $body404 -match '"ok"\s*:\s*false' -and 
            $body404 -match '"error_code"\s*:\s*"NOT_FOUND"' -and
            $body404 -match '"request_id"') {
            # PASS
        } else {
            $failures += "404 envelope missing required fields"
        }
        
        if ($failures.Count -gt 0) {
            $status = "FAIL"
            $exitCode = 1
            $notes = $failures -join "; "
        } else {
            $notes = "422 and 404 envelopes correct"
        }
        
    } catch {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Error: $($_.Exception.Message)"
    }
    
    $script:results += [PSCustomObject]@{
        Check = "Error Contract"
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Helper: Check observability (Prometheus/Alertmanager)
function Test-ObservabilityStatus {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "Running Observability Status Check..."
    } else {
        Write-Host "Running Observability Status Check..." -ForegroundColor Yellow
    }
    
    $status = "WARN"
    $exitCode = 2
    $notes = ""
    
    # Check if observability compose file exists
    $obsComposeFile = "work\hos\docker-compose.yml"
    if (-not (Test-Path $obsComposeFile)) {
        $notes = "Observability compose file not found (WARN only - observability is optional)"
        $script:results += [PSCustomObject]@{
            Check = "Observability Status"
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
        }
        return @{
            Status = $status
            ExitCode = $exitCode
        }
    }
    
    # Try to use alert_pipeline_proof if available
    $alertPipelineScript = "${scriptDir}\alert_pipeline_proof.ps1"
    if (Test-Path $alertPipelineScript) {
        try {
            $obsOutput = & $alertPipelineScript 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0) {
                $status = "PASS"
                $notes = "Alert pipeline verified"
            } elseif ($exitCode -eq 2) {
                $status = "WARN"
                $notes = "Observability services not running (WARN only)"
            } else {
                $status = "WARN"
                $notes = "Observability check failed (WARN only - non-blocking for RC0)"
            }
        } catch {
            $status = "WARN"
            $exitCode = 2
            $notes = "Error checking observability: $($_.Exception.Message) (WARN only)"
        }
    } else {
        # Check Prometheus/Alertmanager manually (basic check)
        try {
            # Try Prometheus /-/ready endpoint
            $prometheusError = $null
            try {
                $prometheusReady = curl.exe -sS -f -m 5 http://localhost:9090/-/ready 2>&1
                $prometheusExitCode = $LASTEXITCODE
            } catch {
                $prometheusError = $_.Exception.Message
                $prometheusExitCode = 1
            }
            
            # Try Alertmanager /-/ready endpoint
            $alertmanagerError = $null
            try {
                $alertmanagerReady = curl.exe -sS -f -m 5 http://localhost:9093/-/ready 2>&1
                $alertmanagerExitCode = $LASTEXITCODE
            } catch {
                $alertmanagerError = $_.Exception.Message
                $alertmanagerExitCode = 1
            }
            
            # Connection refused/timeout (exit code 7 or 28) -> WARN (Rule 34: obs not available)
            if ($prometheusExitCode -eq 7 -or $prometheusExitCode -eq 28 -or $alertmanagerExitCode -eq 7 -or $alertmanagerExitCode -eq 28) {
                $status = "WARN"
                $exitCode = 2
                $notes = "Observability services not accessible (connection refused/timeout - WARN only, Rule 34)"
            }
            # Both accessible and ready
            elseif ($prometheusExitCode -eq 0 -and $alertmanagerExitCode -eq 0 -and $prometheusReady -and $alertmanagerReady) {
                $status = "PASS"
                $exitCode = 0
                $notes = "Prometheus and Alertmanager are ready"
            }
            # One or both not ready (but accessible) -> check for real errors
            else {
                # Check if it's a real config/rules/targets error or just not running
                if ($prometheusReady -match "error|failed|invalid" -or $alertmanagerReady -match "error|failed|invalid") {
                    # Real error (config/rules/targets issue) -> FAIL
                    $status = "FAIL"
                    $exitCode = 1
                    $notes = "Observability config/rules/targets error: Prometheus=$prometheusExitCode, Alertmanager=$alertmanagerExitCode"
                } else {
                    # Not running but accessible -> WARN (Rule 34)
                    $status = "WARN"
                    $exitCode = 2
                    $notes = "Observability services not ready (WARN only - observability is optional, Rule 34)"
                }
            }
        } catch {
            # Connection/timeout error -> WARN (Rule 34)
            $status = "WARN"
            $exitCode = 2
            $notes = "Observability services not available (connection error - WARN only, Rule 34): $($_.Exception.Message)"
        }
    }
    
    $results += [PSCustomObject]@{
        Check = "Observability Status"
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Run RC0 blocking checks in order
Write-Host "=== Running RC0 Gate Checks ===" -ForegroundColor Cyan
Write-Host ""

# 0) RC0 Check (aggregate check - must pass)
$rc0CheckResult = Invoke-RC0Check -CheckName "0) RC0 Check" -ScriptPath "${scriptDir}\rc0_check.ps1"
if ($rc0CheckResult.Status -eq "FAIL") {
    # If rc0_check fails, rc0_gate must fail (do not mask)
    Write-Host ""
    Write-Host "RC0 Check failed - RC0 Gate cannot proceed" -ForegroundColor Red
    Write-Host ""
    Pop-Location
    Invoke-OpsExit 1
    return 1
}

# A) Repository Doctor
$doctorResult = Invoke-RC0Check -CheckName "A) Repository Doctor" -ScriptPath "${scriptDir}\doctor.ps1"

# B) Stack Verification (RC0 mode: /up required)
$verifyResult = Invoke-RC0Check -CheckName "B) Stack Verification" -ScriptPath "${scriptDir}\verify.ps1" -Arguments @("-Release")

# C) Architecture Conformance
$conformanceResult = Invoke-RC0Check -CheckName "C) Architecture Conformance" -ScriptPath "${scriptDir}\conformance.ps1"

# D) Environment Contract
$envContractResult = Invoke-RC0Check -CheckName "D) Environment Contract" -ScriptPath "${scriptDir}\env_contract.ps1"

# E) Security Audit
$securityResult = Invoke-RC0Check -CheckName "E) Security Audit" -ScriptPath "${scriptDir}\security_audit.ps1"

# F) Auth Security Check
$authSecurityResult = Invoke-RC0Check -CheckName "F) Auth Security Check" -ScriptPath "${scriptDir}\auth_security_check.ps1"

# G) Tenant Boundary Check (secrets yoksa SKIP/WARN, net rapor)
$tenantBoundaryResult = $null
try {
    $tenantBoundaryResult = Invoke-RC0Check -CheckName "G) Tenant Boundary Check" -ScriptPath "${scriptDir}\tenant_boundary_check.ps1"
    
    # Null-safe check: if result is null or missing, mark as FAIL
    if ($null -eq $tenantBoundaryResult) {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Tenant boundary check result missing (script error)"
        $script:results += [PSCustomObject]@{
            Check = "G) Tenant Boundary Check"
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
        }
        $tenantBoundaryResult = @{
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
        }
    }
    
    # Null-safe Notes access: use string conversion and ToLowerInvariant
    if ($tenantBoundaryResult.Status -eq "FAIL" -and $tenantBoundaryResult.ExitCode -ne 0) {
        # Check if failure is due to missing secrets (non-blocking for RC0)
        $notesText = if ($null -ne $tenantBoundaryResult.Notes) { [string]$tenantBoundaryResult.Notes } else { "" }
        $notesLower = $notesText.ToLowerInvariant()
        if ($notesLower -match "secret|key|credential|env.*var" -and ($notesLower -match "not.*found|missing|not.*set|not.*configured")) {
            # Update to WARN with clear note
            $tenantBoundaryIndex = $script:results.Count - 1
            if ($tenantBoundaryIndex -ge 0) {
                $script:results[$tenantBoundaryIndex].Status = "WARN"
                $script:results[$tenantBoundaryIndex].ExitCode = 2
                $script:results[$tenantBoundaryIndex].Notes = "Secrets not configured (WARN only - required for production, optional for RC0). Original: $($script:results[$tenantBoundaryIndex].Notes)"
            }
            $tenantBoundaryResult.Status = "WARN"
            $tenantBoundaryResult.ExitCode = 2
        }
    }
} catch {
    # If Invoke-RC0Check throws an exception, mark as FAIL
    $status = "FAIL"
    $exitCode = 1
    $notes = "Tenant boundary check crashed: $($_.Exception.Message)"
        $script:results += [PSCustomObject]@{
            Check = "G) Tenant Boundary Check"
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
        }
    $tenantBoundaryResult = @{
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
}

# H) Session Posture Check (blocking in prod, WARN in local/dev)
$sessionPostureResult = Invoke-RC0Check -CheckName "H) Session Posture Check" -ScriptPath "${scriptDir}\session_posture_check.ps1"
# If local/dev mode, map FAIL to WARN (non-blocking for RC0)
$appEnv = $env:APP_ENV
if (($appEnv -eq "local") -or ($appEnv -eq "dev") -or (-not $appEnv)) {
    if ($sessionPostureResult.Status -eq "FAIL") {
        $sessionIndex = $script:results.Count - 1
        if ($sessionIndex -ge 0) {
            $script:results[$sessionIndex].Status = "WARN"
            $script:results[$sessionIndex].ExitCode = 2
            $script:results[$sessionIndex].Notes = "Session posture FAIL in local/dev (non-blocking, mapped to WARN): $($script:results[$sessionIndex].Notes)"
        }
        $sessionPostureResult.Status = "WARN"
        $sessionPostureResult.ExitCode = 2
    }
}

# I) SLO Check (non-blocking; p50 already non-blocking policy)
$sloResult = Invoke-RC0Check -CheckName "I) SLO Check (N=10)" -ScriptPath "${scriptDir}\slo_check.ps1" -Arguments @("-N", "10")
# Map non-blocking FAIL to WARN for SLO
if ($sloResult.Status -eq "FAIL") {
    $sloIndex = $script:results.Count - 1
    if ($sloIndex -ge 0) {
        $script:results[$sloIndex].Status = "WARN"
        $script:results[$sloIndex].ExitCode = 2
        $script:results[$sloIndex].Notes = "SLO check FAIL (non-blocking, mapped to WARN): $($script:results[$sloIndex].Notes)"
    }
    $sloResult.Status = "WARN"
    $sloResult.ExitCode = 2
}

# J) Observability Status (non-blocking; WARN only if not available)
$obsResult = Test-ObservabilityStatus

# K) Routes Snapshot (non-blocking, but real FAIL is FAIL - don't auto-map to WARN)
$routesResult = Invoke-RC0Check -CheckName "K) Routes Snapshot" -ScriptPath "${scriptDir}\routes_snapshot.ps1"

# L) Schema Snapshot (blocking)
$schemaResult = Invoke-RC0Check -CheckName "L) Schema Snapshot" -ScriptPath "${scriptDir}\schema_snapshot.ps1"

# M) Error Contract Check
$errorContractScript = "${scriptDir}\error_contract_check.ps1"
if (Test-Path $errorContractScript) {
    $errorContractResult = Invoke-RC0Check -CheckName "M) Error Contract" -ScriptPath $errorContractScript
} else {
    # Use inline check (from ops_status pattern)
    $errorContractResult = Test-ErrorContractInline
    # Update check name in results
    $errorContractIndex = $script:results.Count - 1
    if ($errorContractIndex -ge 0) {
        $script:results[$errorContractIndex].Check = "M) Error Contract"
    }
}

# N) Release Bundle (disabled - manually run release_bundle.ps1 if needed)
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "N) Release Bundle Generator (SKIPPED - disabled)"
} else {
    Write-Host "N) Release Bundle Generator (SKIPPED - disabled)" -ForegroundColor Gray
}
$script:results += [PSCustomObject]@{
    Check = "N) Release Bundle"
    Status = "SKIP"
    ExitCode = 0
    Notes = "Release bundle generation disabled (manually run release_bundle.ps1 if needed)"
}

# Print results table
Write-Host ""
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== RC0 GATE RESULTS ==="
} else {
    Write-Host "=== RC0 GATE RESULTS ===" -ForegroundColor Cyan
}
Write-Host ""

$script:results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

# Determine overall status (count only actual results, not empty/zero cases)
$actualResults = $script:results | Where-Object { $_.Status -in @("PASS", "WARN", "FAIL", "SKIP") }
$failCount = ($actualResults | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($actualResults | Where-Object { $_.Status -eq "WARN" }).Count
$passCount = ($actualResults | Where-Object { $_.Status -eq "PASS" }).Count
$skipCount = ($actualResults | Where-Object { $_.Status -eq "SKIP" }).Count

# Ensure summary is never empty (trusted gate requirement)
if ($actualResults.Count -eq 0) {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "RC0 GATE: FAIL (No check results collected - gate error)"
    } else {
        Write-Host "RC0 GATE: FAIL (No check results collected - gate error)" -ForegroundColor Red
    }
    Write-Host ""
    Pop-Location
    Invoke-OpsExit 1
    return 1
}

Write-Host ""
Write-Host "Summary: $passCount PASS, $warnCount WARN, $failCount FAIL, $skipCount SKIP" -ForegroundColor Gray
Write-Host ""

# Overall status: FAIL if any blocking FAIL, WARN if no FAIL and at least one WARN, PASS otherwise
# Note: Non-blocking checks (SLO, routes_snapshot, observability) are already mapped to WARN if they FAIL
if ($failCount -gt 0) {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "RC0 GATE: FAIL ($failCount blocking failures)"
    } else {
        Write-Host "RC0 GATE: FAIL ($failCount blocking failures)" -ForegroundColor Red
    }
    Write-Host ""
    
    # Generate incident bundle on FAIL
    if (Test-Path "${scriptDir}\incident_bundle.ps1") {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Info "Generating incident bundle..."
        } else {
            Write-Host "Generating incident bundle..." -ForegroundColor Yellow
        }
        try {
            $bundleOutput = & "${scriptDir}\incident_bundle.ps1" 2>&1 | Out-String
            # Extract bundle path from output
            $bundlePath = ($bundleOutput | Select-String -Pattern "_archive[\\/]incidents[\\/]incident-\d{8}-\d{6}" | Select-Object -First 1)
            if ($bundlePath) {
                $bundlePath = $bundlePath.Matches.Value
                Write-Host "INCIDENT_BUNDLE_PATH=$bundlePath" -ForegroundColor Yellow
            } else {
                # Fallback: try to find "Bundle location:" line
                $bundlePath = ($bundleOutput | Select-String -Pattern "Bundle location:\s*(.+)" | Select-Object -First 1)
                if ($bundlePath) {
                    $bundlePath = $bundlePath.Matches.Groups[1].Value.Trim()
                    Write-Host "INCIDENT_BUNDLE_PATH=$bundlePath" -ForegroundColor Yellow
                } else {
                    Write-Host "INCIDENT_BUNDLE_PATH=_archive/incidents/ (check output above)" -ForegroundColor Yellow
                }
            }
        } catch {
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Warn "Failed to generate incident bundle: $($_.Exception.Message)"
            } else {
                Write-Host "Warning: Failed to generate incident bundle: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    
    Pop-Location
    Invoke-OpsExit 1
    return 1
} elseif ($warnCount -gt 0) {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Warn "RC0 GATE: WARN ($warnCount warnings, no blocking failures)"
    } else {
        Write-Host "RC0 GATE: WARN ($warnCount warnings, no blocking failures)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "RC0 can proceed with warnings. Review warnings before release." -ForegroundColor Gray
    Pop-Location
    Invoke-OpsExit 2
    return 2
} else {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Pass "RC0 GATE: PASS (All blocking checks passed)"
    } else {
        Write-Host "RC0 GATE: PASS (All blocking checks passed)" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "RC0 release is approved." -ForegroundColor Gray
    Pop-Location
    Invoke-OpsExit 0
    return 0
}

