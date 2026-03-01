#!/usr/bin/env pwsh
# Legacy pricing schema cleanup
# Removes legacy price attribute definitions from catalog tables.

param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

Write-Host "=== PRICING LEGACY SCHEMA CLEANUP ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Mode: $(if ($Apply) { 'APPLY' } else { 'PREVIEW' })" -ForegroundColor Gray
Write-Host ""

$dbUser = if ($env:DB_USERNAME) { $env:DB_USERNAME } else { "pazar" }
$dbName = if ($env:DB_DATABASE) { $env:DB_DATABASE } else { "pazar" }
$dbContainer = "stack-pazar-db-1"
$legacyKeys = "'vehicle_price','real_estate_price','product_price','rent_price','event_price','vehicle_price_per_day'"

function Invoke-PsqlQuery {
    param([string]$Query)

    $singleLineQuery = ($Query -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }) -join " "
    $escapedQuery = $singleLineQuery -replace "'", "'\''"
    $result = docker exec $dbContainer sh -c "psql -U $dbUser -d $dbName -t -A -F '|' -c '$escapedQuery'" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql query failed: $result"
    }
    return $result
}

$summaryQuery = @"
SELECT 'category_filter_schema', attribute_key, COUNT(*)::text
FROM category_filter_schema
WHERE attribute_key IN ($legacyKeys)
GROUP BY attribute_key
UNION ALL
SELECT 'attributes', key, COUNT(*)::text
FROM attributes
WHERE key IN ($legacyKeys)
GROUP BY key
ORDER BY 1,2;
"@

$applyQuery = @"
BEGIN;
DELETE FROM category_filter_schema WHERE attribute_key IN ($legacyKeys);
DELETE FROM attributes WHERE key IN ($legacyKeys);
COMMIT;
"@

try {
    Write-Host "[1] Current legacy schema rows" -ForegroundColor Yellow
    $rows = Invoke-PsqlQuery -Query $summaryQuery
    $lines = @($rows -split "`n" | Where-Object { $_.Trim().Length -gt 0 })
    if ($lines.Count -eq 0) {
        Write-Host "  No legacy pricing schema rows found" -ForegroundColor Green
    } else {
        $lines | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }

    if (-not $Apply) {
        Write-Host ""
        Write-Host "Preview only. Re-run with -Apply to delete legacy pricing schema rows." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "=== PRICING LEGACY SCHEMA CLEANUP: PREVIEW COMPLETE ===" -ForegroundColor Green
        exit 0
    }

    Write-Host ""
    Write-Host "[2] Applying schema cleanup" -ForegroundColor Yellow
    $null = Invoke-PsqlQuery -Query $applyQuery
    Write-Host "  Schema cleanup applied successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "[3] Remaining legacy schema rows" -ForegroundColor Yellow
    $afterRows = Invoke-PsqlQuery -Query $summaryQuery
    $afterLines = @($afterRows -split "`n" | Where-Object { $_.Trim().Length -gt 0 })
    if ($afterLines.Count -eq 0) {
        Write-Host "  No legacy pricing schema rows remain" -ForegroundColor Green
    } else {
        $afterLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
    Write-Host ""
    Write-Host "=== PRICING LEGACY SCHEMA CLEANUP: APPLY COMPLETE ===" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
