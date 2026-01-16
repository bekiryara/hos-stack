# release_bundle.ps1 - RC0 Release Bundle Generator
# Creates a timestamped folder with ops evidence, snapshots, and metadata
# PowerShell 5.1 compatible

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

if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== RC0 RELEASE BUNDLE GENERATOR ==="
} else {
    Write-Host "=== RC0 RELEASE BUNDLE GENERATOR ===" -ForegroundColor Cyan
}
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Preflight: Repo Clean Guard (RC0 requires clean repo)
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "Preflight: Checking repo cleanliness..."
} else {
    Write-Host "Preflight: Checking repo cleanliness..." -ForegroundColor Yellow
}
try {
    $gitStatus = git status --porcelain 2>&1
    $gitStatusLines = ($gitStatus -split "`n" | Where-Object { $_.Trim() -ne "" })
    $uncommittedCount = $gitStatusLines.Count
    
    if ($uncommittedCount -gt 0) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "RC0 bundle requires clean repo. Found $uncommittedCount uncommitted change(s)."
            Write-Info "Commit or stash changes; RC0 requires clean repo."
            Write-Info "Uncommitted changes:"
            $gitStatusLines | ForEach-Object { Write-Info "  $_" }
        } else {
            Write-Host "[FAIL] RC0 bundle requires clean repo. Found $uncommittedCount uncommitted change(s)." -ForegroundColor Red
            Write-Host "Commit or stash changes; RC0 requires clean repo." -ForegroundColor Yellow
        }
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
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "RC0 bundle requires clean repo. Found non-ASCII filenames in root:"
            $rootItems | ForEach-Object { Write-Info "  $($_.Name)" }
            Write-Info "Remove or rename non-ASCII artifacts; RC0 requires clean repo."
        } else {
            Write-Host "[FAIL] RC0 bundle requires clean repo. Found non-ASCII filenames in root." -ForegroundColor Red
        }
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
    
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Pass "Repo is clean (no uncommitted changes, no non-ASCII artifacts)"
    } else {
        Write-Host "[OK] Repo is clean" -ForegroundColor Green
    }
} catch {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "Failed to check repo cleanliness: $($_.Exception.Message)"
    } else {
        Write-Host "[FAIL] Failed to check repo cleanliness: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pop-Location
    Invoke-OpsExit 1
    return 1
}

# Create release bundle folder
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundleFolder = "_archive\releases\rc0-$timestamp"

if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "Creating release bundle folder: $bundleFolder"
} else {
    Write-Host "Creating release bundle folder: $bundleFolder" -ForegroundColor Yellow
}

try {
    if (-not (Test-Path "_archive\releases")) {
        New-Item -ItemType Directory -Path "_archive\releases" -Force | Out-Null
    }
    if (Test-Path $bundleFolder) {
        Remove-Item -Path $bundleFolder -Recurse -Force
    }
    New-Item -ItemType Directory -Path $bundleFolder -Force | Out-Null
    
    if (-not (Test-Path $bundleFolder)) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "Failed to create bundle folder: $bundleFolder"
        } else {
            Write-Host "[FAIL] Failed to create bundle folder: $bundleFolder" -ForegroundColor Red
        }
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
} catch {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "Error creating bundle folder: $($_.Exception.Message)"
    } else {
        Write-Host "[FAIL] Error creating bundle folder: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pop-Location
    Invoke-OpsExit 1
    return 1
}

# Track status
$hasWarn = $false
$collected = 0

