# =========================================
# REPO GOVERNANCE FREEZE v1 (SAFE CLEANUP)
# Run from: D:\stack
# Goal: Keep working system intact; reduce repo chaos; make onboarding deterministic.
# =========================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== 0) Preflight (must be in repo root) ===" -ForegroundColor Cyan
if (-not (Test-Path ".git")) { throw "Not in repo root. cd D:\stack first." }
git status --short

Write-Host "`n=== 1) Ensure authoritative docs exist (single source of truth) ===" -ForegroundColor Cyan
$mustDocs = @(
  "docs/CURRENT.md",
  "docs/ONBOARDING.md",
  "docs/DECISIONS.md",
  "docs/START_HERE.md",
  "docs/REPO_LAYOUT.md",
  "docs/CONTRIBUTING.md",
  "CHANGELOG.md"
)
$missing = @()
foreach ($p in $mustDocs) { if (-not (Test-Path $p)) { $missing += $p } }
if ($missing.Count -gt 0) {
  Write-Host "MISSING docs:" -ForegroundColor Red; $missing | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
  throw "Authoritative docs missing. Stop here and restore them."
}
Write-Host "OK: Authoritative docs present." -ForegroundColor Green

Write-Host "`n=== 2) Identify what CI/workflows actually call (truth source) ===" -ForegroundColor Cyan
Write-Host "Scanning .github/workflows for ops usage..." -ForegroundColor Yellow
$wfOps = Select-String -Path ".github/workflows/*.yml" -Pattern "ops/" -SimpleMatch -ErrorAction SilentlyContinue
if ($wfOps) {
  $wfOps | ForEach-Object { "{0}:{1} {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() } | Select-Object -First 200 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
} else {
  Write-Host "No ops references found in workflows." -ForegroundColor Gray
}
Write-Host "NOTE: Any ops script referenced here is NOT to be removed. Only move candidates not referenced." -ForegroundColor Yellow

Write-Host "`n=== 3) Remove temporary diff artifacts (safe; regenerated) ===" -ForegroundColor Cyan
if (Test-Path "ops/diffs") {
  $diffFiles = Get-ChildItem -Path "ops/diffs" -Force -ErrorAction SilentlyContinue
  if ($diffFiles) {
    $diffFiles | Format-Table Name,Length,LastWriteTime -Auto
    Remove-Item "ops/diffs/*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "OK: ops/diffs cleared." -ForegroundColor Green
  } else {
    Write-Host "SKIP: ops/diffs is empty." -ForegroundColor Gray
  }
} else {
  Write-Host "SKIP: ops/diffs not present." -ForegroundColor Gray
}

Write-Host "`n=== 4) Quarantine: move obvious one-off / legacy scripts (NO DELETE) ===" -ForegroundColor Cyan
# Create quarantine structure
New-Item -ItemType Directory -Force -Path "_graveyard/ops_candidates" | Out-Null

# Candidates from your inventory: one-off restore + old E2E v0 (adjust names if they exist)
$candidates = @(
  "ops/restore_pazar_routes.ps1",
  "ops/STACK_E2E_CRITICAL_TESTS_v0.ps1"
)

foreach ($c in $candidates) {
  if (Test-Path $c) {
    $dest = Join-Path "_graveyard/ops_candidates" (Split-Path $c -Leaf)
    Move-Item $c $dest -Force
    $note = ($dest + ".NOTE.md")
    @"
# Why moved here

- Moved during REPO GOVERNANCE FREEZE v1.

- Reason: one-off / legacy candidate. Keep for reference, not for day-to-day ops.



# How to restore

- Move back to ops/ if you intentionally re-activate it.

- If re-activated, add docs reference + CI/workflow reference explicitly.
"@ | Set-Content -Path $note -Encoding UTF8
    Write-Host "MOVED: $c -> $dest" -ForegroundColor Yellow
  } else {
    Write-Host "SKIP (not found): $c" -ForegroundColor Gray
  }
}

Write-Host "`n=== 5) Protect: verify core ops scripts exist (critical set) ===" -ForegroundColor Cyan
$coreOps = @(
  "ops/verify.ps1",
  "ops/doctor.ps1",
  "ops/conformance.ps1",
  "ops/triage.ps1",
  "ops/baseline_status.ps1",
  "ops/daily_snapshot.ps1",
  "ops/graveyard_check.ps1",
  "ops/routes_snapshot.ps1",
  "ops/schema_snapshot.ps1"
)
$missingOps = @()
foreach ($p in $coreOps) { if (-not (Test-Path $p)) { $missingOps += $p } }
if ($missingOps.Count -gt 0) {
  Write-Host "MISSING core ops scripts:" -ForegroundColor Red; $missingOps | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
  throw "Core ops set incomplete. Stop here and restore."
}
Write-Host "OK: Core ops scripts present." -ForegroundColor Green

Write-Host "`n=== 6) Run signals (local) ===" -ForegroundColor Cyan
Write-Host "Running doctor.ps1..." -ForegroundColor Yellow
.\ops\doctor.ps1
Write-Host "`nRunning conformance.ps1..." -ForegroundColor Yellow
.\ops\conformance.ps1
Write-Host "`nRunning verify.ps1..." -ForegroundColor Yellow
.\ops\verify.ps1

Write-Host "`n=== 7) Git hygiene ===" -ForegroundColor Cyan
git status --short
Write-Host "`nIf the changes look correct: commit with a single message like:" -ForegroundColor Yellow
Write-Host "  chore(repo): governance freeze v1 (quarantine + cleanup + signals)" -ForegroundColor Cyan

Write-Host "`n=== REPO GOVERNANCE FREEZE v1 COMPLETE ===" -ForegroundColor Green

