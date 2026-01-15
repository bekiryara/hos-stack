# product_api_smoke.ps1 - Product API Smoke Gate
# End-to-end smoke test for Product API write-path across all enabled worlds
# PowerShell 5.1 compatible, ASCII-only output, safe exit

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

Write-Host "=== PRODUCT API SMOKE GATE ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()
$overallStatus = "PASS"
$overallExitCode = 0
$hasWarn = $false
$hasFail = $false

function Add-CheckResult {
    param(
        [string]$World,
        [string]$Step,
        [string]$Status,
        [string]$Notes = ""
    )
    $results += [PSCustomObject]@{
        World = $World
        Step = $Step
        Status = $Status
        Notes = $Notes
    }
    if ($Status -eq "FAIL") {
        $script:hasFail = $true
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    } elseif ($Status -eq "WARN") {
        $script:hasWarn = $true
        if ($script:overallStatus -ne "FAIL") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    }
}

# Step 1: Parse enabled worlds from config
Write-Info "Step 1: Parse enabled worlds from config"
try {
    if (-not (Test-Path $WorldsConfigPath)) {
        Write-Fail "Worlds config not found: $WorldsConfigPath"
        Invoke-OpsExit 1
        return
    }
    
    $configContent = Get-Content $WorldsConfigPath -Raw
    $enabledWorlds = @()
    if ($configContent -match "'enabled'\s*=>\s*\[(.*?)\]") {
        $enabledBlock = $matches[1]
        if ($enabledBlock -match "'commerce'") { $enabledWorlds += "commerce" }
        if ($enabledBlock -match "'food'") { $enabledWorlds += "food" }
        if ($enabledBlock -match "'rentals'") { $enabledWorlds += "rentals" }
    }
    
    if ($enabledWorlds.Count -eq 0) {
        Write-Fail "No enabled worlds found in config"
        Invoke-OpsExit 1
        return
    }
    
    Write-Pass "Found enabled worlds: $($enabledWorlds -join ', ')"
} catch {
    Write-Fail "Error parsing config: $($_.Exception.Message)"
    Invoke-OpsExit 1
    return
}

# Step 2: Check test credentials
Write-Info "Step 2: Check test credentials"
if (-not $TestTenantId -or -not $TestAuth) {
    Write-Warn "Test credentials not provided (PRODUCT_TEST_TENANT_ID and PRODUCT_TEST_AUTH env vars missing)"
    Write-Warn "Smoke tests will be skipped (WARN-only, not FAIL)"
    Add-CheckResult -World "ALL" -Step "Credentials" -Status "WARN" -Notes "Test credentials missing, skipping live tests"
    Write-Host ""
    Write-Host "Results Summary:" -ForegroundColor Cyan
    Write-Host "Status: WARN (credentials missing)" -ForegroundColor Yellow
    Write-Host ""
    Invoke-OpsExit 2
    return
}

Write-Pass "Test credentials provided"
$headers = @{
    "Authorization" = "Bearer $TestAuth"
    "X-Tenant-Id" = $TestTenantId
    "Content-Type" = "application/json"
}

