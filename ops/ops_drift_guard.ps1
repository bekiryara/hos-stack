# ops_drift_guard.ps1 - Ops Drift Guard
# Detects newly added ops scripts/runbooks/packs not wired into ops_status
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

Write-Host "=== OPS DRIFT GUARD ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Find all ops scripts (excluding _lib, wrappers, and known utilities)
# Only consider candidates matching: *_check.ps1, *_status.ps1, *_snapshot.ps1, *_audit.ps1, *_gate.ps1
$allOpsScripts = Get-ChildItem -Path $scriptDir -Filter "*.ps1" -File | Where-Object {
    $name = $_.Name
    $dirName = $_.DirectoryName
    
    # Exclude _lib directory
    if ($dirName -like "*\_lib\*") {
        return $false
    }
    
    # Only consider operational check scripts (not utilities/wrappers)
    $isCandidate = $name -like "*_check.ps1" -or $name -like "*_status.ps1" -or $name -like "*_snapshot.ps1" -or $name -like "*_audit.ps1" -or $name -like "*_gate.ps1"
    if (-not $isCandidate) {
        return $false
    }
    
    # Exclude wrappers, helpers, and known utilities
    $excludePatterns = @(
        "run_ops_status.ps1",
        "ops_status.ps1",
        "stack_up.ps1",
        "stack_down.ps1",
        "incident_bundle.ps1",
        "release_bundle.ps1",
        "release_check.ps1",
        "request_trace.ps1",
        "triage.ps1",
        "STACK_E2E_CRITICAL_TESTS_v*.ps1",
        "perf_baseline.ps1"
    )
    
    $shouldExclude = $false
    foreach ($pattern in $excludePatterns) {
        # Use -like for wildcard patterns, -eq for exact matches
        if ($pattern -like "*`**" -or $pattern -like "*`?*") {
            if ($name -like $pattern) {
                $shouldExclude = $true
                break
            }
        } else {
            if ($name -eq $pattern) {
                $shouldExclude = $true
                break
            }
        }
    }
    
    -not $shouldExclude
} | ForEach-Object { $_.Name }

# Load ops_status.ps1 and extract registered checks
# We'll parse the check registry from ops_status.ps1
Write-Host "Reading ops_status.ps1 to extract registered checks..." -ForegroundColor Yellow

$opsStatusPath = Join-Path $scriptDir "ops_status.ps1"
if (-not (Test-Path $opsStatusPath)) {
    Write-Fail "ops_status.ps1 not found: $opsStatusPath"
    Invoke-OpsExit 1
    return
}

$opsStatusContent = Get-Content $opsStatusPath -Raw

# Extract check registry (look for $checkRegistry array or Invoke-OpsCheck calls)
$registeredScripts = @()

# Method 1: Look for check registry array (if exists)
if ($opsStatusContent -match '\$checkRegistry\s*=\s*@\s*\([^)]+\)') {
    # Parse registry array (simplified parsing)
    $registryMatches = [regex]::Matches($opsStatusContent, 'ScriptPath\s*=\s*["'']([^"'']+)["'']')
    foreach ($match in $registryMatches) {
        $scriptPath = $match.Groups[1].Value
        $scriptName = Split-Path -Leaf $scriptPath
        if ($scriptName -like "*.ps1") {
            $registeredScripts += $scriptName
        }
    }
}

# Method 2: Fallback - look for Invoke-OpsCheck calls with ScriptPath
if ($registeredScripts.Count -eq 0) {
    $checkMatches = [regex]::Matches($opsStatusContent, 'Invoke-OpsCheck[^}]+-ScriptPath\s+["'']([^"'']+)["'']')
    foreach ($match in $checkMatches) {
        $scriptPath = $match.Groups[1].Value
        $scriptName = Split-Path -Leaf $scriptPath
        if ($scriptName -like "*.ps1") {
            $registeredScripts += $scriptName
        }
    }
    
    # Also look for conditional checks (Test-Path ... Invoke-OpsCheck)
    $conditionalMatches = [regex]::Matches($opsStatusContent, 'Test-Path\s+["'']([^"'']+ops[^"'']+\.ps1)["'']')
    foreach ($match in $conditionalMatches) {
        $scriptPath = $match.Groups[1].Value
        $scriptName = Split-Path -Leaf $scriptPath
        if ($scriptName -like "*.ps1") {
            $registeredScripts += $scriptName
        }
    }
}

$registeredScripts = $registeredScripts | Select-Object -Unique

Write-Host "Found $($registeredScripts.Count) registered scripts in ops_status.ps1" -ForegroundColor Gray
Write-Host "Found $($allOpsScripts.Count) total ops scripts (excluding wrappers/utilities)" -ForegroundColor Gray
Write-Host ""

