#!/usr/bin/env pwsh
# V2 Gate (runtime + basic alignment)
# Lightweight 6-metric gate:
#  1) Listings linked to inactive categories
#  2) Listings containing schema-unknown attribute keys
#  3) Published listings missing interaction_mode
#  4) Categories count parity (SSOT/Manifest/DB)
#  5) Attributes count parity (SSOT/Manifest/DB)
#  6) Active schema pair count parity (SSOT/Manifest/DB)

param(
  [string]$DatasetRoot = "D:\stack-data\catalog-dataset"
)

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

Write-Host "=== V2 GATE (6 metrics) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$resolvedDatasetRoot = $DatasetRoot
if (-not (Test-Path $resolvedDatasetRoot)) {
  $candidate = Join-Path $repoRoot "..\stack-data\catalog-dataset"
  if (Test-Path $candidate) { $resolvedDatasetRoot = $candidate }
}
$resolvedDatasetRoot = (Resolve-Path $resolvedDatasetRoot -ErrorAction SilentlyContinue).Path
if (-not $resolvedDatasetRoot) {
  Write-Host "FAIL: Dataset root not found (expected: $DatasetRoot)" -ForegroundColor Red
  Invoke-OpsExit 1
  return
}

$csvDir = Join-Path $resolvedDatasetRoot "csv"
$manifestDir = Join-Path $resolvedDatasetRoot "out\manifests"
if (-not (Test-Path $csvDir)) {
  Write-Host "FAIL: SSOT csv directory missing: $csvDir" -ForegroundColor Red
  Invoke-OpsExit 1
  return
}
if (-not (Test-Path $manifestDir)) {
  Write-Host "FAIL: Canonical manifest directory missing: $manifestDir" -ForegroundColor Red
  Invoke-OpsExit 1
  return
}

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

function Read-JsonFile {
  param([string]$Path)
  $raw = Get-Content -Path $Path -Raw -Encoding UTF8
  return ($raw | ConvertFrom-Json)
}

function Get-SsotSchemaRows {
  param([string]$CsvRoot)
  $rows = @()
  $main = Join-Path $CsvRoot "schema.csv"
  if (Test-Path $main) { $rows += @(Import-Csv $main) }
  $schemaDir = Join-Path $CsvRoot "schema"
  if (Test-Path $schemaDir) {
    Get-ChildItem $schemaDir -Filter *.csv | Sort-Object FullName | ForEach-Object {
      $rows += @(Import-Csv $_.FullName)
    }
  }
  return $rows
}

function Get-ManifestSchemaPairCount {
  param([string]$Dir)
  $p = Join-Path $Dir "schema\catalog.csv.json"
  $blocks = @(Read-JsonFile $p)
  $count = 0
  foreach ($b in $blocks) {
    $slugCount = @($b.category_slugs).Count
    $fieldCount = @($b.fields).Count
    $count += ($slugCount * $fieldCount)
  }
  return $count
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
}
Write-Host ""

