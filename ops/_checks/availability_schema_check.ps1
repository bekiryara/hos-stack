#!/usr/bin/env pwsh
# Availability Schema Check
# Purpose: Ensure create-selectable categories with non-none time models
# expose at least one filter_mode=availability field.

[CmdletBinding()]
param(
    [ValidateSet("pilot", "critical")]
    [string]$Scope = "pilot",
    [int]$MaxLeafsPerRule = 40
)

$ErrorActionPreference = "Stop"

Write-Host "=== AVAILABILITY SCHEMA CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Scope: $Scope" -ForegroundColor Gray
Write-Host "MaxLeafsPerRule: $MaxLeafsPerRule" -ForegroundColor Gray
Write-Host ""

$baseUrl = "http://localhost:8080/api/v1"
$violations = @()

function Get-ChildNodes {
    param([object]$Node)
    if ($null -eq $Node) { return @() }
    if (-not $Node.PSObject.Properties["children"]) { return @() }

    $childrenValue = $Node.children
    if ($null -eq $childrenValue) { return @() }

    # API can return children as "" / whitespace for empty nodes.
    if ($childrenValue -is [string]) {
        if ([string]::IsNullOrWhiteSpace($childrenValue)) { return @() }
        return @()
    }

    $children = @($childrenValue)
    return @($children | Where-Object { $_ -ne $null -and $_.PSObject.Properties["id"] })
}

function Collect-Descendants {
    param([object]$Root)
    $result = @()
    $queue = New-Object System.Collections.Queue
    foreach ($c in (Get-ChildNodes -Node $Root)) {
        $queue.Enqueue($c)
    }
    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        $result += $node
        foreach ($child in (Get-ChildNodes -Node $node)) {
            $queue.Enqueue($child)
        }
    }
    return $result
}

function Flatten-Categories {
    param([object[]]$Nodes)
    $flat = @()
    $queue = New-Object System.Collections.Queue
    foreach ($n in @($Nodes)) {
        if ($n -ne $null) { $queue.Enqueue($n) }
    }
    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        $flat += $node
        foreach ($child in (Get-ChildNodes -Node $node)) {
            $queue.Enqueue($child)
        }
    }
    return $flat
}

function Has-NonNoneTimeModel {
    param([object]$Intent)
    if ($null -eq $Intent) { return $false }

    if ($Intent.PSObject.Properties["offer_variants"] -and $Intent.offer_variants) {
        foreach ($v in @($Intent.offer_variants)) {
            $tm = [string]($v.service_time_model)
            if (-not [string]::IsNullOrWhiteSpace($tm) -and $tm -ne "none") {
                return $true
            }
        }
        return $false
    }

    $singleTm = [string]($Intent.service_time_model)
    return (-not [string]::IsNullOrWhiteSpace($singleTm) -and $singleTm -ne "none")
}

function Get-AvailabilityCount {
    param([object]$FilterSchema)
    if ($null -eq $FilterSchema -or -not $FilterSchema.PSObject.Properties["filters"] -or -not $FilterSchema.filters) {
        return 0
    }
    $count = 0
    foreach ($f in @($FilterSchema.filters)) {
        if ([string]($f.filter_mode) -eq "availability") {
            $count++
        }
    }
    return $count
}

