<# 
product_api_smoke.ps1 - Pazar Marketplace API Smoke Gate

Reality lock:
- Pazar "world" is always `marketplace` (H-OS world directory key).
- Catalog vertical roots (category roots) are NOT worlds.
- Listings API is NOT namespaced as /api/v1/{world}/... ; it is /api/v1/listings

This gate:
- Fetches categories, picks a leaf category_id
- Creates a draft listing
- Publishes the listing
- Verifies listing read

PowerShell 5.1 compatible, ASCII-only output, safe exit.
#>

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$WorldsConfigPath = "work\pazar\config\worlds.php",
    [string]$TestTenantId = $env:PRODUCT_TEST_TENANT_ID,
    [string]$TestAuth = $env:PRODUCT_TEST_AUTH
)

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}
if (Test-Path "${scriptDir}\_lib\worlds_config.ps1") {
    . "${scriptDir}\_lib\worlds_config.ps1"
}

Write-Host "=== PAZAR MARKETPLACE API SMOKE GATE ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$results = @()
$overallStatus = "PASS"
$overallExitCode = 0

function Add-CheckResult {
    param(
        [string]$Step,
        [string]$Status,
        [string]$Notes = ""
    )
    $script:results += [PSCustomObject]@{
        Step = $Step
        Status = $Status
        Notes = $Notes
    }
    if ($Status -eq "FAIL") {
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    } elseif ($Status -eq "WARN") {
        if ($script:overallStatus -ne "FAIL") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    }
}

function Normalize-BearerToken {
    param([string]$TokenRaw)
    if ([string]::IsNullOrEmpty($TokenRaw)) { return $null }
    $t = $TokenRaw.Trim()
    if ($t.StartsWith("Bearer ")) { return $t }
    return "Bearer $t"
}

function Find-FirstLeafCategoryId {
    param($Nodes)
    if ($null -eq $Nodes) { return $null }
    foreach ($n in $Nodes) {
        $children = $null
        try { $children = $n.children } catch { $children = $null }
        if ($null -eq $children -or $children.Count -eq 0) {
            if ($n.id) { return [int]$n.id }
        }
        $fromChild = Find-FirstLeafCategoryId -Nodes $children
        if ($fromChild) { return $fromChild }
    }
    return $null
}

# Step 1: Worlds config must declare marketplace only
Write-Info "Step 1: Worlds config sanity (expect enabled=[marketplace], disabled=[])"
try {
    if (-not (Test-Path $WorldsConfigPath)) {
        Write-Fail "Worlds config not found: $WorldsConfigPath"
        Add-CheckResult -Step "Worlds config" -Status "FAIL" -Notes "Missing: $WorldsConfigPath"
        Invoke-OpsExit 1
        return
    }

    $enabled = @()
    $disabled = @()

    if (Get-Command Get-WorldsConfig -ErrorAction SilentlyContinue) {
        $wc = Get-WorldsConfig -WorldsConfigPath $WorldsConfigPath
        $enabled = $wc.Enabled
        $disabled = $wc.Disabled
    } else {
        $content = Get-Content $WorldsConfigPath -Raw
        if ($content -match "(?s)'enabled'\s*=>\s*\[(.*?)\]") {
            $enabledMatches = [regex]::Matches($matches[1], "['""]([a-z0-9_]+)['""]")
            foreach ($m in $enabledMatches) { $enabled += $m.Groups[1].Value }
        }
        if ($content -match "(?s)'disabled'\s*=>\s*\[(.*?)\]") {
            $disabledMatches = [regex]::Matches($matches[1], "['""]([a-z0-9_]+)['""]")
            foreach ($m in $disabledMatches) { $disabled += $m.Groups[1].Value }
        }
    }

    $enabled = @($enabled | Sort-Object -Unique)
    $disabled = @($disabled | Sort-Object -Unique)

    if ($enabled.Count -ne 1 -or $enabled[0] -ne "marketplace" -or $disabled.Count -ne 0) {
        $en = if ($enabled) { $enabled -join ", " } else { "<empty>" }
        $di = if ($disabled) { $disabled -join ", " } else { "<empty>" }
        Write-Fail "Worlds config drift. Expected enabled=[marketplace], disabled=[]. Got enabled=[$en], disabled=[$di]"
        Add-CheckResult -Step "Worlds config" -Status "FAIL" -Notes "Drift detected"
        Invoke-OpsExit 1
        return
    }

    Write-Pass "Worlds config OK (enabled: marketplace)"
    Add-CheckResult -Step "Worlds config" -Status "PASS" -Notes "enabled=[marketplace]"
} catch {
    Write-Fail "Error parsing worlds config: $($_.Exception.Message)"
    Add-CheckResult -Step "Worlds config" -Status "FAIL" -Notes "Parse error"
    Invoke-OpsExit 1
    return
}

