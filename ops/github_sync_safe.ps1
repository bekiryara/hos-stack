#!/usr/bin/env pwsh
# GITHUB SYNC SAFE v2 (PR-BASED FLOW)
# Ensures repository is safe to push to GitHub via PR flow.
# HARD BLOCKS if:
#   - Current branch is default branch (main/master)
#   - Secret scan fails
#   - Public ready check fails
#   - Submodule is dirty (untracked/modified content)
# Only pushes current branch (HEAD), never default branch.

$ErrorActionPreference = "Stop"

Write-Host "=== GITHUB SYNC SAFE v2 ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Get current branch and default branch
$currentBranch = git branch --show-current 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: Cannot determine current branch" -ForegroundColor Red
    exit 1
}

# Detect default branch (main or master)
$defaultBranch = "main"
$masterCheck = git branch -r --list "origin/master" 2>&1
if ($masterCheck -match "origin/master") {
    $defaultBranch = "master"
}

Write-Host "[1] Checking branch protection..." -ForegroundColor Yellow
Write-Host "    Current branch: $currentBranch" -ForegroundColor Gray
Write-Host "    Default branch: $defaultBranch" -ForegroundColor Gray

if ($currentBranch -eq $defaultBranch) {
    Write-Host "FAIL: Cannot push to default branch ($defaultBranch) directly" -ForegroundColor Red
    Write-Host ""
    Write-Host "REMEDIATION:" -ForegroundColor Yellow
    Write-Host "  1. Create a feature branch: git checkout -b feature/your-name" -ForegroundColor Cyan
    Write-Host "  2. Commit your changes: git commit -m 'your message'" -ForegroundColor Cyan
    Write-Host "  3. Push the branch: git push -u origin HEAD" -ForegroundColor Cyan
    Write-Host "  4. Open a Pull Request on GitHub" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "PASS: Not on default branch" -ForegroundColor Green
Write-Host ""

# Check secret scan
Write-Host "[2] Running secret scan..." -ForegroundColor Yellow
$secretScanScript = Join-Path $PSScriptRoot "secret_scan.ps1"
if (-not (Test-Path $secretScanScript)) {
    Write-Host "FAIL: secret_scan.ps1 not found at $secretScanScript" -ForegroundColor Red
    exit 1
}

$secretScanOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $secretScanScript 2>&1
$secretScanExitCode = $LASTEXITCODE

if ($secretScanExitCode -ne 0) {
    Write-Host "FAIL: Secret scan detected secrets in tracked files" -ForegroundColor Red
    Write-Host ""
    Write-Host "SECRET SCAN OUTPUT:" -ForegroundColor Yellow
    Write-Host $secretScanOutput
    Write-Host ""
    Write-Host "REMEDIATION:" -ForegroundColor Yellow
    Write-Host "  1. Review REMEDIATION_SECRETS.md" -ForegroundColor Cyan
    Write-Host "  2. Redact/replace sensitive strings in tracked files" -ForegroundColor Cyan
    Write-Host "  3. Re-run: .\ops\secret_scan.ps1 until PASS" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "PASS: Secret scan - no secrets detected" -ForegroundColor Green
Write-Host ""

# Check public ready check
Write-Host "[3] Running public ready check..." -ForegroundColor Yellow
$publicReadyScript = Join-Path $PSScriptRoot "public_ready_check.ps1"
if (-not (Test-Path $publicReadyScript)) {
    Write-Host "FAIL: public_ready_check.ps1 not found at $publicReadyScript" -ForegroundColor Red
    exit 1
}

$publicReadyOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $publicReadyScript 2>&1
$publicReadyExitCode = $LASTEXITCODE

if ($publicReadyExitCode -ne 0) {
    Write-Host "FAIL: Public ready check failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "PUBLIC READY CHECK OUTPUT:" -ForegroundColor Yellow
    Write-Host $publicReadyOutput
    Write-Host ""
    Write-Host "REMEDIATION:" -ForegroundColor Yellow
    Write-Host "  1. Fix the issues listed above" -ForegroundColor Cyan
    Write-Host "  2. Re-run: .\ops\public_ready_check.ps1 until PASS" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "PASS: Public ready check passed" -ForegroundColor Green
Write-Host ""

# Check submodule status
Write-Host "[4] Checking submodule status..." -ForegroundColor Yellow
$submoduleStatus = git submodule status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: Failed to check submodule status" -ForegroundColor Yellow
} else {
    # Check if work/hos submodule has untracked content
    $workHosPath = Join-Path (Get-Location) "work\hos"
    if (Test-Path $workHosPath) {
        Push-Location $workHosPath
        $submoduleStatus = git status --porcelain 2>&1
        Pop-Location
        
        if ($submoduleStatus -and $submoduleStatus -notmatch '^\s*$') {
            Write-Host "FAIL: Submodule work/hos has uncommitted changes or untracked content" -ForegroundColor Red
            Write-Host ""
            Write-Host "SUBMODULE STATUS:" -ForegroundColor Yellow
            Write-Host $submoduleStatus
            Write-Host ""
            Write-Host "REMEDIATION:" -ForegroundColor Yellow
            Write-Host "  1. Clean submodule: cd work/hos && git status" -ForegroundColor Cyan
            Write-Host "  2. Commit or discard changes in submodule" -ForegroundColor Cyan
            Write-Host "  3. Update submodule pointer: cd .. && git add work/hos" -ForegroundColor Cyan
            Write-Host ""
            exit 1
        }
    }
}

Write-Host "PASS: Submodule is clean" -ForegroundColor Green
Write-Host ""

# Check if there are staged changes
Write-Host "[5] Checking for staged changes..." -ForegroundColor Yellow
$stagedChanges = git diff --cached --name-only 2>&1
if (-not $stagedChanges -or $stagedChanges -match '^\s*$') {
    Write-Host "INFO: No staged changes - skipping commit step" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "INFO: Staged changes detected - you may commit before push" -ForegroundColor Gray
    Write-Host ""
}

# Get remote URL
$remoteUrl = git remote get-url origin 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: Cannot determine remote URL" -ForegroundColor Yellow
    $remoteUrl = "unknown"
}

# Push current branch
Write-Host "[6] Pushing current branch to origin..." -ForegroundColor Yellow
$pushOutput = git push -u origin HEAD 2>&1
$pushExitCode = $LASTEXITCODE

if ($pushExitCode -ne 0) {
    Write-Host "FAIL: Failed to push branch to origin" -ForegroundColor Red
    Write-Host ""
    Write-Host "PUSH OUTPUT:" -ForegroundColor Yellow
    Write-Host $pushOutput
    Write-Host ""
    exit 1
}

Write-Host "PASS: Branch pushed to origin" -ForegroundColor Green
Write-Host ""

# Generate PR URL hint
$prUrl = $remoteUrl -replace '\.git$', ''
if ($prUrl -match 'github\.com[/:]([^/]+)/([^/]+)') {
    $owner = $Matches[1]
    $repo = $Matches[2]
    $prCompareUrl = "https://github.com/$owner/$repo/compare/$defaultBranch...$currentBranch"
    
    Write-Host "=== GITHUB SYNC SAFE v2: PASS ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: Open a Pull Request" -ForegroundColor Cyan
    Write-Host "PR URL: $prCompareUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or visit:" -ForegroundColor Gray
    Write-Host "  https://github.com/$owner/$repo/pull/new/$currentBranch" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "=== GITHUB SYNC SAFE v2: PASS ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Branch pushed successfully. Open a PR on GitHub." -ForegroundColor Cyan
    Write-Host ""
}

Read-Host "Press Enter to exit"
exit 0

