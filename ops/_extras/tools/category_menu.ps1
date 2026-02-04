#!/usr/bin/env pwsh
# Category Menu (temporary admin panel)
# Purpose: Manage category hierarchy (parent_id/sort_order/name/slug/status) without writing SQL manually.
# Works via: docker compose exec -T pazar-db psql ...
#
# Safety rules:
# - Do NOT delete categories (use status=inactive).
# - Do NOT recreate categories (IDs must remain stable).
#
# Usage:
#   Interactive menu:
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\ops\category_menu.ps1
#
#   One-shot actions (no prompts):
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\ops\category_menu.ps1 -Action list_roots
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\ops\category_menu.ps1 -Action tree
#
param(
  [ValidateSet('menu','list_roots','tree','integrity','quick_list_vehicle','quick_list_real_estate','quick_list_service')]
  [string]$Action = 'menu',
  # Safety: moving a category to ROOT (parent_id=NULL) is risky.
  # Default: disabled. Enable only if you really need it.
  [switch]$AllowRootMove
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

# Console/encoding helpers:
# - Menu text is ASCII to avoid mojibake on PS 5.1.
# - For DB output (Turkish chars), try to force UTF-8.
try { chcp 65001 | Out-Null } catch {}
try {
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [Console]::OutputEncoding = $utf8
  $global:OutputEncoding = $utf8
} catch {}

function Write-Title([string]$t) { Write-Host $t -ForegroundColor Cyan }
function Write-Info([string]$t) { Write-Host $t -ForegroundColor Gray }
function Write-Warn([string]$t) { Write-Host $t -ForegroundColor Yellow }
function Write-Fail([string]$t) { Write-Host $t -ForegroundColor Red }
function Write-Pass([string]$t) { Write-Host $t -ForegroundColor Green }

function Escape-SqlLiteral([string]$s) {
  if ($null -eq $s) { return "" }
  return ($s -replace "'", "''")
}

function Invoke-PazarSql {
  param(
    [Parameter(Mandatory=$true)][string]$Sql
  )
  Push-Location $repoRoot
  try {
    # -t -A -F "|" => parseable rows
    # Force client encoding for proper Turkish chars
    $out = docker compose exec -T -e PGCLIENTENCODING=UTF8 pazar-db psql -U pazar -d pazar -t -A -F "|" -c $Sql 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw ("psql failed: " + ($out | Out-String))
    }
    return ($out | Out-String).Trim()
  } finally {
    Pop-Location
  }
}

function Parse-Row([string]$line, [string[]]$cols) {
  $parts = $line -split '\|', -1
  $obj = @{}
  for ($i = 0; $i -lt $cols.Count; $i++) {
    $val = if ($i -lt $parts.Count) { $parts[$i] } else { "" }
    if ($null -eq $val) { $val = "" }
    # Trim to avoid CR/LF or whitespace breaking comparisons/keys (psql output can include \r)
    $obj[$cols[$i]] = ([string]$val).Trim()
  }
  return [pscustomobject]$obj
}

function Get-CategoryBySlug([string]$slug) {
  $s = Escape-SqlLiteral $slug
  $raw = Invoke-PazarSql -Sql "SELECT id,parent_id,slug,name,sort_order,status FROM categories WHERE slug='$s' ORDER BY id LIMIT 1;"
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  $line = ($raw -split "`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
  if (-not $line) { return $null }
  return (Parse-Row $line @('id','parent_id','slug','name','sort_order','status'))
}

function Get-CategoryById([string]$id) {
  if ([string]::IsNullOrWhiteSpace($id)) { return $null }
  $raw = Invoke-PazarSql -Sql "SELECT id,parent_id,slug,name,sort_order,status FROM categories WHERE id=$(($id -as [int])) LIMIT 1;"
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  $line = ($raw -split "`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
  if (-not $line) { return $null }
  return (Parse-Row $line @('id','parent_id','slug','name','sort_order','status'))
}

function Resolve-Category([string]$input) {
  if ([string]::IsNullOrWhiteSpace($input)) { return $null }
  $trim = $input.Trim()
  if ($trim -match '^\d+$') { return Get-CategoryById $trim }
  return Get-CategoryBySlug $trim
}

function Print-Category($c) {
  if (-not $c) { return }
  $parentIdText = $c.parent_id
  if ([string]::IsNullOrWhiteSpace($parentIdText)) { $parentIdText = "NULL" }
  Write-Host ("id={0} parent_id={1} slug={2} name={3} sort={4} status={5}" -f $c.id, $parentIdText, $c.slug, $c.name, $c.sort_order, $c.status)
}

function List-Roots {
  $raw = Invoke-PazarSql -Sql "SELECT id,parent_id,slug,name,sort_order,status FROM categories WHERE parent_id IS NULL AND status='active' ORDER BY sort_order ASC, id ASC;"
  if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Warn "No active root categories found."
    return
  }
  Write-Title "Aktif kok kategoriler"
  $raw -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $c = Parse-Row $_ @('id','parent_id','slug','name','sort_order','status')
    Print-Category $c
  }
}