# Step 2: Credentials (tenant required for write)
Write-Info "Step 2: Credentials"
if ([string]::IsNullOrEmpty($TestTenantId)) {
    Write-Warn "PRODUCT_TEST_TENANT_ID not provided. Write tests will be skipped."
    Add-CheckResult -Step "Credentials" -Status "WARN" -Notes "Missing PRODUCT_TEST_TENANT_ID"
    Invoke-OpsExit 2
    return
}

$authHeader = Normalize-BearerToken -TokenRaw $TestAuth
if ([string]::IsNullOrEmpty($authHeader)) {
    Write-Warn "PRODUCT_TEST_AUTH not provided. Auth may be optional (GENESIS_ALLOW_UNAUTH_STORE=1)."
    Add-CheckResult -Step "Auth token" -Status "WARN" -Notes "Missing PRODUCT_TEST_AUTH (may be OK in GENESIS)"
} else {
    Add-CheckResult -Step "Auth token" -Status "PASS" -Notes "Provided"
}

# Shared headers for store-scope endpoints
$storeHeaders = @{
    "Accept" = "application/json"
    "Content-Type" = "application/json"
    "X-Active-Tenant-Id" = $TestTenantId
}
if ($authHeader) {
    $storeHeaders["Authorization"] = $authHeader
}

# Step 3: Fetch categories and pick a leaf
Write-Info "Step 3: Fetch categories and pick a leaf category_id"
$leafCategoryId = $null
try {
    $catRes = Invoke-WebRequest -Uri "$BaseUrl/api/v1/categories" -Method GET -UseBasicParsing -ErrorAction Stop
    if ($catRes.StatusCode -ne 200) {
        Write-Fail "GET /api/v1/categories expected 200, got $($catRes.StatusCode)"
        Add-CheckResult -Step "Categories" -Status "FAIL" -Notes "HTTP $($catRes.StatusCode)"
        Invoke-OpsExit 1
        return
    }
    $tree = $catRes.Content | ConvertFrom-Json
    $leafCategoryId = Find-FirstLeafCategoryId -Nodes $tree
    if (-not $leafCategoryId) {
        Write-Fail "No leaf category_id found in categories tree"
        Add-CheckResult -Step "Categories" -Status "FAIL" -Notes "No leaf found"
        Invoke-OpsExit 1
        return
    }
    Write-Pass "Leaf category_id selected: $leafCategoryId"
    Add-CheckResult -Step "Categories" -Status "PASS" -Notes "leaf_category_id=$leafCategoryId"
} catch {
    Write-Fail "GET /api/v1/categories failed: $($_.Exception.Message)"
    Add-CheckResult -Step "Categories" -Status "FAIL" -Notes "Request failed"
    Invoke-OpsExit 1
    return
}

