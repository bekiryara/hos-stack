#!/usr/bin/env pwsh
# V2 Gate (pre-V2 discipline lock)
# Enforces "0 targets" before bulk catalog changes.
#
# Metrics (minimum set):
#  1) Listings linked to inactive categories
#  2) Listings containing attribute keys not allowed by category schema (incl. applies_to_transaction_modes)
#  3) Published listings missing interaction_mode
#
# Exit codes:
#  0 PASS (all metrics are 0)
#  1 FAIL (any metric > 0 or query error)
#
# PowerShell 5.1 compatible.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
  . "${scriptDir}\_lib\ops_exit.ps1"
  Initialize-OpsExit
}
if (-not (Get-Command Invoke-OpsExit -ErrorAction SilentlyContinue)) {
  function Invoke-OpsExit { param([int]$Code = 1) exit $Code }
}

Write-Host "=== V2 GATE (0-targets) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# DB connection defaults (match other ops scripts)
$dbHost = $env:DB_HOST; if (-not $dbHost) { $dbHost = "localhost" }
$dbPort = $env:DB_PORT; if (-not $dbPort) { $dbPort = "5432" }
$dbName = $env:DB_DATABASE; if (-not $dbName) { $dbName = "pazar" }
$dbUser = $env:DB_USERNAME; if (-not $dbUser) { $dbUser = "pazar" }
$dbPassword = $env:DB_PASSWORD; if (-not $dbPassword) { $dbPassword = "pazar_password" }

$useDocker = $false
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
  $useDocker = $true
  Write-Host "Using docker compose exec -T pazar-db for DB (psql not found)" -ForegroundColor Gray
}

function Invoke-PostgresQuery {
  param(
    [Parameter(Mandatory = $true)][string]$Query,
    [Parameter(Mandatory = $true)][string]$Description
  )
  $singleLineQuery = ($Query -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }) -join " "
  try {
    $env:PGPASSWORD = $dbPassword
    if ($useDocker) {
      Push-Location $repoRoot
      $result = docker compose exec -T pazar-db psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -t -A -F "|" -c $singleLineQuery 2>&1
      Pop-Location
    } else {
      $result = $singleLineQuery | & psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -t -A -F "|" 2>&1
    }
    $env:PGPASSWORD = $null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "FAIL: $Description" -ForegroundColor Red
      $msg = ($result | Out-String).Trim()
      if ($msg) { Write-Host "  $msg" -ForegroundColor Yellow }
      return $null
    }
    return $result
  } catch {
    $env:PGPASSWORD = $null
    Write-Host "FAIL: $Description - $($_.Exception.Message)" -ForegroundColor Red
    return $null
  }
}

function Parse-IntOrNull {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  $t = $Text.Trim()
  $n = 0
  if ([int]::TryParse($t, [ref]$n)) { return $n }
  return $null
}

$hasFailures = $false

# -------------------------
# Metric 1: inactive categories
# -------------------------
Write-Host "[1] Inactive category listings..." -ForegroundColor Yellow
$inactiveCountSql = @"
SELECT count(*)
FROM listings l
JOIN categories c ON c.id = l.category_id
WHERE c.status <> 'active';
"@
$inactiveCountRaw = Invoke-PostgresQuery -Query $inactiveCountSql -Description "Count listings linked to inactive categories"
if ($null -eq $inactiveCountRaw) { Invoke-OpsExit 1; return }
$inactiveCount = Parse-IntOrNull ($inactiveCountRaw | Select-Object -First 1)
if ($inactiveCount -eq $null) { Write-Host "FAIL: Could not parse inactive category listings count" -ForegroundColor Red; Invoke-OpsExit 1; return }

