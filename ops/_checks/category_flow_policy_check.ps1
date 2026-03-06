#!/usr/bin/env pwsh
# Category Flow Policy Gate
# Validates listings against work/pazar/config/category_flow_policy.php (offer_variant, transaction_mode, interaction_mode).

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== CATEGORY FLOW POLICY CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# 1) Load policy from PHP (JSON output)
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
# Strip possible PHP warnings (take line that starts with {)
$policyLine = ($policyJson -split "`n" | Where-Object { $_ -match '^\s*\{' }) | Select-Object -First 1
if (-not $policyLine) { $policyLine = $policyJson.Trim() }
$policy = $policyLine | ConvertFrom-Json
$rules = @{}
if ($policy.rules) {
    $policy.rules.PSObject.Properties | ForEach-Object {
        $rules[$_.Name] = $_.Value
    }
}

# 1.1) Validate service primitive enums (if present in rules)
$validFulfillmentModes = @("provider_location", "customer_location", "remote", "hybrid")
$validLocationScopes = @("none", "city", "point", "service_area")
$validServiceTimeModels = @("none", "date_range", "slot", "session")
$validOfferRequirements = @("no_offer", "optional_offer", "required_offer")
$validPricingStrategies = @("base_only", "offer_only")
$validBillingModels = @("one_time", "per_day", "per_month", "per_night", "per_person", "per_hour", "per_session", "per_visit")
$primitiveViolations = @()

foreach ($ruleKey in $rules.Keys) {
    $rule = $rules[$ruleKey]
    if (-not $rule) { continue }

    if ($rule.PSObject.Properties['fulfillment_mode']) {
        $v = [string]$rule.fulfillment_mode
        if ($validFulfillmentModes -notcontains $v) {
            $primitiveViolations += "rules.$ruleKey.fulfillment_mode invalid: $v"
        }
    }
    if ($rule.PSObject.Properties['location_scope']) {
        $v = [string]$rule.location_scope
        if ($validLocationScopes -notcontains $v) {
            $primitiveViolations += "rules.$ruleKey.location_scope invalid: $v"
        }
    }
    if ($rule.PSObject.Properties['service_time_model']) {
        $v = [string]$rule.service_time_model
        if ($validServiceTimeModels -notcontains $v) {
            $primitiveViolations += "rules.$ruleKey.service_time_model invalid: $v"
        }
    }
    if ($rule.PSObject.Properties['offer_requirement']) {
        $v = [string]$rule.offer_requirement
        if ($validOfferRequirements -notcontains $v) {
            $primitiveViolations += "rules.$ruleKey.offer_requirement invalid: $v"
        }
        if ($v -eq "required_offer") {
            $supportsPackages = $false
            if ($rule.PSObject.Properties['supports_packages']) {
                $supportsPackages = [bool]$rule.supports_packages
            }
            if (-not $supportsPackages) {
                $primitiveViolations += "rules.$ruleKey.offer_requirement=required_offer requires supports_packages=true"
            }
        }
    }
    if ($rule.PSObject.Properties['pricing_strategy']) {
        $v = [string]$rule.pricing_strategy
        if ($validPricingStrategies -notcontains $v) {
            $primitiveViolations += "rules.$ruleKey.pricing_strategy invalid: $v"
        }
    }
    if ($rule.PSObject.Properties['billing_model']) {
        $v = [string]$rule.billing_model
        if ($validBillingModels -notcontains $v) {
            $primitiveViolations += "rules.$ruleKey.billing_model invalid: $v"
        }
    }

    if ($rule.PSObject.Properties['offer_variants'] -and $rule.offer_variants) {
        foreach ($variant in $rule.offer_variants) {
            if (-not $variant) { continue }
            $variantKey = ""
            if ($variant.PSObject.Properties['key']) { $variantKey = [string]$variant.key }
            if ([string]::IsNullOrWhiteSpace($variantKey)) { $variantKey = "<missing-key>" }

            if ($variant.PSObject.Properties['fulfillment_mode']) {
                $v = [string]$variant.fulfillment_mode
                if ($validFulfillmentModes -notcontains $v) {
                    $primitiveViolations += "rules.$ruleKey.offer_variants[$variantKey].fulfillment_mode invalid: $v"
                }
            }
            if ($variant.PSObject.Properties['location_scope']) {
                $v = [string]$variant.location_scope
                if ($validLocationScopes -notcontains $v) {
                    $primitiveViolations += "rules.$ruleKey.offer_variants[$variantKey].location_scope invalid: $v"
                }
            }
            if ($variant.PSObject.Properties['service_time_model']) {
                $v = [string]$variant.service_time_model
                if ($validServiceTimeModels -notcontains $v) {
                    $primitiveViolations += "rules.$ruleKey.offer_variants[$variantKey].service_time_model invalid: $v"
                }
            }
            if ($variant.PSObject.Properties['offer_requirement']) {
                $v = [string]$variant.offer_requirement
                if ($validOfferRequirements -notcontains $v) {
                    $primitiveViolations += "rules.$ruleKey.offer_variants[$variantKey].offer_requirement invalid: $v"
                }
            }
            if ($variant.PSObject.Properties['pricing_strategy']) {
                $v = [string]$variant.pricing_strategy
                if ($validPricingStrategies -notcontains $v) {
                    $primitiveViolations += "rules.$ruleKey.offer_variants[$variantKey].pricing_strategy invalid: $v"
                }
            }
            if ($variant.PSObject.Properties['billing_model']) {
                $v = [string]$variant.billing_model
                if ($validBillingModels -notcontains $v) {
                    $primitiveViolations += "rules.$ruleKey.offer_variants[$variantKey].billing_model invalid: $v"
                }
            }
        }
    }
}