# Step 4: Create listing (draft)
Write-Info "Step 4: Create listing (POST /api/v1/listings)"
$listingId = $null
try {
    $createBody = @{
        category_id = $leafCategoryId
        title = "Smoke Test Listing $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
        description = "Smoke test listing"
        transaction_modes = @("sale")
        attributes = @{}
    } | ConvertTo-Json -Depth 6

    $createRes = Invoke-WebRequest -Uri "$BaseUrl/api/v1/listings" -Method POST -Headers $storeHeaders -Body $createBody -UseBasicParsing -ErrorAction Stop
    if ($createRes.StatusCode -ne 201) {
        Write-Fail "POST /api/v1/listings expected 201, got $($createRes.StatusCode)"
        Add-CheckResult -Step "Create listing" -Status "FAIL" -Notes "HTTP $($createRes.StatusCode)"
        Invoke-OpsExit 1
        return
    }
    $json = $createRes.Content | ConvertFrom-Json
    if (-not $json.id) {
        Write-Fail "Create response missing id"
        Add-CheckResult -Step "Create listing" -Status "FAIL" -Notes "Missing id"
        Invoke-OpsExit 1
        return
    }
    $listingId = [string]$json.id
    Write-Pass "Created listing: $listingId (status: $($json.status))"
    Add-CheckResult -Step "Create listing" -Status "PASS" -Notes "id=$listingId"
} catch {
    Write-Fail "POST /api/v1/listings failed: $($_.Exception.Message)"
    Add-CheckResult -Step "Create listing" -Status "FAIL" -Notes "Request failed"
    Invoke-OpsExit 1
    return
}

# Step 5: Publish listing
Write-Info "Step 5: Publish listing (POST /api/v1/listings/{id}/publish)"
try {
    $pubRes = Invoke-WebRequest -Uri "$BaseUrl/api/v1/listings/$listingId/publish" -Method POST -Headers $storeHeaders -UseBasicParsing -ErrorAction Stop
    if ($pubRes.StatusCode -ne 200) {
        Write-Fail "Publish expected 200, got $($pubRes.StatusCode)"
        Add-CheckResult -Step "Publish listing" -Status "FAIL" -Notes "HTTP $($pubRes.StatusCode)"
        Invoke-OpsExit 1
        return
    }
    $pubJson = $pubRes.Content | ConvertFrom-Json
    if ($pubJson.id -ne $listingId -or $pubJson.status -ne "published") {
        Write-Fail "Publish response invalid (id/status mismatch)"
        Add-CheckResult -Step "Publish listing" -Status "FAIL" -Notes "Invalid response"
        Invoke-OpsExit 1
        return
    }
    Write-Pass "Published listing: $listingId"
    Add-CheckResult -Step "Publish listing" -Status "PASS" -Notes "published"
} catch {
    Write-Fail "Publish failed: $($_.Exception.Message)"
    Add-CheckResult -Step "Publish listing" -Status "FAIL" -Notes "Request failed"
    Invoke-OpsExit 1
    return
}

# Step 6: Show listing (read path)
Write-Info "Step 6: Show listing (GET /api/v1/listings/{id})"
try {
    $showRes = Invoke-WebRequest -Uri "$BaseUrl/api/v1/listings/$listingId" -Method GET -Headers @{ "Accept" = "application/json" } -UseBasicParsing -ErrorAction Stop
    if ($showRes.StatusCode -ne 200) {
        Write-Fail "Show expected 200, got $($showRes.StatusCode)"
        Add-CheckResult -Step "Show listing" -Status "FAIL" -Notes "HTTP $($showRes.StatusCode)"
        Invoke-OpsExit 1
        return
    }
    $showJson = $showRes.Content | ConvertFrom-Json
    if ($showJson.id -ne $listingId -or $showJson.status -ne "published") {
        Write-Fail "Show response invalid (id/status mismatch)"
        Add-CheckResult -Step "Show listing" -Status "FAIL" -Notes "Invalid response"
        Invoke-OpsExit 1
        return
    }
    Write-Pass "Show OK (id/status match)"
    Add-CheckResult -Step "Show listing" -Status "PASS" -Notes "id=$listingId"
} catch {
    Write-Fail "Show failed: $($_.Exception.Message)"
    Add-CheckResult -Step "Show listing" -Status "FAIL" -Notes "Request failed"
    Invoke-OpsExit 1
    return
}

# Summary
Write-Host ""
Write-Host "Results Summary:" -ForegroundColor Cyan
Write-Host "Step | Status | Notes" -ForegroundColor Gray
Write-Host ("-" * 80) -ForegroundColor Gray
foreach ($r in $results) {
    $color = switch ($r.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "Gray" }
    }
    Write-Host "$($r.Step) | $($r.Status) | $($r.Notes)" -ForegroundColor $color
}
Write-Host ""
Write-Host "Overall Status: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
Write-Host ""

Invoke-OpsExit $overallExitCode