if ($inactiveCount -eq 0) {
  Write-Host "PASS: 0 listings linked to inactive categories" -ForegroundColor Green
} else {
  $hasFailures = $true
  Write-Host "FAIL: $inactiveCount listings linked to inactive categories" -ForegroundColor Red
  $inactiveSampleSql = @"
SELECT l.id, c.slug, c.status, l.status
FROM listings l
JOIN categories c ON c.id = l.category_id
WHERE c.status <> 'active'
ORDER BY l.created_at DESC
LIMIT 10;
"@
  $inactiveSample = Invoke-PostgresQuery -Query $inactiveSampleSql -Description "Sample inactive-category listings"
  if ($inactiveSample) {
    Write-Host "  Sample (listing_id|category_slug|category_status|listing_status):" -ForegroundColor Gray
    ($inactiveSample -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object { Write-Host ("  - " + $_) -ForegroundColor Gray }
  }
}
Write-Host ""

# -------------------------
# Metric 2: schema drift (unknown attribute keys)
# -------------------------
Write-Host "[2] Schema drift: unknown attribute keys..." -ForegroundColor Yellow
$unknownKeysCountSql = @"
WITH l AS (
  SELECT
    id,
    category_id,
    COALESCE(attributes_json::jsonb, '{}'::jsonb) AS attrs,
    COALESCE(transaction_modes_json::jsonb, '[]'::jsonb) AS modes
  FROM listings
),
m AS (
  SELECT
    l.*,
    CASE
      WHEN jsonb_typeof(modes) = 'array' AND jsonb_array_length(modes) > 0 THEN (modes->>0)
      ELSE NULL
    END AS mode
  FROM l
),
bad AS (
  SELECT
    m.id,
    m.category_id,
    m.mode,
    k.key AS attr_key
  FROM m
  CROSS JOIN LATERAL jsonb_object_keys(m.attrs) AS k(key)
  WHERE k.key NOT IN ('offer_variant','interaction_mode')
    AND NOT EXISTS (
      SELECT 1
      FROM category_filter_schema s
      WHERE s.category_id = m.category_id
        AND s.status = 'active'
        AND s.attribute_key = k.key
        AND (
          s.applies_to_transaction_modes IS NULL
          OR (jsonb_typeof(s.applies_to_transaction_modes::jsonb) = 'array' AND jsonb_array_length(s.applies_to_transaction_modes::jsonb) = 0)
          OR (m.mode IS NOT NULL AND (s.applies_to_transaction_modes::jsonb ? m.mode))
        )
    )
)
SELECT count(DISTINCT id)
FROM bad;
"@
$unknownCountRaw = Invoke-PostgresQuery -Query $unknownKeysCountSql -Description "Count listings with schema-unknown attribute keys"
if ($null -eq $unknownCountRaw) { Invoke-OpsExit 1; return }
$unknownListingsCount = Parse-IntOrNull ($unknownCountRaw | Select-Object -First 1)
if ($unknownListingsCount -eq $null) { Write-Host "FAIL: Could not parse schema drift count" -ForegroundColor Red; Invoke-OpsExit 1; return }

if ($unknownListingsCount -eq 0) {
  Write-Host "PASS: 0 listings contain unknown attribute keys" -ForegroundColor Green
} else {
  $hasFailures = $true
  Write-Host "FAIL: $unknownListingsCount listings contain unknown attribute keys" -ForegroundColor Red
  $unknownSampleSql = @"
WITH l AS (
  SELECT
    id,
    category_id,
    COALESCE(attributes_json::jsonb, '{}'::jsonb) AS attrs,
    COALESCE(transaction_modes_json::jsonb, '[]'::jsonb) AS modes
  FROM listings
),
m AS (
  SELECT
    l.*,
    CASE
      WHEN jsonb_typeof(modes) = 'array' AND jsonb_array_length(modes) > 0 THEN (modes->>0)
      ELSE NULL
    END AS mode
  FROM l
),
bad AS (
  SELECT
    m.id,
    m.category_id,
    m.mode,
    k.key AS attr_key
  FROM m
  CROSS JOIN LATERAL jsonb_object_keys(m.attrs) AS k(key)
  WHERE k.key NOT IN ('offer_variant','interaction_mode')
    AND NOT EXISTS (
      SELECT 1
      FROM category_filter_schema s
      WHERE s.category_id = m.category_id
        AND s.status = 'active'
        AND s.attribute_key = k.key
        AND (
          s.applies_to_transaction_modes IS NULL
          OR (jsonb_typeof(s.applies_to_transaction_modes::jsonb) = 'array' AND jsonb_array_length(s.applies_to_transaction_modes::jsonb) = 0)
          OR (m.mode IS NOT NULL AND (s.applies_to_transaction_modes::jsonb ? m.mode))
        )
    )
)
SELECT id, category_id, COALESCE(mode,'-') AS mode, attr_key
FROM bad
ORDER BY id
LIMIT 10;
"@
  $unknownSample = Invoke-PostgresQuery -Query $unknownSampleSql -Description "Sample schema drift keys"
  if ($unknownSample) {
    Write-Host "  Sample (listing_id|category_id|mode|unknown_attr_key):" -ForegroundColor Gray
    ($unknownSample -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object { Write-Host ("  - " + $_) -ForegroundColor Gray }
  }
}
Write-Host ""

# -------------------------
# Metric 3: published listings missing interaction_mode
# -------------------------
Write-Host "[3] Published listings missing interaction_mode..." -ForegroundColor Yellow
$missingInteractionSql = @"
SELECT count(*)
FROM listings
WHERE status = 'published'
  AND (
    attributes_json IS NULL
    OR NOT (attributes_json::jsonb ? 'interaction_mode')
    OR COALESCE(attributes_json::jsonb->>'interaction_mode','') = ''
  );
"@
$missingInteractionRaw = Invoke-PostgresQuery -Query $missingInteractionSql -Description "Count published listings missing interaction_mode"
if ($null -eq $missingInteractionRaw) { Invoke-OpsExit 1; return }
$missingInteractionCount = Parse-IntOrNull ($missingInteractionRaw | Select-Object -First 1)
if ($missingInteractionCount -eq $null) { Write-Host "FAIL: Could not parse missing interaction_mode count" -ForegroundColor Red; Invoke-OpsExit 1; return }

if ($missingInteractionCount -eq 0) {
  Write-Host "PASS: 0 published listings missing interaction_mode" -ForegroundColor Green
} else {
  $hasFailures = $true
  Write-Host "FAIL: $missingInteractionCount published listings missing interaction_mode" -ForegroundColor Red
  $missingInteractionSampleSql = @"
SELECT id, category_id, created_at
FROM listings
WHERE status = 'published'
  AND (
    attributes_json IS NULL
    OR NOT (attributes_json::jsonb ? 'interaction_mode')
    OR COALESCE(attributes_json::jsonb->>'interaction_mode','') = ''
  )
ORDER BY created_at DESC
LIMIT 10;
"@
  $missingInteractionSample = Invoke-PostgresQuery -Query $missingInteractionSampleSql -Description "Sample missing interaction_mode listings"
  if ($missingInteractionSample) {
    Write-Host "  Sample (listing_id|category_id|created_at):" -ForegroundColor Gray
    ($missingInteractionSample -split "`n" | Where-Object { $_.Trim().Length -gt 0 }) | ForEach-Object { Write-Host ("  - " + $_) -ForegroundColor Gray }
  }
}
Write-Host ""

# Summary
Write-Host "=== V2 GATE SUMMARY ===" -ForegroundColor Cyan
if ($hasFailures) {
  Write-Host "FAIL: One or more metrics are non-zero." -ForegroundColor Red
  Invoke-OpsExit 1
} else {
  Write-Host "PASS: All metrics are 0." -ForegroundColor Green
  Invoke-OpsExit 0
}