function Get-AllActiveCategories {
  $raw = Invoke-PazarSql -Sql "SELECT id,parent_id,slug,name,sort_order,status FROM categories WHERE status='active' ORDER BY sort_order ASC, id ASC;"
  $rows = @()
  if ([string]::IsNullOrWhiteSpace($raw)) { return $rows }
  $raw -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $rows += (Parse-Row $_ @('id','parent_id','slug','name','sort_order','status'))
  }
  return $rows
}

function Print-Tree {
  $cats = Get-AllActiveCategories
  if ($cats.Count -eq 0) { Write-Warn "No active categories."; return }

  $byId = @{}
  $children = @{}
  foreach ($c in $cats) {
    $byId[$c.id] = $c
    $parentKey = $c.parent_id
    if ([string]::IsNullOrWhiteSpace($parentKey)) { $parentKey = "NULL" }
    if (-not $children.ContainsKey($parentKey)) { $children[$parentKey] = @() }
    $children[$parentKey] += $c
  }

  function Recurse([string]$parentKey, [int]$depth) {
    if (-not $children.ContainsKey($parentKey)) { return }
    foreach ($c in $children[$parentKey]) {
      $indent = ("  " * $depth)
      Write-Host ("{0}- {1} (id={2}, sort={3})" -f $indent, $c.slug, $c.id, $c.sort_order)
      Recurse $c.id ($depth + 1)
    }
  }

  Write-Title "Kategori agaci (aktif)"
  Recurse "NULL" 0
}

function Print-SubtreeCompactByRootId {
  param(
    [Parameter(Mandatory=$true)][int]$RootId,
    [switch]$HideIlanLeaves,
    [switch]$HideInactive
  )

  $sql = @"
WITH RECURSIVE t AS (
  SELECT id, parent_id, slug, name, sort_order, status
  FROM categories
  WHERE id = $RootId
  UNION ALL
  SELECT c.id, c.parent_id, c.slug, c.name, c.sort_order, c.status
  FROM categories c
  JOIN t ON c.parent_id = t.id
)
SELECT id,parent_id,slug,name,sort_order,status
FROM t;
"@

  $raw = Invoke-PazarSql -Sql $sql
  if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Warn "Alt agac bulunamadi."
    return
  }

  $rows = @()
  $raw -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $rows += (Parse-Row $_ @('id','parent_id','slug','name','sort_order','status'))
  }

  if ($HideInactive) {
    $rows = $rows | Where-Object { $_.status -eq 'active' -or [string]$_.id -eq [string]$RootId }
  }

  if ($HideIlanLeaves) {
    # keep root even if it matches pattern
    $rows = $rows | Where-Object {
      ([string]$_.id -eq [string]$RootId) -or (-not ([string]$_.slug).EndsWith('-ilan'))
    }
  }

  # adjacency
  $byParent = @{}
  foreach ($r in $rows) {
    $pk = $r.parent_id
    if ([string]::IsNullOrWhiteSpace($pk)) { $pk = "NULL" }
    if (-not $byParent.ContainsKey($pk)) { $byParent[$pk] = New-Object System.Collections.ArrayList }
    [void]$byParent[$pk].Add($r)
  }

  function Sort-Siblings($list) {
    return $list | Sort-Object `
      @{ Expression = { [int]($_.sort_order -as [int]) }; Ascending = $true }, `
      @{ Expression = { [int]($_.id -as [int]) }; Ascending = $true }
  }

  function Print-NodeCompact($r, [int]$depth) {
    $indent = ("  " * $depth)
    $inactiveMark = if ($r.status -ne 'active') { " [inactive]" } else { "" }
    Write-Host ("{0}{1}  {2}  {3}{4}" -f $indent, $r.id, $r.slug, $r.name, $inactiveMark)
    $kidsKey = [string]$r.id
    if ($byParent.ContainsKey($kidsKey)) {
      $kids = Sort-Siblings $byParent[$kidsKey]
      foreach ($k in $kids) { Print-NodeCompact $k ($depth + 1) }
    }
  }

  $rootRow = $rows | Where-Object { [string]$_.id -eq [string]$RootId } | Select-Object -First 1
  if (-not $rootRow) {
    Write-Warn "Root satiri bulunamadi (id=$RootId)."
    return
  }

  Write-Host ""
  Write-Title "LISTE (kolay)"
  Write-Info  "Format: id  slug  name"
  if ($HideIlanLeaves) { Write-Info "Not: *-ilan leaf'ler gizli" }
  if ($HideInactive) { Write-Info "Not: inactive kategoriler gizli" }
  Write-Host ""
  Print-NodeCompact $rootRow 0
}

