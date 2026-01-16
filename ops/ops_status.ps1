# ops_status.ps1 - Unified Ops Dashboard
# Aggregates all ops checks into a single status report
# PowerShell 5.1 compatible

param(
    [switch]$Ci,
    [switch]$ReleaseBundle,
    [switch]$RecordAudit
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
if (Test-Path "${scriptDir}\_lib\core_availability.ps1") {
    . "${scriptDir}\_lib\core_availability.ps1"
}

$ErrorActionPreference = "Continue"

Write-Host "=== UNIFIED OPS STATUS DASHBOARD ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Probe core availability (H-OS + hos-db)
Write-Host "Probing core availability..." -ForegroundColor Gray
$coreAvailability = Test-CoreAvailability
if ($coreAvailability.Available) {
    Write-Host "[INFO] Core available: H-OS and hos-db reachable" -ForegroundColor Green
} else {
    Write-Host "[WARN] Core unavailable: $($coreAvailability.Reason)" -ForegroundColor Yellow
    Write-Host "[INFO] Core-dependent checks will be SKIP with reason=CORE_UNAVAILABLE" -ForegroundColor Yellow
}
Write-Host ""

# Check Registry: Explicit enumeration of all checks with metadata
# Each check has: Id, Name, ScriptPath, Blocking, OnFailAction, Arguments, CoreDependent (bool)
# CoreDependent: true if check requires H-OS API or database to be running
$checkRegistry = @(
    @{ Id = "ops_drift_guard"; Name = "Ops Drift Guard"; ScriptPath = ".\ops\ops_drift_guard.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "storage_permissions"; Name = "Storage Permissions"; ScriptPath = ".\ops\storage_permissions_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $false },
    @{ Id = "doctor"; Name = "Repository Doctor"; ScriptPath = ".\ops\doctor.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "verify"; Name = "Stack Verification"; ScriptPath = ".\ops\verify.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "triage"; Name = "Incident Triage"; ScriptPath = ".\ops\triage.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); CoreDependent = $false },
    @{ Id = "storage_write"; Name = "Storage Write"; ScriptPath = ".\ops\storage_write_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "storage_posture"; Name = "Storage Posture"; ScriptPath = ".\ops\storage_posture_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "pazar_ui_smoke"; Name = "Pazar UI Smoke"; ScriptPath = ".\ops\pazar_ui_smoke.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "pazar_storage_posture"; Name = "Pazar Storage Posture"; ScriptPath = ".\ops\pazar_storage_posture.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "slo_check"; Name = "SLO Check"; ScriptPath = ".\ops\slo_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @("-N", "10"); CoreDependent = $true },
    @{ Id = "security_audit"; Name = "Security Audit"; ScriptPath = ".\ops\security_audit.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "conformance"; Name = "Conformance"; ScriptPath = ".\ops\conformance.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "product_spine"; Name = "Product Spine Check"; ScriptPath = ".\ops\product_spine_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_spine_e2e"; Name = "Product Spine E2E Check"; ScriptPath = ".\ops\product_spine_e2e_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_read_path"; Name = "Product Read Path Check"; ScriptPath = ".\ops\product_read_path_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "routes_snapshot"; Name = "Routes Snapshot"; ScriptPath = ".\ops\routes_snapshot.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
    @{ Id = "schema_snapshot"; Name = "Schema Snapshot"; ScriptPath = ".\ops\schema_snapshot.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
    @{ Id = "error_contract"; Name = "Error Contract"; ScriptPath = $null; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); InlineCheck = $true; CoreDependent = $true },
    @{ Id = "env_contract"; Name = "Environment Contract"; ScriptPath = ".\ops\env_contract.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $false },
    @{ Id = "auth_security"; Name = "Auth Security"; ScriptPath = ".\ops\auth_security_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "tenant_boundary"; Name = "Tenant Boundary"; ScriptPath = ".\ops\tenant_boundary_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "world_spine"; Name = "World Spine Governance"; ScriptPath = ".\ops\world_spine_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_contract"; Name = "Product Contract"; ScriptPath = ".\ops\product_contract.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_contract_check"; Name = "Product Contract Check"; ScriptPath = ".\ops\product_contract_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_e2e"; Name = "Product E2E"; ScriptPath = ".\ops\product_e2e.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_e2e_contract"; Name = "Product E2E Contract"; ScriptPath = ".\ops\product_e2e_contract.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_api_crud_e2e"; Name = "Product API CRUD E2E"; ScriptPath = ".\ops\product_api_crud_e2e.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_api_smoke"; Name = "Product API Smoke"; ScriptPath = ".\ops\product_api_smoke.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_perf_guard"; Name = "Product Perf Guard"; ScriptPath = ".\ops\product_perf_guard.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_mvp"; Name = "Product MVP Loop"; ScriptPath = ".\ops\product_mvp_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_spine_governance"; Name = "Product Spine Governance"; ScriptPath = ".\ops\product_spine_governance.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_write_spine"; Name = "Product Write Spine"; ScriptPath = ".\ops\product_write_spine_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "session_posture"; Name = "Session Posture"; ScriptPath = ".\ops\session_posture_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
    @{ Id = "product_read_path"; Name = "Product Read-Path"; ScriptPath = ".\ops\product_read_path_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_spine_smoke"; Name = "Product Spine Smoke"; ScriptPath = ".\ops\product_spine_smoke.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "openapi_contract"; Name = "OpenAPI Contract"; ScriptPath = ".\ops\openapi_contract.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "smoke_surface"; Name = "Smoke Surface Gate"; ScriptPath = ".\ops\smoke_surface.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "observability_status"; Name = "Observability Status"; ScriptPath = ".\ops\observability_status.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "rc0_gate"; Name = "RC0 Gate"; ScriptPath = ".\ops\rc0_gate.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $false },
    @{ Id = "rc0_check"; Name = "RC0 Check"; ScriptPath = ".\ops\rc0_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $false }
)

# Results table
$script:results = @()

# Helper: Run script and capture status
function Invoke-OpsCheckFromRegistry {
    param(
        [hashtable]$CheckDef
    )
    
    $checkName = $CheckDef.Name
    $scriptPath = $CheckDef.ScriptPath
    $arguments = if ($CheckDef.Arguments) { $CheckDef.Arguments } else { @() }
    $isOptional = if ($CheckDef.Optional) { $CheckDef.Optional } else { $false }
    $isInline = if ($CheckDef.InlineCheck) { $CheckDef.InlineCheck } else { $false }
    $isCoreDependent = if ($CheckDef.CoreDependent) { $CheckDef.CoreDependent } else { $false }
    
    Write-Host "Running $checkName..." -ForegroundColor Yellow
    
    $exitCode = 0
    $status = "PASS"
    $notes = ""
    
    # Gate: If core-dependent and core unavailable, SKIP
    if ($isCoreDependent -and -not $coreAvailability.Available) {
        $status = "SKIP"
        $exitCode = 0
        $notes = "CORE_UNAVAILABLE: $($coreAvailability.Reason)"
        
        $script:results += [PSCustomObject]@{
            Check = $checkName
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
            Blocking = $CheckDef.Blocking
            CheckId = $CheckDef.Id
        }
        
        return @{
            Status = $status
            ExitCode = $exitCode
            Blocking = $CheckDef.Blocking
        }
    }
    
    if ($isInline) {
        # Handle inline checks (e.g., Test-ErrorContract)
        if ($CheckDef.Id -eq "error_contract") {
            # Remove any existing error_contract result (to avoid duplicates)
            $script:results = $script:results | Where-Object { $_.CheckId -ne "error_contract" }
            $result = Test-ErrorContract
            $status = $result.Status
            $exitCode = $result.ExitCode
            $notes = ($script:results | Where-Object { $_.Check -eq "Error Contract" } | Select-Object -First 1).Notes
            # Don't add to results again (Test-ErrorContract already added it)
            return $result
        }
    } elseif (-not $scriptPath -or $null -eq $scriptPath) {
        $status = "SKIP"
        $exitCode = 0
        $notes = "No script path defined"
    } elseif (-not (Test-Path $scriptPath)) {
        if ($isOptional) {
            $status = "SKIP"
            $exitCode = 0
            $notes = "Script not found (optional)"
        } else {
            $status = "SKIP"
            $exitCode = 0
            $notes = "Script not found - treating as WARN for blocking checks"
        }
    } else {
        try {
            # Capture output (use splatting for argument array)
            if ($null -eq $arguments) {
                $arguments = @()
            }
            $scriptOutput = & $scriptPath @arguments 2>&1 | Out-String
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
    }
    
    # Add blocking/non-blocking indicator to notes for display
    $blockingNote = if ($CheckDef.Blocking) { "(BLOCKING)" } else { "(NON-BLOCKING)" }
    if ($notes) {
        $notes = "$blockingNote $notes"
    } else {
        $notes = $blockingNote
    }
    
    $script:results += [PSCustomObject]@{
        Check = $checkName
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
        Blocking = $CheckDef.Blocking
        CheckId = $CheckDef.Id
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
        Blocking = $CheckDef.Blocking
    }
}

# Helper: Check error contract (422 and 404 envelopes)
function Test-ErrorContract {
    Write-Host "Running Error Contract Check..." -ForegroundColor Yellow
    
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
        
        # Check for connection failure (no HTTP status code means connection failed)
        if (-not $status422) {
            # Check if curl output indicates connection error
            $response422Str = $response422 -join " "
            if ($response422Str -match "Failed to connect|Connection refused|Could not resolve|Connection timed out|Unable to connect") {
                $status = "SKIP"
                $exitCode = 0
                $notes = "CORE_UNAVAILABLE: Cannot connect to http://localhost:8080"
                
                $script:results += [PSCustomObject]@{
                    Check = "Error Contract"
                    Status = $status
                    ExitCode = $exitCode
                    Notes = $notes
                    Blocking = $true
                    CheckId = "error_contract"
                }
                
                return @{
                    Status = $status
                    ExitCode = $exitCode
                }
            }
            $failures += "422 status check failed (got $status422)"
        }
        
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
        
        # Check for connection failure (no HTTP status code means connection failed)
        if (-not $status404) {
            # Check if curl output indicates connection error
            $response404Str = $response404 -join " "
            if ($response404Str -match "Failed to connect|Connection refused|Could not resolve|Connection timed out|Unable to connect") {
                $status = "SKIP"
                $exitCode = 0
                $notes = "CORE_UNAVAILABLE: Cannot connect to http://localhost:8080"
                
                $script:results += [PSCustomObject]@{
                    Check = "Error Contract"
                    Status = $status
                    ExitCode = $exitCode
                    Notes = $notes
                    Blocking = $true
                    CheckId = "error_contract"
                }
                
                return @{
                    Status = $status
                    ExitCode = $exitCode
                }
            }
            $failures += "404 status check failed (got $status404)"
        }
        
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
        # Check if exception indicates connection failure
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "Failed to connect|Connection refused|Could not resolve|Connection timed out|Unable to connect|The remote name could not be resolved") {
            $status = "SKIP"
            $exitCode = 0
            $notes = "CORE_UNAVAILABLE: Cannot connect to http://localhost:8080"
        } else {
            $status = "FAIL"
            $exitCode = 1
            $notes = "Error: $errorMsg"
        }
    }
    
    $script:results += [PSCustomObject]@{
        Check = "Error Contract"
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
        Blocking = $true
        CheckId = "error_contract"
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Run all checks from registry
Write-Host "=== Running Ops Checks ===" -ForegroundColor Cyan
Write-Host ""

foreach ($check in $checkRegistry) {
    Invoke-OpsCheckFromRegistry -CheckDef $check | Out-Null
}

# Print results table
Write-Host ""
Write-Host "=== OPS STATUS RESULTS ===" -ForegroundColor Cyan
Write-Host ""

# Print header
Write-Host "Check                                      Status ExitCode Notes" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

# Print rows using helper (if available) or Format-Table
if (Get-Command Write-OpsTableRow -ErrorAction SilentlyContinue) {
    foreach ($result in $script:results) {
        Write-OpsTableRow -Check $result.Check -Status $result.Status -ExitCode $result.ExitCode -Notes $result.Notes
    }
} else {
    $script:results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize
}

Write-Host ""

# Determine overall status based on blocking semantics
$blockingFails = ($script:results | Where-Object { $_.Blocking -eq $true -and $_.Status -eq "FAIL" }).Count
$blockingSkips = ($script:results | Where-Object { $_.Blocking -eq $true -and $_.Status -eq "SKIP" }).Count
$nonBlockingWarns = ($script:results | Where-Object { $_.Blocking -eq $false -and ($_.Status -eq "WARN" -or $_.Status -eq "FAIL") }).Count
$skipCount = ($script:results | Where-Object { $_.Status -eq "SKIP" }).Count
$passCount = ($script:results | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($script:results | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($script:results | Where-Object { $_.Status -eq "FAIL" }).Count

# Root cause analysis
$rootCause = ""
if (-not $coreAvailability.Available) {
    $rootCause = "Core unavailable: $($coreAvailability.Reason). $skipCount core-dependent check(s) SKIP."
} elseif ($blockingFails -gt 0) {
    $rootCause = "$blockingFails blocking check(s) FAIL"
} elseif ($blockingSkips -gt 0) {
    $rootCause = "$blockingSkips blocking check(s) SKIP"
} elseif ($nonBlockingWarns -gt 0) {
    $rootCause = "$nonBlockingWarns non-blocking check(s) WARN/FAIL"
} else {
    $rootCause = "All checks passed"
}

# Treat blocking SKIPs due to core unavailability as informational (not WARN)
$coreUnavailableSkips = ($script:results | Where-Object { $_.Blocking -eq $true -and $_.Status -eq "SKIP" -and $_.Notes -match "CORE_UNAVAILABLE" }).Count
if ($blockingSkips -gt 0 -and $coreUnavailableSkips -lt $blockingSkips) {
    Write-Host "[WARN] $($blockingSkips - $coreUnavailableSkips) blocking check(s) were SKIP (not due to core unavailability)" -ForegroundColor Yellow
}

# Optional: Release Bundle generation
if ($ReleaseBundle) {
    Write-Host ""
    Write-Host "=== Generating Release Bundle ===" -ForegroundColor Cyan
    Write-Host ""
    try {
        $bundleScript = Join-Path $scriptDir "release_bundle.ps1"
        if (Test-Path $bundleScript) {
            & $bundleScript -Ci
            $bundleExitCode = $LASTEXITCODE
            Write-Host ""
            if ($bundleExitCode -eq 0) {
                Write-Host "[INFO] Release bundle generated successfully" -ForegroundColor Green
            } elseif ($bundleExitCode -eq 2) {
                Write-Host "[WARN] Release bundle generated with warnings" -ForegroundColor Yellow
            } else {
                Write-Host "[WARN] Release bundle generation failed (exit code: $bundleExitCode)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[WARN] release_bundle.ps1 not found: $bundleScript" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARN] Error generating release bundle: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Print summary
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "PASS: $passCount, WARN: $warnCount, FAIL: $failCount, SKIP: $skipCount" -ForegroundColor Gray
if ($rootCause) {
    Write-Host "Root cause: $rootCause" -ForegroundColor Gray
}
Write-Host ""

# Determine overall status
if ($blockingFails -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($blockingFails blocking failure(s))" -ForegroundColor Red
    
    # Generate incident bundle
    Write-Host ""
    Write-Host "Generating incident bundle..." -ForegroundColor Yellow
    try {
        $bundleOutput = & .\ops\incident_bundle.ps1 2>&1 | Out-String
        # Extract bundle path from output
        $bundlePath = ($bundleOutput | Select-String -Pattern "_archive[\\/]incidents[\\/]incident-\d{8}-\d{6}" | Select-Object -First 1)
        if ($bundlePath) {
            $bundlePath = $bundlePath.Matches.Value
            Write-Host "INCIDENT_BUNDLE_PATH=$bundlePath" -ForegroundColor Yellow
        } else {
            $bundlePath = ($bundleOutput | Select-String -Pattern "Bundle location:\s*(.+)" | Select-Object -First 1)
            if ($bundlePath) {
                $bundlePath = $bundlePath.Matches.Groups[1].Value.Trim()
                Write-Host "INCIDENT_BUNDLE_PATH=$bundlePath" -ForegroundColor Yellow
            } else {
                Write-Host "INCIDENT_BUNDLE_PATH=_archive/incidents/ (check output above)" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "Warning: Failed to generate incident bundle: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Invoke-OpsExit 1
} elseif ($blockingSkips -gt 0 -and $coreUnavailableSkips -lt $blockingSkips) {
    # Blocking SKIPs not due to core unavailability
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Write-Host "  - $($blockingSkips - $coreUnavailableSkips) blocking check(s) SKIP (not core-related)" -ForegroundColor Yellow
    if ($nonBlockingWarns -gt 0) {
        Write-Host "  - $nonBlockingWarns non-blocking check(s) WARN/FAIL" -ForegroundColor Yellow
    }
    Invoke-OpsExit 2
} elseif ($nonBlockingWarns -gt 0) {
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Write-Host "  - $nonBlockingWarns non-blocking check(s) WARN/FAIL" -ForegroundColor Yellow
    Invoke-OpsExit 2
} else {
    if (-not $coreAvailability.Available) {
        Write-Host "OVERALL STATUS: WARN (Core unavailable, $skipCount check(s) SKIP)" -ForegroundColor Yellow
        Invoke-OpsExit 2
    } else {
        Write-Host "OVERALL STATUS: PASS (All blocking checks passed)" -ForegroundColor Green
        Invoke-OpsExit 0
    }
}
