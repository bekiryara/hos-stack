#!/usr/bin/env pwsh
# Repository Health Doctor Script
# Comprehensive diagnostics for repository health

$ErrorActionPreference = "Continue"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== REPOSITORY DOCTOR ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$results = @()
$hasFailures = $false

# 0. Check if running from repo root (WARN only, not FAIL)
Write-Host "[0] Checking execution directory..." -ForegroundColor Yellow
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$currentDir = (Get-Location).Path

# Normalize paths for comparison
$repoRootNormalized = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
$currentDirNormalized = [System.IO.Path]::GetFullPath($currentDir).TrimEnd('\')

if ($repoRootNormalized -ne $currentDirNormalized) {
    $results += @{
        Check = "Execution Directory"
        Status = "WARN"
        Details = "Not running from repo root. Current: $currentDirNormalized, Expected: $repoRootNormalized"
    }
    Write-Host "WARNING: Script should be run from repo root" -ForegroundColor Yellow
    Write-Host "Hint: cd $repoRootNormalized" -ForegroundColor Gray
} else {
    $results += @{
        Check = "Execution Directory"
        Status = "PASS"
        Details = "Running from repo root"
    }
}

Write-Host ""

# 0.1. Check for duplicate compose usage patterns (WARN only)
Write-Host "[0.1] Checking for duplicate compose service/port conflicts..." -ForegroundColor Yellow
try {
    $rootComposeFile = "docker-compose.yml"
    $hosComposeFile = "work\hos\docker-compose.yml"
    $conflicts = @()
    
    if ((Test-Path $rootComposeFile) -and (Test-Path $hosComposeFile)) {
        # Check for duplicate service names
        $rootServices = docker compose -f $rootComposeFile config --services 2>&1 | Where-Object { $_ -ne "" }
        $hosServices = docker compose -f $hosComposeFile config --services 2>&1 | Where-Object { $_ -ne "" }
        
        $duplicateServices = $rootServices | Where-Object { $hosServices -contains $_ }
        
        if ($duplicateServices.Count -gt 0) {
            $conflicts += "Duplicate service names: $($duplicateServices -join ', ')"
        }
        
        # Check for port conflicts (simplified: check if both have services on same ports)
        # This is a heuristic check - actual conflicts depend on which compose is used
        $conflictMsg = "Both root and work/hos compose files exist. Ensure obs profile does not start core services."
        if ($conflicts.Count -eq 0 -and $conflictMsg) {
            $conflicts += $conflictMsg
        }
    }
    
    if ($conflicts.Count -gt 0) {
        $results += @{
            Check = "Duplicate Compose Patterns"
            Status = "WARN"
            Details = ($conflicts -join "; ")
        }
        Write-Host "WARNING: Potential compose usage conflicts detected" -ForegroundColor Yellow
        Write-Host "Guidance: Use ops/stack_up.ps1 -Profile obs to start only observability services" -ForegroundColor Gray
    } else {
        $results += @{
            Check = "Duplicate Compose Patterns"
            Status = "PASS"
            Details = "No conflicts detected"
        }
    }
} catch {
    $results += @{
        Check = "Duplicate Compose Patterns"
        Status = "WARN"
        Details = "Could not check: $($_.Exception.Message)"
    }
}

Write-Host ""

# 1. Docker Compose Services Status
Write-Host "[1] Checking Docker Compose services..." -ForegroundColor Yellow
try {
    $composeStatus = docker compose ps --format json 2>&1 | ConvertFrom-Json
    $allUp = $true
    foreach ($service in $composeStatus) {
        $isUp = $service.State -eq "running" -or $service.State -eq "Up"
        $allUp = $allUp -and $isUp
    }
    if ($allUp) {
        $results += @{
            Check = "Docker Compose Services"
            Status = "PASS"
            Details = "All services running"
        }
    } else {
        $results += @{
            Check = "Docker Compose Services"
            Status = "FAIL"
            Details = "One or more services not running"
        }
        $hasFailures = $true
    }
} catch {
    $results += @{
        Check = "Docker Compose Services"
        Status = "FAIL"
        Details = "Error: $($_.Exception.Message)"
    }
    $hasFailures = $true
}

Write-Host ""

# 2. H-OS Health Endpoint
Write-Host "[2] Checking H-OS health endpoint..." -ForegroundColor Yellow
try {
    $hosResponse = Invoke-WebRequest -Uri "http://localhost:3000/v1/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($hosResponse.StatusCode -eq 200) {
        $hosBody = $hosResponse.Content | ConvertFrom-Json
        if ($hosBody.ok -eq $true) {
            $results += @{
                Check = "H-OS Health (/v1/health)"
                Status = "PASS"
                Details = "HTTP 200, ok:true"
            }
        } else {
            $results += @{
                Check = "H-OS Health (/v1/health)"
                Status = "FAIL"
                Details = "HTTP 200 but ok != true"
            }
            $hasFailures = $true
        }
    } else {
        $results += @{
            Check = "H-OS Health (/v1/health)"
            Status = "FAIL"
            Details = "HTTP $($hosResponse.StatusCode)"
        }
        $hasFailures = $true
    }
} catch {
    $results += @{
        Check = "H-OS Health (/v1/health)"
        Status = "WARN"
        Details = "Not accessible: $($_.Exception.Message)"
    }
}

