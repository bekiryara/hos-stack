#!/usr/bin/env pwsh
# Variant Matrix Check
# Purpose: Lock critical offer_variant -> primitive behavior mappings deterministically.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

Write-Host "=== POLICY VARIANT MATRIX CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$policyPath = Join-Path $repoRoot "work\pazar\config\category_flow_policy.php"
if (-not (Test-Path $policyPath)) {
    Write-Host "FAIL: Policy file not found: $policyPath" -ForegroundColor Red
    exit 1
}

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
    Write-Host "FAIL: Could not load policy (php -r failed or empty)" -ForegroundColor Red
    exit 1
}

$policyLine = ($policyJson -split "`n" | Where-Object { $_ -match '^\s*\{' }) | Select-Object -First 1
if (-not $policyLine) { $policyLine = $policyJson.Trim() }
$policy = $policyLine | ConvertFrom-Json

$rules = @{}
if ($policy.rules) {
    $policy.rules.PSObject.Properties | ForEach-Object {
        $rules[$_.Name] = $_.Value
    }
}

# Matrix rows are explicit contract targets.
# Extend this table gradually when new business-critical families stabilize.
$matrix = @(
    @{ Rule = "vehicle"; Variant = "sale"; TransactionMode = "sale"; InteractionMode = "contact_only"; PricingStrategy = "base_only"; BillingModel = "one_time"; LocationScope = "point"; ServiceTimeModel = "none"; OfferRequirement = "no_offer" },
    @{ Rule = "vehicle"; Variant = "rental"; TransactionMode = "rental"; InteractionMode = "flow"; PricingStrategy = "base_only"; BillingModel = "per_day"; LocationScope = "point"; ServiceTimeModel = "date_range"; OfferRequirement = "no_offer" },

    @{ Rule = "konut"; Variant = "sale"; TransactionMode = "sale"; InteractionMode = "contact_only"; PricingStrategy = "base_only"; BillingModel = "one_time"; LocationScope = "point"; ServiceTimeModel = "none"; OfferRequirement = "no_offer" },
    @{ Rule = "konut"; Variant = "rental"; TransactionMode = "rental"; InteractionMode = "contact_only"; PricingStrategy = "base_only"; BillingModel = "per_day"; LocationScope = "point"; ServiceTimeModel = "date_range"; OfferRequirement = "no_offer" },
    @{ Rule = "konut"; Variant = "turistik_gunluk_kiralik"; TransactionMode = "reservation"; InteractionMode = "flow"; PricingStrategy = "base_only"; BillingModel = "per_day"; LocationScope = "point"; ServiceTimeModel = "slot"; OfferRequirement = "optional_offer" },
    @{ Rule = "konut"; Variant = "devren_satilik_konut"; TransactionMode = "sale"; InteractionMode = "contact_only"; PricingStrategy = "base_only"; BillingModel = "one_time"; LocationScope = "point"; ServiceTimeModel = "none"; OfferRequirement = "no_offer" },

    @{ Rule = "is-yeri"; Variant = "sale"; TransactionMode = "sale"; InteractionMode = "contact_only"; PricingStrategy = "base_only"; BillingModel = "one_time"; LocationScope = "point"; ServiceTimeModel = "none"; OfferRequirement = "no_offer" },
    @{ Rule = "is-yeri"; Variant = "rental"; TransactionMode = "rental"; InteractionMode = "contact_only"; PricingStrategy = "base_only"; BillingModel = "per_day"; LocationScope = "point"; ServiceTimeModel = "date_range"; OfferRequirement = "no_offer" },
    @{ Rule = "is-yeri"; Variant = "devren_satilik"; TransactionMode = "sale"; InteractionMode = "contact_only"; PricingStrategy = "base_only"; BillingModel = "one_time"; LocationScope = "point"; ServiceTimeModel = "none"; OfferRequirement = "no_offer" },
    @{ Rule = "is-yeri"; Variant = "devren_kiralik"; TransactionMode = "rental"; InteractionMode = "contact_only"; PricingStrategy = "base_only"; BillingModel = "per_day"; LocationScope = "point"; ServiceTimeModel = "date_range"; OfferRequirement = "no_offer" },

    @{ Rule = "service-product"; Variant = "sale"; TransactionMode = "sale"; InteractionMode = "flow"; PricingStrategy = "base_only"; BillingModel = "one_time"; LocationScope = "point"; ServiceTimeModel = "none"; OfferRequirement = "no_offer" },
    @{ Rule = "events"; Variant = "reservation"; TransactionMode = "reservation"; InteractionMode = "flow"; PricingStrategy = "base_only"; BillingModel = "per_person"; LocationScope = "point"; ServiceTimeModel = "slot"; OfferRequirement = "optional_offer" },
    @{ Rule = "food"; Variant = "sale"; TransactionMode = "sale"; InteractionMode = "flow"; PricingStrategy = "base_only"; BillingModel = "one_time"; LocationScope = "service_area"; ServiceTimeModel = "none"; OfferRequirement = "no_offer" }
)

$violations = @()

foreach ($row in $matrix) {
    $ruleKey = [string]$row.Rule
    $variantKey = [string]$row.Variant
    if (-not $rules.ContainsKey($ruleKey)) {
        $violations += "rules.$ruleKey missing"
        continue
    }

    $rule = $rules[$ruleKey]
    $variants = @()
    if ($rule.PSObject.Properties['offer_variants'] -and $rule.offer_variants) {
        $variants = @($rule.offer_variants)
    }
    $variant = $null
    foreach ($v in $variants) {
        if ($v -and $v.PSObject.Properties['key'] -and ([string]$v.key -eq $variantKey)) {
            $variant = $v
            break
        }
    }
    if (-not $variant) {
        $violations += "rules.$ruleKey.offer_variants[$variantKey] missing"
        continue
    }

    $checks = @(
        @{ Field = "transaction_mode"; Expected = [string]$row.TransactionMode },
        @{ Field = "interaction_mode"; Expected = [string]$row.InteractionMode },
        @{ Field = "pricing_strategy"; Expected = [string]$row.PricingStrategy },
        @{ Field = "billing_model"; Expected = [string]$row.BillingModel },
        @{ Field = "location_scope"; Expected = [string]$row.LocationScope },
        @{ Field = "service_time_model"; Expected = [string]$row.ServiceTimeModel },
        @{ Field = "offer_requirement"; Expected = [string]$row.OfferRequirement }
    )

    foreach ($c in $checks) {
        $field = [string]$c.Field
        $expected = [string]$c.Expected
        $actual = ""
        if ($variant.PSObject.Properties[$field]) {
            $actual = [string]$variant.$field
        }
        if ($actual -ne $expected) {
            $violations += "rules.$ruleKey.offer_variants[$variantKey].$field expected=$expected actual=$actual"
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host "FAIL: Variant matrix mismatches detected:" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  - $v" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "PASS: Variant matrix contract is valid" -ForegroundColor Green
Write-Host "=== POLICY VARIANT MATRIX CHECK: PASS ===" -ForegroundColor Green
exit 0
