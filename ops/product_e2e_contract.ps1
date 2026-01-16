# product_e2e_contract.ps1 - Product API E2E Contract Gate
# Snapshot-driven route discovery + comprehensive E2E validation
# Validates: unauthorized, tenant missing, world invalid, happy path, cross-tenant leakage
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [string]$BaseUrl = $env:BASE_URL,
    [string]$TestEmail = $env:PRODUCT_TEST_EMAIL,
    [string]$TestPassword = $env:PRODUCT_TEST_PASSWORD,
    [string]$TestAuth = $env:PRODUCT_TEST_AUTH,
    [string]$TenantA = $env:TENANT_A_SLUG,
    [string]$TenantB = $env:TENANT_B_SLUG,
    [string]$TenantAId = $env:TENANT_A_ID,
    [string]$RoutesSnapshotPath = "ops\snapshots\routes.pazar.json",
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
. "$ScriptDir\_lib\routes_json.ps1"

Initialize-OpsOutput

Write-Info "Product API E2E Contract Gate"
Write-Info "Base URL: ${BaseUrl}"
Write-Info ""

# Result tracking
$checkResults = @()
$overallPass = $true
$hasWarn = $false

function Add-CheckResult {
    param(
        [string]$Check,
        [string]$Status,
        [string]$Notes = ""
    )
    $script:checkResults += [PSCustomObject]@{
        Check = $Check
        Status = $Status
        Notes = $Notes
    }
    if ($Status -eq "FAIL") {
        $script:overallPass = $false
    } elseif ($Status -eq "WARN") {
        $script:hasWarn = $true
    }
}

# Helper: Make HTTP request and return response details
function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers = @{},
        [string]$Body = $null,
        [int]$ExpectedStatusCode = 200
    )
    
    try {
        $fullUrl = if ($Uri -like "http*") { $Uri } else { "$BaseUrl$Uri" }
        
        $request = [System.Net.HttpWebRequest]::Create($fullUrl)
        $request.Method = $Method
        $request.ContentType = "application/json"
        $request.Accept = "application/json"
        
        foreach ($key in $Headers.Keys) {
            if ($key -eq "Authorization") {
                $request.Headers.Add("Authorization", $Headers[$key])
            } elseif ($key -eq "X-Tenant-Id") {
                $request.Headers.Add("X-Tenant-Id", $Headers[$key])
            } elseif ($key -eq "X-World") {
                $request.Headers.Add("X-World", $Headers[$key])
            } else {
                $request.Headers.Add($key, $Headers[$key])
            }
        }
        
        if ($Body) {
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
            $request.ContentLength = $bodyBytes.Length
            $requestStream = $request.GetRequestStream()
            $requestStream.Write($bodyBytes, 0, $bodyBytes.Length)
            $requestStream.Close()
        }
        
        $response = $request.GetResponse()
        $statusCode = [int]$response.StatusCode
        $responseStream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $responseBody = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()
        
        $requestId = $response.Headers["X-Request-Id"]
        if (-not $requestId) {
            if ($responseBody -match '"request_id"\s*:\s*"([^"]+)"') {
                $requestId = $matches[1]
            }
        }
        
        return @{
            StatusCode = $statusCode
            Body = $responseBody
            RequestId = $requestId
            Success = ($statusCode -eq $ExpectedStatusCode)
        }
    } catch {
        $statusCode = 0
        $responseBody = ""
        $requestId = $null
        
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $responseBody = $reader.ReadToEnd()
            $reader.Close()
            
            $requestId = $_.Exception.Response.Headers["X-Request-Id"]
            if (-not $requestId -and $responseBody -match '"request_id"\s*:\s*"([^"]+)"') {
                $requestId = $matches[1]
            }
        } else {
            $responseBody = $_.Exception.Message
        }
        
        return @{
            StatusCode = $statusCode
            Body = $responseBody
            RequestId = $requestId
            Success = $false
            Error = $_.Exception.Message
        }
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

# Step 2: Snapshot-driven route discovery
Write-Info ""
Write-Info "Step 2: Discovering routes from snapshot..."

$discoveredRoutes = @{}

