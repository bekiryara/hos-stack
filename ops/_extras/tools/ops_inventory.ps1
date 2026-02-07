#!/usr/bin/env pwsh
# ops_inventory.ps1 - ops/ script inventory + dependency graph (PS 5.1 compatible)
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\ops\_extras\tools\ops_inventory.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\ops\_extras\tools\ops_inventory.ps1 -Output Json
#
# Output:
#  - Table (default) or JSON (Output=Json)
#
# This script is intentionally lightweight: no external modules.

param(
  [ValidateSet('Table', 'Json')]
  [string]$Output = 'Table',
  [int]$HeadLines = 80,
  # Optional substring/regex filter on relative path (case-insensitive)
  [string]$MatchPath = ""
)

$ErrorActionPreference = "Stop"

function To-RelPath {
  param([string]$Path, [string]$Root)
  $p = $Path
  $r = $Root.TrimEnd('\','/')
  if ($p.StartsWith($r, [System.StringComparison]::OrdinalIgnoreCase)) {
    $p = $p.Substring($r.Length).TrimStart('\','/')
  }
  return ($p -replace '\\','/')
}

function Read-Head {
  param([string]$Path, [int]$N)
  try { return @(Get-Content -LiteralPath $Path -TotalCount $N -ErrorAction Stop) } catch { return @() }
}

function Extract-Summary {
  param([string[]]$Lines)
  # Prefer: "# something - ..." in first ~20 lines
  $max = [Math]::Min(25, $Lines.Count)
  for ($i=0; $i -lt $max; $i++) {
    $l = $Lines[$i]
    if ($null -eq $l) { continue }
    $t = $l.Trim()
    if ($t -match '^#\s*([^#].{0,180})$') {
      return $Matches[1].Trim()
    }
    if ($t -match '^Write-Host\s+\"===\s*([^=]+)\s*===\"') {
      return ("banner: " + $Matches[1].Trim())
    }
  }
  return ""
}

function Has-ParamBlock {
  param([string[]]$Lines)
  $text = ($Lines -join "`n")
  return [bool]([regex]::IsMatch($text, '(?im)^\s*param\s*\('))
}

function Extract-Tags {
  param([string[]]$Lines)
  $text = ($Lines -join "`n")
  $tags = New-Object System.Collections.Generic.List[string]
  $m = [regex]::Matches($text, 'WP-\d+[A-Z]?', 'IgnoreCase')
  foreach ($x in $m) { $tags.Add($x.Value.ToUpperInvariant()) }
  if ($text -match '(?i)HISTORICAL|RETIRED|DEPRECATED|WRAPPER') { $tags.Add("LEGACY") }
  if ($text -match '(?i)EXPERIMENT|PROTOTYPE|PROOF') { $tags.Add("DEV") }
  # uniq
  return @($tags | Sort-Object -Unique)
}

function Read-WorkflowOpsRefs {
  param([string]$RepoRoot)
  $wfDir = Join-Path $RepoRoot ".github\workflows"
  if (-not (Test-Path $wfDir)) { return @() }
  $rx = New-Object System.Text.RegularExpressions.Regex('ops[\\/][^ \r\n\t\"''`]+?\.ps1', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $refs = New-Object System.Collections.Generic.List[string]
  Get-ChildItem -Path $wfDir -File -Filter *.yml | ForEach-Object {
    $t = Get-Content -LiteralPath $_.FullName -Raw
    foreach ($m in $rx.Matches($t)) {
      $refs.Add((($m.Value -replace '\\','/').Trim()).ToLowerInvariant())
    }
  }
  return @($refs | Sort-Object -Unique)
}

function Read-DocsOpsRefs {
  param([string]$RepoRoot)
  $docsDir = Join-Path $RepoRoot "docs"
  $rx = New-Object System.Text.RegularExpressions.Regex('ops[\\/][^ \r\n\t\"''`]+?\.ps1', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $refs = New-Object System.Collections.Generic.List[string]

  $scanPaths = New-Object System.Collections.Generic.List[string]
  if (Test-Path $docsDir) { $scanPaths.Add($docsDir) }
  # Also scan a few common root docs
  foreach ($p in @("README.md","CHANGELOG.md","WORLD_REGISTRY.md")) {
    $fp = Join-Path $RepoRoot $p
    if (Test-Path $fp) { $scanPaths.Add($fp) }
  }

  foreach ($sp in $scanPaths) {
    if (Test-Path $sp -PathType Leaf) {
      $t = Get-Content -LiteralPath $sp -Raw
      foreach ($m in $rx.Matches($t)) {
        $refs.Add((($m.Value -replace '\\','/').Trim()).ToLowerInvariant())
      }
      continue
    }

    Get-ChildItem -Path $sp -Recurse -File -Include *.md,*.txt,*.yaml,*.yml -ErrorAction SilentlyContinue | ForEach-Object {
      $t = ""
      try { $t = Get-Content -LiteralPath $_.FullName -Raw } catch { $t = "" }
      if (-not $t) { return }
      foreach ($m in $rx.Matches($t)) {
        $refs.Add((($m.Value -replace '\\','/').Trim()).ToLowerInvariant())
      }
    }
  }

  return @($refs | Sort-Object -Unique)
}

function Read-ScriptEdges {
  param([string[]]$RelPaths, [hashtable]$AbsByRel, [int]$HeadLines)
  # Only supports typical patterns: .\ops\foo.ps1, ./ops/foo.ps1, ops/foo.ps1
  $rx = New-Object System.Text.RegularExpressions.Regex('(?i)(?:\.\s*\\\s*ops\\\s*|\.\/ops\/|ops[\\/])([a-z0-9_\-]+\.ps1)')
  $edges = New-Object System.Collections.Generic.List[object]
  foreach ($rel in $RelPaths) {
    $abs = $AbsByRel[$rel]
    $text = ""
    try { $text = Get-Content -LiteralPath $abs -Raw } catch { $text = "" }
    foreach ($m in $rx.Matches($text)) {
      $to = ("ops/" + $m.Groups[1].Value.ToLowerInvariant())
      $edges.Add([pscustomobject]@{ from=$rel.ToLowerInvariant(); to=$to })
    }
  }
  return $edges
}

function Guess-Category {
  param(
    [string]$RelPath,
    [bool]$IsCiRef,
    [int]$CalledByCount
  )
  $p = $RelPath.ToLowerInvariant()
  if ($p.StartsWith("ops/_extras/")) { return "extras" }
  if ($p -in @("ops/ops.ps1","ops/ops_status.ps1","ops/ops_run.ps1","ops/ship_main.ps1","ops/frontend_refresh.ps1")) { return "entrypoint" }
  if ($IsCiRef) { return "ci_gate" }
  if ($p -match 'release|bundle|ship') { return "release" }
  if ($p -match 'snapshot|inventory|report|audit') { return "reporting" }
  if ($p -match 'db_|hos_db|psql|postgres') { return "db" }
  if ($p -match 'smoke|verify|doctor|triage|status') { return "diagnostic" }
  if ($p -match 'guard|contract|check|posture|policy') { return "gate_or_check" }
  if ($CalledByCount -eq 0) { return "leaf" }
  return "misc"
}

# repo / ops roots
# This script lives at: <repo>/ops/_extras/tools/ops_inventory.ps1
$opsRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) # <repo>/ops
$repoRoot = Split-Path -Parent $opsRoot                                                             # <repo>

if (-not (Test-Path $opsRoot)) { throw "ops root not found: $opsRoot" }

$ps1 = Get-ChildItem -Path $opsRoot -Recurse -File -Filter *.ps1
$absByRel = @{}
$relPaths = New-Object System.Collections.Generic.List[string]
foreach ($f in $ps1) {
  $rel = To-RelPath -Path $f.FullName -Root $repoRoot
  $absByRel[$rel] = $f.FullName
  $relPaths.Add($rel)
}

$ciRefs = Read-WorkflowOpsRefs -RepoRoot $repoRoot
$ciSet = @{}
foreach ($r in $ciRefs) { $ciSet[$r] = $true }

$docRefs = Read-DocsOpsRefs -RepoRoot $repoRoot
$docSet = @{}
foreach ($r in $docRefs) { $docSet[$r] = $true }

$edges = Read-ScriptEdges -RelPaths $relPaths -AbsByRel $absByRel -HeadLines $HeadLines
$calledBy = @{}
$calls = @{}
foreach ($e in $edges) {
  if (-not $calls.ContainsKey($e.from)) { $calls[$e.from] = 0 }
  $calls[$e.from]++
  if (-not $calledBy.ContainsKey($e.to)) { $calledBy[$e.to] = 0 }
  $calledBy[$e.to]++
}

$rows = New-Object System.Collections.Generic.List[object]
foreach ($rel in $relPaths) {
  $head = Read-Head -Path $absByRel[$rel] -N $HeadLines
  $tags = Extract-Tags -Lines $head
  $isCi = $false
  $key = $rel.ToLowerInvariant()
  if ($ciSet.ContainsKey($key)) { $isCi = $true }
  $isDoc = $false
  if ($docSet.ContainsKey($key)) { $isDoc = $true }
  $cb = 0
  if ($calledBy.ContainsKey($key)) { $cb = [int]$calledBy[$key] }
  $cc = 0
  if ($calls.ContainsKey($key)) { $cc = [int]$calls[$key] }
  $cat = Guess-Category -RelPath $rel -IsCiRef $isCi -CalledByCount $cb
  $rows.Add([pscustomobject]@{
    path = $rel
    category = $cat
    ci_ref = $isCi
    doc_ref = $isDoc
    called_by = $cb
    calls = $cc
    has_param = (Has-ParamBlock -Lines $head)
    tags = ($tags -join ",")
    summary = (Extract-Summary -Lines $head)
  })
}

$rowsSorted = $rows | Sort-Object category, path

if (-not [string]::IsNullOrWhiteSpace($MatchPath)) {
  $rx = New-Object System.Text.RegularExpressions.Regex($MatchPath, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $rowsSorted = $rowsSorted | Where-Object { $rx.IsMatch($_.path) }
}

if ($Output -eq 'Json') {
  $rowsSorted | ConvertTo-Json -Depth 4
  exit 0
}

Write-Host "=== OPS INVENTORY ===" -ForegroundColor Cyan
Write-Host ("repo: {0}" -f $repoRoot) -ForegroundColor Gray
Write-Host ("ops scripts: {0}" -f $rowsSorted.Count) -ForegroundColor Gray
Write-Host ("ci referenced: {0}" -f ($rowsSorted | Where-Object { $_.ci_ref } | Measure-Object).Count) -ForegroundColor Gray
Write-Host ("docs referenced: {0}" -f ($rowsSorted | Where-Object { $_.doc_ref } | Measure-Object).Count) -ForegroundColor Gray
Write-Host ""

$rowsSorted |
  Select-Object category, ci_ref, doc_ref, called_by, calls, path, tags, summary |
  Format-Table -AutoSize

Write-Host ""
Write-Host "Candidates (root, non-CI, not entrypoint, nobody calls them):" -ForegroundColor Yellow
$candidates = $rowsSorted | Where-Object {
  $_.path -like 'ops/*.ps1' -and
  -not $_.path.StartsWith('ops/_extras/') -and
  -not $_.ci_ref -and
  -not $_.doc_ref -and
  $_.category -ne 'entrypoint' -and
  $_.called_by -eq 0
}
$candidates | Select-Object path, category, tags, summary | Format-Table -AutoSize