function Print-SubtreeDetailedByRootId {
  param(
    [Parameter(Mandatory=$true)][int]$RootId
  )

  $sql = @"
WITH RECURSIVE t AS (
  SELECT id, parent_id, slug, name, sort_order, status
  FROM categories
  WHERE id = $RootId
  UNION ALL
  SELECT c.id, c.parent_id, c.slug, c.name, c.sort_order, c.status
  FROM categories c
  JOIN t ON c.parent_id = t.id
)
SELECT id,parent_id,slug,name,sort_order,status
FROM t;
"@

  $raw = Invoke-PazarSql -Sql $sql
  if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Warn "Alt agac bulunamadi."
    return
  }

  Write-Host ""
  Write-Title "LISTE (detayli)"
  Write-Info  "Kolonlar: id | parent_id | slug | name | sort | status"
  Write-Host ""

  # Build adjacency map and print as a real tree (prevents misleading indentation/order)
  $rows = @()
  $raw -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $rows += (Parse-Row $_ @('id','parent_id','slug','name','sort_order','status'))
  }

  $byParent = @{}
  foreach ($r in $rows) {
    $pk = $r.parent_id
    if ([string]::IsNullOrWhiteSpace($pk)) { $pk = "NULL" }
    if (-not $byParent.ContainsKey($pk)) { $byParent[$pk] = New-Object System.Collections.ArrayList }
    [void]$byParent[$pk].Add($r)
  }

  function Sort-Siblings($list) {
    return $list | Sort-Object `
      @{ Expression = { [int]($_.sort_order -as [int]) }; Ascending = $true }, `
      @{ Expression = { [int]($_.id -as [int]) }; Ascending = $true }
  }

  function Print-Node($r, [int]$depth) {
    $indent = ("  " * $depth)
    $pText = $r.parent_id
    if ([string]::IsNullOrWhiteSpace($pText)) { $pText = "NULL" }
    Write-Host ("{0}id={1} parent_id={2} slug={3} name={4} sort={5} status={6}" -f $indent, $r.id, $pText, $r.slug, $r.name, $r.sort_order, $r.status)
    $kidsKey = [string]$r.id
    if ($byParent.ContainsKey($kidsKey)) {
      $kids = Sort-Siblings $byParent[$kidsKey]
      foreach ($k in $kids) { Print-Node $k ($depth + 1) }
    }
  }

  # Find root row in the subtree and print from there
  $rootRow = $rows | Where-Object { [string]$_.id -eq [string]$RootId } | Select-Object -First 1
  if (-not $rootRow) {
    Write-Warn "Root satiri bulunamadi (id=$RootId)."
    return
  }
  Print-Node $rootRow 0
}

function Quick-SelectRoot {
  Write-Host ""
  Write-Title "Ana dal sec"
  Write-Host "1) vasita (vehicle)"
  Write-Host "2) emlak (real-estate)"
  Write-Host "3) service"
  Write-Host "0) geri"
  $sel = Read-Host "Secim"
  if ($sel -eq "1") { return 4 }
  if ($sel -eq "2") { return 5 }
  if ($sel -eq "3") { return 1 }
  return 0
}

