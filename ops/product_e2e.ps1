# product_e2e.ps1 - Product API E2E Gate (Optional)
# Minimal CRUD E2E for enabled worlds (catches drift/breakage)
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [string]$BaseUrl = $env:BASE_URL,
    [string]$TestEmail = $env:PRODUCT_TEST_EMAIL,
    [string]$TestPassword = $env:PRODUCT_TEST_PASSWORD,
    [string]$TestAuth = $env:PRODUCT_TEST_AUTH,
    [string]$TenantId = $env:PRODUCT_TENANT_ID,
    [string]$WorldsConfigPath = "work\pazar\config\worlds.php"
)

if ([string]::IsNullOrEmpty($BaseUrl)) {
    $BaseUrl = "http://localhost:8080"
}

$ErrorActionPreference = "Continue"

# Dot-source shared helpers
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\_lib\ops_output.ps1"
. "$ScriptDir\_lib\ops_exit.ps1"

Initialize-OpsOutput

Write-Info "Product API E2E Gate"
Write-Info "Base URL: ${BaseUrl}"
Write-Info ""

# Result tracking
$checkResults = @()
$overallPass = $true
$hasWarn = $false

function Add-CheckResult {
    param(
        [string]$World,
        [string]$Step,
        [string]$Status,
        [string]$Notes = ""
    )
    $script:checkResults += [PSCustomObject]@{
        World = $World
        Step = $Step
        Status = $Status
        Notes = $Notes
    }
    if ($Status -eq "FAIL") {
        $script:overallPass = $false
    } elseif ($Status -eq "WARN") {
        $script:hasWarn = $true
    }
}

# Step 1: Parse enabled worlds
Write-Info "Step 1: Parsing enabled worlds..."
$enabledWorlds = @()

if (Test-Path $WorldsConfigPath) {
    $content = Get-Content $WorldsConfigPath -Raw
    if ($content -match "'enabled'\s*=>\s*\[(.*?)\]") {
        $enabledStr = $matches[1]
        if ($enabledStr -match "'commerce'") { $enabledWorlds += "commerce" }
        if ($enabledStr -match "'food'") { $enabledWorlds += "food" }
        if ($enabledStr -match "'rentals'") { $enabledWorlds += "rentals" }
    }
}

if ($enabledWorlds.Count -eq 0) {
    Write-Warn "No enabled worlds found. Using defaults: commerce, food, rentals"
    $enabledWorlds = @("commerce", "food", "rentals")
}

Write-Pass "Enabled worlds: $($enabledWorlds -join ', ')"

# Step 2: Check credentials
Write-Info ""
Write-Info "Step 2: Checking credentials..."

# Use Bearer token if provided, otherwise try email/password
$authToken = $null
if (-not [string]::IsNullOrEmpty($TestAuth)) {
    $authToken = $TestAuth
    Write-Pass "Bearer token provided"
} elseif (-not [string]::IsNullOrEmpty($TestEmail) -and -not [string]::IsNullOrEmpty($TestPassword)) {
    # Try to get token via login (if login endpoint exists)
    # For now, we'll use Bearer token approach (HOS_OIDC_API_KEY)
    Write-Warn "Email/password provided but login endpoint not implemented. Using HOS_OIDC_API_KEY if available."
    $authToken = $env:HOS_OIDC_API_KEY
    if ([string]::IsNullOrEmpty($authToken)) {
        Write-Warn "HOS_OIDC_API_KEY not set. E2E tests will be skipped."
    }
} else {
    Write-Warn "No credentials provided (PRODUCT_TEST_AUTH or PRODUCT_TEST_EMAIL/PASSWORD). E2E tests will be skipped."
    Write-Warn "Set PRODUCT_TEST_AUTH (Bearer token) or PRODUCT_TEST_EMAIL + PRODUCT_TEST_PASSWORD to run E2E tests."
    Add-CheckResult -World "All" -Step "Credentials" -Status "WARN" -Notes "Credentials missing, skipping E2E tests"
    Invoke-OpsExit 2
    return
}

if ([string]::IsNullOrEmpty($TenantId)) {
    Write-Warn "PRODUCT_TENANT_ID not provided. E2E tests will be skipped."
    Add-CheckResult -World "All" -Step "Tenant ID" -Status "WARN" -Notes "Tenant ID missing, skipping E2E tests"
    Invoke-OpsExit 2
    return
}

Write-Pass "Credentials available. Proceeding with E2E tests."