Write-Host ""

# 3. Pazar Up Endpoint
Write-Host "[3] Checking Pazar up endpoint..." -ForegroundColor Yellow
try {
    $pazarResponse = Invoke-WebRequest -Uri "http://localhost:8080/up" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($pazarResponse.StatusCode -eq 200) {
        $results += @{
            Check = "Pazar Up (/up)"
            Status = "PASS"
            Details = "HTTP 200"
        }
    } else {
        $results += @{
            Check = "Pazar Up (/up)"
            Status = "FAIL"
            Details = "HTTP $($pazarResponse.StatusCode)"
        }
        $hasFailures = $true
    }
} catch {
    $results += @{
        Check = "Pazar Up (/up)"
        Status = "WARN"
        Details = "Not accessible: $($_.Exception.Message)"
    }
}

Write-Host ""

# 4. Check Tracked Secrets
Write-Host "[4] Checking for tracked secrets..." -ForegroundColor Yellow
$trackedSecrets = git ls-files | Select-String -Pattern "secrets/|\.env$" -CaseSensitive:$false
if ($trackedSecrets) {
    $secretList = ($trackedSecrets | ForEach-Object { $_.Line }) -join ", "
    $results += @{
        Check = "Tracked Secrets"
        Status = "FAIL"
        Details = "Found: $secretList"
    }
    $hasFailures = $true
} else {
    $results += @{
        Check = "Tracked Secrets"
        Status = "PASS"
        Details = "No secrets/*.txt or .env files tracked"
    }
}

Write-Host ""

# 5. Check Forbidden Root Artifacts
Write-Host "[5] Checking for forbidden root artifacts..." -ForegroundColor Yellow
$forbiddenPatterns = @("*.zip", "*.rar", "*.bak", "*.tmp")
$foundArtifacts = @()
foreach ($pattern in $forbiddenPatterns) {
    $matches = Get-ChildItem -Path . -Filter $pattern -File -ErrorAction SilentlyContinue
    if ($matches) {
        $foundArtifacts += $matches.Name
    }
}
if ($foundArtifacts.Count -gt 0) {
    $artifactList = $foundArtifacts -join ", "
    $results += @{
        Check = "Forbidden Root Artifacts"
        Status = "FAIL"
        Details = "Found: $artifactList"
    }
    $hasFailures = $true
} else {
    $results += @{
        Check = "Forbidden Root Artifacts"
        Status = "PASS"
        Details = "No *.zip, *.rar, *.bak, *.tmp files in root"
    }
}

Write-Host ""