function Quick-MoveByRoot {
  Write-Title "HIZLI TASIMA"
  $rootId = Quick-SelectRoot
  if (-not $rootId) { return }

  $root = Get-CategoryById ([string]$rootId)
  if (-not $root) { Write-Fail "Root bulunamadi (id=$rootId)"; return }

  Write-Info ("Secilen root: " + $root.slug + " (id=" + $root.id + ")")
  # Quick view: hide *-ilan leaves and inactive nodes to reduce noise
  Print-SubtreeCompactByRootId -RootId ([int]$root.id) -HideIlanLeaves -HideInactive

  Write-Host ""
  $childIdRaw = Read-Host "Tasinacak ID (Enter/0=iptal)"
  if ([string]::IsNullOrWhiteSpace($childIdRaw) -or $childIdRaw.Trim() -eq "0") { Write-Warn "Iptal."; return }
  if ($childIdRaw -notmatch '^\d+$') { Write-Fail "ID sayi olmali."; return }

  $parentIdRaw = Read-Host "Nereye (ust ID) (Enter/0=iptal; ROOT tasima kapali)"
  if ([string]::IsNullOrWhiteSpace($parentIdRaw) -or $parentIdRaw.Trim() -eq "0") {
    if ($AllowRootMove) {
      Write-Warn "Bos birakildi: ROOT tasima secildi (AllowRootMove acik)."
    } else {
      Write-Warn "Iptal (ROOT tasima kapali)."
      return
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($parentIdRaw) -and ($parentIdRaw -notmatch '^\d+$')) {
    Write-Fail "Ust ID sayi olmali (veya bos)."
    return
  }

  $child = Get-CategoryById $childIdRaw
  if (-not $child) { Write-Fail ("Bulunamadi: id=" + $childIdRaw); return }

  $newParent = $null
  $newParentId = 0
  if (-not [string]::IsNullOrWhiteSpace($parentIdRaw)) {
    $newParent = Get-CategoryById $parentIdRaw
    if (-not $newParent) { Write-Fail ("Bulunamadi: ust id=" + $parentIdRaw); return }
    $newParentId = [int]$newParent.id
  }

  if (-not (Test-MoveIsSafe -ChildId ([int]$child.id) -NewParentId $newParentId)) {
    Write-Fail "Guven­siz tasima (cycle olur veya self-parent). Iptal."
    return
  }

  Write-Host ""
  Write-Info "Onizleme:"
  Write-Host "  KATEGORI: " -NoNewline; Print-Category $child
  if ($newParent) { Write-Host "  UST:      " -NoNewline; Print-Category $newParent }
  else { Write-Host "  UST:      ROOT (parent_id=NULL)" }

  $confirm = Read-Host "Uygula? (e/H)"
  if ($confirm.ToLowerInvariant() -ne "e") { Write-Warn "Iptal."; return }

  $sql = if ($newParent) {
    "UPDATE categories SET parent_id = $newParentId WHERE id = $([int]$child.id);"
  } else {
    "UPDATE categories SET parent_id = NULL WHERE id = $([int]$child.id);"
  }
  Invoke-PazarSql -Sql "BEGIN; $sql COMMIT;"
  Write-Pass "Tasima uygulandi."
}

function Quick-RenameByRoot {
  Write-Title "HIZLI ISIM DEGISTIRME"
  $rootId = Quick-SelectRoot
  if (-not $rootId) { return }

  $root = Get-CategoryById ([string]$rootId)
  if (-not $root) { Write-Fail "Root bulunamadi (id=$rootId)"; return }

  Write-Info ("Secilen root: " + $root.slug + " (id=" + $root.id + ")")
  # Quick view: hide *-ilan leaves and inactive nodes to reduce noise
  Print-SubtreeCompactByRootId -RootId ([int]$root.id) -HideIlanLeaves -HideInactive

  Write-Host ""
  $idRaw = Read-Host "ID (Enter/0=iptal)"
  if ([string]::IsNullOrWhiteSpace($idRaw) -or $idRaw.Trim() -eq "0") { Write-Warn "Iptal."; return }
  if ($idRaw -notmatch '^\d+$') { Write-Fail "ID sayi olmali."; return }

  $c = Get-CategoryById $idRaw
  if (-not $c) { Write-Fail ("Bulunamadi: id=" + $idRaw); return }

  Write-Info "Mevcut:"
  Print-Category $c

  $newName = Read-Host "Yeni ad"
  if ([string]::IsNullOrWhiteSpace($newName)) { Write-Warn "Degisiklik yok."; return }

  $escaped = Escape-SqlLiteral $newName
  Invoke-PazarSql -Sql "BEGIN; UPDATE categories SET name='$escaped' WHERE id=$([int]$c.id); COMMIT;"
  Write-Pass "Ad guncellendi."
}

function Show-CategoryPathInteractive {
  Write-Title "Kategori yolu (root path) goster"
  $in = Read-Host "Kategori (slug veya id)"
  $c = Resolve-Category $in
  if (-not $c) { Write-Fail "Bulunamadi: $in"; return }

  $cid = [int]$c.id
  $sql = @"
WITH RECURSIVE up AS (
  SELECT id, parent_id, slug FROM categories WHERE id = $cid
  UNION ALL
  SELECT c.id, c.parent_id, c.slug FROM categories c
  JOIN up u ON u.parent_id = c.id
)
SELECT id,parent_id,slug FROM up;
"@
  $raw = Invoke-PazarSql -Sql $sql
  $rows = @()
  if (-not [string]::IsNullOrWhiteSpace($raw)) {
    $raw -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
      $rows += (Parse-Row $_ @('id','parent_id','slug'))
    }
  }
  if ($rows.Count -eq 0) {
    Write-Warn "Path bulunamadi."
    return
  }

  # Build map and walk up from current to root
  $byId = @{}
  foreach ($r in $rows) { $byId[[string]$r.id] = $r }
  $path = @()
  $cur = [string]$cid
  $seen = @{}
  while ($cur -and $byId.ContainsKey($cur)) {
    if ($seen.ContainsKey($cur)) { break }
    $seen[$cur] = $true
    $path += $byId[$cur].slug
    $cur = $byId[$cur].parent_id
    if ([string]::IsNullOrWhiteSpace($cur)) { break }
  }
  $pathText = ($path -join "/")
  Write-Pass ("PATH: " + $pathText)
  Write-Info ("id=" + $c.id + " slug=" + $c.slug)
}