if (Test-Path $RoutesSnapshotPath) {
    $snapshotContent = Get-Content $RoutesSnapshotPath -Raw -Encoding UTF8
    $routes = Convert-RoutesJsonToCanonicalArray -RawJsonText $snapshotContent
    
    foreach ($world in $enabledWorlds) {
        $worldRoutes = $routes | Where-Object {
            $_.uri -like "/api/v1/$world/*" -or $_.uri -like "/api/v1/$world"
        }
        
        $getList = $worldRoutes | Where-Object { $_.method_primary -eq "GET" -and $_.uri -like "*/listings" -and $_.uri -notlike "*{*}" } | Select-Object -First 1
        $getShow = $worldRoutes | Where-Object { $_.method_primary -eq "GET" -and $_.uri -like "*/listings/{*}" } | Select-Object -First 1
        $postCreate = $worldRoutes | Where-Object { $_.method_primary -eq "POST" -and $_.uri -like "*/listings" -and $_.uri -notlike "*{*}" } | Select-Object -First 1
        $patchUpdate = $worldRoutes | Where-Object { ($_.method_primary -eq "PATCH" -or $_.method_primary -eq "PUT") -and $_.uri -like "*/listings/{*}" } | Select-Object -First 1
        $deleteDestroy = $worldRoutes | Where-Object { $_.method_primary -eq "DELETE" -and $_.uri -like "*/listings/{*}" } | Select-Object -First 1
        
        $discoveredRoutes[$world] = @{
            GetList = if ($getList) { $getList.uri } else { $null }
            GetShow = if ($getShow) { $getShow.uri } else { $null }
            PostCreate = if ($postCreate) { $postCreate.uri } else { $null }
            PatchUpdate = if ($patchUpdate) { $patchUpdate.uri } else { $null }
            DeleteDestroy = if ($deleteDestroy) { $deleteDestroy.uri } else { $null }
        }
    }
    
    Write-Pass "Route discovery complete for $($enabledWorlds.Count) worlds"
} else {
    Write-Warn "Routes snapshot not found. Using default route patterns."
    foreach ($world in $enabledWorlds) {
        $discoveredRoutes[$world] = @{
            GetList = "/api/v1/$world/listings"
            GetShow = "/api/v1/$world/listings/{id}"
            PostCreate = "/api/v1/$world/listings"
            PatchUpdate = "/api/v1/$world/listings/{id}"
            DeleteDestroy = "/api/v1/$world/listings/{id}"
        }
    }
}

# Step 3: Check credentials
Write-Info ""
Write-Info "Step 3: Checking credentials..."

$authToken = $null
if (-not [string]::IsNullOrEmpty($TestAuth)) {
    $authToken = $TestAuth
    Write-Pass "Bearer token provided"
} elseif (-not [string]::IsNullOrEmpty($TestEmail) -and -not [string]::IsNullOrEmpty($TestPassword)) {
    # Try login
    try {
        $loginBody = @{
            email = $TestEmail
            password = $TestPassword
        } | ConvertTo-Json -Compress
        
        $loginResponse = Invoke-ApiRequest -Method "POST" -Uri "/auth/login" -Body $loginBody -ExpectedStatusCode 200
        
        if ($loginResponse.Success) {
            $loginJson = $loginResponse.Body | ConvertFrom-Json
            if ($loginJson.token) {
                $authToken = $loginJson.token
                Write-Pass "Token acquired via login"
            } elseif ($loginJson.access_token) {
                $authToken = $loginJson.access_token
                Write-Pass "Access token acquired via login"
            }
        }
    } catch {
        Write-Warn "Login failed: $($_.Exception.Message)"
    }
}

if ([string]::IsNullOrEmpty($authToken)) {
    Write-Warn "No auth token available. Some tests will be skipped."
    Add-CheckResult -Check "Credentials" -Status "WARN" -Notes "No auth token (PRODUCT_TEST_AUTH or login)"
}

if ([string]::IsNullOrEmpty($TenantA) -and [string]::IsNullOrEmpty($TenantAId)) {
    Write-Warn "TENANT_A_SLUG or TENANT_A_ID not provided. Some tests will be skipped."
    Add-CheckResult -Check "Tenant A" -Status "WARN" -Notes "TENANT_A_SLUG or TENANT_A_ID missing"
}