# Helper: Run script and capture output to file (best-effort, never hard fail)
function Invoke-ScriptCapture {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [string]$OutputFile,
        [string]$Description,
        [bool]$WarnIfMissing = $true
    )
    
    Write-Host "Capturing ${Description}..." -ForegroundColor Yellow
    try {
        if (-not (Test-Path $ScriptPath)) {
            if ($WarnIfMissing) {
                "[SKIP] Script not found: $ScriptPath" | Set-Content -Path $OutputFile -Encoding UTF8
                Write-Host "  [WARN] Script not found: $ScriptPath" -ForegroundColor Yellow
                $script:hasWarn = $true
            } else {
                "[SKIP] Script not found: $ScriptPath" | Set-Content -Path $OutputFile -Encoding UTF8
                Write-Host "  [SKIP] Script not found: $ScriptPath" -ForegroundColor Gray
            }
            return
        }
        
        if ($null -eq $Arguments) {
            $Arguments = @()
        }
        # Capture ALL streams (*>&1) to get Write-Host, Information stream, etc.
        $output = & $ScriptPath @Arguments *>&1 | Out-String
        $exitCode = $LASTEXITCODE
        
        # Use Set-Content with UTF8 encoding (no BOM in PowerShell 5.1)
        # Note: PowerShell 5.1 Set-Content -Encoding UTF8 creates UTF-8 with BOM
        # To avoid BOM, we use a workaround: write bytes directly
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText((Resolve-Path $OutputFile -ErrorAction SilentlyContinue).Path, $output, $utf8NoBom)
        
        # Validation: Check if output is non-empty and contains expected markers
        $isValid = $true
        $validationErrors = @()
        
        if ($output.Length -lt 5) {
            $isValid = $false
            $validationErrors += "Output suspiciously small (< 5 chars)"
        }
        
        # Expected markers validation (based on script type)
        $expectedMarkers = @()
        if ($ScriptPath -like "*ops_status*") {
            $expectedMarkers = @("OPS STATUS", "OVERALL STATUS", "Check")
        } elseif ($ScriptPath -like "*doctor*") {
            $expectedMarkers = @("DOCTOR", "OVERALL STATUS")
        } elseif ($ScriptPath -like "*conformance*") {
            $expectedMarkers = @("CONFORMANCE", "OVERALL STATUS")
        } elseif ($ScriptPath -like "*schema_snapshot*") {
            $expectedMarkers = @("SCHEMA SNAPSHOT", "CREATE TABLE")
        } elseif ($ScriptPath -like "*routes_snapshot*") {
            $expectedMarkers = @("ROUTES SNAPSHOT", "Snapshot routes")
        }
        
        if ($expectedMarkers.Count -gt 0) {
            foreach ($marker in $expectedMarkers) {
                if ($output -notmatch [regex]::Escape($marker)) {
                    $isValid = $false
                    $validationErrors += "Missing expected marker: $marker"
                }
            }
        }
        
        if (-not $isValid) {
            $errorMsg = "[VALIDATION FAIL] $($validationErrors -join '; ')"
            $errorMsg | Add-Content -Path $OutputFile -Encoding UTF8
            Write-Host "  [FAIL] ${Description}: $($validationErrors -join '; ')" -ForegroundColor Red
            $script:hasWarn = $true
        }
        
        if ($exitCode -eq 0) {
            Write-Host "  [OK] $(Split-Path -Leaf $OutputFile)" -ForegroundColor Green
        } elseif ($exitCode -eq 2) {
            Write-Host "  [WARN] $(Split-Path -Leaf $OutputFile)" -ForegroundColor Yellow
            $script:hasWarn = $true
        } else {
            Write-Host "  [WARN] $(Split-Path -Leaf $OutputFile) (exit code: $exitCode)" -ForegroundColor Yellow
            $script:hasWarn = $true
        }
        
        $script:collected++
    } catch {
        $errorMsg = "Error: $($_.Exception.Message)"
        try {
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText((Resolve-Path $OutputFile -ErrorAction SilentlyContinue).Path, $errorMsg, $utf8NoBom)
        } catch {
            # Fallback to Set-Content if Resolve-Path fails
            $errorMsg | Set-Content -Path $OutputFile -Encoding UTF8
        }
        Write-Host "  [WARN] ${Description}: $($_.Exception.Message)" -ForegroundColor Yellow
        $script:hasWarn = $true
        $script:collected++
    }
}

# 1) meta.txt: timestamp, git branch, git commit, git status --porcelain summary, docker version, compose version
Write-Host "=== Collecting Metadata ===" -ForegroundColor Cyan
try {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $branch = & git rev-parse --abbrev-ref HEAD 2>&1
    $commit = & git rev-parse HEAD 2>&1
    $gitStatus = & git status --porcelain 2>&1 | Out-String
    $gitStatusSummary = if ($gitStatus.Trim() -eq "") { "clean" } else { "dirty" }
    
    # Docker version (best-effort, no docker -> WARN)
    $dockerVersion = "not available"
    try {
        $dockerVersionOutput = & docker --version 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $dockerVersionOutput -match 'Docker version\s+([^\s,]+)') {
            $dockerVersion = $matches[1]
        }
    } catch {
        $hasWarn = $true
    }
    
    # Compose version (best-effort, no compose -> WARN)
    $composeVersion = "not available"
    try {
        $composeVersionOutput = & docker compose version 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $composeVersionOutput -match 'Docker Compose version\s+v?([^\s,]+)') {
            $composeVersion = $matches[1]
        }
    } catch {
        $hasWarn = $true
    }
    
    $metaContent = @"