function List-ChildrenInteractive {
  Write-Title "Cocuk kategorileri listele (direct children)"
  $in = Read-Host "Ust kategori (slug veya id) veya ROOT icin bos birak"
  $parent = Resolve-Category $in
  $sql = $null
  if ($parent) {
    $parentId = [int]$parent.id
    $sql = "SELECT id,parent_id,slug,name,sort_order,status FROM categories WHERE parent_id=$parentId ORDER BY sort_order ASC, id ASC;"
    Write-Info ("UST: id=" + $parent.id + " slug=" + $parent.slug)
  } else {
    $sql = "SELECT id,parent_id,slug,name,sort_order,status FROM categories WHERE parent_id IS NULL ORDER BY sort_order ASC, id ASC;"
    Write-Info "UST: ROOT"
  }
  $raw = Invoke-PazarSql -Sql $sql
  if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Warn "Cocuk kategori yok."
    return
  }
  $raw -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $c = Parse-Row $_ @('id','parent_id','slug','name','sort_order','status')
    Print-Category $c
  }
}

function Print-SubtreeInteractive {
  Write-Title "Alt agaci yazdir (subtree)"
  $in = Read-Host "Baslangic kategori (slug veya id) veya ROOT icin bos birak"
  $root = Resolve-Category $in
  $rootId = if ($root) { [int]$root.id } else { 0 }
  $title = if ($root) { ("ALT AGAC: " + $root.slug + " (id=" + $root.id + ")") } else { "ALT AGAC: ROOT" }
  Write-Info $title

  $where = if ($root) { "id = $rootId" } else { "parent_id IS NULL" }
  $sql = @"
WITH RECURSIVE t AS (
  SELECT id, parent_id, slug, sort_order FROM categories WHERE $where
  UNION ALL
  SELECT c.id, c.parent_id, c.slug, c.sort_order
  FROM categories c
  JOIN t ON c.parent_id = t.id
  WHERE c.status='active'
)
SELECT id,parent_id,slug,sort_order FROM t ORDER BY parent_id NULLS FIRST, sort_order ASC, id ASC;
"@
  $raw = Invoke-PazarSql -Sql $sql
  if ([string]::IsNullOrWhiteSpace($raw)) { Write-Warn "Alt agac bulunamadi."; return }

  $rows = @()
  $raw -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    $rows += (Parse-Row $_ @('id','parent_id','slug','sort_order'))
  }

  $children = @{}
  foreach ($r in $rows) {
    $pk = $r.parent_id
    if ([string]::IsNullOrWhiteSpace($pk)) { $pk = "NULL" }
    if (-not $children.ContainsKey($pk)) { $children[$pk] = @() }
    $children[$pk] += $r
  }

  function RecurseSub([string]$parentKey, [int]$depth) {
    if (-not $children.ContainsKey($parentKey)) { return }
    foreach ($c in $children[$parentKey]) {
      $indent = ("  " * $depth)
      Write-Host ("{0}- {1} (id={2}, sort={3})" -f $indent, $c.slug, $c.id, $c.sort_order)
      RecurseSub $c.id ($depth + 1)
    }
  }

  if ($root) {
    # Print root itself and recurse its children
    Write-Host ("- {0} (id={1})" -f $root.slug, $root.id)
    RecurseSub $root.id 1
  } else {
    RecurseSub "NULL" 0
  }
}