$tenantAId = if ($TenantAId) { $TenantAId } else { $TenantA }
$tenantBId = $TenantB

# Step 4: A) Unauthorized check
Write-Info ""
Write-Info "Step 4A: Testing unauthorized access (no token)..."

foreach ($world in $enabledWorlds) {
    $listUri = $discoveredRoutes[$world].GetList
    if ($listUri) {
        $response = Invoke-ApiRequest -Method "GET" -Uri $listUri -ExpectedStatusCode 401
        
        if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403) {
            $hasJsonEnvelope = $false
            $hasRequestId = $false
            
            try {
                $json = $response.Body | ConvertFrom-Json
                if ($json.ok -eq $false -and $json.error_code) {
                    $hasJsonEnvelope = $true
                }
                if ($json.request_id -or $response.RequestId) {
                    $hasRequestId = $true
                }
            } catch {
                # Not JSON
            }
            
            if ($hasJsonEnvelope -and $hasRequestId) {
                Write-Pass "Unauthorized (${world}): $($response.StatusCode), JSON envelope + request_id"
                Add-CheckResult -Check "Unauthorized (${world})" -Status "PASS" -Notes "$($response.StatusCode), envelope + request_id"
            } else {
                Write-Warn "Unauthorized (${world}): $($response.StatusCode) but missing envelope/request_id"
                Add-CheckResult -Check "Unauthorized (${world})" -Status "WARN" -Notes "$($response.StatusCode) but invalid envelope"
            }
        } else {
            Write-Fail "Unauthorized (${world}): Expected 401/403, got $($response.StatusCode)"
            Add-CheckResult -Check "Unauthorized (${world})" -Status "FAIL" -Notes "Expected 401/403, got $($response.StatusCode)"
        }
    }
}

# Step 5: B) Tenant missing check
Write-Info ""
Write-Info "Step 5B: Testing tenant missing (no X-Tenant-Id)..."

if ($authToken) {
    foreach ($world in $enabledWorlds) {
        $listUri = $discoveredRoutes[$world].GetList
        if ($listUri) {
            $headers = @{
                "Authorization" = "Bearer $authToken"
            }
            
            $response = Invoke-ApiRequest -Method "GET" -Uri $listUri -Headers $headers -ExpectedStatusCode 403
            
            if ($response.StatusCode -eq 403 -or $response.StatusCode -eq 400) {
                $hasRequestId = $false
                try {
                    $json = $response.Body | ConvertFrom-Json
                    if ($json.request_id -or $response.RequestId) {
                        $hasRequestId = $true
                    }
                } catch {
                    if ($response.RequestId) {
                        $hasRequestId = $true
                    }
                }
                
                if ($hasRequestId) {
                    Write-Pass "Tenant missing (${world}): $($response.StatusCode), request_id present"
                    Add-CheckResult -Check "Tenant missing (${world})" -Status "PASS" -Notes "$($response.StatusCode), request_id"
                } else {
                    Write-Warn "Tenant missing (${world}): $($response.StatusCode) but no request_id"
                    Add-CheckResult -Check "Tenant missing (${world})" -Status "WARN" -Notes "$($response.StatusCode) but no request_id"
                }
            } else {
                Write-Warn "Tenant missing (${world}): Expected 403/400, got $($response.StatusCode) (may be OK if tenant optional)"
                Add-CheckResult -Check "Tenant missing (${world})" -Status "WARN" -Notes "Expected 403/400, got $($response.StatusCode)"
            }
        }
    }
} else {
    Write-Warn "Skipping tenant missing check (no auth token)"
    Add-CheckResult -Check "Tenant missing" -Status "WARN" -Notes "Skipped (no auth token)"
}

# Step 6: C) World invalid check (if applicable)
Write-Info ""
Write-Info "Step 6C: Testing world invalid (wrong world context)..."

