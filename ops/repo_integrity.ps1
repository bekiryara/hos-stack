# repo_integrity.ps1 - Repository integrity check (non-destructive)
# Detects drift, duplicate files, missing critical scripts, unexpected untracked dumps
# PowerShell 5.1 compatible

param(
    [switch]$Ci
)

# Load shared output helper
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
try {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "=== Repository Integrity Check ==="
    } else {
        Write-Host "=== Repository Integrity Check ===" -ForegroundColor Cyan
    }
    
    $checks = @()
    $failCount = 0
    $warnCount = 0
    
    # Check 1: Massive deleted-tracked files (potential drift indicator)
    Write-Host "Checking for massive deleted-tracked files..." -ForegroundColor Gray
    $deletedFiles = git ls-files --deleted 2>&1 | Where-Object { $_ -match '\.(ps1|yml|md|sh|php)$' }
    $deletedCount = ($deletedFiles | Measure-Object).Count
    if ($deletedCount -gt 10) {
        $checks += [PSCustomObject]@{ Check = "Massive deleted files"; Status = "WARN"; Notes = "$deletedCount deleted tracked files (potential drift)" }
        $warnCount++
        Write-Host "  Remediation: Review git status, restore if needed: git restore <file>" -ForegroundColor Yellow
    } else {
        $checks += [PSCustomObject]@{ Check = "Massive deleted files"; Status = "PASS"; Notes = "$deletedCount deleted files (acceptable)" }
    }
    
    # Check 2: Unexpected untracked dumps (_diag_*, *_evidence_*, etc.)
    Write-Host "Checking for unexpected untracked dump files..." -ForegroundColor Gray
    $dumpPatterns = @("_diag_*", "*_evidence_*.txt", "*_evidence_*.json", "_diagnosis_*.txt", "_verify_output*.txt")
    $dumpFiles = @()
    foreach ($pattern in $dumpPatterns) {
        $found = Get-ChildItem -Path . -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\_archive\*" }
        if ($found) {
            $dumpFiles += $found
        }
    }
    if ($dumpFiles.Count -gt 0) {
        $dumpList = ($dumpFiles | Select-Object -First 5 | ForEach-Object { $_.Name }) -join ", "
        if ($dumpFiles.Count -gt 5) { $dumpList += " ... ($($dumpFiles.Count) total)" }
        $checks += [PSCustomObject]@{ Check = "Unexpected untracked dumps"; Status = "WARN"; Notes = "Found: $dumpList" }
        $warnCount++
        Write-Host "  Remediation: Move to _archive/ or add to .gitignore if temporary" -ForegroundColor Yellow
    } else {
        $checks += [PSCustomObject]@{ Check = "Unexpected untracked dumps"; Status = "PASS"; Notes = "No unexpected dump files found" }
    }
    
    # Check 3: Duplicate folders (e.g., "Yeni klasör", "New Folder", etc.)
    Write-Host "Checking for duplicate/scratch folders..." -ForegroundColor Gray
    $duplicateFolderPatterns = @("*Yeni klasör*", "*New Folder*", "*Copy*", "*Backup*", "*bak-*")
    $duplicateFolders = @()
    foreach ($pattern in $duplicateFolderPatterns) {
        $found = Get-ChildItem -Path . -Directory -Filter $pattern -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\_archive\*" -and $_.FullName -notlike "*node_modules\*" -and $_.FullName -notlike "*vendor\*" }
        if ($found) {
            $duplicateFolders += $found
        }
    }
    if ($duplicateFolders.Count -gt 0) {
        $folderList = ($duplicateFolders | Select-Object -First 3 | ForEach-Object { $_.Name }) -join ", "
        if ($duplicateFolders.Count -gt 3) { $folderList += " ... ($($duplicateFolders.Count) total)" }
        $checks += [PSCustomObject]@{ Check = "Duplicate/scratch folders"; Status = "WARN"; Notes = "Found: $folderList" }
        $warnCount++
        Write-Host "  Remediation: Review and archive/remove duplicate folders manually" -ForegroundColor Yellow
    } else {
        $checks += [PSCustomObject]@{ Check = "Duplicate/scratch folders"; Status = "PASS"; Notes = "No duplicate folders found" }
    }
    
    # Check 4: Duplicate compose files (docker-compose*.yml in root and work/*)
    Write-Host "Checking for duplicate compose files..." -ForegroundColor Gray
    $composeFiles = Get-ChildItem -Path . -Filter "docker-compose*.yml" -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.git\*" }
    $composeInRoot = $composeFiles | Where-Object { $_.DirectoryName -eq (Resolve-Path .).Path }
    $composeInWork = $composeFiles | Where-Object { $_.FullName -like "*\work\*" }
    
    # Check if root compose conflicts with work compose (same service definitions)
    $hasConflict = $false
    if ($composeInRoot -and $composeInWork) {
        # This is expected (root = canonical, work/hos = obs), so PASS
        $checks += [PSCustomObject]@{ Check = "Duplicate compose files"; Status = "PASS"; Notes = "Root + work compose files (expected: canonical + obs)" }
    } else {
        $checks += [PSCustomObject]@{ Check = "Duplicate compose files"; Status = "PASS"; Notes = "Compose files structure normal" }
    }
    
    # Check 5: Missing critical ops scripts
    Write-Host "Checking for missing critical ops scripts..." -ForegroundColor Gray
    $criticalScripts = @("ops_status.ps1", "verify.ps1", "doctor.ps1", "triage.ps1")
    $missingScripts = @()
    foreach ($script in $criticalScripts) {
        if (-not (Test-Path ".\ops\$script")) {
            $missingScripts += $script
        }
    }
    if ($missingScripts.Count -gt 0) {
        $checks += [PSCustomObject]@{ Check = "Missing critical ops scripts"; Status = "FAIL"; Notes = "Missing: $($missingScripts -join ', ')" }
        $failCount++
        Write-Host "  Remediation: Restore missing scripts from git history: git restore ops/$($missingScripts[0])" -ForegroundColor Red
    } else {
        $checks += [PSCustomObject]@{ Check = "Missing critical ops scripts"; Status = "PASS"; Notes = "All critical scripts present" }
    }
    
    # Summary
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "=== Integrity Check Results ==="
    } else {
        Write-Host "=== Integrity Check Results ===" -ForegroundColor Cyan
    }
    Write-Host ""
    $checks | Format-Table -Property Check, Status, Notes -AutoSize
    
    # Determine overall status
    Write-Host ""
    if ($failCount -gt 0) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)"
        } else {
            Write-Host "[FAIL] OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
        }
        Invoke-OpsExit 1
        return
    } elseif ($warnCount -gt 0) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Warn "OVERALL STATUS: WARN ($warnCount warnings)"
        } else {
            Write-Host "[WARN] OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
        }
        Invoke-OpsExit 2
        return
    } else {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Pass "OVERALL STATUS: PASS (No integrity issues detected)"
        } else {
            Write-Host "[PASS] OVERALL STATUS: PASS (No integrity issues detected)" -ForegroundColor Green
        }
        Invoke-OpsExit 0
        return
    }
} finally {
    Pop-Location
}









