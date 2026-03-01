#!/usr/bin/env pwsh
# Marketplace test data reset
# Preview by default; use -Apply to delete transactional/test business data.

param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

Write-Host "=== MARKETPLACE TEST RESET ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Mode: $(if ($Apply) { 'APPLY' } else { 'PREVIEW' })" -ForegroundColor Gray
Write-Host ""

$dbUser = if ($env:DB_USERNAME) { $env:DB_USERNAME } else { "pazar" }
$dbName = if ($env:DB_DATABASE) { $env:DB_DATABASE } else { "pazar" }
$dbContainer = "stack-pazar-db-1"

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
SELECT 'orders', COUNT(*)::text FROM orders
UNION ALL
SELECT 'rentals', COUNT(*)::text FROM rentals
UNION ALL
SELECT 'reservations', COUNT(*)::text FROM reservations
UNION ALL
SELECT 'listing_offers', COUNT(*)::text FROM listing_offers
UNION ALL
SELECT 'listings', COUNT(*)::text FROM listings
UNION ALL
SELECT 'idempotency_keys', COUNT(*)::text FROM idempotency_keys
ORDER BY 1;
"@

$applyQuery = @"
BEGIN;
DELETE FROM orders;
DELETE FROM rentals;
DELETE FROM reservations;
DELETE FROM listing_offers;
DELETE FROM listings;
DELETE FROM idempotency_keys;
COMMIT;
"@

try {
    Write-Host "[1] Current counts" -ForegroundColor Yellow
    $summaryRows = Invoke-PsqlQuery -Query $summaryQuery
    ($summaryRows -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object {
        $parts = $_ -split '\|', 2
        if ($parts.Count -eq 2) {
            Write-Host ("  {0}: {1}" -f $parts[0], $parts[1]) -ForegroundColor Gray
        }
    }

    if (-not $Apply) {
        Write-Host ""
        Write-Host "Preview only. Re-run with -Apply to delete marketplace business test data." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "=== MARKETPLACE TEST RESET: PREVIEW COMPLETE ===" -ForegroundColor Green
        exit 0
    }

    Write-Host ""
    Write-Host "[2] Applying reset" -ForegroundColor Yellow
    $null = Invoke-PsqlQuery -Query $applyQuery
    Write-Host "  Reset applied successfully" -ForegroundColor Green
    Write-Host ""

    Write-Host "[3] Counts after reset" -ForegroundColor Yellow
    $afterRows = Invoke-PsqlQuery -Query $summaryQuery
    ($afterRows -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object {
        $parts = $_ -split '\|', 2
        if ($parts.Count -eq 2) {
            Write-Host ("  {0}: {1}" -f $parts[0], $parts[1]) -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "=== MARKETPLACE TEST RESET: APPLY COMPLETE ===" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