if ($primitiveViolations.Count -gt 0) {
    Write-Host "FAIL: Service primitive policy violations detected:" -ForegroundColor Red
    foreach ($v in $primitiveViolations) {
        Write-Host "  - $v" -ForegroundColor Yellow
    }
    exit 1
}

# 2) DB connection
$dbHost = $env:DB_HOST
if (-not $dbHost) { $dbHost = "localhost" }
$dbPort = $env:DB_PORT
if (-not $dbPort) { $dbPort = "5432" }
$dbName = $env:DB_DATABASE
if (-not $dbName) { $dbName = "pazar" }
$dbUser = $env:DB_USERNAME
if (-not $dbUser) { $dbUser = "pazar" }
$dbPassword = $env:DB_PASSWORD
if (-not $dbPassword) { $dbPassword = "pazar_password" }

$useDocker = $false
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
    $useDocker = $true
    Write-Host "Using docker compose exec -T pazar-db for DB (psql not found)" -ForegroundColor Gray
}

function Invoke-PostgresQuery {
    param([string]$Query, [string]$Description)
    $singleLineQuery = ($Query -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }) -join " "
    $escapedQuery = $singleLineQuery -replace "'", "''"
    try {
        if ($useDocker) {
            $env:PGPASSWORD = $dbPassword
            Push-Location $repoRoot
            $result = docker compose exec -T pazar-db psql -U $dbUser -d $dbName -t -A -F "|" -c "$escapedQuery" 2>&1
            Pop-Location
            $env:PGPASSWORD = $null
        } else {
            $env:PGPASSWORD = $dbPassword
            $result = $escapedQuery | & psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -t -A -F "|" 2>&1
            $env:PGPASSWORD = $null
        }
        if ($LASTEXITCODE -ne 0) { return $null }
        return $result
    } catch {
        Write-Host "FAIL: $Description - $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# 3) Fetch categories id -> parent_id, slug (build path map later)
$catQuery = "SELECT id, parent_id, slug FROM categories"
$catRaw = Invoke-PostgresQuery -Query $catQuery -Description "Fetch categories"
if ($null -eq $catRaw) {
    Write-Host "FAIL: Could not fetch categories" -ForegroundColor Red
    exit 1
}
$catById = @{}
$catRaw -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
    $cols = $_ -split '\|'
    if ($cols.Count -ge 3) {
        $catById[$cols[0]] = @{ parent_id = $cols[1]; slug = $cols[2] }
    }
}

# 3.1) Drift visibility: policy rule keys must exist as category slugs
# This is a WARNING-only signal (does not fail the check) to prevent silent typos like "isyeri" vs "is-yeri".
# The check is intentionally non-blocking while catalog/policy is still evolving.
$allCategorySlugs = @{}
foreach ($kv in $catById.GetEnumerator()) {
    $s = $kv.Value.slug
    if (-not [string]::IsNullOrWhiteSpace($s)) {
        $allCategorySlugs[$s] = $true
    }
}

$unknownPolicyKeys = @()
foreach ($k in $rules.Keys) {
    if (-not $allCategorySlugs.ContainsKey($k)) {
        $unknownPolicyKeys += $k
    }
}
$unknownPolicyKeys = $unknownPolicyKeys | Sort-Object
if ($unknownPolicyKeys.Count -gt 0) {
    Write-Host "WARN: Policy rules reference missing category slug(s): $($unknownPolicyKeys -join ', ')" -ForegroundColor Yellow
    Write-Host "  Note: This is non-blocking (visibility-only). Consider enforcing later in CI." -ForegroundColor Gray
    Write-Host ""
}

function Get-CategoryPathSlugs {
    param([string]$categoryId)
    $path = @()
    $cid = $categoryId
    $seen = @{}
    while ($cid -and $catById[$cid]) {
        if ($seen[$cid]) { break }
        $seen[$cid] = $true
        $path += $catById[$cid].slug
        $cid = $catById[$cid].parent_id
    }
    return $path
}

function Get-ResolvedRule {
    param([string[]]$pathSlugs)
    foreach ($s in $pathSlugs) {
        if ($rules.ContainsKey($s)) { return $rules[$s] }
    }
    return $null
}

# 4) Fetch listings
$listingsQuery = "SELECT id, category_id, status, transaction_modes_json, attributes_json FROM listings"
$listingsRaw = Invoke-PostgresQuery -Query $listingsQuery -Description "Fetch listings"
if ($null -eq $listingsRaw) {
    Write-Host "FAIL: Could not fetch listings" -ForegroundColor Red
    exit 1
}