RC0 Release Bundle Metadata
Generated: $timestamp
Git Branch: $branch
Git Commit: $commit
Git Status: $gitStatusSummary
Docker Version: $dockerVersion
Compose Version: $composeVersion

Git Status Details:
$gitStatus
"@
    
    # Use UTF-8 no-BOM encoding
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("${bundleFolder}\meta.txt", ($metaContent -join "`n"), $utf8NoBom)
    Write-Host "  [OK] meta.txt" -ForegroundColor Green
    $collected++
} catch {
        # Use UTF-8 no-BOM encoding
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText("${bundleFolder}\meta.txt", "Error collecting metadata: $($_.Exception.Message)", $utf8NoBom)
    Write-Host "  [WARN] Failed to collect metadata: $($_.Exception.Message)" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# 2) ops_status.txt: run_ops_status.ps1
Write-Host ""
Write-Host "=== Collecting Ops Evidence ===" -ForegroundColor Cyan
$opsStatusScript = "${scriptDir}\run_ops_status.ps1"
if (-not (Test-Path $opsStatusScript)) {
    $opsStatusScript = "${scriptDir}\ops_status.ps1"
}
# Use run_ops_status.ps1 wrapper if available (prevents terminal closure)
$opsStatusScript = "${scriptDir}\run_ops_status.ps1"
if (-not (Test-Path $opsStatusScript)) {
    $opsStatusScript = "${scriptDir}\ops_status.ps1"
}
$opsStatusOutput = & $opsStatusScript -Ci *>&1 | Out-String
$opsStatusExitCode = $LASTEXITCODE
# Use UTF-8 no-BOM encoding
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("${bundleFolder}\ops_status.txt", $opsStatusOutput, $utf8NoBom)

# Validate ops_status.txt contains expected markers
if ($opsStatusOutput.Length -lt 5 -or 
    $opsStatusOutput -notmatch "OPS STATUS" -or 
    $opsStatusOutput -notmatch "OVERALL STATUS" -or 
    $opsStatusOutput -notmatch "Check") {
    $errorMsg = "[VALIDATION FAIL] ops_status.txt missing expected markers (OPS STATUS, OVERALL STATUS, Check)"
    $errorMsg | Add-Content -Path "${bundleFolder}\ops_status.txt" -Encoding UTF8
    Write-Host "  [FAIL] ops_status.txt validation failed - missing expected markers" -ForegroundColor Red
    $hasWarn = $true
}
if ($opsStatusExitCode -eq 0) {
    Write-Host "  [OK] ops_status.txt" -ForegroundColor Green
} elseif ($opsStatusExitCode -eq 2) {
    Write-Host "  [WARN] ops_status.txt" -ForegroundColor Yellow
    $hasWarn = $true
} else {
    Write-Host "  [WARN] ops_status.txt (exit code: $opsStatusExitCode)" -ForegroundColor Yellow
    $hasWarn = $true
}
$collected++

# 3) incident_bundle_link.txt: If ops_status FAIL and an incident bundle was produced, record path
Write-Host "Checking for incident bundle..." -ForegroundColor Yellow
$incidentBundlePath = $null
if ($opsStatusExitCode -ne 0) {
    # Check for most recent incident bundle in _archive/incidents/
    $incidentsDir = "_archive\incidents"
    if (Test-Path $incidentsDir) {
        $incidentFolders = Get-ChildItem -Path $incidentsDir -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        if ($incidentFolders.Count -gt 0) {
            $incidentBundlePath = $incidentFolders[0].FullName
        }
    }
}
if ($incidentBundlePath) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("${bundleFolder}\incident_bundle_link.txt", $incidentBundlePath, $utf8NoBom)
    Write-Host "  [OK] incident_bundle_link.txt (path: $incidentBundlePath)" -ForegroundColor Green
    $collected++
} else {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("${bundleFolder}\incident_bundle_link.txt", "No incident bundle found (ops_status exit code: $opsStatusExitCode)", $utf8NoBom)
    Write-Host "  [SKIP] incident_bundle_link.txt (no incident bundle)" -ForegroundColor Gray
    $collected++
}

