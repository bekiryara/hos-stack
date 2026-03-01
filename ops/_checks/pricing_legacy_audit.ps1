#!/usr/bin/env pwsh
# Pricing legacy audit
# Purpose:
# - Measure how much of listings pricing still depends on legacy attribute keys
# - Detect canonical-only / legacy-only / mixed / mismatch states before cleanup

$ErrorActionPreference = "Stop"

Write-Host "=== PRICING LEGACY AUDIT ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
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
WITH pricing AS (
    SELECT
        id,
        status,
        price_amount,
        attributes_json::jsonb AS attrs,
        COALESCE(
            NULLIF(attributes_json::jsonb->>'vehicle_price', ''),
            NULLIF(attributes_json::jsonb->>'real_estate_price', ''),
            NULLIF(attributes_json::jsonb->>'product_price', ''),
            NULLIF(attributes_json::jsonb->>'rent_price', ''),
            NULLIF(attributes_json::jsonb->>'event_price', ''),
            NULLIF(attributes_json::jsonb->>'vehicle_price_per_day', '')
        ) AS legacy_price_raw
    FROM listings
)
SELECT 'total_listings', COUNT(*)::text FROM pricing
UNION ALL
SELECT 'published_listings', COUNT(*)::text FROM pricing WHERE status = 'published'
UNION ALL
SELECT 'canonical_only', COUNT(*)::text FROM pricing WHERE price_amount IS NOT NULL AND legacy_price_raw IS NULL
UNION ALL
SELECT 'legacy_only', COUNT(*)::text FROM pricing WHERE price_amount IS NULL AND legacy_price_raw IS NOT NULL
UNION ALL
SELECT 'canonical_and_legacy_same', COUNT(*)::text
FROM pricing
WHERE price_amount IS NOT NULL
  AND legacy_price_raw IS NOT NULL
  AND price_amount = CAST(legacy_price_raw AS NUMERIC)
UNION ALL
SELECT 'canonical_and_legacy_mismatch', COUNT(*)::text
FROM pricing
WHERE price_amount IS NOT NULL
  AND legacy_price_raw IS NOT NULL
  AND price_amount <> CAST(legacy_price_raw AS NUMERIC)
UNION ALL
SELECT 'no_price_anywhere', COUNT(*)::text FROM pricing WHERE price_amount IS NULL AND legacy_price_raw IS NULL
ORDER BY 1;
"@

$legacyKeysQuery = @"
SELECT key, COUNT(*)::text
FROM (
    SELECT 'vehicle_price' AS key FROM listings WHERE COALESCE(NULLIF(attributes_json::jsonb->>'vehicle_price', ''), '') <> ''
    UNION ALL
    SELECT 'real_estate_price' AS key FROM listings WHERE COALESCE(NULLIF(attributes_json::jsonb->>'real_estate_price', ''), '') <> ''
    UNION ALL
    SELECT 'product_price' AS key FROM listings WHERE COALESCE(NULLIF(attributes_json::jsonb->>'product_price', ''), '') <> ''
    UNION ALL
    SELECT 'rent_price' AS key FROM listings WHERE COALESCE(NULLIF(attributes_json::jsonb->>'rent_price', ''), '') <> ''
    UNION ALL
    SELECT 'event_price' AS key FROM listings WHERE COALESCE(NULLIF(attributes_json::jsonb->>'event_price', ''), '') <> ''
    UNION ALL
    SELECT 'vehicle_price_per_day' AS key FROM listings WHERE COALESCE(NULLIF(attributes_json::jsonb->>'vehicle_price_per_day', ''), '') <> ''
) t
GROUP BY key
ORDER BY COUNT(*) DESC, key ASC;
"@

$mismatchSampleQuery = @"
WITH pricing AS (
    SELECT
        id,
        status,
        title,
        updated_at,
        price_amount,
        COALESCE(
            NULLIF(attributes_json::jsonb->>'vehicle_price', ''),
            NULLIF(attributes_json::jsonb->>'real_estate_price', ''),
            NULLIF(attributes_json::jsonb->>'product_price', ''),
            NULLIF(attributes_json::jsonb->>'rent_price', ''),
            NULLIF(attributes_json::jsonb->>'event_price', ''),
            NULLIF(attributes_json::jsonb->>'vehicle_price_per_day', '')
        ) AS legacy_price_raw
    FROM listings
)
SELECT id, status, COALESCE(title, ''), price_amount::text, legacy_price_raw
FROM pricing
WHERE price_amount IS NOT NULL
  AND legacy_price_raw IS NOT NULL
  AND price_amount <> CAST(legacy_price_raw AS NUMERIC)
ORDER BY updated_at DESC NULLS LAST, id DESC
LIMIT 10;
"@

try {
    Write-Host "[1] Summary" -ForegroundColor Yellow
    $summaryRows = Invoke-PsqlQuery -Query $summaryQuery
    ($summaryRows -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object {
        $parts = $_ -split '\|', 2
        if ($parts.Count -eq 2) {
            Write-Host ("  {0}: {1}" -f $parts[0], $parts[1]) -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "[2] Legacy key coverage" -ForegroundColor Yellow
    $legacyRows = Invoke-PsqlQuery -Query $legacyKeysQuery
    if (-not $legacyRows -or $legacyRows.Trim().Length -eq 0) {
        Write-Host "  No legacy price keys found in listings.attributes_json" -ForegroundColor Green
    } else {
        ($legacyRows -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object {
            $parts = $_ -split '\|', 2
            if ($parts.Count -eq 2) {
                Write-Host ("  {0}: {1}" -f $parts[0], $parts[1]) -ForegroundColor Gray
            }
        }
    }

    Write-Host ""
    Write-Host "[3] Mismatch sample" -ForegroundColor Yellow
    $mismatchRows = Invoke-PsqlQuery -Query $mismatchSampleQuery
    if (-not $mismatchRows -or $mismatchRows.Trim().Length -eq 0) {
        Write-Host "  No canonical/legacy mismatches found" -ForegroundColor Green
    } else {
        Write-Host "  id | status | title | canonical_price | legacy_price" -ForegroundColor Gray
        ($mismatchRows -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "=== PRICING LEGACY AUDIT: COMPLETE ===" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
