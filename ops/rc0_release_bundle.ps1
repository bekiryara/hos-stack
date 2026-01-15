# rc0_release_bundle.ps1 - RC0 Release Bundle Generator
# Creates a timestamped folder with full RC0 evidence, snapshots, and metadata
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [switch]$Ci
)

$ErrorActionPreference = "Continue"

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

# Ensure we're in repo root
$repoRoot = Split-Path -Parent $scriptDir
Push-Location $repoRoot

Write-Info "=== RC0 RELEASE BUNDLE GENERATOR ==="
Write-Info "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Info ""

# Preflight: Repo Clean Guard (RC0 requires clean repo)
Write-Info "Preflight: Checking repo cleanliness..."
try {
    $gitStatus = git status --porcelain 2>&1
    $gitStatusLines = ($gitStatus -split "`n" | Where-Object { $_.Trim() -ne "" })
    $uncommittedCount = $gitStatusLines.Count
    
    if ($uncommittedCount -gt 0) {
        Write-Fail "RC0 bundle requires clean repo. Found $uncommittedCount uncommitted change(s)."
        Write-Info "Commit or stash changes; RC0 requires clean repo."
        Write-Info "Uncommitted changes:"
        $gitStatusLines | ForEach-Object { Write-Info "  $_" }
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
    
    # Check for non-ASCII filenames in repo root (artifact guard)
    $rootItems = Get-ChildItem -Path $repoRoot -File -ErrorAction SilentlyContinue | Where-Object {
        $name = $_.Name
        # Check if name contains non-ASCII characters
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($name)
        $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
        $name -ne $decoded -or ($name -match '[^\x00-\x7F]')
    }
    
    if ($rootItems.Count -gt 0) {
        Write-Fail "RC0 bundle requires clean repo. Found non-ASCII filenames in root:"
        $rootItems | ForEach-Object { Write-Info "  $($_.Name)" }
        Write-Info "Remove or rename non-ASCII artifacts; RC0 requires clean repo."
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
    
    Write-Pass "Repo is clean (no uncommitted changes, no non-ASCII artifacts)"
} catch {
    Write-Fail "Failed to check repo cleanliness: $($_.Exception.Message)"
    Pop-Location
    Invoke-OpsExit 1
    return 1
}

# Create release bundle folder
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundleFolder = "_archive\releases\rc0-$timestamp"

Write-Info "Creating release bundle folder: $bundleFolder"

try {
    if (-not (Test-Path "_archive\releases")) {
        New-Item -ItemType Directory -Path "_archive\releases" -Force | Out-Null
    }
    if (Test-Path $bundleFolder) {
        Remove-Item -Path $bundleFolder -Recurse -Force
    }
    New-Item -ItemType Directory -Path $bundleFolder -Force | Out-Null
    Write-Pass "Bundle folder created: $bundleFolder"
} catch {
    Write-Fail "Failed to create bundle folder: $($_.Exception.Message)"
    Invoke-OpsExit 1
    return
}

$collectedFiles = @()

# Helper function to collect script output with validation
function Collect-ScriptOutput {
    param(
        [string]$ScriptPath,
        [string]$OutputFile,
        [string]$Description,
        [string[]]$Arguments = @(),
        [string[]]$ExpectedMarkers = @()
    )
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Warn "$Description script not found: $ScriptPath (SKIP)"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText("$bundleFolder\$OutputFile", "[SKIP] Script not found: $ScriptPath", $utf8NoBom)
        return $false
    }
    
    try {
        Write-Info "Collecting $Description..."
        if ($null -eq $Arguments) {
            $Arguments = @()
        }
        # Capture ALL streams (*>&1) to get Write-Host, Information stream, etc.
        $output = & $ScriptPath @Arguments *>&1 | Out-String
        $exitCode = $LASTEXITCODE
        
        # Use UTF-8 no-BOM encoding
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText("$bundleFolder\$OutputFile", $output, $utf8NoBom)
        
        # Validation: Check if output is non-empty and contains expected markers
        $isValid = $true
        $validationErrors = @()
        
        if ($output.Length -lt 5) {
            $isValid = $false
            $validationErrors += "Output suspiciously small (< 5 chars)"
        }
        
        if ($ExpectedMarkers.Count -gt 0) {
            foreach ($marker in $ExpectedMarkers) {
                if ($output -notmatch [regex]::Escape($marker)) {
                    $isValid = $false
                    $validationErrors += "Missing expected marker: $marker"
                }
            }
        }
        
        if (-not $isValid) {
            $errorMsg = "[VALIDATION FAIL] $($validationErrors -join '; ')"
            $errorMsg | Add-Content -Path "$bundleFolder\$OutputFile" -Encoding UTF8
            Write-Fail "  [FAIL] $OutputFile - $($validationErrors -join '; ')"
            return $false
        }
        
        Write-Pass "  [OK] $OutputFile"
        $script:collectedFiles += $OutputFile
        return $true
    } catch {
        Write-Warn "Failed to collect ${Description}: $($_.Exception.Message) (SKIP)"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText("$bundleFolder\$OutputFile", "[ERROR] Failed to collect: $($_.Exception.Message)", $utf8NoBom)
        return $false
    }
}

# Helper function to collect file content
function Collect-FileContent {
    param(
        [string]$SourcePath,
        [string]$OutputFile,
        [string]$Description
    )
    
    if (-not (Test-Path $SourcePath)) {
        Write-Warn "$Description not found: $SourcePath (SKIP)"
        Add-Content -Path "$bundleFolder\$OutputFile" -Value "[SKIP] File not found: $SourcePath"
        return $false
    }
    
    try {
        Write-Info "Collecting $Description..."
        Copy-Item -Path $SourcePath -Destination "$bundleFolder\$OutputFile" -Force
        Write-Pass "  [OK] $OutputFile"
        $script:collectedFiles += $OutputFile
        return $true
    } catch {
        Write-Warn "Failed to collect ${Description}: $($_.Exception.Message) (SKIP)"
        Add-Content -Path "$bundleFolder\$OutputFile" -Value "[ERROR] Failed to collect: $($_.Exception.Message)"
        return $false
    }
}

Write-Info ""
Write-Info "=== Collecting Metadata ==="

# meta.txt - Git metadata
try {
    $metaContent = @()
    $metaContent += "RC0 Release Bundle"
    $metaContent += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $metaContent += ""
    
    # Git info
    try {
        $gitBranch = git rev-parse --abbrev-ref HEAD 2>&1
        $gitCommit = git rev-parse HEAD 2>&1
        $gitStatus = git status --porcelain 2>&1
        $gitStatusLines = ($gitStatus -split "`n" | Where-Object { $_.Trim() -ne "" })
        $gitStatusCount = $gitStatusLines.Count
        $repoClean = ($gitStatusCount -eq 0)
        
        $metaContent += "Git Branch: $gitBranch"
        $metaContent += "Git Commit: $gitCommit"
        $metaContent += "Repo Clean: $repoClean"
        $metaContent += "Git Status: $gitStatusCount uncommitted changes"
        if ($gitStatusCount -eq 0) {
            $metaContent += "Git Status Details: clean"
        } else {
            $metaContent += "Git Status Details:"
            $metaContent += $gitStatus
        }
    } catch {
        $metaContent += "Git info: Not available"
    }
    
    Set-Content -Path "$bundleFolder\meta.txt" -Value ($metaContent -join "`n")
    Write-Pass "  [OK] meta.txt"
    $collectedFiles += "meta.txt"
} catch {
    Write-Warn "Failed to create meta.txt: $($_.Exception.Message) (SKIP)"
}

Write-Info ""
Write-Info "=== Collecting Ops Evidence ==="

# rc0_check.txt - RC0 gate output (capture exit code for incident bundle link)
Write-Info "Collecting RC0 Check..."
try {
    $rc0CheckOutput = & "ops\rc0_check.ps1" *>&1 | Out-String
    $rc0CheckExitCode = $LASTEXITCODE
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$bundleFolder\rc0_check.txt", $rc0CheckOutput, $utf8NoBom)
    
    # Validate rc0_check.txt contains expected markers
    if ($rc0CheckOutput.Length -lt 5 -or 
        $rc0CheckOutput -notmatch "RC0" -or 
        $rc0CheckOutput -notmatch "OVERALL STATUS") {
        $errorMsg = "[VALIDATION FAIL] rc0_check.txt missing expected markers (RC0, OVERALL STATUS)"
        $errorMsg | Add-Content -Path "$bundleFolder\rc0_check.txt" -Encoding UTF8
        Write-Fail "rc0_check.txt validation failed - missing expected markers"
    } else {
        Write-Pass "  [OK] rc0_check.txt"
        $collectedFiles += "rc0_check.txt"
    }
    
    # If rc0_check FAIL, find and link incident bundle
    if ($rc0CheckExitCode -ne 0) {
        $incidentsDir = "_archive\incidents"
        if (Test-Path $incidentsDir) {
            $incidentFolders = Get-ChildItem -Path $incidentsDir -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            if ($incidentFolders.Count -gt 0) {
                $incidentBundlePath = $incidentFolders[0].FullName
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText("$bundleFolder\incident_bundle_link.txt", $incidentBundlePath, $utf8NoBom)
                Write-Pass "  [OK] incident_bundle_link.txt (path: $incidentBundlePath)"
                $collectedFiles += "incident_bundle_link.txt"
            }
        }
    }
} catch {
    Write-Warn "Failed to collect RC0 Check: $($_.Exception.Message) (SKIP)"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$bundleFolder\rc0_check.txt", "[ERROR] Failed to collect: $($_.Exception.Message)", $utf8NoBom)
}

# ops_status.txt - Use run_ops_status.ps1 wrapper if available (prevents terminal closure)
if (Test-Path "ops\run_ops_status.ps1") {
    Collect-ScriptOutput -ScriptPath "ops\run_ops_status.ps1" -OutputFile "ops_status.txt" -Description "Ops Status" -ExpectedMarkers @("OPS STATUS", "OVERALL STATUS", "Check")
} else {
    Collect-ScriptOutput -ScriptPath "ops\ops_status.ps1" -OutputFile "ops_status.txt" -Description "Ops Status" -ExpectedMarkers @("OPS STATUS", "OVERALL STATUS", "Check")
}

# Individual check outputs (if scripts exist) - with expected markers validation
Collect-ScriptOutput -ScriptPath "ops\conformance.ps1" -OutputFile "conformance.txt" -Description "Conformance" -ExpectedMarkers @("CONFORMANCE", "OVERALL STATUS")
Collect-ScriptOutput -ScriptPath "ops\security_audit.ps1" -OutputFile "security_audit.txt" -Description "Security Audit" -ExpectedMarkers @("SECURITY", "OVERALL STATUS")
Collect-ScriptOutput -ScriptPath "ops\env_contract.ps1" -OutputFile "env_contract.txt" -Description "Environment Contract" -ExpectedMarkers @("ENV CONTRACT", "OVERALL STATUS")
Collect-ScriptOutput -ScriptPath "ops\session_posture_check.ps1" -OutputFile "session_posture.txt" -Description "Session Posture" -ExpectedMarkers @("SESSION", "OVERALL STATUS")
Collect-ScriptOutput -ScriptPath "ops\slo_check.ps1" -OutputFile "slo_check.txt" -Description "SLO Check" -Arguments @("-N", 30) -ExpectedMarkers @("SLO", "Summary:")
Collect-ScriptOutput -ScriptPath "ops\observability_status.ps1" -OutputFile "observability_status.txt" -Description "Observability Status" -ExpectedMarkers @("OBSERVABILITY", "OVERALL STATUS")
Collect-ScriptOutput -ScriptPath "ops\product_e2e.ps1" -OutputFile "product_e2e.txt" -Description "Product E2E" -ExpectedMarkers @("PRODUCT E2E", "OVERALL STATUS")

Write-Info ""
Write-Info "=== Collecting Snapshots ==="

# routes_snapshot.txt - Run routes_snapshot.ps1 and capture output
Collect-ScriptOutput -ScriptPath "ops\routes_snapshot.ps1" -OutputFile "routes_snapshot.txt" -Description "Routes Snapshot" -ExpectedMarkers @("ROUTES SNAPSHOT", "Snapshot routes", "Current routes")

# Also copy the snapshot file if it exists
if (Test-Path "ops\snapshots\routes.pazar.json") {
    Collect-FileContent -SourcePath "ops\snapshots\routes.pazar.json" -OutputFile "routes.pazar.json" -Description "Routes Snapshot JSON"
}

# schema_snapshot.txt - Run schema_snapshot.ps1 and capture output
Collect-ScriptOutput -ScriptPath "ops\schema_snapshot.ps1" -OutputFile "schema_snapshot.txt" -Description "Schema Snapshot" -ExpectedMarkers @("SCHEMA SNAPSHOT", "CREATE TABLE", "Snapshot generated")

# Also copy the snapshot file if it exists
if (Test-Path "ops\snapshots\schema.pazar.sql") {
    Collect-FileContent -SourcePath "ops\snapshots\schema.pazar.sql" -OutputFile "schema.pazar.sql" -Description "Schema Snapshot SQL"
}

Write-Info ""
Write-Info "=== Collecting Logs (if Docker available) ==="

# Check if docker is available
$dockerAvailable = $false
try {
    $null = docker compose ps 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerAvailable = $true
    }
} catch {
    # Docker not available
}

