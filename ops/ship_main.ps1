# Ship Main (WP-45)
# One command publish: gates + smokes + push (no PR, no branch)

$ErrorActionPreference = "Stop"

Write-Host "=== SHIP MAIN (WP-45) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

# Helper: Print sanitized
function Write-Sanitized {
    param([string]$text, [string]$Color = "White")
    $sanitized = Sanitize-Ascii $text
    Write-Host $sanitized -ForegroundColor $Color
}

# Pre-flight checks
Write-Host "[PRE-FLIGHT] Checking prerequisites..." -ForegroundColor Yellow

# Check current branch
$currentBranch = git branch --show-current
if ($currentBranch -ne "main") {
    Write-Host "FAIL: Current branch is not main (found: $currentBranch)" -ForegroundColor Red
    Write-Host "  Ship main requires working on main branch" -ForegroundColor Yellow
    exit 1
}
Write-Host "PASS: Current branch is main" -ForegroundColor Green

# Check working tree
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "FAIL: Working tree is not clean" -ForegroundColor Red
    Write-Host "  Uncommitted changes:" -ForegroundColor Yellow
    $gitStatus | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    Write-Host "  Fix: Commit or stash changes before shipping" -ForegroundColor Yellow
    exit 1
}
Write-Host "PASS: Working tree is clean" -ForegroundColor Green

Write-Host ""

# Run gates (fail-fast)
Write-Host "[GATES] Running quality gates..." -ForegroundColor Yellow

$gateScripts = @(
    ".\ops\secret_scan.ps1",
    ".\ops\public_ready_check.ps1",
    ".\ops\repo_payload_guard.ps1",
    ".\ops\closeouts_size_gate.ps1",
    ".\ops\conformance.ps1",
    ".\ops\frontend_smoke.ps1",
    ".\ops\prototype_smoke.ps1",
    ".\ops\prototype_flow_smoke.ps1"
)

$gateIndex = 1
foreach ($script in $gateScripts) {
    $scriptName = Split-Path $script -Leaf
    Write-Host "  [$gateIndex] Running $scriptName..." -ForegroundColor Gray
    try {
        $output = & $script 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Host "FAIL: $scriptName returned exit code $exitCode" -ForegroundColor Red
            $output | ForEach-Object { Write-Sanitized $_ "Gray" }
            exit 1
        } else {
            Write-Host "PASS: $scriptName" -ForegroundColor Green
        }
    } catch {
        Write-Sanitized "FAIL: $scriptName failed: $($_.Exception.Message)" "Red"
        exit 1
    }
    $gateIndex++
}

Write-Host ""

# Git operations
Write-Host "[GIT] Synchronizing with origin..." -ForegroundColor Yellow

try {
    # Pull with rebase
    Write-Host "  Pulling from origin/main (rebase)..." -ForegroundColor Gray
    $pullOutput = git pull --rebase origin main 2>&1
    $pullExitCode = $LASTEXITCODE
    if ($pullExitCode -ne 0) {
        Write-Sanitized "FAIL: git pull --rebase failed with exit code $pullExitCode" "Red"
        $pullOutput | ForEach-Object { Write-Sanitized $_ "Gray" }
        exit 1
    }
    Write-Host "PASS: Pulled from origin/main" -ForegroundColor Green
    
    # Push
    Write-Host "  Pushing to origin/main..." -ForegroundColor Gray
    $pushOutput = git push origin main 2>&1
    $pushExitCode = $LASTEXITCODE
    if ($pushExitCode -ne 0) {
        Write-Sanitized "FAIL: git push failed with exit code $pushExitCode" "Red"
        $pushOutput | ForEach-Object { Write-Sanitized $_ "Gray" }
        exit 1
    }
    Write-Host "PASS: Pushed to origin/main" -ForegroundColor Green
} catch {
    Write-Sanitized "FAIL: Git operation failed: $($_.Exception.Message)" "Red"
    exit 1
}

# Summary
Write-Host ""
Write-Host "=== SHIP MAIN: PASS ===" -ForegroundColor Green
Write-Host "  All gates: PASS" -ForegroundColor Gray
Write-Host "  Git sync: PASS" -ForegroundColor Gray
Write-Host "  Main branch published to origin" -ForegroundColor Gray
exit 0