if ($authToken -and $tenantAId) {
    # Try to access commerce endpoint with wrong world context
    $commerceListUri = $discoveredRoutes["commerce"].GetList
    if ($commerceListUri) {
        $headers = @{
            "Authorization" = "Bearer $authToken"
            "X-Tenant-Id" = $tenantAId
            "X-World" = "invalid_world"
        }
        
        $response = Invoke-ApiRequest -Method "GET" -Uri $commerceListUri -Headers $headers -ExpectedStatusCode 400
        
        if ($response.StatusCode -eq 400) {
            $hasWorldError = $false
            try {
                $json = $response.Body | ConvertFrom-Json
                if ($json.error_code -like "*WORLD*" -or $json.message -like "*world*") {
                    $hasWorldError = $true
                }
            } catch {
                # Not JSON or no error_code
            }
            
            if ($hasWorldError) {
                Write-Pass "World invalid: 400, WORLD_CONTEXT_INVALID error"
                Add-CheckResult -Check "World invalid" -Status "PASS" -Notes "400, WORLD_CONTEXT_INVALID"
            } else {
                Write-Warn "World invalid: 400 but no WORLD_CONTEXT_INVALID error code"
                Add-CheckResult -Check "World invalid" -Status "WARN" -Notes "400 but no WORLD error code"
            }
        } else {
            Write-Warn "World invalid: Expected 400, got $($response.StatusCode) (may be OK if world validation not implemented)"
            Add-CheckResult -Check "World invalid" -Status "WARN" -Notes "Expected 400, got $($response.StatusCode)"
        }
    }
} else {
    Write-Warn "Skipping world invalid check (no auth token or tenant)"
    Add-CheckResult -Check "World invalid" -Status "WARN" -Notes "Skipped (no auth/tenant)"
}

# Step 7: D) Happy path smoke
Write-Info ""
Write-Info "Step 7D: Testing happy path (authenticated CRUD)..."