function Test-MoveIsSafe {
  param(
    [Parameter(Mandatory=$true)][int]$ChildId,
    [int]$NewParentId
  )
  if ($NewParentId -eq $ChildId) { return $false }
  if (-not $NewParentId) { return $true } # moving to root

  # Prevent cycles: new parent cannot be inside child's subtree
  $sql = @"
WITH RECURSIVE sub AS (
  SELECT id, parent_id FROM categories WHERE id = $ChildId
  UNION ALL
  SELECT c.id, c.parent_id FROM categories c
  JOIN sub s ON c.parent_id = s.id
)
SELECT COUNT(*) FROM sub WHERE id = $NewParentId;
"@
  $raw = Invoke-PazarSql -Sql $sql
  $n = 0
  [void][int]::TryParse(($raw -split "`n" | Select-Object -First 1), [ref]$n)
  return ($n -eq 0)
}

function Move-CategoryInteractive {
  Write-Title "Kategori tasi (ust kategori degistir)"
  $childIn = Read-Host "Tasinacak kategori (slug veya id)"
  $child = Resolve-Category $childIn
  if (-not $child) { Write-Fail "Bulunamadi: $childIn"; return }

  $parentIn = Read-Host "Yeni ust kategori (slug/id) (ROOT tasima kapali; Enter=iptal)"
  if ([string]::IsNullOrWhiteSpace($parentIn)) {
    if ($AllowRootMove) {
      Write-Warn "Bos birakildi: ROOT tasima secildi (AllowRootMove acik)."
    } else {
      Write-Warn "Iptal (ROOT tasima kapali)."
      return
    }
  }
  $newParent = Resolve-Category $parentIn
  $newParentId = if ($newParent) { [int]$newParent.id } else { 0 }

  if (-not (Test-MoveIsSafe -ChildId ([int]$child.id) -NewParentId $newParentId)) {
    Write-Fail "Guven­siz tasima (cycle olur veya self-parent). Iptal."
    return
  }

  Write-Info "Onizleme:"
  Write-Host "  KATEGORI: " -NoNewline; Print-Category $child
  if ($newParent) { Write-Host "  UST:      " -NoNewline; Print-Category $newParent }
  else { Write-Host "  UST:      ROOT (parent_id=NULL)" }

  $confirm = Read-Host "Uygula? (e/H)"
  if ($confirm.ToLowerInvariant() -ne "e") { Write-Warn "Iptal."; return }

  $sql = if ($newParent) {
    "UPDATE categories SET parent_id = $newParentId WHERE id = $([int]$child.id);"
  } else {
    "UPDATE categories SET parent_id = NULL WHERE id = $([int]$child.id);"
  }
  Invoke-PazarSql -Sql "BEGIN; $sql COMMIT;"
  Write-Pass "Tasima uygulandi."
}

