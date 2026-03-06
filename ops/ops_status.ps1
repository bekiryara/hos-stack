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

# WP-68C: Golden Commands Banner (keep stable)
Write-Host "=== GOLDEN COMMANDS ===" -ForegroundColor Yellow
Write-Host "(0) Dispatcher:    .\\ops\\ops.ps1 full|status|run|..." -ForegroundColor White
Write-Host "(1) FULL GATES:     .\\ops\\ops.ps1 full" -ForegroundColor White
Write-Host "(2) Status/Audit:   .\\ops\\ops_status.ps1" -ForegroundColor White
Write-Host "(3) Publish:        .\\ops\\ops.ps1 ship" -ForegroundColor White
Write-Host "(4) Frontend Apply: .\\ops\\frontend_refresh.ps1 [-Build]" -ForegroundColor White
Write-Host "Docs: docs\\ops\\OPS_ENTRYPOINTS.md and ops\\README.md" -ForegroundColor Gray
Write-Host ""

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
    @{ Id = "ops_drift_guard"; Name = "Ops Drift Guard"; ScriptPath = ".\ops\ops_drift_guard.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $false },
    @{ Id = "storage_permissions"; Name = "Storage Permissions"; ScriptPath = ".\ops\storage_permissions_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $false },
    @{ Id = "doctor"; Name = "Repository Doctor"; ScriptPath = ".\ops\doctor.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "verify"; Name = "Stack Verification"; ScriptPath = ".\ops\verify.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "triage"; Name = "Incident Triage"; ScriptPath = ".\ops\triage.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); CoreDependent = $false },
    @{ Id = "storage_write"; Name = "Storage Write"; ScriptPath = ".\ops\storage_write_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "storage_posture"; Name = "Storage Posture"; ScriptPath = ".\ops\storage_posture_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "google_first_oauth_smoke"; Name = "Google-first OAuth Smoke"; ScriptPath = ".\ops\google_first_oauth_smoke.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
    @{ Id = "pazar_ui_smoke"; Name = "Pazar UI Smoke"; ScriptPath = ".\ops\pazar_ui_smoke.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "pazar_storage_posture"; Name = "Pazar Storage Posture"; ScriptPath = ".\ops\pazar_storage_posture.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "slo_check"; Name = "SLO Check"; ScriptPath = ".\ops\slo_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @("10"); Optional = $true; CoreDependent = $true },
    # Baseline CI: security boundary (SSOT: Admin in H-OS, not Pazar)
    @{ Id = "security_audit"; Name = "Security Audit"; ScriptPath = ".\ops\security_audit.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "conformance"; Name = "Conformance"; ScriptPath = ".\ops\conformance.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $false },
    @{ Id = "policy_variant_matrix"; Name = "Policy Variant Matrix"; ScriptPath = ".\ops\policy_variant_matrix_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
    @{ Id = "product_spine"; Name = "Product Spine Check"; ScriptPath = ".\ops\product_spine_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_spine_e2e"; Name = "Product Spine E2E Check"; ScriptPath = ".\ops\product_spine_e2e_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "product_read_path"; Name = "Product Read Path Check"; ScriptPath = ".\ops\product_read_path_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    # Baseline CI: contracts/snapshots (detect drift early)
    @{ Id = "routes_snapshot"; Name = "Routes Snapshot"; ScriptPath = ".\ops\routes_snapshot.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
    @{ Id = "schema_snapshot"; Name = "Schema Snapshot"; ScriptPath = ".\ops\schema_snapshot.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
    @{ Id = "error_contract"; Name = "Error Contract"; ScriptPath = $null; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); InlineCheck = $true; Optional = $true; CoreDependent = $true },
    @{ Id = "env_contract"; Name = "Environment Contract"; ScriptPath = ".\ops\env_contract.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $false },
    # Baseline CI: auth & boundary guarantees
    @{ Id = "auth_security"; Name = "Auth Security"; ScriptPath = ".\ops\auth_security_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
    @{ Id = "tenant_boundary"; Name = "Tenant Boundary"; ScriptPath = ".\ops\tenant_boundary_check.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); CoreDependent = $true },
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
    @{ Id = "product_spine_smoke"; Name = "Product Spine Smoke"; ScriptPath = ".\ops\product_spine_smoke.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "openapi_contract"; Name = "OpenAPI Contract"; ScriptPath = ".\ops\openapi_contract.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "smoke_surface"; Name = "Smoke Surface Gate"; ScriptPath = ".\ops\smoke_surface.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @(); Optional = $true; CoreDependent = $true },
    @{ Id = "observability_status"; Name = "Observability Status"; ScriptPath = ".\ops\observability_status.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true },
    
    # Registry-only: leaf scripts tracked by ops_drift_guard for discoverability.
    # These are intentionally NOT executed by ops_status (avoid heavy side effects / duplication).
    @{ Id = "leaf_account_portal_read"; Name = "Leaf: Account Portal Read Check"; ScriptPath = ".\ops\account_portal_read_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_baseline_status"; Name = "Leaf: Baseline Status"; ScriptPath = ".\ops\baseline_status.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $false; RegistryOnly = $true },
    @{ Id = "leaf_boundary_contract"; Name = "Leaf: Boundary Contract Check"; ScriptPath = ".\ops\boundary_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_catalog_contract"; Name = "Leaf: Catalog Contract Check"; ScriptPath = ".\ops\catalog_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_catalog_integrity"; Name = "Leaf: Catalog Integrity Check"; ScriptPath = ".\ops\catalog_integrity_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_category_flow_policy"; Name = "Leaf: Category Flow Policy Check"; ScriptPath = ".\ops\category_flow_policy_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_closeouts_size_gate"; Name = "Leaf: Closeouts Size Gate"; ScriptPath = ".\ops\closeouts_size_gate.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $false; RegistryOnly = $true },
    @{ Id = "leaf_core_persona_contract"; Name = "Leaf: Core Persona Contract Check"; ScriptPath = ".\ops\core_persona_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_daily_snapshot"; Name = "Leaf: Daily Snapshot"; ScriptPath = ".\ops\daily_snapshot.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $false; RegistryOnly = $true },
    @{ Id = "leaf_graveyard_check"; Name = "Leaf: Graveyard Check"; ScriptPath = ".\ops\graveyard_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $false; RegistryOnly = $true },
    @{ Id = "leaf_idempotency_coverage"; Name = "Leaf: Idempotency Coverage Check"; ScriptPath = ".\ops\idempotency_coverage_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $false; RegistryOnly = $true },
    @{ Id = "leaf_listing_contract"; Name = "Leaf: Listing Contract Check"; ScriptPath = ".\ops\listing_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_messaging_contract"; Name = "Leaf: Messaging Contract Check"; ScriptPath = ".\ops\messaging_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_messaging_journey"; Name = "Leaf: Messaging Journey Check"; ScriptPath = ".\ops\messaging_journey_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_messaging_write_contract"; Name = "Leaf: Messaging Write Contract Check"; ScriptPath = ".\ops\messaging_write_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_offer_contract"; Name = "Leaf: Offer Contract Check"; ScriptPath = ".\ops\offer_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_order_contract"; Name = "Leaf: Order Contract Check"; ScriptPath = ".\ops\order_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_pazar_spine"; Name = "Leaf: Pazar Spine Check"; ScriptPath = ".\ops\pazar_spine_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_persona_scope"; Name = "Leaf: Persona Scope Check"; ScriptPath = ".\ops\persona_scope_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_public_ready"; Name = "Leaf: Public Ready Check"; ScriptPath = ".\ops\public_ready_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $false; RegistryOnly = $true },
    @{ Id = "leaf_read_snapshot"; Name = "Leaf: Read Snapshot Check"; ScriptPath = ".\ops\read_snapshot_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_rental_contract"; Name = "Leaf: Rental Contract Check"; ScriptPath = ".\ops\rental_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_repo_payload_audit"; Name = "Leaf: Repo Payload Audit"; ScriptPath = ".\ops\repo_payload_audit.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $false; RegistryOnly = $true },
    @{ Id = "leaf_reservation_contract"; Name = "Leaf: Reservation Contract Check"; ScriptPath = ".\ops\reservation_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_tenant_scope_contract"; Name = "Leaf: Tenant Scope Contract Check"; ScriptPath = ".\ops\tenant_scope_contract_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_v2_gate"; Name = "Leaf: V2 Gate (0-targets)"; ScriptPath = ".\ops\v2_gate.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_world_status"; Name = "Leaf: World Status Check"; ScriptPath = ".\ops\world_status_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },
    @{ Id = "leaf_write_snapshot"; Name = "Leaf: Write Snapshot Check"; ScriptPath = ".\ops\write_snapshot_check.ps1"; Blocking = $false; OnFailAction = $null; Arguments = @(); Optional = $true; CoreDependent = $true; RegistryOnly = $true },

    @{ Id = "rc0_gate"; Name = "RC0 Gate"; ScriptPath = ".\ops\ops.ps1"; Blocking = $true; OnFailAction = "incident_bundle"; Arguments = @("rc0-gate"); Optional = $true; CoreDependent = $false },
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
    $isRegistryOnly = if ($CheckDef.RegistryOnly) { $CheckDef.RegistryOnly } else { $false }
    
    $exitCode = 0
    $status = "PASS"
    $notes = ""
    $blocking = $CheckDef.Blocking

    # Compatibility: scripts moved under ops/_checks and ops/_tools.
    # If registry still points to .\ops\<name>.ps1, auto-resolve to new location.
    if ($scriptPath -and -not $isInline) {
        try {
            if (-not (Test-Path $scriptPath)) {
                $leaf = Split-Path -Leaf $scriptPath
                $candidates = @(
                    (".\\ops\\_checks\\$leaf"),
                    (".\\ops\\_tools\\$leaf")
                )
                foreach ($cand in $candidates) {
                    if (Test-Path $cand) {
                        $scriptPath = $cand
                        break
                    }
                }
            }
        } catch {
            # Best-effort only; fall through to normal handling
        }
    }

    # Registry-only entries: listed for drift guard discoverability, not executed in ops_status.
    if ($isRegistryOnly) {
        # Keep these in the registry for ops_drift_guard, but do not show them in the dashboard
        # (avoids clutter / confusion for humans).
        return @{
            Status = "SKIP"
            ExitCode = 0
            Blocking = $false
        }
    }

    # Optional checks are CI-only by default (to keep ops_status usable in local/dev)
    if ($isOptional -and -not $Ci) {
        $status = "SKIP"
        $exitCode = 0
        $notes = "OPTIONAL_DISABLED: run with -Ci to enable"
        $blocking = $false

        $script:results += [PSCustomObject]@{
            Check = $checkName
            Status = $status
            ExitCode = $exitCode
            Notes = $notes
            Blocking = $blocking
            CheckId = $CheckDef.Id
        }

        return @{
            Status = $status
            ExitCode = $exitCode
            Blocking = $blocking
        }
    }
    
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
            Blocking = $blocking
            CheckId = $CheckDef.Id
        }
        
        return @{
            Status = $status
            ExitCode = $exitCode
            Blocking = $blocking
        }
    }

    # Only print "Running ..." for checks that will actually execute.
    Write-Host "Running $checkName..." -ForegroundColor Yellow
    
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
    $blockingNote = if ($blocking) { "(BLOCKING)" } else { "(NON-BLOCKING)" }
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
        Blocking = $blocking
        CheckId = $CheckDef.Id
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
        Blocking = $blocking
    }
}

# Helper: Check error contract (422 and 404 envelopes)
function Test-ErrorContract {
    Write-Host "Running Error Contract Check..." -ForegroundColor Yellow
    
    $status = "PASS"
    $exitCode = 0
    $notes = ""
    
    try {
        $helper = Join-Path $scriptDir "_lib\error_contract.ps1"
        if (-not (Test-Path $helper)) {
            $status = "FAIL"
            $exitCode = 1
            $notes = "Missing helper: $helper"
        } else {
            . $helper
            $res = Invoke-ErrorContractCheck -BaseUrl "http://localhost:8080"
            $status = $res.Status
            $exitCode = [int]$res.ExitCode
            $notes = [string]$res.Notes
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

# In local mode, hide optional SKIP rows to reduce “scary” noise.
# (We still count them in the summary; run with -Ci to execute them.)
$displayResults = $script:results
$hiddenOptionalSkips = 0
if (-not $Ci) {
    $hiddenOptionalSkips = ($script:results | Where-Object { $_.Status -eq "SKIP" -and $_.Notes -like "OPTIONAL_DISABLED*" }).Count
    $displayResults = $script:results | Where-Object { -not ($_.Status -eq "SKIP" -and $_.Notes -like "OPTIONAL_DISABLED*") }
}

# Print rows using helper (if available) or Format-Table
if (Get-Command Write-OpsTableRow -ErrorAction SilentlyContinue) {
    foreach ($result in $displayResults) {
        Write-OpsTableRow -Check $result.Check -Status $result.Status -ExitCode $result.ExitCode -Notes $result.Notes
    }
} else {
    $displayResults | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize
}

Write-Host ""
if (-not $Ci -and $hiddenOptionalSkips -gt 0) {
    Write-Host ("(hidden) {0} optional checks skipped. Run with -Ci to enable." -f $hiddenOptionalSkips) -ForegroundColor Gray
    Write-Host ""
}

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
if (-not $Ci -and $hiddenOptionalSkips -gt 0) {
    Write-Host "PASS: $passCount, WARN: $warnCount, FAIL: $failCount, SKIP: $skipCount (optional hidden: $hiddenOptionalSkips)" -ForegroundColor Gray
} else {
    Write-Host "PASS: $passCount, WARN: $warnCount, FAIL: $failCount, SKIP: $skipCount" -ForegroundColor Gray
}
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