if ($authToken -and $tenantAId) {
    foreach ($world in $enabledWorlds) {
        $headers = @{
            "Authorization" = "Bearer $authToken"
            "X-Tenant-Id" = $tenantAId
        }
        
        $createdId = $null
        
        # D.1: GET list
        $listUri = $discoveredRoutes[$world].GetList
        if ($listUri) {
            $response = Invoke-ApiRequest -Method "GET" -Uri $listUri -Headers $headers -ExpectedStatusCode 200
            
            if ($response.Success) {
                try {
                    $json = $response.Body | ConvertFrom-Json
                    if ($json.ok -eq $true) {
                        Write-Pass "Happy path (${world}): GET list 200 ok:true"
                        Add-CheckResult -Check "Happy path (${world}): GET list" -Status "PASS" -Notes "200 ok:true"
                    } else {
                        Write-Fail "Happy path (${world}): GET list 200 but ok:false"
                        Add-CheckResult -Check "Happy path (${world}): GET list" -Status "FAIL" -Notes "200 but ok:false"
                    }
                } catch {
                    Write-Fail "Happy path (${world}): GET list 200 but invalid JSON"
                    Add-CheckResult -Check "Happy path (${world}): GET list" -Status "FAIL" -Notes "200 but invalid JSON"
                }
            } else {
                Write-Fail "Happy path (${world}): GET list Expected 200, got $($response.StatusCode)"
                Add-CheckResult -Check "Happy path (${world}): GET list" -Status "FAIL" -Notes "Expected 200, got $($response.StatusCode)"
            }
        }
        
        # D.2: POST create (if route exists)
        $createUri = $discoveredRoutes[$world].PostCreate
        if ($createUri) {
            $createBody = @{
                title = "E2E Contract Test $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
                status = "draft"
            } | ConvertTo-Json -Compress
            
            $response = Invoke-ApiRequest -Method "POST" -Uri $createUri -Headers $headers -Body $createBody -ExpectedStatusCode 201
            
            if ($response.Success -or $response.StatusCode -eq 200) {
                try {
                    $json = $response.Body | ConvertFrom-Json
                    if ($json.ok -eq $true -and $json.item -and $json.item.id) {
                        $createdId = $json.item.id
                        Write-Pass "Happy path (${world}): POST create $($response.StatusCode) ok:true, id: ${createdId}"
                        Add-CheckResult -Check "Happy path (${world}): POST create" -Status "PASS" -Notes "$($response.StatusCode) ok:true"
                    } else {
                        Write-Fail "Happy path (${world}): POST create $($response.StatusCode) but invalid response"
                        Add-CheckResult -Check "Happy path (${world}): POST create" -Status "FAIL" -Notes "$($response.StatusCode) but invalid response"
                    }
                } catch {
                    Write-Fail "Happy path (${world}): POST create $($response.StatusCode) but invalid JSON"
                    Add-CheckResult -Check "Happy path (${world}): POST create" -Status "FAIL" -Notes "$($response.StatusCode) but invalid JSON"
                }
            } else {
                Write-Warn "Happy path (${world}): POST create Expected 201/200, got $($response.StatusCode) (may be 501 if not implemented)"
                Add-CheckResult -Check "Happy path (${world}): POST create" -Status "WARN" -Notes "Expected 201/200, got $($response.StatusCode)"
            }
        } else {
            Write-Warn "Happy path (${world}): POST create route not found (may be OK if write not implemented)"
            Add-CheckResult -Check "Happy path (${world}): POST create" -Status "WARN" -Notes "Route not found"
        }
        
        # D.3: PATCH update (if route exists and create succeeded)
        if ($createdId) {
            $updateUri = $discoveredRoutes[$world].PatchUpdate
            if ($updateUri) {
                $updateUri = $updateUri -replace "{id}", $createdId
                $updateBody = @{
                    title = "Updated E2E Title $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
                } | ConvertTo-Json -Compress
                
                $response = Invoke-ApiRequest -Method "PATCH" -Uri $updateUri -Headers $headers -Body $updateBody -ExpectedStatusCode 200
                
                if ($response.Success) {
                    try {
                        $json = $response.Body | ConvertFrom-Json
                        if ($json.ok -eq $true) {
                            Write-Pass "Happy path (${world}): PATCH update 200 ok:true"
                            Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "PASS" -Notes "200 ok:true"
                        } else {
                            Write-Fail "Happy path (${world}): PATCH update 200 but ok:false"
                            Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "FAIL" -Notes "200 but ok:false"
                        }
                    } catch {
                        Write-Fail "Happy path (${world}): PATCH update 200 but invalid JSON"
                        Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "FAIL" -Notes "200 but invalid JSON"
                    }
                } else {
                    Write-Warn "Happy path (${world}): PATCH update Expected 200, got $($response.StatusCode)"
                    Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "WARN" -Notes "Expected 200, got $($response.StatusCode)"
                }
            }
            
            # D.4: DELETE (if route exists)
            $deleteUri = $discoveredRoutes[$world].DeleteDestroy
            if ($deleteUri) {
                $deleteUri = $deleteUri -replace "{id}", $createdId
                
                $response = Invoke-ApiRequest -Method "DELETE" -Uri $deleteUri -Headers $headers -ExpectedStatusCode 204
                
                if ($response.Success -or $response.StatusCode -eq 200) {
                    Write-Pass "Happy path (${world}): DELETE $($response.StatusCode) OK"
                    Add-CheckResult -Check "Happy path (${world}): DELETE" -Status "PASS" -Notes "$($response.StatusCode) OK"
                } else {
                    Write-Warn "Happy path (${world}): DELETE Expected 204/200, got $($response.StatusCode)"
                    Add-CheckResult -Check "Happy path (${world}): DELETE" -Status "WARN" -Notes "Expected 204/200, got $($response.StatusCode)"
                }
            }
        }
    }
} else {
    Write-Warn "Skipping happy path tests (no auth token or tenant)"
    Add-CheckResult -Check "Happy path" -Status "WARN" -Notes "Skipped (no auth/tenant)"
}

# Step 8: E) Cross-tenant leakage
Write-Info ""
Write-Info "Step 8E: Testing cross-tenant leakage..."

