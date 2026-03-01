#!/usr/bin/env pwsh
# Canonical pricing backfill
# Default mode: preview only
# Use -Apply to write canonical price_amount/currency for legacy-only listings

param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

Write-Host "=== PRICING CANONICAL BACKFILL ===" -ForegroundColor Cyan
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

$candidateQuery = @"
WITH candidates AS (
    SELECT
        id,
        status,
        COALESCE(title, '') AS title,
        COALESCE(
            NULLIF(attributes_json::jsonb->>'vehicle_price', ''),
            NULLIF(attributes_json::jsonb->>'real_estate_price', ''),
            NULLIF(attributes_json::jsonb->>'product_price', ''),
            NULLIF(attributes_json::jsonb->>'rent_price', ''),
            NULLIF(attributes_json::jsonb->>'event_price', ''),
            NULLIF(attributes_json::jsonb->>'vehicle_price_per_day', '')
        ) AS legacy_price_raw,
        CASE
            WHEN COALESCE(NULLIF(attributes_json::jsonb->>'vehicle_price', ''), '') <> '' THEN 'vehicle_price'
            WHEN COALESCE(NULLIF(attributes_json::jsonb->>'real_estate_price', ''), '') <> '' THEN 'real_estate_price'
            WHEN COALESCE(NULLIF(attributes_json::jsonb->>'product_price', ''), '') <> '' THEN 'product_price'
            WHEN COALESCE(NULLIF(attributes_json::jsonb->>'rent_price', ''), '') <> '' THEN 'rent_price'
            WHEN COALESCE(NULLIF(attributes_json::jsonb->>'event_price', ''), '') <> '' THEN 'event_price'
            WHEN COALESCE(NULLIF(attributes_json::jsonb->>'vehicle_price_per_day', ''), '') <> '' THEN 'vehicle_price_per_day'
            ELSE NULL
        END AS legacy_key
    FROM listings
    WHERE price_amount IS NULL
)
SELECT id, status, title, legacy_key, legacy_price_raw
FROM candidates
WHERE legacy_price_raw IS NOT NULL
ORDER BY status DESC, id ASC;
"@

$applyQuery = @"
WITH candidates AS (
    SELECT
        id,
        CAST(
            COALESCE(
                NULLIF(attributes_json::jsonb->>'vehicle_price', ''),
                NULLIF(attributes_json::jsonb->>'real_estate_price', ''),
                NULLIF(attributes_json::jsonb->>'product_price', ''),
                NULLIF(attributes_json::jsonb->>'rent_price', ''),
                NULLIF(attributes_json::jsonb->>'event_price', ''),
                NULLIF(attributes_json::jsonb->>'vehicle_price_per_day', '')
            ) AS NUMERIC
        ) AS canonical_price
    FROM listings
    WHERE price_amount IS NULL
      AND COALESCE(
            NULLIF(attributes_json::jsonb->>'vehicle_price', ''),
            NULLIF(attributes_json::jsonb->>'real_estate_price', ''),
            NULLIF(attributes_json::jsonb->>'product_price', ''),
            NULLIF(attributes_json::jsonb->>'rent_price', ''),
            NULLIF(attributes_json::jsonb->>'event_price', ''),
            NULLIF(attributes_json::jsonb->>'vehicle_price_per_day', '')
      ) IS NOT NULL
)
UPDATE listings l
SET price_amount = c.canonical_price,
    currency = COALESCE(NULLIF(l.currency, ''), 'TRY'),
    updated_at = NOW()
FROM candidates c
WHERE l.id = c.id;
"@

try {
    Write-Host "[1] Backfill candidates" -ForegroundColor Yellow
    $candidateRows = Invoke-PsqlQuery -Query $candidateQuery
    $rows = @($candidateRows -split "`n" | Where-Object { $_.Trim().Length -gt 0 })

    if ($rows.Count -eq 0) {
        Write-Host "  No legacy-only listings need backfill" -ForegroundColor Green
    } else {
        Write-Host "  id | status | title | legacy_key | legacy_price" -ForegroundColor Gray
        $rows | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }

    if (-not $Apply) {
        Write-Host ""
        Write-Host "Preview only. Re-run with -Apply to write canonical price_amount/currency." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "=== PRICING CANONICAL BACKFILL: PREVIEW COMPLETE ===" -ForegroundColor Green
        exit 0
    }

    Write-Host ""
    Write-Host "[2] Applying backfill" -ForegroundColor Yellow
    $null = Invoke-PsqlQuery -Query $applyQuery
    Write-Host "  Backfill applied successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== PRICING CANONICAL BACKFILL: APPLY COMPLETE ===" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