# 3) doctor.txt
Invoke-ScriptCapture -ScriptPath "${scriptDir}\doctor.ps1" -OutputFile "${bundleFolder}\doctor.txt" -Description "Doctor output"

# 4) verify.txt (if available)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\verify.ps1" -OutputFile "${bundleFolder}\verify.txt" -Description "Verify output" -WarnIfMissing $false

# 5) conformance.txt
Invoke-ScriptCapture -ScriptPath "${scriptDir}\conformance.ps1" -OutputFile "${bundleFolder}\conformance.txt" -Description "Conformance output"

# 6) env_contract.txt (no docker required)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\env_contract.ps1" -OutputFile "${bundleFolder}\env_contract.txt" -Description "Env Contract output" -WarnIfMissing $false

# 7) security_audit.txt
Invoke-ScriptCapture -ScriptPath "${scriptDir}\security_audit.ps1" -OutputFile "${bundleFolder}\security_audit.txt" -Description "Security Audit output" -WarnIfMissing $false

# 8) tenant_boundary.txt (if secrets missing -> WARN, still captured)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\tenant_boundary_check.ps1" -OutputFile "${bundleFolder}\tenant_boundary.txt" -Description "Tenant Boundary output" -WarnIfMissing $false

# 9) session_posture.txt (if docker missing -> WARN)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\session_posture_check.ps1" -OutputFile "${bundleFolder}\session_posture.txt" -Description "Session Posture output" -WarnIfMissing $false

# 10) observability_status.txt (if obs not running -> WARN)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\observability_status.ps1" -OutputFile "${bundleFolder}\observability_status.txt" -Description "Observability Status output" -WarnIfMissing $false

