#!/usr/bin/env pwsh
# Trendyol Category Coverage Check
# Measures menu reachability, gender isolation, and menu_edges integrity
# for the service-product (Trendyol) branch only.
# Exit codes: 0 PASS, 1 FAIL

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== TRENDYOL CATEGORY COVERAGE CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "BaseUrl: $BaseUrl" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# --- Fetch APIs ---
Write-Host "[0] Fetching category APIs..." -ForegroundColor Yellow

$menuData = $null
$dbData = $null

try {
    $menuRaw = Invoke-RestMethod -Uri "$BaseUrl/api/v1/categories?view=menu" -Method Get -TimeoutSec 60 -ErrorAction Stop
    $menuData = $menuRaw
} catch {
    Write-Host "FAIL: Could not fetch menu API: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

try {
    $dbRaw = Invoke-RestMethod -Uri "$BaseUrl/api/v1/categories" -Method Get -TimeoutSec 60 -ErrorAction Stop
    $dbData = $dbRaw
} catch {
    Write-Host "FAIL: Could not fetch DB categories API: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

if (-not $menuData -or -not $dbData) {
    Write-Host "=== TRENDYOL CATEGORY COVERAGE CHECK: FAIL ===" -ForegroundColor Red
    exit 1
}

# --- Helper: flatten tree ---
function Get-FlatNodes {
    param($Tree, [int]$Depth = 0)
    $result = @()
    foreach ($node in $Tree) {
        $result += [pscustomobject]@{
            id = $node.id
            canonical_category_id = $node.canonical_category_id
            title = $node.title
            slug = $node.slug
            depth = $Depth
        }
        if ($node.children) {
            $result += Get-FlatNodes -Tree $node.children -Depth ($Depth + 1)
        }
    }
    return $result
}

# Slug-based search avoids Turkish character encoding issues in PowerShell
function Find-NodeBySlugChain {
    param($Tree, [string[]]$SlugParts, [int]$Index = 0)
    foreach ($node in $Tree) {
        $s = if ($node.slug) { $node.slug } else { "" }
        if ($s -like "*$($SlugParts[$Index])*") {
            if ($Index -eq ($SlugParts.Count - 1)) { return $node }
            if ($node.children) {
                $found = Find-NodeBySlugChain -Tree $node.children -SlugParts $SlugParts -Index ($Index + 1)
                if ($found) { return $found }
            }
        }
        if ($node.children) {
            $found = Find-NodeBySlugChain -Tree $node.children -SlugParts $SlugParts -Index $Index
            if ($found) { return $found }
        }
    }
    return $null
}

$menuFlat = Get-FlatNodes -Tree $menuData
$dbFlat = Get-FlatNodes -Tree $dbData

$menuCids = @{}
foreach ($n in $menuFlat) {
    if ($n.canonical_category_id) { $menuCids[$n.canonical_category_id] = $true }
}

$dbIds = @{}
foreach ($n in $dbFlat) {
    if ($n.id) { $dbIds[$n.id] = $n }
}

$reachable = $menuCids.Count
$dbCount = $dbIds.Count
$unreachable = $dbCount - $reachable
$coveragePct = if ($dbCount -gt 0) { [math]::Round($reachable / $dbCount * 100, 1) } else { 0 }

Write-Host "  Menu nodes: $($menuFlat.Count), DB categories: $dbCount" -ForegroundColor Gray
Write-Host ""

# --- [A] Coverage ---
Write-Host "[A] Trendyol category coverage..." -ForegroundColor Yellow
$coverageThreshold = 99.0
if ($coveragePct -ge $coverageThreshold) {
    Write-Host "PASS: Coverage $coveragePct% ($reachable / $dbCount reachable)" -ForegroundColor Green
} else {
    Write-Host "FAIL: Coverage $coveragePct% < $coverageThreshold% ($unreachable unreachable)" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# --- [B] Gender isolation ---
Write-Host "[B] Gender isolation (Erkek > Giyim)..." -ForegroundColor Yellow
$erkekGiyim = Find-NodeBySlugChain -Tree $menuData -SlugParts @("service-product-erkek", "ty-c82")
$genderLeaks = @()
if ($erkekGiyim -and $erkekGiyim.children) {
    $badForErkek = @("Gelinlik", "Etek", "Abiye", "Tesettür")
    foreach ($child in $erkekGiyim.children) {
        $ct = if ($child.title) { $child.title } else { "" }
        foreach ($bad in $badForErkek) {
            if ($ct -eq $bad) { $genderLeaks += "Erkek > Giyim > $ct" }
        }
    }
}
if ($genderLeaks.Count -eq 0) {
    Write-Host "PASS: No gender leakage detected" -ForegroundColor Green
} else {
    Write-Host "FAIL: Gender leakage found: $($genderLeaks -join ', ')" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# --- [C] Erkek Giyim count ---
Write-Host "[C] Erkek > Giyim child count..." -ForegroundColor Yellow
$erkekCount = if ($erkekGiyim -and $erkekGiyim.children) { $erkekGiyim.children.Count } else { 0 }
if ($erkekCount -ge 20 -and $erkekCount -le 30) {
    Write-Host "PASS: Erkek > Giyim has $erkekCount children (threshold: 20-30)" -ForegroundColor Green
} elseif ($erkekCount -gt 0) {
    Write-Host "WARN: Erkek > Giyim has $erkekCount children (expected: 20-30)" -ForegroundColor Yellow
} else {
    Write-Host "FAIL: Erkek > Giyim not found or empty" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# --- [D] Kadin Giyim count ---
Write-Host "[D] Kadin > Giyim child count..." -ForegroundColor Yellow
$kadinGiyim = Find-NodeBySlugChain -Tree $menuData -SlugParts @("service-product-kadin", "ty-c82")
$kadinCount = if ($kadinGiyim -and $kadinGiyim.children) { $kadinGiyim.children.Count } else { 0 }
if ($kadinCount -ge 30 -and $kadinCount -le 45) {
    Write-Host "PASS: Kadin > Giyim has $kadinCount children (threshold: 30-45)" -ForegroundColor Green
} elseif ($kadinCount -gt 0) {
    Write-Host "WARN: Kadin > Giyim has $kadinCount children (expected: 30-45)" -ForegroundColor Yellow
} else {
    Write-Host "FAIL: Kadin > Giyim not found or empty" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# --- [E] Top-level Urun sections ---
Write-Host "[E] Top-level Urun (service-product) sections..." -ForegroundColor Yellow
$urun = Find-NodeBySlugChain -Tree $menuData -SlugParts @("service-product")
$sectionCount = 0
$sectionNames = @()
if ($urun -and $urun.children) {
    $sectionCount = $urun.children.Count
    foreach ($s in $urun.children) {
        $cc = if ($s.children) { $s.children.Count } else { 0 }
        $sectionNames += "$($s.title)($cc)"
    }
}
if ($sectionCount -ge 10) {
    Write-Host "PASS: $sectionCount top sections (threshold: >=10)" -ForegroundColor Green
    Write-Host "  $($sectionNames -join ', ')" -ForegroundColor Gray
} else {
    Write-Host "FAIL: Only $sectionCount top sections (need >=10)" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# --- [F] Null canonical_id ratio ---
Write-Host "[F] Null canonical_category_id ratio..." -ForegroundColor Yellow
$nullCids = ($menuFlat | Where-Object { -not $_.canonical_category_id }).Count
$nullPct = if ($menuFlat.Count -gt 0) { [math]::Round($nullCids / $menuFlat.Count * 100, 1) } else { 0 }
if ($nullPct -lt 5) {
    Write-Host "PASS: $nullPct% null canonical IDs ($nullCids / $($menuFlat.Count))" -ForegroundColor Green
} else {
    Write-Host "FAIL: $nullPct% null canonical IDs (threshold: <5%)" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# --- [G] menu_edges file integrity ---
Write-Host "[G] menu_edges.trendyol.json integrity..." -ForegroundColor Yellow
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$edgesPath = Join-Path $repoRoot "work\pazar\routes\menu_edges.trendyol.json"
if (Test-Path $edgesPath) {
    $edgesRaw = Get-Content $edgesPath -Raw -Encoding UTF8
    $edgesData = $edgesRaw | ConvertFrom-Json
    $declaredCount = $edgesData.edges_count
    $actualCount = $edgesData.edges.Count

    if ($declaredCount -eq $actualCount) {
        Write-Host "PASS: edges_count matches ($actualCount)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: edges_count=$declaredCount but actual=$actualCount" -ForegroundColor Red
        $hasFailures = $true
    }

    # Check WC references exist in DB
    $wcRefs = @{}
    foreach ($e in $edgesData.edges) {
        if ($e.wc -and $e.wc -match '^\d+$') {
            $wcRefs[$e.wc] = $e.child_slug
        }
    }
    $dbSlugs = @{}
    foreach ($n in $dbFlat) {
        if ($n.slug) { $dbSlugs[$n.slug] = $true }
    }
    $brokenWcs = @()
    foreach ($wc in $wcRefs.Keys) {
        $expectedSlug = "service-product-ty-c$wc"
        if (-not $dbSlugs.ContainsKey($expectedSlug)) {
            $brokenWcs += "wc=$wc (child: $($wcRefs[$wc]))"
        }
    }
    if ($brokenWcs.Count -eq 0) {
        Write-Host "PASS: All WC references in menu_edges exist in DB ($($wcRefs.Count) checked)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: $($brokenWcs.Count) WC references not found in DB" -ForegroundColor Red
        $brokenWcs | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        $hasFailures = $true
    }
} else {
    Write-Host "FAIL: menu_edges file not found: $edgesPath" -ForegroundColor Red
    $hasFailures = $true
}
Write-Host ""

# --- Summary ---
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Coverage:        $coveragePct% ($reachable / $dbCount)" -ForegroundColor Gray
Write-Host "  Gender leaks:    $($genderLeaks.Count)" -ForegroundColor Gray
Write-Host "  Erkek Giyim:     $erkekCount children" -ForegroundColor Gray
Write-Host "  Kadin Giyim:     $kadinCount children" -ForegroundColor Gray
Write-Host "  Top sections:    $sectionCount" -ForegroundColor Gray
Write-Host "  Null CIDs:       $nullPct%" -ForegroundColor Gray
Write-Host ""

if ($hasFailures) {
    Write-Host "=== TRENDYOL CATEGORY COVERAGE CHECK: FAIL ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== TRENDYOL CATEGORY COVERAGE CHECK: PASS ===" -ForegroundColor Green
    exit 0
}