$violations = @()
$lines = $listingsRaw -split "`n" | Where-Object { $_.Trim().Length -gt 0 }
foreach ($line in $lines) {
    $cols = $line -split '\|'
    if ($cols.Count -lt 5) { continue }
    $id = $cols[0]
    $categoryId = $cols[1]
    $transactionModesJson = $cols[3]
    $attributesJson = $cols[4]

    if ([string]::IsNullOrWhiteSpace($categoryId)) {
        $violations += @{
            listing_id = $id
            category_path = ""
            offer_variant = ""
            tx_modes = $transactionModesJson
            expected = "category_id required"
        }
        continue
    }

    $pathSlugs = Get-CategoryPathSlugs -categoryId $categoryId
    $categoryPath = $pathSlugs -join "/"
    $rule = Get-ResolvedRule -pathSlugs $pathSlugs

    if (-not $rule) {
        continue
    }

    $txModes = @()
    if (-not [string]::IsNullOrWhiteSpace($transactionModesJson)) {
        try {
            $parsed = $transactionModesJson | ConvertFrom-Json
            if ($parsed -is [array]) {
                $txModes = @($parsed)
            } elseif ($parsed) {
                $txModes = @($parsed)
            }
        } catch { }
    }

    $attrs = $null
    if (-not [string]::IsNullOrWhiteSpace($attributesJson)) {
        try {
            $attrs = $attributesJson | ConvertFrom-Json
        } catch { }
    }

    $offerVariant = $null
    $interactionMode = $null
    if ($attrs -and $attrs.PSObject.Properties['offer_variant']) {
        $offerVariant = $attrs.offer_variant
    }
    if ($attrs -and $attrs.PSObject.Properties['interaction_mode']) {
        $interactionMode = $attrs.interaction_mode
    }

    if ($offerVariant) {
        $variantKeys = @()
        if ($rule.offer_variants) {
            foreach ($v in $rule.offer_variants) {
                if ($v.PSObject.Properties['key']) { $variantKeys += $v.key }
            }
        }
        if ($variantKeys -notcontains $offerVariant) {
            $violations += @{
                listing_id = $id
                category_path = $categoryPath
                offer_variant = $offerVariant
                tx_modes = ($transactionModesJson -replace '\|',' ')
                expected = "offer_variant must be one of: $($variantKeys -join ', ')"
            }
            continue
        }
        $variant = $null
        foreach ($v in $rule.offer_variants) {
            if ($v.key -eq $offerVariant) { $variant = $v; break }
        }
        if (-not $variant) { continue }

        $expectedTx = $variant.transaction_mode
        $listingTx = if ($txModes.Count -eq 1) { $txModes[0] } else { $null }
        if ($listingTx -ne $expectedTx) {
            $violations += @{
                listing_id = $id
                category_path = $categoryPath
                offer_variant = $offerVariant
                tx_modes = ($transactionModesJson -replace '\|',' ')
                expected = "transaction_mode must be: $expectedTx (single mode)"
            }
            continue
        }
        $expectedInteraction = $variant.interaction_mode
        if ($null -ne $expectedInteraction -and $interactionMode -ne $expectedInteraction) {
            $violations += @{
                listing_id = $id
                category_path = $categoryPath
                offer_variant = $offerVariant
                tx_modes = ($transactionModesJson -replace '\|',' ')
                expected = "interaction_mode must be: $expectedInteraction"
            }
        }
    } else {
        $allowed = @()
        if ($rule.allowed_transaction_modes) {
            $allowed = @($rule.allowed_transaction_modes)
        }
        $firstTx = if ($txModes.Count -gt 0) { $txModes[0] } else { $null }
        if ($null -eq $firstTx -or ($allowed -notcontains $firstTx)) {
            $violations += @{
                listing_id = $id
                category_path = $categoryPath
                offer_variant = ""
                tx_modes = ($transactionModesJson -replace '\|',' ')
                expected = "transaction_modes_json[0] must be in allowed_transaction_modes: $($allowed -join ', ')"
            }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host "FAIL: $($violations.Count) listing(s) violate category flow policy" -ForegroundColor Red
    $toShow = if ($violations.Count -gt 20) { 20 } else { $violations.Count }
    Write-Host "First $toShow violation(s):" -ForegroundColor Yellow
    for ($i = 0; $i -lt $toShow; $i++) {
        $v = $violations[$i]
        Write-Host "  listing_id=$($v.listing_id) category_path=$($v.category_path) offer_variant=$($v.offer_variant) tx_modes=$($v.tx_modes) expected=$($v.expected)" -ForegroundColor Yellow
    }
    Write-Host "=== CATEGORY FLOW POLICY CHECK: FAIL ===" -ForegroundColor Red
    exit 1
}

Write-Host "PASS: All listings conform to category flow policy" -ForegroundColor Green
Write-Host "=== CATEGORY FLOW POLICY CHECK: PASS ===" -ForegroundColor Green
exit 0