# 6. Check Snapshot Files
Write-Host "[6] Checking snapshot files..." -ForegroundColor Yellow
$requiredSnapshots = @(
    "ops/snapshots/routes.pazar.json",
    "ops/snapshots/schema.pazar.sql"
)
$missingSnapshots = @()
foreach ($snapshot in $requiredSnapshots) {
    if (-not (Test-Path $snapshot)) {
        $missingSnapshots += $snapshot
    }
}
if ($missingSnapshots.Count -gt 0) {
    $missingList = $missingSnapshots -join ", "
    $results += @{
        Check = "Snapshot Files"
        Status = "FAIL"
        Details = "Missing: $missingList"
    }
    $hasFailures = $true
} else {
    $results += @{
        Check = "Snapshot Files"
        Status = "PASS"
        Details = "All required snapshots present"
    }
}

Write-Host ""

# 7. Repository Integrity Check (non-destructive, WARN-only unless critical)
Write-Host "[7] Running repository integrity check..." -ForegroundColor Yellow
if (Test-Path ".\ops\repo_integrity.ps1") {
    try {
        $integrityOutput = & .\ops\repo_integrity.ps1 2>&1 | Out-String
        $integrityExitCode = $LASTEXITCODE
        
        # Extract status from output (look for OVERALL STATUS line)
        if ($integrityOutput -match "OVERALL STATUS:\s*(PASS|WARN|FAIL)") {
            $integrityStatus = $matches[1]
            if ($integrityStatus -eq "FAIL") {
                $results += @{
                    Check = "Repository Integrity"
                    Status = "FAIL"
                    Details = "Critical integrity issues detected (see repo_integrity.ps1 output above)"
                }
                $hasFailures = $true
            } elseif ($integrityStatus -eq "WARN") {
                $results += @{
                    Check = "Repository Integrity"
                    Status = "WARN"
                    Details = "Minor integrity issues detected (non-critical drift)"
                }
            } else {
                $results += @{
                    Check = "Repository Integrity"
                    Status = "PASS"
                    Details = "No integrity issues detected"
                }
            }
        } else {
            $results += @{
                Check = "Repository Integrity"
                Status = "WARN"
                Details = "Could not parse integrity check output"
            }
        }
    } catch {
        $results += @{
            Check = "Repository Integrity"
            Status = "WARN"
            Details = "Error running integrity check: $($_.Exception.Message)"
        }
    }
} else {
    $results += @{
        Check = "Repository Integrity"
        Status = "SKIP"
        Details = "repo_integrity.ps1 not found (optional check)"
    }
}

Write-Host ""
$requiredSnapshots = @(
    "ops/snapshots/routes.pazar.json",
    "ops/snapshots/schema.pazar.sql"
)
$missingSnapshots = @()
foreach ($snapshot in $requiredSnapshots) {
    if (-not (Test-Path $snapshot)) {
        $missingSnapshots += $snapshot
    }
}
if ($missingSnapshots.Count -gt 0) {
    $missingList = $missingSnapshots -join ", "
    $results += @{
        Check = "Snapshot Files"
        Status = "FAIL"
        Details = "Missing: $missingList"
    }
    $hasFailures = $true
} else {
    $results += @{
        Check = "Snapshot Files"
        Status = "PASS"
        Details = "All required snapshots present"
    }
}

Write-Host ""

# Summary Table
Write-Host "=== DOCTOR SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host ("{0,-40} {1,-10} {2}" -f "Check", "Status", "Details")
Write-Host ("-" * 80)
foreach ($result in $results) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "Gray" }
    }
    Write-Host ("{0,-40} {1,-10} {2}" -f $result.Check, $result.Status, $result.Details) -ForegroundColor $color
}

Write-Host ""

# Next Steps
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" } | Measure-Object).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" } | Measure-Object).Count

if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Review failures above" -ForegroundColor Gray
    Write-Host "  2. Run .\ops\triage.ps1 for detailed diagnostics" -ForegroundColor Gray
    Write-Host "  3. Fix issues before committing" -ForegroundColor Gray
    Invoke-OpsExit 1
    return
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: Some checks returned warnings (services may be down)" -ForegroundColor Gray
    Invoke-OpsExit 0
    return
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    Invoke-OpsExit 0
    return
}

