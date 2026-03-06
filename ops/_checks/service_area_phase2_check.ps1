#!/usr/bin/env pwsh
# Service Area Phase-2 Check
# Purpose: Keep service_area infrastructure deterministic while rollout remains controlled.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

Write-Host "=== SERVICE AREA PHASE-2 CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$violations = @()

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Label
    )
    if (-not (Test-Path $Path)) {
        $script:violations += "$Label missing file: $Path"
        return
    }
    $content = Get-Content -Path $Path -Raw
    if ($content -notmatch $Pattern) {
        $script:violations += "$Label missing pattern: $Pattern"
    }
}

# 1) Policy guardrail: service_area should stay explicit and controlled.
$policyPath = Join-Path $repoRoot "work\pazar\config\category_flow_policy.php"
if (-not (Test-Path $policyPath)) {
    $violations += "Policy file missing: $policyPath"
} else {
    Push-Location $repoRoot
    $phpCode = "error_reporting(0); chdir('work/pazar'); echo json_encode(require 'config/category_flow_policy.php');"
    $phpCmd = Get-Command php -ErrorAction SilentlyContinue
    if ($phpCmd) {
        $policyJson = & php -r $phpCode 2>&1
    } else {
        $policyJson = docker compose exec -T pazar-app php -r $phpCode 2>&1
    }
    Pop-Location

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($policyJson)) {
        $violations += "Could not load policy JSON"
    } else {
        $policyLine = ($policyJson -split "`n" | Where-Object { $_ -match '^\s*\{' }) | Select-Object -First 1
        if (-not $policyLine) { $policyLine = $policyJson.Trim() }
        $policy = $policyLine | ConvertFrom-Json

        $serviceAreaRows = @()
        if ($policy.rules) {
            foreach ($rp in $policy.rules.PSObject.Properties) {
                $ruleKey = [string]$rp.Name
                $rule = $rp.Value
                $variants = @()
                if ($rule.PSObject.Properties['offer_variants'] -and $rule.offer_variants) {
                    $variants = @($rule.offer_variants)
                }
                foreach ($v in $variants) {
                    $scope = if ($v.PSObject.Properties['location_scope']) { [string]$v.location_scope } else { "" }
                    if ($scope -eq "service_area") {
                        $serviceAreaRows += [PSCustomObject]@{
                            Rule = $ruleKey
                            Variant = [string]$v.key
                            TransactionMode = if ($v.PSObject.Properties['transaction_mode']) { [string]$v.transaction_mode } else { "" }
                        }
                    }
                }
            }
        }

        if ($serviceAreaRows.Count -eq 0) {
            $violations += "No service_area variant found in policy (expected controlled baseline row)"
        } else {
            # Controlled baseline allowlist (phase-2 prep posture).
            $allow = @("food:sale")
            foreach ($row in $serviceAreaRows) {
                $sig = "$($row.Rule):$($row.Variant)"
                if ($allow -notcontains $sig) {
                    $violations += "Unexpected service_area activation row: $sig"
                }
                if ($row.TransactionMode -ne "sale") {
                    $violations += "service_area row must stay sale-mode in prep phase: $sig transaction_mode=$($row.TransactionMode)"
                }
            }
        }
    }
}

# 2) UI/editor surface exists (pasif ama deterministic).
$createFormPath = Join-Path $repoRoot "work\marketplace-web\src\components\listing\create\CreateListingForm.vue"
Assert-FileContains -Path $createFormPath -Pattern "policyLocationScope === 'service_area'" -Label "CreateListingForm"
Assert-FileContains -Path $createFormPath -Pattern "local\.location\.service_area" -Label "CreateListingForm"
Assert-FileContains -Path $createFormPath -Pattern "all_districts" -Label "CreateListingForm"

# 3) Backend write/read normalization + persistence hooks exist.
$writePath = Join-Path $repoRoot "work\pazar\routes\api\03a_listings_write.php"
$readPath = Join-Path $repoRoot "work\pazar\routes\api\03b_listings_read.php"
Assert-FileContains -Path $writePath -Pattern "location\.service_area must include at least one city" -Label "ListingsWrite"
Assert-FileContains -Path $writePath -Pattern "pazar_listing_sync_service_areas" -Label "ListingsWrite"
Assert-FileContains -Path $readPath -Pattern "listing_service_areas" -Label "ListingsRead"
Assert-FileContains -Path $readPath -Pattern '''service_area'' => \$rows' -Label "ListingsRead"

# 4) Schema snapshot contains required table/column contract.
$schemaSnapshotPath = Join-Path $repoRoot "ops\snapshots\schema.pazar.sql"
Assert-FileContains -Path $schemaSnapshotPath -Pattern "CREATE TABLE public\.listing_service_areas" -Label "SchemaSnapshot"
Assert-FileContains -Path $schemaSnapshotPath -Pattern "location_scope character varying\(20\)" -Label "SchemaSnapshot"

if ($violations.Count -gt 0) {
    Write-Host "FAIL: Service area phase-2 contract violations detected:" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  - $v" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "PASS: Service area phase-2 prep contract is valid" -ForegroundColor Green
Write-Host "=== SERVICE AREA PHASE-2 CHECK: PASS ===" -ForegroundColor Green
exit 0
