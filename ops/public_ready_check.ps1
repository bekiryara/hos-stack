#!/usr/bin/env pwsh
# PUBLIC READY CHECK
# Verifies repository is safe for public GitHub release.
# Exits 0 only if all checks pass.

$ErrorActionPreference = "Stop"

Write-Host "=== PUBLIC READY CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Check 1: Secret Scan
Write-Host "[1] Running secret scan..." -ForegroundColor Yellow
try {
    $secretScanOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File "ops\secret_scan.ps1" 2>&1
    $secretScanExitCode = $LASTEXITCODE
    
    if ($secretScanExitCode -ne 0) {
        Write-Host "FAIL: Secret scan found secrets in tracked files" -ForegroundColor Red
        Write-Host "  Run: .\ops\secret_scan.ps1" -ForegroundColor Yellow
        Write-Host "  See: REMEDIATION_SECRETS.md for remediation steps" -ForegroundColor Yellow
        $hasFailures = $true
    } else {
        Write-Host "PASS: Secret scan - no secrets detected" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Secret scan script failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Check 2: Git Status (must be clean, ignore submodule untracked content)
Write-Host "[2] Checking git status..." -ForegroundColor Yellow
try {
    $gitStatus = git status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: Git status command failed" -ForegroundColor Red
        $hasFailures = $true
    } else {
        # Filter out submodule untracked content (e.g., "modified:   work/hos (untracked content)")
        $relevantChanges = $gitStatus | Where-Object { 
            $_ -and 
            -not ($_ -match '\(untracked content\)') -and
            -not ($_ -match '\(new commits\)')
        }
        
        if ($relevantChanges) {
            Write-Host "FAIL: Git working directory is not clean" -ForegroundColor Red
            Write-Host "  Uncommitted changes:" -ForegroundColor Yellow
            $relevantChanges | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            Write-Host "  Fix: Commit or stash changes before public release" -ForegroundColor Yellow
            $hasFailures = $true
        } else {
            Write-Host "PASS: Git working directory is clean" -ForegroundColor Green
            if ($gitStatus -match 'untracked content') {
                Write-Host "  Note: Submodule untracked content ignored (not blocking)" -ForegroundColor Gray
            }
        }
    }
} catch {
    Write-Host "FAIL: Git status check failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Check 3: .env files must NOT be tracked
Write-Host "[3] Checking .env files are not tracked..." -ForegroundColor Yellow
try {
    $envFiles = git ls-files -- .env .env.* 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: Git ls-files command failed" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($envFiles) {
        Write-Host "FAIL: .env files are tracked in git" -ForegroundColor Red
        Write-Host "  Tracked .env files:" -ForegroundColor Yellow
        $envFiles | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        Write-Host "  Fix: Remove from git: git rm --cached <file>" -ForegroundColor Yellow
        Write-Host "  Ensure .env is in .gitignore" -ForegroundColor Yellow
        $hasFailures = $true
    } else {
        Write-Host "PASS: No .env files are tracked" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: .env check failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Check 4: vendor/ must NOT be tracked
Write-Host "[4] Checking vendor/ is not tracked..." -ForegroundColor Yellow
try {
    $vendorFiles = git ls-files | Select-String -Pattern "^.*vendor/" | Select-Object -First 10
    if ($vendorFiles) {
        Write-Host "FAIL: vendor/ directories are tracked in git" -ForegroundColor Red
        Write-Host "  Tracked vendor files (first 10):" -ForegroundColor Yellow
        $vendorFiles | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        Write-Host "  Fix: Remove from git: git rm -r --cached <path>" -ForegroundColor Yellow
        Write-Host "  Ensure vendor/ is in .gitignore" -ForegroundColor Yellow
        $hasFailures = $true
    } else {
        Write-Host "PASS: No vendor/ directories are tracked" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: vendor/ check failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Check 5: node_modules/ must NOT be tracked
Write-Host "[5] Checking node_modules/ is not tracked..." -ForegroundColor Yellow
try {
    $nodeModulesFiles = git ls-files | Select-String -Pattern "^.*node_modules/" | Select-Object -First 10
    if ($nodeModulesFiles) {
        Write-Host "FAIL: node_modules/ directories are tracked in git" -ForegroundColor Red
        Write-Host "  Tracked node_modules files (first 10):" -ForegroundColor Yellow
        $nodeModulesFiles | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        Write-Host "  Fix: Remove from git: git rm -r --cached <path>" -ForegroundColor Yellow
        Write-Host "  Ensure node_modules/ is in .gitignore" -ForegroundColor Yellow
        $hasFailures = $true
    } else {
        Write-Host "PASS: No node_modules/ directories are tracked" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: node_modules/ check failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== PUBLIC READY CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "Fix the issues above before making repository public." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "See: docs/runbooks/repo_public_release.md for detailed remediation steps" -ForegroundColor Cyan
    exit 1
} else {
    Write-Host "=== PUBLIC READY CHECK: PASS ===" -ForegroundColor Green
    Write-Host "Repository appears safe for public release." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Review REMEDIATION_SECRETS.md (if secrets were found)" -ForegroundColor Gray
    Write-Host "2. Create GitHub repository (public)" -ForegroundColor Gray
    Write-Host "3. Push: git push <remote> main" -ForegroundColor Gray
    exit 0
}