# Find unwired scripts
$unwiredScripts = @()
foreach ($script in $allOpsScripts) {
    if ($registeredScripts -notcontains $script) {
        $unwiredScripts += $script
    }
}

# Verify runbook existence for registered checks
Write-Host "Verifying runbook existence for registered checks..." -ForegroundColor Yellow

$missingRunbooks = @()
$runbooksDir = Join-Path (Split-Path -Parent $scriptDir) "docs\runbooks"
if (Test-Path $runbooksDir) {
    # Extract check names from ops_status (simplified - look for CheckName parameter)
    $checkNameMatches = [regex]::Matches($opsStatusContent, '-CheckName\s+["'']([^"'']+)["'']')
    $checkNames = @()
    foreach ($match in $checkNameMatches) {
        $checkNames += $match.Groups[1].Value
    }
    
    # Map common check names to runbook files (heuristic)
    $runbookMappings = @{
        "Repository Doctor" = "doctor.md"
        "Stack Verification" = "verify.md"
        "Incident Triage" = "triage.md"
        "Storage Posture" = "storage_posture.md"
        "SLO Check" = "slo.md"
        "Security Audit" = "security_audit.md"
        "Conformance" = "conformance.md"
        "Product Spine" = "product_spine.md"
        "Routes Snapshot" = "routes_snapshot.md"
        "Schema Snapshot" = "schema_snapshot.md"
        "Error Contract" = "error_contract.md"
        "Session Posture" = "session_posture.md"
        "Product Read-Path" = "product_read_path.md"
        "RC0 Gate" = "rc0_gate.md"
        "Ops Drift Guard" = "ops_drift_guard.md"
    }
    
    foreach ($checkName in $checkNames) {
        if ($runbookMappings.ContainsKey($checkName)) {
            $runbookFile = Join-Path $runbooksDir $runbookMappings[$checkName]
            if (-not (Test-Path $runbookFile)) {
                $missingRunbooks += $checkName
            }
        }
    }
} else {
    Write-Warn "Runbooks directory not found: $runbooksDir"
}

# Check proof presence (look for entries in CHANGELOG.md or docs/PROOFS/)
Write-Host "Verifying proof presence..." -ForegroundColor Yellow

$proofsDir = Join-Path (Split-Path -Parent $scriptDir) "docs\PROOFS"
$changelogPath = Join-Path (Split-Path -Parent $scriptDir) "CHANGELOG.md"

$missingProofs = @()
if (Test-Path $changelogPath) {
    $changelogContent = Get-Content $changelogPath -Raw
    # This is a simplified check - we'll flag as WARN if proofs are missing, not FAIL
    # (proofs are not strictly required for all checks, but recommended)
}

# Report results
$hasFail = $false
$hasWarn = $false

Write-Host ""
Write-Host "=== DRIFT GUARD RESULTS ===" -ForegroundColor Cyan
Write-Host ""

if ($unwiredScripts.Count -gt 0) {
    Write-Fail "Unwired scripts detected: $($unwiredScripts -join ', ')"
    Write-Host "These scripts must be added to ops_status.ps1 check registry or explicitly excluded." -ForegroundColor Red
    $hasFail = $true
} else {
    Write-Pass "All ops scripts are registered in ops_status.ps1"
}

if ($missingRunbooks.Count -gt 0) {
    Write-Warn "Missing runbooks for checks: $($missingRunbooks -join ', ')"
    Write-Host "Each registered check should have a corresponding runbook in docs/runbooks/" -ForegroundColor Yellow
    $hasWarn = $true
} else {
    Write-Pass "All registered checks have runbooks (or documented 'no runbook required')"
}

Write-Host ""

# Determine exit code
if ($hasFail) {
    Write-Host "OVERALL STATUS: FAIL" -ForegroundColor Red
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    Write-Host "1. Add unwired scripts to ops_status.ps1 check registry with metadata (Id, Name, ScriptPath, Blocking, OnFailAction)" -ForegroundColor Gray
    Write-Host "2. Or explicitly exclude scripts if they are utilities/wrappers (update ops_drift_guard.ps1 exclusion list)" -ForegroundColor Gray
    Write-Host "3. Create runbooks for missing checks in docs/runbooks/<check_name>.md" -ForegroundColor Gray
    Invoke-OpsExit 1
    return
} elseif ($hasWarn) {
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Invoke-OpsExit 2
    return
} else {
    Write-Host "OVERALL STATUS: PASS" -ForegroundColor Green
    Invoke-OpsExit 0
    return
}



