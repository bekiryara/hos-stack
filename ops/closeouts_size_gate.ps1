# Closeouts Size Gate (WP-46)
# Fails if docs/WP_CLOSEOUTS.md exceeds safe budget or "keep last N" policy

$ErrorActionPreference = "Stop"

# Policy constants
$KeepLast = 8  # Keep last 8 WP entries (align with WP-45 note)
$BudgetLines = 1200  # Conservative line budget (allows header + 8 WP entries with some buffer)
$Buffer = 2  # Buffer for header sections and separators

Write-Host "=== CLOSEOUTS SIZE GATE (WP-46) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$closeoutsPath = "docs/WP_CLOSEOUTS.md"

if (-not (Test-Path $closeoutsPath)) {
    Write-Host "FAIL: Closeouts file not found: $closeoutsPath" -ForegroundColor Red
    exit 1
}

# Read file
$content = Get-Content $closeoutsPath -Raw
$lines = Get-Content $closeoutsPath
$lineCount = $lines.Count

# Count WP headings (## WP-XX:)
$wpHeadingPattern = '(?m)^##\s+WP-\d+:'
$wpMatches = [regex]::Matches($content, $wpHeadingPattern)
$wpCount = $wpMatches.Count

Write-Host "Current state:" -ForegroundColor Yellow
Write-Host "  WP sections: $wpCount" -ForegroundColor Gray
Write-Host "  Line count: $lineCount" -ForegroundColor Gray
Write-Host "  Policy: Keep last $KeepLast, max $BudgetLines lines" -ForegroundColor Gray
Write-Host ""

# Check policy violations
$hasViolation = $false

if ($wpCount -gt ($KeepLast + $Buffer)) {
    Write-Host "FAIL: Too many WP sections ($wpCount > $($KeepLast + $Buffer))" -ForegroundColor Red
    Write-Host "  Policy: Keep last $KeepLast WP entries only" -ForegroundColor Yellow
    $hasViolation = $true
}

if ($lineCount -gt $BudgetLines) {
    Write-Host "FAIL: File exceeds line budget ($lineCount > $BudgetLines)" -ForegroundColor Red
    Write-Host "  Policy: Maximum $BudgetLines lines allowed" -ForegroundColor Yellow
    $hasViolation = $true
}

if ($hasViolation) {
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    Write-Host "  Run: .\ops\closeouts_rollover.ps1 -Keep $KeepLast" -ForegroundColor Gray
    Write-Host ""
    Write-Host "=== CLOSEOUTS SIZE GATE: FAIL ===" -ForegroundColor Red
    exit 1
}

Write-Host "PASS: Closeouts file within policy limits" -ForegroundColor Green
Write-Host "=== CLOSEOUTS SIZE GATE: PASS ===" -ForegroundColor Green
exit 0