# Step 3: Run smoke tests for each enabled world
Write-Info "Step 3: Run smoke tests for each enabled world"
foreach ($world in $enabledWorlds) {
    Write-Host ""
    Write-Host "Testing world: $world" -ForegroundColor Cyan
    
    $createdListingId = $null
    $createdRequestId = $null
    
    # Step 3.1: Create listing (POST)
    Write-Info "  Step 3.1: Create listing (POST)"
    try {
        $createBody = @{
            title = "Smoke Test Listing $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
            description = "Test description"
            price_amount = 1000
            currency = "TRY"
            status = "draft"
        } | ConvertTo-Json
        
        $createResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$world/listings" `
            -Method POST `
            -Headers $headers `
            -Body $createBody `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($createResponse.StatusCode -eq 201) {
            $createJson = $createResponse.Content | ConvertFrom-Json
            if ($createJson.ok -eq $true -and $createJson.item -and $createJson.item.id) {
                $createdListingId = $createJson.item.id
                $createdRequestId = $createJson.request_id
                $headerRequestId = $createResponse.Headers["X-Request-Id"]
                
                if ($createdRequestId -and $headerRequestId -and $createdRequestId -eq $headerRequestId) {
                    Write-Pass "  POST /api/v1/$world/listings -> 201 CREATED, ok:true, request_id consistent"
                    Add-CheckResult -World $world -Step "Create (POST)" -Status "PASS" -Notes "201 CREATED, id: $createdListingId"
                } else {
                    Write-Warn "  POST /api/v1/$world/listings -> request_id mismatch (body: $createdRequestId, header: $headerRequestId)"
                    Add-CheckResult -World $world -Step "Create (POST)" -Status "WARN" -Notes "Request ID mismatch"
                }
            } else {
                Write-Fail "  POST /api/v1/$world/listings -> Invalid response format (ok:true, item.id expected)"
                Add-CheckResult -World $world -Step "Create (POST)" -Status "FAIL" -Notes "Invalid response format"
            }
        } else {
            Write-Fail "  POST /api/v1/$world/listings -> Expected 201, got $($createResponse.StatusCode)"
            Add-CheckResult -World $world -Step "Create (POST)" -Status "FAIL" -Notes "Status code: $($createResponse.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Fail "  POST /api/v1/$world/listings -> Error: $statusCode"
        Add-CheckResult -World $world -Step "Create (POST)" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    if (-not $createdListingId) {
        Write-Warn "  Skipping remaining tests for $world (create failed)"
        continue
    }
    
    # Step 3.2: List listings (GET)
    Write-Info "  Step 3.2: List listings (GET)"
    try {
        $listResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$world/listings" `
            -Method GET `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($listResponse.StatusCode -eq 200) {
            $listJson = $listResponse.Content | ConvertFrom-Json
            if ($listJson.ok -eq $true -and $listJson.items) {
                $foundId = $listJson.items | Where-Object { $_.id -eq $createdListingId } | Select-Object -First 1
                if ($foundId) {
                    Write-Pass "  GET /api/v1/$world/listings -> 200 OK, created id found in list"
                    Add-CheckResult -World $world -Step "List (GET)" -Status "PASS" -Notes "Created id found in list"
                } else {
                    Write-Warn "  GET /api/v1/$world/listings -> Created id not found in list"
                    Add-CheckResult -World $world -Step "List (GET)" -Status "WARN" -Notes "Created id not found"
                }
            } else {
                Write-Fail "  GET /api/v1/$world/listings -> Invalid response format (ok:true, items expected)"
                Add-CheckResult -World $world -Step "List (GET)" -Status "FAIL" -Notes "Invalid response format"
            }
        } else {
            Write-Fail "  GET /api/v1/$world/listings -> Expected 200, got $($listResponse.StatusCode)"
            Add-CheckResult -World $world -Step "List (GET)" -Status "FAIL" -Notes "Status code: $($listResponse.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Fail "  GET /api/v1/$world/listings -> Error: $statusCode"
        Add-CheckResult -World $world -Step "List (GET)" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    # Step 3.3: Show listing (GET)
    Write-Info "  Step 3.3: Show listing (GET)"
    try {
        $showResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$world/listings/$createdListingId" `
            -Method GET `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($showResponse.StatusCode -eq 200) {
            $showJson = $showResponse.Content | ConvertFrom-Json
            if ($showJson.ok -eq $true -and $showJson.item -and $showJson.item.id -eq $createdListingId) {
                Write-Pass "  GET /api/v1/$world/listings/$createdListingId -> 200 OK, id matches"
                Add-CheckResult -World $world -Step "Show (GET)" -Status "PASS" -Notes "Id matches"
            } else {
                Write-Fail "  GET /api/v1/$world/listings/$createdListingId -> Id mismatch"
                Add-CheckResult -World $world -Step "Show (GET)" -Status "FAIL" -Notes "Id mismatch"
            }
        } else {
            Write-Fail "  GET /api/v1/$world/listings/$createdListingId -> Expected 200, got $($showResponse.StatusCode)"
            Add-CheckResult -World $world -Step "Show (GET)" -Status "FAIL" -Notes "Status code: $($showResponse.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Fail "  GET /api/v1/$world/listings/$createdListingId -> Error: $statusCode"
        Add-CheckResult -World $world -Step "Show (GET)" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    # Step 3.4: Update listing (PATCH)
    Write-Info "  Step 3.4: Update listing (PATCH)"
    try {
        $updateBody = @{
            title = "Updated Title $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
        } | ConvertTo-Json
        
        $updateResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$world/listings/$createdListingId" `
            -Method PATCH `
            -Headers $headers `
            -Body $updateBody `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($updateResponse.StatusCode -eq 200) {
            $updateJson = $updateResponse.Content | ConvertFrom-Json
            if ($updateJson.ok -eq $true -and $updateJson.item -and $updateJson.item.title -like "Updated Title*") {
                Write-Pass "  PATCH /api/v1/$world/listings/$createdListingId -> 200 OK, title updated"
                Add-CheckResult -World $world -Step "Update (PATCH)" -Status "PASS" -Notes "Title updated"
            } else {
                Write-Fail "  PATCH /api/v1/$world/listings/$createdListingId -> Title not updated"
                Add-CheckResult -World $world -Step "Update (PATCH)" -Status "FAIL" -Notes "Title not updated"
            }
        } else {
            Write-Fail "  PATCH /api/v1/$world/listings/$createdListingId -> Expected 200, got $($updateResponse.StatusCode)"
            Add-CheckResult -World $world -Step "Update (PATCH)" -Status "FAIL" -Notes "Status code: $($updateResponse.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Fail "  PATCH /api/v1/$world/listings/$createdListingId -> Error: $statusCode"
        Add-CheckResult -World $world -Step "Update (PATCH)" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    # Step 3.5: Delete listing (DELETE)
    Write-Info "  Step 3.5: Delete listing (DELETE)"
    try {
        $deleteResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$world/listings/$createdListingId" `
            -Method DELETE `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($deleteResponse.StatusCode -eq 204) {
            Write-Pass "  DELETE /api/v1/$world/listings/$createdListingId -> 204 NO CONTENT"
            Add-CheckResult -World $world -Step "Delete (DELETE)" -Status "PASS" -Notes "204 NO CONTENT"
        } elseif ($deleteResponse.StatusCode -eq 200) {
            Write-Warn "  DELETE /api/v1/$world/listings/$createdListingId -> 200 OK (expected 204)"
            Add-CheckResult -World $world -Step "Delete (DELETE)" -Status "WARN" -Notes "200 OK (expected 204)"
        } else {
            Write-Fail "  DELETE /api/v1/$world/listings/$createdListingId -> Expected 204/200, got $($deleteResponse.StatusCode)"
            Add-CheckResult -World $world -Step "Delete (DELETE)" -Status "FAIL" -Notes "Status code: $($deleteResponse.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Fail "  DELETE /api/v1/$world/listings/$createdListingId -> Error: $statusCode"
        Add-CheckResult -World $world -Step "Delete (DELETE)" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    # Step 3.6: Verify deleted (GET -> 404)
    Write-Info "  Step 3.6: Verify deleted (GET -> 404)"
    try {
        $verifyResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$world/listings/$createdListingId" `
            -Method GET `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        
        Write-Fail "  GET /api/v1/$world/listings/$createdListingId -> Expected 404, got $($verifyResponse.StatusCode)"
        Add-CheckResult -World $world -Step "Verify Deleted (GET)" -Status "FAIL" -Notes "Expected 404, got $($verifyResponse.StatusCode)"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Pass "  GET /api/v1/$world/listings/$createdListingId -> 404 NOT FOUND (correct)"
            Add-CheckResult -World $world -Step "Verify Deleted (GET)" -Status "PASS" -Notes "404 NOT FOUND (correct)"
        } else {
            Write-Fail "  GET /api/v1/$world/listings/$createdListingId -> Expected 404, got $statusCode"
            Add-CheckResult -World $world -Step "Verify Deleted (GET)" -Status "FAIL" -Notes "Expected 404, got $statusCode"
        }
    }
}

# Summary
Write-Host ""
Write-Host "Results Summary:" -ForegroundColor Cyan
Write-Host "World | Step | Status | Notes" -ForegroundColor Gray
Write-Host ("-" * 80) -ForegroundColor Gray
foreach ($result in $results) {
    $statusColor = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "Gray" }
    }
    $line = "$($result.World) | $($result.Step) | $($result.Status) | $($result.Notes)"
    Write-Host $line -ForegroundColor $statusColor
}

Write-Host ""
Write-Host "Overall Status: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
Write-Host ""

Invoke-OpsExit $overallExitCode