# 4) routes_snapshot.txt: include ops/snapshots/routes.pazar.json if exists
Write-Host ""
Write-Host "=== Collecting Snapshots ===" -ForegroundColor Cyan
if (Test-Path "ops\snapshots\routes.pazar.json") {
    Copy-Item -Path "ops\snapshots\routes.pazar.json" -Destination "${bundleFolder}\routes_snapshot.txt" -Force
    Write-Host "  [OK] routes_snapshot.txt" -ForegroundColor Green
    $collected++
} else {
    "[SKIP] routes.pazar.json not found" | Out-File -FilePath "${bundleFolder}\routes_snapshot.txt" -Encoding UTF8
    Write-Host "  [WARN] routes.pazar.json not found" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# 5) schema_snapshot.txt: include ops/snapshots/schema.pazar.sql if exists
if (Test-Path "ops\snapshots\schema.pazar.sql") {
    Copy-Item -Path "ops\snapshots\schema.pazar.sql" -Destination "${bundleFolder}\schema_snapshot.txt" -Force
    Write-Host "  [OK] schema_snapshot.txt" -ForegroundColor Green
    $collected++
} else {
    "[SKIP] schema.pazar.sql not found" | Out-File -FilePath "${bundleFolder}\schema_snapshot.txt" -Encoding UTF8
    Write-Host "  [WARN] schema.pazar.sql not found" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# 6) changelog_unreleased.txt: extract [Unreleased] section from CHANGELOG.md
Write-Host ""
Write-Host "=== Collecting Version Info ===" -ForegroundColor Cyan
if (Test-Path "CHANGELOG.md") {
    try {
        $changelogContent = Get-Content "CHANGELOG.md" -Raw -Encoding UTF8
        if ($changelogContent -match '##\s*\[Unreleased\]\s*([\s\S]*?)(?=##\s*\[|\Z)') {
            $unreleasedSection = $matches[1]
            $unreleasedSection | Out-File -FilePath "${bundleFolder}\changelog_unreleased.txt" -Encoding UTF8
            Write-Host "  [OK] changelog_unreleased.txt" -ForegroundColor Green
            $collected++
        } else {
            "No [Unreleased] section found in CHANGELOG.md" | Out-File -FilePath "${bundleFolder}\changelog_unreleased.txt" -Encoding UTF8
            Write-Host "  [WARN] No [Unreleased] section found" -ForegroundColor Yellow
            $hasWarn = $true
            $collected++
        }
    } catch {
        "Error extracting [Unreleased] section: $($_.Exception.Message)" | Out-File -FilePath "${bundleFolder}\changelog_unreleased.txt" -Encoding UTF8
        Write-Host "  [WARN] Failed to extract [Unreleased] section: $($_.Exception.Message)" -ForegroundColor Yellow
        $hasWarn = $true
        $collected++
    }
} else {
    "CHANGELOG.md not found" | Out-File -FilePath "${bundleFolder}\changelog_unreleased.txt" -Encoding UTF8
    Write-Host "  [WARN] CHANGELOG.md not found" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# 7) version.txt: read VERSION if exists
if (Test-Path "VERSION") {
    Copy-Item -Path "VERSION" -Destination "${bundleFolder}\version.txt" -Force
    Write-Host "  [OK] version.txt" -ForegroundColor Green
    $collected++
} else {
    "VERSION file not found" | Out-File -FilePath "${bundleFolder}\version.txt" -Encoding UTF8
    Write-Host "  [WARN] VERSION file not found" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# 8) architecture.txt: docs/ARCHITECTURE.md if exists
Write-Host ""
Write-Host "=== Collecting Documentation ===" -ForegroundColor Cyan
if (Test-Path "docs\ARCHITECTURE.md") {
    Copy-Item -Path "docs\ARCHITECTURE.md" -Destination "${bundleFolder}\architecture.txt" -Force
    Write-Host "  [OK] architecture.txt" -ForegroundColor Green
    $collected++
} else {
    "docs/ARCHITECTURE.md not found" | Out-File -FilePath "${bundleFolder}\architecture.txt" -Encoding UTF8
    Write-Host "  [WARN] docs/ARCHITECTURE.md not found" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# 9) repo_layout.txt: docs/REPO_LAYOUT.md if exists
if (Test-Path "docs\REPO_LAYOUT.md") {
    Copy-Item -Path "docs\REPO_LAYOUT.md" -Destination "${bundleFolder}\repo_layout.txt" -Force
    Write-Host "  [OK] repo_layout.txt" -ForegroundColor Green
    $collected++
} else {
    "docs/REPO_LAYOUT.md not found" | Out-File -FilePath "${bundleFolder}\repo_layout.txt" -Encoding UTF8
    Write-Host "  [WARN] docs/REPO_LAYOUT.md not found" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# 10) rules.txt: docs/RULES.md if exists
if (Test-Path "docs\RULES.md") {
    Copy-Item -Path "docs\RULES.md" -Destination "${bundleFolder}\rules.txt" -Force
    Write-Host "  [OK] rules.txt" -ForegroundColor Green
    $collected++
} else {
    "docs/RULES.md not found" | Out-File -FilePath "${bundleFolder}\rules.txt" -Encoding UTF8
    Write-Host "  [WARN] docs/RULES.md not found" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# 11) proofs_index.txt: list docs/PROOFS/*.md with last write time
$proofsDir = "docs\PROOFS"
if (Test-Path $proofsDir) {
    $proofFiles = Get-ChildItem -Path $proofsDir -Filter "*.md" -ErrorAction SilentlyContinue | Sort-Object Name
    $proofsList = @()
    foreach ($proof in $proofFiles) {
        $proofsList += "$($proof.Name) | LastWriteTime: $($proof.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    }
    if ($proofsList.Count -gt 0) {
        $proofsList -join "`n" | Out-File -FilePath "${bundleFolder}\proofs_index.txt" -Encoding UTF8
        Write-Host "  [OK] proofs_index.txt ($($proofsList.Count) proof files)" -ForegroundColor Green
        $collected++
    } else {
        "No proof files found in docs/PROOFS/" | Out-File -FilePath "${bundleFolder}\proofs_index.txt" -Encoding UTF8
        Write-Host "  [WARN] No proof files found" -ForegroundColor Yellow
        $hasWarn = $true
        $collected++
    }
} else {
    "docs/PROOFS/ directory not found" | Out-File -FilePath "${bundleFolder}\proofs_index.txt" -Encoding UTF8
    Write-Host "  [WARN] docs/PROOFS/ directory not found" -ForegroundColor Yellow
    $hasWarn = $true
    $collected++
}

# Additional ops evidence files (best-effort)
Write-Host ""
Write-Host "=== Collecting Additional Ops Evidence ===" -ForegroundColor Cyan
# doctor.txt
Invoke-ScriptCapture -ScriptPath "${scriptDir}\doctor.ps1" -OutputFile "${bundleFolder}\doctor.txt" -Description "Doctor output"

# verify.txt (if available)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\verify.ps1" -OutputFile "${bundleFolder}\verify.txt" -Description "Verify output" -WarnIfMissing $false

# conformance.txt
Invoke-ScriptCapture -ScriptPath "${scriptDir}\conformance.ps1" -OutputFile "${bundleFolder}\conformance.txt" -Description "Conformance output"

# env_contract.txt (no docker required)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\env_contract.ps1" -OutputFile "${bundleFolder}\env_contract.txt" -Description "Env Contract output" -WarnIfMissing $false

# security_audit.txt
Invoke-ScriptCapture -ScriptPath "${scriptDir}\security_audit.ps1" -OutputFile "${bundleFolder}\security_audit.txt" -Description "Security Audit output" -WarnIfMissing $false

# tenant_boundary.txt (if secrets missing -> WARN, still captured)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\tenant_boundary_check.ps1" -OutputFile "${bundleFolder}\tenant_boundary.txt" -Description "Tenant Boundary output" -WarnIfMissing $false

# session_posture.txt (if docker missing -> WARN)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\session_posture_check.ps1" -OutputFile "${bundleFolder}\session_posture.txt" -Description "Session Posture output" -WarnIfMissing $false

# observability_status.txt (if obs not running -> WARN)
Invoke-ScriptCapture -ScriptPath "${scriptDir}\observability_status.ps1" -OutputFile "${bundleFolder}\observability_status.txt" -Description "Observability Status output" -WarnIfMissing $false

# README_cutover.md: auto-generated short file
Write-Host ""
Write-Host "=== Generating Cutover README ===" -ForegroundColor Cyan
$readmeContent = @"
# RC0 Release Bundle Cutover Guide

This bundle was generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').

## Quick Start

1. **Read START_HERE**: See `docs/START_HERE.md` (or `work/hos/docs/pazar/START_HERE_ajan_onboarding.md` for onboarding)
2. **Start Stack**: Run `.\ops\stack_up.ps1 -Profile all` (or `docker compose up -d` for core services)
3. **Verify Health**: Check `.\ops\verify.ps1` output
4. **Run Ops Status**: Execute `.\ops\run_ops_status.ps1` (or `.\ops\ops_status.ps1`)

## Bundle Contents

This bundle contains:
- **meta.txt**: Git metadata, Docker/Compose versions
- **ops_status.txt**: Unified ops status dashboard output
- **doctor.txt**: Repository health check output
- **verify.txt**: Stack verification output
- **conformance.txt**: Architecture conformance check output
- **env_contract.txt**: Environment contract validation output
- **security_audit.txt**: Security audit output
- **tenant_boundary.txt**: Tenant boundary check output
- **session_posture.txt**: Session posture check output
- **observability_status.txt**: Observability status output
- **routes_snapshot.txt**: API routes snapshot (JSON)
- **schema_snapshot.txt**: Database schema snapshot (SQL)
- **changelog_unreleased.txt**: Unreleased changes from CHANGELOG.md
- **version.txt**: Version file content

## For Full Cutover Steps

See `docs/runbooks/rc0_release.md` for complete 10-step cutover checklist.

## Restoration

To restore from this bundle:
1. Review all evidence files
2. Run `.\ops\stack_up.ps1` to bring up services
3. Verify with `.\ops\verify.ps1` and `.\ops\run_ops_status.ps1`
4. Check snapshots match current state

"@
$readmeContent | Out-File -FilePath "${bundleFolder}\README_cutover.md" -Encoding UTF8
Write-Host "  [OK] README_cutover.md" -ForegroundColor Green
$collected++

# Summary
Write-Host ""
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== RELEASE BUNDLE COMPLETE ==="
} else {
    Write-Host "=== RELEASE BUNDLE COMPLETE ===" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "Bundle folder: $bundleFolder" -ForegroundColor Green
Write-Host "Files collected: $collected" -ForegroundColor Gray
Write-Host ""

# Print RELEASE_BUNDLE_PATH
Write-Host "RELEASE_BUNDLE_PATH=$bundleFolder" -ForegroundColor Yellow

# Exit code: 0 PASS (bundle created), 2 WARN (bundle created but some optional files missing), 1 FAIL (cannot create folder)
Pop-Location
$exitCode = if ($hasWarn) { 2 } else { 0 }
Invoke-OpsExit $exitCode
return $exitCode