# -------------------------
# Metric 4: categories count parity
# -------------------------
Write-Host "[4] Categories count parity (SSOT/Manifest/DB)..." -ForegroundColor Yellow
try {
  $ssotCategoriesCount = @(Import-Csv (Join-Path $csvDir "categories.csv")).Count
  $manifestCategoriesCount = @(Read-JsonFile (Join-Path $manifestDir "categories\catalog.csv.json")).Count
  $dbCategoriesRaw = Invoke-PostgresQuery -Query "SELECT count(*) FROM categories;" -Description "Count DB categories"
  if ($null -eq $dbCategoriesRaw) { Invoke-OpsExit 1; return }
  $dbCategoriesCount = Parse-IntOrNull ($dbCategoriesRaw | Select-Object -First 1)
  if ($dbCategoriesCount -eq $null) { throw "Could not parse DB categories count" }

  if ($ssotCategoriesCount -eq $manifestCategoriesCount -and $manifestCategoriesCount -eq $dbCategoriesCount) {
    Write-Host "PASS: Categories counts aligned" -ForegroundColor Green
  } else {
    $hasFailures = $true
    Write-Host "FAIL: Categories count mismatch" -ForegroundColor Red
  }
  Write-Host "  ssot=$ssotCategoriesCount manifest=$manifestCategoriesCount db=$dbCategoriesCount" -ForegroundColor Gray
} catch {
  $hasFailures = $true
  Write-Host "FAIL: Categories parity check failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# -------------------------
# Metric 5: attributes count parity
# -------------------------
Write-Host "[5] Attributes count parity (SSOT/Manifest/DB)..." -ForegroundColor Yellow
try {
  $ssotAttributesCount = @(Import-Csv (Join-Path $csvDir "attributes.csv")).Count
  $manifestAttributesCount = @(Read-JsonFile (Join-Path $manifestDir "attributes.json")).Count
  $dbAttributesRaw = Invoke-PostgresQuery -Query "SELECT count(*) FROM attributes;" -Description "Count DB attributes"
  if ($null -eq $dbAttributesRaw) { Invoke-OpsExit 1; return }
  $dbAttributesCount = Parse-IntOrNull ($dbAttributesRaw | Select-Object -First 1)
  if ($dbAttributesCount -eq $null) { throw "Could not parse DB attributes count" }

  if ($ssotAttributesCount -eq $manifestAttributesCount -and $manifestAttributesCount -eq $dbAttributesCount) {
    Write-Host "PASS: Attributes counts aligned" -ForegroundColor Green
  } else {
    $hasFailures = $true
    Write-Host "FAIL: Attributes count mismatch" -ForegroundColor Red
  }
  Write-Host "  ssot=$ssotAttributesCount manifest=$manifestAttributesCount db=$dbAttributesCount" -ForegroundColor Gray
} catch {
  $hasFailures = $true
  Write-Host "FAIL: Attributes parity check failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# -------------------------
# Metric 6: active schema pair count parity
# -------------------------
Write-Host "[6] Active schema pair count parity (SSOT/Manifest/DB)..." -ForegroundColor Yellow
try {
  $ssotSchemaRows = Get-SsotSchemaRows -CsvRoot $csvDir
  $ssotSchemaCount = @($ssotSchemaRows | Where-Object { $_.category_slug -and $_.attribute_key }).Count
  $manifestSchemaCount = Get-ManifestSchemaPairCount -Dir $manifestDir
  $dbSchemaRaw = Invoke-PostgresQuery -Query "SELECT count(*) FROM category_filter_schema WHERE status = 'active';" -Description "Count DB active schema pairs"
  if ($null -eq $dbSchemaRaw) { Invoke-OpsExit 1; return }
  $dbSchemaCount = Parse-IntOrNull ($dbSchemaRaw | Select-Object -First 1)
  if ($dbSchemaCount -eq $null) { throw "Could not parse DB schema count" }

  if ($ssotSchemaCount -eq $manifestSchemaCount -and $manifestSchemaCount -eq $dbSchemaCount) {
    Write-Host "PASS: Active schema pair counts aligned" -ForegroundColor Green
  } else {
    $hasFailures = $true
    Write-Host "FAIL: Active schema pair count mismatch" -ForegroundColor Red
  }
  Write-Host "  ssot=$ssotSchemaCount manifest=$manifestSchemaCount db_active=$dbSchemaCount" -ForegroundColor Gray
} catch {
  $hasFailures = $true
  Write-Host "FAIL: Schema parity check failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "=== V2 GATE SUMMARY ===" -ForegroundColor Cyan
if ($hasFailures) {
  Write-Host "FAIL: One or more runtime/alignment checks failed." -ForegroundColor Red
  Invoke-OpsExit 1
} else {
  Write-Host "PASS: 6/6 checks passed." -ForegroundColor Green
  Invoke-OpsExit 0
}