function Rename-CategoryInteractive {
  Write-Title "Kategori adini degistir (name)"
  $in = Read-Host "Kategori (slug veya id)"
  $c = Resolve-Category $in
  if (-not $c) { Write-Fail "Bulunamadi: $in"; return }
  Write-Info "Mevcut:"
  Print-Category $c
  $newName = Read-Host "Yeni ad"
  if ([string]::IsNullOrWhiteSpace($newName)) { Write-Warn "Degisiklik yok."; return }
  $escaped = Escape-SqlLiteral $newName
  Invoke-PazarSql -Sql "BEGIN; UPDATE categories SET name='$escaped' WHERE id=$([int]$c.id); COMMIT;"
  Write-Pass "Ad guncellendi."
}

function Change-SlugInteractive {
  Write-Title "Slug degistir (TEHLIKELI: policy/URL etkiler)"
  Write-Warn "Slug degisimi policy eslesmesini degistirebilir. Mumkunse slug stabil kalsin."
  $in = Read-Host "Kategori (slug veya id)"
  $c = Resolve-Category $in
  if (-not $c) { Write-Fail "Bulunamadi: $in"; return }
  Write-Info "Mevcut:"
  Print-Category $c
  $newSlug = Read-Host "Yeni slug (ascii, benzersiz)"
  if ([string]::IsNullOrWhiteSpace($newSlug)) { Write-Warn "Degisiklik yok."; return }
  $escaped = Escape-SqlLiteral $newSlug.Trim()
  $confirm = Read-Host "Slug degisikligini uygula? (e/H)"
  if ($confirm.ToLowerInvariant() -ne "e") { Write-Warn "Iptal."; return }
  Invoke-PazarSql -Sql "BEGIN; UPDATE categories SET slug='$escaped' WHERE id=$([int]$c.id); COMMIT;"
  Write-Pass "Slug guncellendi."
}

function Set-SortOrderInteractive {
  Write-Title "Siralama (sort_order) degistir"
  $in = Read-Host "Kategori (slug veya id)"
  $c = Resolve-Category $in
  if (-not $c) { Write-Fail "Bulunamadi: $in"; return }
  Write-Info "Mevcut:"
  Print-Category $c
  $nRaw = Read-Host "Yeni sort_order (tamsayi)"
  $n = 0
  if (-not [int]::TryParse($nRaw, [ref]$n)) { Write-Fail "Gecersiz tamsayi."; return }
  Invoke-PazarSql -Sql "BEGIN; UPDATE categories SET sort_order=$n WHERE id=$([int]$c.id); COMMIT;"
  Write-Pass "sort_order guncellendi."
}

function Set-StatusInteractive {
  Write-Title "Aktif/Pasif yap (status)"
  $in = Read-Host "Kategori (slug veya id)"
  $c = Resolve-Category $in
  if (-not $c) { Write-Fail "Bulunamadi: $in"; return }
  Write-Info "Mevcut:"
  Print-Category $c
  Write-Host ""
  Write-Host "1) active (aktif)"
  Write-Host "2) inactive (pasif)"
  $sel = Read-Host "Sec"
  $status = if ($sel -eq "1") { "active" } elseif ($sel -eq "2") { "inactive" } else { "" }
  if (-not $status) { Write-Warn "Iptal."; return }
  Invoke-PazarSql -Sql "BEGIN; UPDATE categories SET status='$status' WHERE id=$([int]$c.id); COMMIT;"
  Write-Pass "Status guncellendi."
}

function Run-IntegrityGate {
  Write-Title "catalog_integrity_check calisiyor..."
  $gate = Join-Path $repoRoot "ops\catalog_integrity_check.ps1"
  if (-not (Test-Path $gate)) { Write-Fail "Eksik gate: $gate"; return }
  & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $gate
  if ($LASTEXITCODE -eq 0) { Write-Pass "catalog_integrity_check: PASS" }
  else { Write-Fail "catalog_integrity_check: FAIL (kod=$LASTEXITCODE)" }
}

