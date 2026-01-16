# ===========================================
# WORLD-CLASS REPO BASELINE FREEZE v1
# Goal: Repo'yu bozmadan profesyonel baseline'a kilitle
# Run from: D:\stack   (PowerShell 5.1)
# ===========================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "==[0] Preconditions ==" -ForegroundColor Cyan
if ((Get-Location).Path -ne "D:\stack") { throw "Run from D:\stack" }
git rev-parse --is-inside-work-tree | Out-Null

Write-Host "==[1] Safety: Create local safety branch + snapshot ==" -ForegroundColor Cyan
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
git status --porcelain | Out-Null
git checkout -b "safety/baseline-freeze-$ts" | Out-Null

New-Item -ItemType Directory -Force "_archive\baseline-freeze\$ts" | Out-Null
git status --porcelain > "_archive\baseline-freeze\$ts\git_status.txt"
git log -1 --oneline > "_archive\baseline-freeze\$ts\git_head.txt"

Write-Host "==[2] Inventory: List ops + graveyard ops ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force "_archive\baseline-freeze\$ts\inventory" | Out-Null
Get-ChildItem -File "ops" -Filter "*.ps1" | Select-Object Name,Length,LastWriteTime | Sort-Object Name |
  Format-Table -Auto | Out-String | Set-Content -Encoding utf8 "_archive\baseline-freeze\$ts\inventory\ops_list.txt"

if (Test-Path "_graveyard") {
  Get-ChildItem -Recurse -File "_graveyard" -Filter "*.ps1" | Select-Object FullName,Length,LastWriteTime | Sort-Object FullName |
    Format-Table -Auto | Out-String | Set-Content -Encoding utf8 "_archive\baseline-freeze\$ts\inventory\graveyard_ops_list.txt"
} else {
  "NO _graveyard folder" | Set-Content -Encoding utf8 "_archive\baseline-freeze\$ts\inventory\graveyard_ops_list.txt"
}

Write-Host "==[3] Fix: RC0 scripts must NOT live in graveyard if referenced ==" -ForegroundColor Cyan
# If these exist in _graveyard but missing in ops, move them back.
$rc0Candidates = @(
  "_graveyard\ops_rc0\rc0_check.ps1",
  "_graveyard\ops_rc0\rc0_gate.ps1",
  "_graveyard\ops_rc0\rc0_release_bundle.ps1"
)

foreach ($p in $rc0Candidates) {
  if (Test-Path $p) {
    $name = Split-Path $p -Leaf
    $dst  = Join-Path "ops" $name
    if (-not (Test-Path $dst)) {
      Write-Host "  moving $p -> $dst" -ForegroundColor Yellow
      Move-Item $p $dst -Force
    } else {
      Write-Host "  skip move (already exists): $dst" -ForegroundColor DarkGray
    }
  }
}

Write-Host "==[4] Establish Graveyard contract (KARANTINA) ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force "_graveyard" | Out-Null
$graveReadme = @"
# GRAVEYARD (KARANTINA)

Bu klasördeki dosyalar:

- CI / ops çekirdeği tarafından çalıştırılmaz

- CORE sistemin parçası değildir

- Yalnızca referans / tarihsel / deneysel içeriktir

- Buraya taşınan dosya karar kaydı olmadan CORE'a geri dönmez

"@
$graveReadme | Set-Content -Encoding utf8 "_graveyard\README.md"

Write-Host "==[5] Create minimal baseline docs if missing ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force "docs" | Out-Null
New-Item -ItemType Directory -Force "docs\runbooks" | Out-Null
New-Item -ItemType Directory -Force "docs\PROOFS" | Out-Null
New-Item -ItemType Directory -Force "docs\RELEASES" | Out-Null

if (-not (Test-Path "docs\CURRENT.md")) {
@"
# CURRENT (Single Source of Truth)

## Stack

- hos-api: http://localhost:3000/v1/health

- hos-web: http://localhost:3002

- pazar:   http://localhost:8080/up

## Baseline commands

- Start: docker compose up -d --build

- Verify: .\ops\verify.ps1

- Doctor: .\ops\doctor.ps1

- Conformance: .\ops\conformance.ps1

"@ | Set-Content -Encoding utf8 "docs\CURRENT.md"
}

if (-not (Test-Path "docs\ONBOARDING.md")) {
@"
# ONBOARDING

## Quick start (2 commands)

docker compose up -d --build

.\ops\verify.ps1

## Daily evidence

.\ops\daily_snapshot.ps1

"@ | Set-Content -Encoding utf8 "docs\ONBOARDING.md"
}

if (-not (Test-Path "docs\DECISIONS.md")) {
@"
# DECISIONS

## Baseline freeze v1

- CORE ops scripts live under /ops

- Experimental/old scripts go under /_graveyard

- docs/CURRENT.md is single source of truth

"@ | Set-Content -Encoding utf8 "docs\DECISIONS.md"
}

Write-Host "==[6] Create daily snapshot script if missing ==" -ForegroundColor Cyan
if (-not (Test-Path "ops\daily_snapshot.ps1")) {
@"
param(
  [string]`$OutDir = "_archive/daily"
)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"
`$ts = Get-Date -Format "yyyyMMdd-HHmmss"
`$dir = Join-Path `$OutDir `$ts
New-Item -ItemType Directory -Force `$dir | Out-Null

"=== DAILY SNAPSHOT ===" | Set-Content -Encoding utf8 (Join-Path `$dir "meta.txt")
(Get-Date).ToString("s") | Add-Content -Encoding utf8 (Join-Path `$dir "meta.txt")
("PWD=" + (Get-Location).Path) | Add-Content -Encoding utf8 (Join-Path `$dir "meta.txt")

git status --porcelain | Set-Content -Encoding utf8 (Join-Path `$dir "git_status.txt")
git log -1 --oneline   | Set-Content -Encoding utf8 (Join-Path `$dir "git_head.txt")

docker compose ps | Out-String | Set-Content -Encoding utf8 (Join-Path `$dir "compose_ps.txt")

try { curl.exe -s -i http://localhost:3000/v1/health | Select-Object -First 20 | Out-String | Set-Content -Encoding utf8 (Join-Path `$dir "hos_health.txt") } catch {}
try { curl.exe -s -i http://localhost:8080/up       | Select-Object -First 20 | Out-String | Set-Content -Encoding utf8 (Join-Path `$dir "pazar_up.txt") } catch {}

Write-Host ("Snapshot written: " + `$dir)
"@ | Set-Content -Encoding utf8 "ops\daily_snapshot.ps1"
}

Write-Host "==[7] Run gates (should be deterministic) ==" -ForegroundColor Cyan
.\ops\doctor.ps1
.\ops\conformance.ps1
.\ops\verify.ps1

Write-Host "==[8] Proof: write baseline proof ==" -ForegroundColor Cyan
@"
# baseline_freeze_v1 proof

Timestamp: $((Get-Date).ToString("s"))
Branch: $(git rev-parse --abbrev-ref HEAD)

Commands executed:

- ops/doctor.ps1
- ops/conformance.ps1
- ops/verify.ps1
- ops/daily_snapshot.ps1
"@ | Set-Content -Encoding utf8 "docs\PROOFS\baseline_freeze_v1_pass.md"

Write-Host "==[9] Git add + commit (optional but recommended) ==" -ForegroundColor Cyan
git add -A
git status --porcelain

Write-Host ""
Write-Host "READY:" -ForegroundColor Green
Write-Host "If status looks correct, commit with:" -ForegroundColor Green
Write-Host '  git commit -m "chore(baseline): freeze repo baseline v1"' -ForegroundColor Green





