#!/usr/bin/env pwsh
# Create/Edit Parity Check
# Ensures UI parity contract keeps up with policy primitives.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

Write-Host "=== CREATE/EDIT PARITY CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$policyPath = Join-Path $repoRoot "work\pazar\config\category_flow_policy.php"
$createFormPath = Join-Path $repoRoot "work\marketplace-web\src\components\listing\create\CreateListingForm.vue"
$editPagePath = Join-Path $repoRoot "work\marketplace-web\src\pages\EditListingPage.vue"

foreach ($p in @($policyPath, $createFormPath, $editPagePath)) {
    if (-not (Test-Path $p)) {
        Write-Host "FAIL: File not found: $p" -ForegroundColor Red
        exit 1
    }
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
    Write-Host "FAIL: Could not load policy JSON" -ForegroundColor Red
    exit 1
}

$policyLine = ($policyJson -split "`n" | Where-Object { $_ -match '^\s*\{' }) | Select-Object -First 1
if (-not $policyLine) { $policyLine = $policyJson.Trim() }
$policy = $policyLine | ConvertFrom-Json

$billingModels = New-Object System.Collections.Generic.HashSet[string]
$timeModels = New-Object System.Collections.Generic.HashSet[string]

if ($policy.rules) {
    foreach ($ruleProp in $policy.rules.PSObject.Properties) {
        $rule = $ruleProp.Value
        if ($rule -and $rule.offer_variants) {
            foreach ($v in @($rule.offer_variants)) {
                if ($v -and $v.billing_model) { [void]$billingModels.Add([string]$v.billing_model) }
                if ($v -and $v.service_time_model) { [void]$timeModels.Add([string]$v.service_time_model) }
            }
        }
    }
}

$createText = Get-Content -Path $createFormPath -Raw
$editText = Get-Content -Path $editPagePath -Raw

$violations = @()

# 1) Edit must reuse Create form in edit mode (single behavior surface).
if ($editText -notmatch '<CreateListingForm') {
    $violations += "EditListingPage does not render CreateListingForm"
}
if ($editText -notmatch ':mode="''edit''"') {
    $violations += "EditListingPage does not pass mode='edit' to CreateListingForm"
}

# 2) Pricing label map must cover policy billing models.
$billingLabelMap = @{
    one_time = "Toplam Fiyat"
    per_day = "Gunluk Fiyat"
    per_month = "Aylik Fiyat"
    per_night = "Gecelik Fiyat"
    per_person = "Kisi Basi Fiyat"
    per_hour = "Saatlik Fiyat"
    per_session = "Seans Fiyati"
    per_visit = "Ziyaret Basi Fiyat"
}
foreach ($bm in $billingModels) {
    if (-not $billingLabelMap.ContainsKey($bm)) {
        $violations += "CreateListingForm canonicalPriceFieldLabel missing billing_model '$bm'"
    }
}

# 3) Time guidance must cover policy time models.
$knownGuidanceTimeModels = @("none", "slot", "date_range", "session")
foreach ($tm in $timeModels) {
    if ($knownGuidanceTimeModels -notcontains $tm) {
        $violations += "CreateListingForm timeModelGuidance missing service_time_model '$tm'"
    }
}

# 4) Ensure submit path still sends canonical fields needed by backend.
if ($createText -notmatch "price_amount:\s*this\.isCanonicalPriceEnabled\s*\?\s*this\.local\.price_amount\s*:\s*null") {
    $violations += "Create submit snapshot lost canonical price binding"
}
if ($createText -notmatch "attributes:\s*attributesPayload") {
    $violations += "Create submit snapshot lost attributes payload binding"
}
if ($editText -notmatch "attributes:\s*this\.sanitizeAttributes\(formSnapshot\.attributes\)") {
    $violations += "Edit submit payload lost sanitized attributes binding"
}

if ($violations.Count -gt 0) {
    Write-Host "FAIL: Create/Edit parity violations detected:" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  - $v" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "PASS: Create/Edit parity contract is valid" -ForegroundColor Green
Write-Host "=== CREATE/EDIT PARITY CHECK: PASS ===" -ForegroundColor Green
exit 0