try {
    $categories = Invoke-RestMethod -Uri "$baseUrl/categories" -Method Get -TimeoutSec 20 -ErrorAction Stop
} catch {
    Write-Host "FAIL: Could not fetch categories: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$roots = @($categories)
if (($roots | Measure-Object).Count -eq 0) {
    Write-Host "FAIL: Categories list is empty" -ForegroundColor Red
    exit 1
}
$flat = Flatten-Categories -Nodes $roots

if ($Scope -eq "pilot") {
    $pilotSlugs = @("bando", "wedding-hall", "otomobil-alfa-romeo", "daire")
    Write-Host "Pilot categories:" -ForegroundColor Cyan
    foreach ($slug in $pilotSlugs) {
        Write-Host "  - $slug" -ForegroundColor Gray
    }
    Write-Host ""

    foreach ($slug in $pilotSlugs) {
        $category = $flat | Where-Object { [string]$_.slug -eq $slug } | Select-Object -First 1
        if (-not $category) {
            $violations += "Pilot category not found: $slug"
            continue
        }

        $categoryId = [string]$category.id
        $intent = $null
        try {
            $intent = Invoke-RestMethod -Uri "$baseUrl/categories/$categoryId/intent-schema" -Method Get -TimeoutSec 20 -ErrorAction Stop
        } catch {
            $violations += "Intent schema fetch failed for pilot slug=$slug id=${categoryId}: $($_.Exception.Message)"
            continue
        }

        if (-not (Has-NonNoneTimeModel -Intent $intent)) {
            continue
        }

        $filterSchema = $null
        try {
            $filterSchema = Invoke-RestMethod -Uri "$baseUrl/categories/$categoryId/filter-schema" -Method Get -TimeoutSec 20 -ErrorAction Stop
        } catch {
            $violations += "Filter schema fetch failed for pilot slug=$slug id=${categoryId}: $($_.Exception.Message)"
            continue
        }

        $availabilityCount = Get-AvailabilityCount -FilterSchema $filterSchema
        if ($availabilityCount -lt 1) {
            $violations += "Missing availability filter in pilot category: slug=$slug id=$categoryId"
        }
    }
} else {
    # Critical rule roots where non-none service_time_model variants are expected in current policy.
    $criticalRuleSlugs = @("vehicle", "konut", "is-yeri", "events")
    $ruleSummaries = @()

    foreach ($ruleSlug in $criticalRuleSlugs) {
        $root = $flat | Where-Object { [string]$_.slug -eq $ruleSlug } | Select-Object -First 1
        if (-not $root) {
            $violations += "Category root not found for critical rule: $ruleSlug"
            continue
        }

        $desc = Collect-Descendants -Root $root
        $candidateLeafs = @(
            $desc |
                Where-Object {
                    $_.PSObject.Properties["selectable_for_create"] -and
                    $_.selectable_for_create -eq $true -and
                    (Get-ChildNodes -Node $_).Count -eq 0
                } |
                Sort-Object @{ Expression = { [int]$_.id } }, @{ Expression = { [string]$_.slug } }
        )

        $sampleLeafs = @($candidateLeafs | Select-Object -First $MaxLeafsPerRule)
        $checked = 0
        $timeEnabled = 0
        $missingAvailability = 0

        foreach ($leaf in $sampleLeafs) {
            $checked++
            $categoryId = [string]$leaf.id
            $categorySlug = [string]$leaf.slug

            $intent = $null
            try {
                $intent = Invoke-RestMethod -Uri "$baseUrl/categories/$categoryId/intent-schema" -Method Get -TimeoutSec 20 -ErrorAction Stop
            } catch {
                $violations += "Intent schema fetch failed for rule=$ruleSlug category_id=$categoryId slug=${categorySlug}: $($_.Exception.Message)"
                continue
            }

            if (-not (Has-NonNoneTimeModel -Intent $intent)) {
                continue
            }
            $timeEnabled++

            $filterSchema = $null
            try {
                $filterSchema = Invoke-RestMethod -Uri "$baseUrl/categories/$categoryId/filter-schema" -Method Get -TimeoutSec 20 -ErrorAction Stop
            } catch {
                $violations += "Filter schema fetch failed for rule=$ruleSlug category_id=$categoryId slug=${categorySlug}: $($_.Exception.Message)"
                continue
            }

            $availabilityCount = Get-AvailabilityCount -FilterSchema $filterSchema
            if ($availabilityCount -lt 1) {
                $missingAvailability++
                $violations += "Missing availability filter: rule=$ruleSlug category_id=$categoryId slug=$categorySlug (time_model!=none)"
            }
        }

        $ruleSummaries += [PSCustomObject]@{
            Rule = $ruleSlug
            CandidateLeafs = $candidateLeafs.Count
            CheckedLeafs = $checked
            TimeEnabledLeafs = $timeEnabled
            MissingAvailability = $missingAvailability
        }
    }

    Write-Host "Rule summary:" -ForegroundColor Cyan
    foreach ($s in $ruleSummaries) {
        Write-Host ("  - {0}: candidates={1}, checked={2}, time_enabled={3}, missing={4}" -f $s.Rule, $s.CandidateLeafs, $s.CheckedLeafs, $s.TimeEnabledLeafs, $s.MissingAvailability) -ForegroundColor Gray
    }
    Write-Host ""
}

if ($violations.Count -gt 0) {
    Write-Host "FAIL: Availability schema violations detected:" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  - $v" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "PASS: Availability schema contract is valid for checked create-selectable categories" -ForegroundColor Green
Write-Host "=== AVAILABILITY SCHEMA CHECK: PASS ===" -ForegroundColor Green
exit 0