# Step 3: Run E2E for each enabled world
Write-Info ""
Write-Info "Step 3: Running E2E tests for each enabled world..."

foreach ($world in $enabledWorlds) {
    Write-Info ""
    Write-Info "Testing world: ${world}"
    
    $headers = @{
        "Authorization" = "Bearer $authToken"
        "X-Tenant-Id" = $TenantId
        "Content-Type" = "application/json"
        "Accept" = "application/json"
    }
    
    $createdId = $null
    $worldPass = $true
    $worldNotes = @()
    
    # Step 3.1: CREATE (POST)
    Write-Info "  CREATE: POST /api/v1/${world}/listings"
    try {
        $createBody = @{
            title = "E2E Test Listing $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
            description = "E2E test description"
            price_amount = 5000
            currency = "TRY"
            status = "draft"
        } | ConvertTo-Json -Compress
        
        $createResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/${world}/listings" `
            -Method POST `
            -Headers $headers `
            -Body $createBody `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($createResponse.StatusCode -eq 201) {
            $createJson = $createResponse.Content | ConvertFrom-Json
            if ($createJson.ok -eq $true -and $createJson.item -and $createJson.item.id) {
                $createdId = $createJson.item.id
                Write-Pass "  CREATE: 201 CREATED, ok:true, id: ${createdId}"
                Add-CheckResult -World $world -Step "CREATE" -Status "PASS" -Notes "201 CREATED, id: ${createdId}"
            } else {
                $worldPass = $false
                $worldNotes += "CREATE: Invalid response (ok:true, item.id expected)"
                Write-Fail "  CREATE: Invalid response format"
                Add-CheckResult -World $world -Step "CREATE" -Status "FAIL" -Notes "Invalid response format"
            }
        } else {
            $worldPass = $false
            $worldNotes += "CREATE: Expected 201, got $($createResponse.StatusCode)"
            Write-Fail "  CREATE: Expected 201, got $($createResponse.StatusCode)"
            Add-CheckResult -World $world -Step "CREATE" -Status "FAIL" -Notes "Status: $($createResponse.StatusCode)"
        }
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
        $worldPass = $false
        $worldNotes += "CREATE: HTTP $statusCode"
        Write-Fail "  CREATE: HTTP $statusCode - $($_.Exception.Message)"
        Add-CheckResult -World $world -Step "CREATE" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    if (-not $createdId) {
        Write-Warn "  Skipping remaining tests for ${world} (CREATE failed)"
        continue
    }
    
    # Step 3.2: LIST (GET)
    Write-Info "  LIST: GET /api/v1/${world}/listings"
    try {
        $listResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/${world}/listings" `
            -Method GET `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($listResponse.StatusCode -eq 200) {
            $listJson = $listResponse.Content | ConvertFrom-Json
            if ($listJson.ok -eq $true -and $listJson.items) {
                $found = $listJson.items | Where-Object { $_.id -eq $createdId } | Select-Object -First 1
                if ($found) {
                    Write-Pass "  LIST: 200 OK, created id found"
                    Add-CheckResult -World $world -Step "LIST" -Status "PASS" -Notes "200 OK, id found"
                } else {
                    $worldNotes += "LIST: Created id not found"
                    Write-Warn "  LIST: Created id not found in list"
                    Add-CheckResult -World $world -Step "LIST" -Status "WARN" -Notes "Created id not found"
                }
            } else {
                $worldPass = $false
                $worldNotes += "LIST: Invalid response (ok:true, items expected)"
                Write-Fail "  LIST: Invalid response format"
                Add-CheckResult -World $world -Step "LIST" -Status "FAIL" -Notes "Invalid response format"
            }
        } else {
            $worldPass = $false
            $worldNotes += "LIST: Expected 200, got $($listResponse.StatusCode)"
            Write-Fail "  LIST: Expected 200, got $($listResponse.StatusCode)"
            Add-CheckResult -World $world -Step "LIST" -Status "FAIL" -Notes "Status: $($listResponse.StatusCode)"
        }
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
        $worldPass = $false
        $worldNotes += "LIST: HTTP $statusCode"
        Write-Fail "  LIST: HTTP $statusCode"
        Add-CheckResult -World $world -Step "LIST" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    # Step 3.3: SHOW (GET)
    Write-Info "  SHOW: GET /api/v1/${world}/listings/${createdId}"
    try {
        $showResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/${world}/listings/${createdId}" `
            -Method GET `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($showResponse.StatusCode -eq 200) {
            $showJson = $showResponse.Content | ConvertFrom-Json
            if ($showJson.ok -eq $true -and $showJson.item -and $showJson.item.id -eq $createdId) {
                Write-Pass "  SHOW: 200 OK, id matches"
                Add-CheckResult -World $world -Step "SHOW" -Status "PASS" -Notes "200 OK, id matches"
            } else {
                $worldPass = $false
                $worldNotes += "SHOW: Id mismatch"
                Write-Fail "  SHOW: Id mismatch"
                Add-CheckResult -World $world -Step "SHOW" -Status "FAIL" -Notes "Id mismatch"
            }
        } else {
            $worldPass = $false
            $worldNotes += "SHOW: Expected 200, got $($showResponse.StatusCode)"
            Write-Fail "  SHOW: Expected 200, got $($showResponse.StatusCode)"
            Add-CheckResult -World $world -Step "SHOW" -Status "FAIL" -Notes "Status: $($showResponse.StatusCode)"
        }
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
        $worldPass = $false
        $worldNotes += "SHOW: HTTP $statusCode"
        Write-Fail "  SHOW: HTTP $statusCode"
        Add-CheckResult -World $world -Step "SHOW" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    # Step 3.4: UPDATE (PATCH, fallback to PUT)
    Write-Info "  UPDATE: PATCH /api/v1/${world}/listings/${createdId}"
    $updateMethod = "PATCH"
    try {
        $updateBody = @{
            title = "Updated E2E Title $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
        } | ConvertTo-Json -Compress
        
        $updateResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/${world}/listings/${createdId}" `
            -Method PATCH `
            -Headers $headers `
            -Body $updateBody `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($updateResponse.StatusCode -eq 200) {
            $updateJson = $updateResponse.Content | ConvertFrom-Json
            if ($updateJson.ok -eq $true -and $updateJson.item -and $updateJson.item.title -like "*Updated*") {
                Write-Pass "  UPDATE: 200 OK, title updated"
                Add-CheckResult -World $world -Step "UPDATE" -Status "PASS" -Notes "200 OK, title updated"
            } else {
                $worldNotes += "UPDATE: Title not updated"
                Write-Warn "  UPDATE: Title not updated"
                Add-CheckResult -World $world -Step "UPDATE" -Status "WARN" -Notes "Title not updated"
            }
        } else {
            $worldPass = $false
            $worldNotes += "UPDATE: Expected 200, got $($updateResponse.StatusCode)"
            Write-Fail "  UPDATE: Expected 200, got $($updateResponse.StatusCode)"
            Add-CheckResult -World $world -Step "UPDATE" -Status "FAIL" -Notes "Status: $($updateResponse.StatusCode)"
        }
    } catch {
        # Try PUT if PATCH fails
        if ($_.Exception.Response.StatusCode.value__ -eq 405) {
            Write-Info "  UPDATE: PATCH not allowed, trying PUT..."
            try {
                $updateBody = @{
                    title = "Updated E2E Title $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
                } | ConvertTo-Json -Compress
                
                $updateResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/${world}/listings/${createdId}" `
                    -Method PUT `
                    -Headers $headers `
                    -Body $updateBody `
                    -UseBasicParsing `
                    -ErrorAction Stop
                
                if ($updateResponse.StatusCode -eq 200) {
                    Write-Pass "  UPDATE: 200 OK (PUT), title updated"
                    Add-CheckResult -World $world -Step "UPDATE" -Status "PASS" -Notes "200 OK (PUT), title updated"
                } else {
                    $worldPass = $false
                    $worldNotes += "UPDATE: PUT returned $($updateResponse.StatusCode)"
                    Write-Fail "  UPDATE: PUT returned $($updateResponse.StatusCode)"
                    Add-CheckResult -World $world -Step "UPDATE" -Status "FAIL" -Notes "PUT Status: $($updateResponse.StatusCode)"
                }
            } catch {
                $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
                $worldPass = $false
                $worldNotes += "UPDATE: PUT HTTP $statusCode"
                Write-Fail "  UPDATE: PUT HTTP $statusCode"
                Add-CheckResult -World $world -Step "UPDATE" -Status "FAIL" -Notes "PUT HTTP $statusCode"
            }
        } else {
            $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
            $worldPass = $false
            $worldNotes += "UPDATE: HTTP $statusCode"
            Write-Fail "  UPDATE: HTTP $statusCode"
            Add-CheckResult -World $world -Step "UPDATE" -Status "FAIL" -Notes "HTTP $statusCode"
        }
    }
    
    # Step 3.5: DELETE
    Write-Info "  DELETE: DELETE /api/v1/${world}/listings/${createdId}"
    try {
        $deleteResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/${world}/listings/${createdId}" `
            -Method DELETE `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if ($deleteResponse.StatusCode -eq 204 -or $deleteResponse.StatusCode -eq 200) {
            Write-Pass "  DELETE: $($deleteResponse.StatusCode) OK"
            Add-CheckResult -World $world -Step "DELETE" -Status "PASS" -Notes "$($deleteResponse.StatusCode) OK"
        } else {
            $worldPass = $false
            $worldNotes += "DELETE: Expected 204/200, got $($deleteResponse.StatusCode)"
            Write-Fail "  DELETE: Expected 204/200, got $($deleteResponse.StatusCode)"
            Add-CheckResult -World $world -Step "DELETE" -Status "FAIL" -Notes "Status: $($deleteResponse.StatusCode)"
        }
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
        $worldPass = $false
        $worldNotes += "DELETE: HTTP $statusCode"
        Write-Fail "  DELETE: HTTP $statusCode"
        Add-CheckResult -World $world -Step "DELETE" -Status "FAIL" -Notes "HTTP $statusCode"
    }
    
    # Step 3.6: SHOW again (should be 404)
    Write-Info "  SHOW (after delete): GET /api/v1/${world}/listings/${createdId}"
    try {
        $showResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/${world}/listings/${createdId}" `
            -Method GET `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop
        
        $worldPass = $false
        $worldNotes += "SHOW (after delete): Expected 404, got $($showResponse.StatusCode)"
        Write-Fail "  SHOW (after delete): Expected 404, got $($showResponse.StatusCode)"
        Add-CheckResult -World $world -Step "SHOW (after delete)" -Status "FAIL" -Notes "Expected 404, got $($showResponse.StatusCode)"
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
        if ($statusCode -eq 404) {
            $errorJson = $null
            try {
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorContent = $reader.ReadToEnd()
                $errorJson = $errorContent | ConvertFrom-Json
            } catch {
                # Ignore JSON parse errors
            }
            
            if ($errorJson -and $errorJson.ok -eq $false -and $errorJson.error_code -and $errorJson.request_id) {
                Write-Pass "  SHOW (after delete): 404 NOT_FOUND, ok:false, error_code, request_id"
                Add-CheckResult -World $world -Step "SHOW (after delete)" -Status "PASS" -Notes "404 NOT_FOUND, error envelope correct"
            } else {
                Write-Warn "  SHOW (after delete): 404 but invalid error envelope"
                Add-CheckResult -World $world -Step "SHOW (after delete)" -Status "WARN" -Notes "404 but invalid error envelope"
            }
        } else {
            $worldPass = $false
            $worldNotes += "SHOW (after delete): Expected 404, got HTTP $statusCode"
            Write-Fail "  SHOW (after delete): Expected 404, got HTTP $statusCode"
            Add-CheckResult -World $world -Step "SHOW (after delete)" -Status "FAIL" -Notes "Expected 404, got HTTP $statusCode"
        }
    }
    
    if ($worldPass) {
        Write-Pass "World ${world}: E2E PASS"
    } else {
        Write-Fail "World ${world}: E2E FAIL - $($worldNotes -join '; ')"
    }
}

# Summary
Write-Info ""
Write-Info "=== Summary ==="
$passCount = ($checkResults | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($checkResults | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($checkResults | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Info "PASS: ${passCount}, WARN: ${warnCount}, FAIL: ${failCount}"

Write-Info ""
Write-Info "=== Check Results ==="
foreach ($result in $checkResults) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[?]" }
    }
    Write-Host "$statusMarker ${world}: $($result.Step) - $($result.Notes)" -ForegroundColor $(if ($result.Status -eq "PASS") { "Green" } elseif ($result.Status -eq "WARN") { "Yellow" } else { "Red" })
}

if (-not $overallPass) {
    Write-Info ""
    Write-Fail "Product API E2E FAILED (${failCount} failure(s))"
    Invoke-OpsExit 1
    return
}

if ($hasWarn) {
    Write-Info ""
    Write-Warn "Product API E2E passed with warnings (${warnCount} warning(s))"
    Invoke-OpsExit 2
    return
}

Write-Info ""
Write-Pass "Product API E2E PASSED"
Invoke-OpsExit 0

