#!/usr/bin/env pwsh
# Availability Schema Check
# Purpose: Ensure categories with non-none time models have at least one availability filter.

$ErrorActionPreference = "Stop"

Write-Host "=== AVAILABILITY SCHEMA CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$baseUrl = "http://localhost:8080/api/v1"
$violations = @()

function Flatten-Categories {
    param([object[]]$Nodes)
    $flat = @()
    foreach ($n in ($Nodes | Where-Object { $_ -ne $null })) {
        $flat += $n
        if ($n.children) {
            $flat += Flatten-Categories -Nodes @($n.children)
        }
    }
    return $flat
}

try {
    $categories = Invoke-RestMethod -Uri "$baseUrl/categories" -Method Get -TimeoutSec 20 -ErrorAction Stop
} catch {
    Write-Host "FAIL: Could not fetch categories: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$flat = Flatten-Categories -Nodes @($categories)
if (($flat | Measure-Object).Count -eq 0) {
    Write-Host "FAIL: Categories list is empty" -ForegroundColor Red
    exit 1
}

# Critical rule roots where non-none service_time_model variants are expected in current policy.
$criticalRuleSlugs = @("vehicle", "konut", "is-yeri", "events")

foreach ($ruleSlug in $criticalRuleSlugs) {
    $category = $flat | Where-Object { [string]$_.slug -eq $ruleSlug } | Select-Object -First 1
    if (-not $category) {
        $violations += "Category slug not found for critical rule: $ruleSlug"
        continue
    }

    $categoryId = [string]$category.id
    $intent = $null
    $filterSchema = $null
    try {
        $intent = Invoke-RestMethod -Uri "$baseUrl/categories/$categoryId/intent-schema" -Method Get -TimeoutSec 20 -ErrorAction Stop
    } catch {
        $violations += "Intent schema fetch failed for slug=${ruleSlug} id=${categoryId}: $($_.Exception.Message)"
        continue
    }

    try {
        $filterSchema = Invoke-RestMethod -Uri "$baseUrl/categories/$categoryId/filter-schema" -Method Get -TimeoutSec 20 -ErrorAction Stop
    } catch {
        $violations += "Filter schema fetch failed for slug=${ruleSlug} id=${categoryId}: $($_.Exception.Message)"
        continue
    }

    $hasNonNoneTimeModel = $false
    if ($intent -and $intent.offer_variants -and ($intent.offer_variants | Measure-Object).Count -gt 0) {
        foreach ($v in @($intent.offer_variants)) {
            $tm = [string]($v.service_time_model)
            if ($tm -and $tm -ne "none") {
                $hasNonNoneTimeModel = $true
                break
            }
        }
    } else {
        $tm = [string]($intent.service_time_model)
        if ($tm -and $tm -ne "none") {
            $hasNonNoneTimeModel = $true
        }
    }

    if (-not $hasNonNoneTimeModel) {
        continue
    }

    $availabilityCount = 0
    $filters = @()
    if ($filterSchema -and $filterSchema.filters) {
        $filters = @($filterSchema.filters)
    }
    foreach ($f in $filters) {
        $mode = [string]($f.filter_mode)
        if ($mode -eq "availability") {
            $availabilityCount++
        }
    }

    if ($availabilityCount -lt 1) {
        $violations += "Category slug=$ruleSlug id=$categoryId has non-none time model but no filter_mode=availability field"
    }
}

if ($violations.Count -gt 0) {
    Write-Host "FAIL: Availability schema violations detected:" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  - $v" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "PASS: Availability schema contract is valid for critical categories" -ForegroundColor Green
Write-Host "=== AVAILABILITY SCHEMA CHECK: PASS ===" -ForegroundColor Green
exit 0