if ($authToken -and $tenantAId -and $tenantBId) {
    # Create item with Tenant A
    $world = $enabledWorlds[0] # Use first enabled world
    $createUri = $discoveredRoutes[$world].PostCreate
    if ($createUri) {
        $headersA = @{
            "Authorization" = "Bearer $authToken"
            "X-Tenant-Id" = $tenantAId
        }
        
        $createBody = @{
            title = "Cross-tenant test $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
            status = "draft"
        } | ConvertTo-Json -Compress
        
        $createResponse = Invoke-ApiRequest -Method "POST" -Uri $createUri -Headers $headersA -Body $createBody -ExpectedStatusCode 201
        
        if ($createResponse.Success -or $createResponse.StatusCode -eq 200) {
            try {
                $createJson = $createResponse.Body | ConvertFrom-Json
                $createdId = $createJson.item.id
                
                # Try to access with Tenant B
                $showUri = $discoveredRoutes[$world].GetShow
                if ($showUri) {
                    $showUri = $showUri -replace "{id}", $createdId
                    $headersB = @{
                        "Authorization" = "Bearer $authToken"
                        "X-Tenant-Id" = $tenantBId
                    }
                    
                    $showResponse = Invoke-ApiRequest -Method "GET" -Uri $showUri -Headers $headersB -ExpectedStatusCode 404
                    
                    if ($showResponse.StatusCode -eq 404) {
                        try {
                            $errorJson = $showResponse.Body | ConvertFrom-Json
                            if ($errorJson.ok -eq $false -and $errorJson.error_code) {
                                Write-Pass "Cross-tenant leakage: 404 NOT_FOUND, error envelope correct"
                                Add-CheckResult -Check "Cross-tenant leakage" -Status "PASS" -Notes "404, error envelope"
                            } else {
                                Write-Warn "Cross-tenant leakage: 404 but invalid error envelope"
                                Add-CheckResult -Check "Cross-tenant leakage" -Status "WARN" -Notes "404 but invalid envelope"
                            }
                        } catch {
                            Write-Warn "Cross-tenant leakage: 404 but no JSON envelope"
                            Add-CheckResult -Check "Cross-tenant leakage" -Status "WARN" -Notes "404 but no JSON"
                        }
                    } else {
                        Write-Fail "Cross-tenant leakage: Expected 404, got $($showResponse.StatusCode) - SECURITY ISSUE"
                        Add-CheckResult -Check "Cross-tenant leakage" -Status "FAIL" -Notes "Expected 404, got $($showResponse.StatusCode) - LEAKAGE"
                    }
                } else {
                    Write-Warn "Cross-tenant leakage: Show route not found"
                    Add-CheckResult -Check "Cross-tenant leakage" -Status "WARN" -Notes "Show route not found"
                }
            } catch {
                Write-Warn "Cross-tenant leakage: Failed to create test item"
                Add-CheckResult -Check "Cross-tenant leakage" -Status "WARN" -Notes "Failed to create test item"
            }
        } else {
            Write-Warn "Cross-tenant leakage: Failed to create test item (status: $($createResponse.StatusCode))"
            Add-CheckResult -Check "Cross-tenant leakage" -Status "WARN" -Notes "Failed to create (status: $($createResponse.StatusCode))"
        }
    } else {
        Write-Warn "Cross-tenant leakage: Create route not found"
        Add-CheckResult -Check "Cross-tenant leakage" -Status "WARN" -Notes "Create route not found"
    }
} else {
    Write-Warn "Skipping cross-tenant leakage test (no auth token or TENANT_B_SLUG)"
    Add-CheckResult -Check "Cross-tenant leakage" -Status "WARN" -Notes "Skipped (no auth/TENANT_B_SLUG)"
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
Write-Host "Check                                      Status Notes" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

foreach ($result in $checkResults) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[?]" }
    }
    Write-Host "$statusMarker $($result.Check.PadRight(40)) $($result.Notes)" -ForegroundColor $(if ($result.Status -eq "PASS") { "Green" } elseif ($result.Status -eq "WARN") { "Yellow" } else { "Red" })
}

if (-not $overallPass) {
    Write-Info ""
    Write-Fail "Product API E2E Contract FAILED (${failCount} failure(s))"
    Invoke-OpsExit 1
    return
}

if ($hasWarn) {
    Write-Info ""
    Write-Warn "Product API E2E Contract passed with warnings (${warnCount} warning(s))"
    Invoke-OpsExit 2
    return
}

Write-Info ""
Write-Pass "Product API E2E Contract PASSED"
Invoke-OpsExit 0