function Show-Menu {
  while ($true) {
    cls
    Write-Title "=== KATEGORI MENUSU (gecici admin) ==="
    Write-Info  ("Repo: " + $repoRoot)
    Write-Info  ("DB: docker compose exec -T pazar-db psql -U pazar -d pazar")
    Write-Host ""
    Write-Host "1) HIZLI TASIMA (root sec -> liste -> childId -> parentId)"
    Write-Host "2) HIZLI ISIM DEGISTIR (root sec -> liste -> id -> yeni ad)"
    Write-Host ""
    Write-Host "--- Gelismis ---"
    Write-Host "3) Aktif kok kategorileri goster"
    Write-Host "4) Aktif kategori agacini yazdir"
    Write-Host "5) Slug/ID ile kategori bul"
    Write-Host "6) Kategori tasi (ust kategori degistir)"
    Write-Host "7) Kategori adini degistir (name)"
    Write-Host "8) Slug degistir (TEHLIKELI)"
    Write-Host "9) Siralama degistir (sort_order)"
    Write-Host "10) Aktif/Pasif yap (status)"
    Write-Host "11) catalog_integrity_check calistir"
    Write-Host "12) Kategori yolu (path) goster"
    Write-Host "13) Alt agaci yazdir (subtree)"
    Write-Host "14) Cocuklari listele (direct children)"
    Write-Host "0) Cikis"
    Write-Host ""
    $sel = Read-Host "Secim"

    if ($sel -eq "0") { return }
    elseif ($sel -eq "1") { Quick-MoveByRoot }
    elseif ($sel -eq "2") { Quick-RenameByRoot }
    elseif ($sel -eq "3") { List-Roots }
    elseif ($sel -eq "4") { Print-Tree }
    elseif ($sel -eq "5") {
      $q = Read-Host "slug veya id"
      $c = Resolve-Category $q
      if ($c) { Print-Category $c } else { Write-Fail "Bulunamadi: $q" }
    }
    elseif ($sel -eq "6") { Move-CategoryInteractive }
    elseif ($sel -eq "7") { Rename-CategoryInteractive }
    elseif ($sel -eq "8") { Change-SlugInteractive }
    elseif ($sel -eq "9") { Set-SortOrderInteractive }
    elseif ($sel -eq "10") { Set-StatusInteractive }
    elseif ($sel -eq "11") { Run-IntegrityGate }
    elseif ($sel -eq "12") { Show-CategoryPathInteractive }
    elseif ($sel -eq "13") { Print-SubtreeInteractive }
    elseif ($sel -eq "14") { List-ChildrenInteractive }
    else { Write-Warn "Bilinmeyen secim." }

    Write-Host ""
    Write-Host "Enter = menuye don"
    [void](Read-Host "Devam etmek icin Enter")
  }
}

try {
  if ($Action -eq 'list_roots') { List-Roots; exit 0 }
  if ($Action -eq 'tree') { Print-Tree; exit 0 }
  if ($Action -eq 'integrity') { Run-IntegrityGate; exit $LASTEXITCODE }
  if ($Action -eq 'quick_list_vehicle') {
    $root = Get-CategoryById "4"
    if (-not $root) { Write-Fail "Root bulunamadi (vehicle id=4)"; exit 1 }
    Write-Info ("Secilen root: " + $root.slug + " (id=" + $root.id + ")")
    Print-SubtreeCompactByRootId -RootId ([int]$root.id) -HideIlanLeaves -HideInactive
    exit 0
  }
  if ($Action -eq 'quick_list_real_estate') {
    $root = Get-CategoryById "5"
    if (-not $root) { Write-Fail "Root bulunamadi (real-estate id=5)"; exit 1 }
    Write-Info ("Secilen root: " + $root.slug + " (id=" + $root.id + ")")
    Print-SubtreeCompactByRootId -RootId ([int]$root.id) -HideIlanLeaves -HideInactive
    exit 0
  }
  if ($Action -eq 'quick_list_service') {
    $root = Get-CategoryById "1"
    if (-not $root) { Write-Fail "Root bulunamadi (service id=1)"; exit 1 }
    Write-Info ("Secilen root: " + $root.slug + " (id=" + $root.id + ")")
    Print-SubtreeCompactByRootId -RootId ([int]$root.id) -HideIlanLeaves -HideInactive
    exit 0
  }
  Show-Menu
  exit 0
} catch {
  Write-Fail ("HATA: " + $_.Exception.Message)
  exit 1
}