if ($dockerAvailable) {
    try {
        Write-Info "Collecting last logs from pazar-app..."
        $pazarLogs = docker compose logs --tail=500 pazar-app 2>&1 | Out-String
        Set-Content -Path "$bundleFolder\logs_pazar_app.txt" -Value $pazarLogs
        Write-Pass "  [OK] logs_pazar_app.txt"
        $collectedFiles += "logs_pazar_app.txt"
    } catch {
        Write-Warn "Failed to collect pazar-app logs: $($_.Exception.Message) (SKIP)"
    }
    
    try {
        Write-Info "Collecting last logs from hos-api..."
        $hosLogs = docker compose logs --tail=500 hos-api 2>&1 | Out-String
        Set-Content -Path "$bundleFolder\logs_hos_api.txt" -Value $hosLogs
        Write-Pass "  [OK] logs_hos_api.txt"
        $collectedFiles += "logs_hos_api.txt"
    } catch {
        Write-Warn "Failed to collect hos-api logs: $($_.Exception.Message) (SKIP)"
    }
} else {
    Write-Info "Docker not available - skipping log collection"
}

Write-Info ""
Write-Info "=== Generating Release Note Template ==="

# release_note.md template
try {
    $releaseNoteContent = @()
    $releaseNoteContent += "# RC0 Release Note"
    $releaseNoteContent += ""
    $releaseNoteContent += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $releaseNoteContent += ""
    $releaseNoteContent += "## RC0 Checklist"
    $releaseNoteContent += ""
    $releaseNoteContent += "### Checks Performed"
    $releaseNoteContent += ""
    $releaseNoteContent += "- [ ] Repository Doctor (doctor.ps1)"
    $releaseNoteContent += "- [ ] Stack Verification (verify.ps1)"
    $releaseNoteContent += "- [ ] Conformance (conformance.ps1)"
    $releaseNoteContent += "- [ ] Security Audit (security_audit.ps1)"
    $releaseNoteContent += "- [ ] Environment Contract (env_contract.ps1)"
    $releaseNoteContent += "- [ ] Session Posture (session_posture_check.ps1)"
    $releaseNoteContent += "- [ ] SLO Check (slo_check.ps1 -N 30)"
    $releaseNoteContent += "- [ ] Observability Status (observability_status.ps1) - Optional"
    $releaseNoteContent += "- [ ] Product E2E (product_e2e.ps1) - Optional"
    $releaseNoteContent += "- [ ] Tenant Boundary (tenant_boundary_check.ps1)"
    $releaseNoteContent += ""
    $releaseNoteContent += "### Results Summary"
    $releaseNoteContent += ""
    $releaseNoteContent += "<!-- Paste rc0_check.txt summary here -->"
    $releaseNoteContent += ""
    $releaseNoteContent += "### What Passed"
    $releaseNoteContent += ""
    $releaseNoteContent += "<!-- List checks that passed -->"
    $releaseNoteContent += ""
    $releaseNoteContent += "### What Warned"
    $releaseNoteContent += ""
    $releaseNoteContent += "<!-- List checks that warned (if any) -->"
    $releaseNoteContent += ""
    $releaseNoteContent += "### What Was Skipped"
    $releaseNoteContent += ""
    $releaseNoteContent += "<!-- List checks that were skipped (if any) -->"
    $releaseNoteContent += ""
    $releaseNoteContent += "## Bundle Contents"
    $releaseNoteContent += ""
    $releaseNoteContent += "This bundle contains the following artifacts:"
    $releaseNoteContent += ""
    foreach ($file in $collectedFiles) {
        $releaseNoteContent += "- ``$file``"
    }
    $releaseNoteContent += ""
    $releaseNoteContent += "## Next Steps"
    $releaseNoteContent += ""
    $releaseNoteContent += "1. Review all collected artifacts"
    $releaseNoteContent += "2. Verify rc0_check shows PASS/WARN (no FAIL)"
    $releaseNoteContent += "3. Update release_note.md with actual results"
    $releaseNoteContent += "4. Proceed with RC0 release if all checks pass"
    
    Set-Content -Path "$bundleFolder\release_note.md" -Value ($releaseNoteContent -join "`n")
    Write-Pass "  [OK] release_note.md"
    $collectedFiles += "release_note.md"
} catch {
    Write-Warn "Failed to create release_note.md: $($_.Exception.Message) (SKIP)"
}

Write-Info ""
Write-Info "=== RC0 RELEASE BUNDLE COMPLETE ==="
Write-Info ""
Write-Info "Bundle folder: $bundleFolder"
Write-Info "Files collected: $($collectedFiles.Count)"
Write-Info ""
Write-Host "RC0_RELEASE_BUNDLE_PATH=$bundleFolder" -ForegroundColor Cyan

Invoke-OpsExit 0
return 0

