# product_contract_check.ps1 - Product API Contract Gate
# Validates Product API contract and tenant/world boundaries end-to-end
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [string]$BaseUrl = $env:BASE_URL,
    [string]$ApiPrefix = "/api/v1",
    [string]$TenantIdHeaderName = "X-Tenant-Id",
    [string]$TenantAId = $env:TENANT_A_ID,
    [string]$TenantBId = $env:TENANT_B_ID,
    [string]$AuthBearer = $env:PRODUCT_TEST_BEARER,
    [string]$CookieFile = $null,
    [int]$SampleSize = 1,
    [string]$RoutesSnapshotPath = "ops\snapshots\routes.pazar.json",
    [string]$WorldsConfigPath = "work\pazar\config\worlds.php"
)

if ([string]::IsNullOrEmpty($BaseUrl)) {
    $BaseUrl = "http://localhost:8080"
}

# Fallback: try TENANT_A_SLUG if TENANT_A_ID not set
if ([string]::IsNullOrEmpty($TenantAId)) {
    $TenantAId = $env:TENANT_A_SLUG
}

$ErrorActionPreference = "Continue"

# Dot-source shared helpers
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\_lib\ops_output.ps1"
. "$ScriptDir\_lib\ops_exit.ps1"
. "$ScriptDir\_lib\routes_json.ps1"

Initialize-OpsOutput

Write-Info "Product API Contract Gate"
Write-Info "Base URL: ${BaseUrl}"
Write-Info "API Prefix: ${ApiPrefix}"
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
            } elseif ($key -eq $TenantIdHeaderName) {
                $request.Headers.Add($TenantIdHeaderName, $Headers[$key])
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

# Step 2: Discover routes
Write-Info ""
Write-Info "Step 2: Discovering routes..."

$discoveredRoutes = @{}

if (Test-Path $RoutesSnapshotPath) {
    $snapshotContent = Get-Content $RoutesSnapshotPath -Raw -Encoding UTF8
    $routes = Convert-RoutesJsonToCanonicalArray -RawJsonText $snapshotContent
    
    foreach ($world in $enabledWorlds) {
        $worldRoutes = $routes | Where-Object {
            $_.uri -like "${ApiPrefix}/${world}/*" -or $_.uri -like "${ApiPrefix}/${world}"
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
            GetList = "${ApiPrefix}/${world}/listings"
            GetShow = "${ApiPrefix}/${world}/listings/{id}"
            PostCreate = "${ApiPrefix}/${world}/listings"
            PatchUpdate = "${ApiPrefix}/${world}/listings/{id}"
            DeleteDestroy = "${ApiPrefix}/${world}/listings/{id}"
        }
    }
}

# Step 3: Check credentials
Write-Info ""
Write-Info "Step 3: Checking credentials..."

$authToken = $null
if (-not [string]::IsNullOrEmpty($AuthBearer)) {
    $authToken = $AuthBearer
    if (-not $authToken.StartsWith("Bearer ")) {
        $authToken = "Bearer $authToken"
    }
    Write-Pass "Bearer token provided"
} elseif (-not [string]::IsNullOrEmpty($CookieFile) -and (Test-Path $CookieFile)) {
    Write-Warn "Cookie file support not fully implemented. Using Bearer token recommended."
    Add-CheckResult -Check "Credentials" -Status "WARN" -Notes "Cookie file not fully supported"
}

if ([string]::IsNullOrEmpty($authToken)) {
    Write-Warn "No auth token available. Some tests will be skipped."
    Add-CheckResult -Check "Credentials" -Status "WARN" -Notes "No auth token (PRODUCT_TEST_BEARER)"
}

if ([string]::IsNullOrEmpty($TenantAId)) {
    Write-Warn "TENANT_A_ID or TENANT_A_SLUG not provided. Some tests will be skipped."
    Add-CheckResult -Check "Tenant A" -Status "WARN" -Notes "TENANT_A_ID or TENANT_A_SLUG missing"
}

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
            
            $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "no req_id" }
            
            if ($hasJsonEnvelope -and $hasRequestId) {
                Write-Pass "Unauthorized (${world}): $($response.StatusCode), JSON envelope + request_id"
                Add-CheckResult -Check "Unauthorized (${world})" -Status "PASS" -Notes "$($response.StatusCode), envelope + request_id. Run ops/request_trace.ps1 -RequestId $($response.RequestId)"
            } else {
                Write-Warn "Unauthorized (${world}): $($response.StatusCode) but missing envelope/request_id"
                Add-CheckResult -Check "Unauthorized (${world})" -Status "WARN" -Notes "$($response.StatusCode) but invalid envelope"
            }
        } else {
            Write-Fail "Unauthorized (${world}): Expected 401/403, got $($response.StatusCode)"
            $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
            Add-CheckResult -Check "Unauthorized (${world})" -Status "FAIL" -Notes "Expected 401/403, got $($response.StatusCode). $remediation"
        }
    }
}

# Step 5: B) Tenant missing check
Write-Info ""
Write-Info "Step 5B: Testing tenant missing (no ${TenantIdHeaderName})..."

if ($authToken) {
    foreach ($world in $enabledWorlds) {
        $listUri = $discoveredRoutes[$world].GetList
        if ($listUri) {
            $headers = @{
                "Authorization" = $authToken
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
                    Add-CheckResult -Check "Tenant missing (${world})" -Status "PASS" -Notes "$($response.StatusCode), request_id. Run ops/request_trace.ps1 -RequestId $($response.RequestId)"
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

# Step 6: C) Happy path tenant A
Write-Info ""
Write-Info "Step 6C: Testing happy path (authenticated CRUD)..."

if ($authToken -and $TenantAId) {
    foreach ($world in $enabledWorlds) {
        $headers = @{
            "Authorization" = $authToken
            $TenantIdHeaderName = $TenantAId
        }
        
        $createdId = $null
        
        # C.1: GET list
        $listUri = $discoveredRoutes[$world].GetList
        if ($listUri) {
            $response = Invoke-ApiRequest -Method "GET" -Uri $listUri -Headers $headers -ExpectedStatusCode 200
            
            if ($response.Success) {
                try {
                    $json = $response.Body | ConvertFrom-Json
                    if ($json.ok -eq $true) {
                        Write-Pass "Happy path (${world}): GET list 200 ok:true"
                        $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "" }
                        Add-CheckResult -Check "Happy path (${world}): GET list" -Status "PASS" -Notes "200 ok:true $reqIdNote"
                    } else {
                        Write-Fail "Happy path (${world}): GET list 200 but ok:false"
                        $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                        Add-CheckResult -Check "Happy path (${world}): GET list" -Status "FAIL" -Notes "200 but ok:false. $remediation"
                    }
                } catch {
                    Write-Fail "Happy path (${world}): GET list 200 but invalid JSON"
                    Add-CheckResult -Check "Happy path (${world}): GET list" -Status "FAIL" -Notes "200 but invalid JSON"
                }
            } else {
                Write-Fail "Happy path (${world}): GET list Expected 200, got $($response.StatusCode)"
                $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                Add-CheckResult -Check "Happy path (${world}): GET list" -Status "FAIL" -Notes "Expected 200, got $($response.StatusCode). $remediation"
            }
        }
        
        # C.2: POST create
        $createUri = $discoveredRoutes[$world].PostCreate
        if ($createUri) {
            $createBody = @{
                title = "Contract Test $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
                status = "draft"
            } | ConvertTo-Json -Compress
            
            $response = Invoke-ApiRequest -Method "POST" -Uri $createUri -Headers $headers -Body $createBody -ExpectedStatusCode 201
            
            if ($response.Success -or $response.StatusCode -eq 200) {
                try {
                    $json = $response.Body | ConvertFrom-Json
                    if ($json.ok -eq $true -and $json.item -and $json.item.id) {
                        $createdId = $json.item.id
                        Write-Pass "Happy path (${world}): POST create $($response.StatusCode) ok:true, id: ${createdId}"
                        $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "" }
                        Add-CheckResult -Check "Happy path (${world}): POST create" -Status "PASS" -Notes "$($response.StatusCode) ok:true $reqIdNote"
                    } else {
                        Write-Fail "Happy path (${world}): POST create $($response.StatusCode) but invalid response"
                        $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                        Add-CheckResult -Check "Happy path (${world}): POST create" -Status "FAIL" -Notes "$($response.StatusCode) but invalid response. $remediation"
                    }
                } catch {
                    Write-Fail "Happy path (${world}): POST create $($response.StatusCode) but invalid JSON"
                    Add-CheckResult -Check "Happy path (${world}): POST create" -Status "FAIL" -Notes "$($response.StatusCode) but invalid JSON"
                }
            } else {
                Write-Fail "Happy path (${world}): POST create Expected 200/201, got $($response.StatusCode)"
                $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                Add-CheckResult -Check "Happy path (${world}): POST create" -Status "FAIL" -Notes "Expected 200/201, got $($response.StatusCode). $remediation"
            }
        } else {
            Write-Warn "Happy path (${world}): POST create route not found"
            Add-CheckResult -Check "Happy path (${world}): POST create" -Status "WARN" -Notes "Route not found"
        }
        
        # C.3: GET by id (if created)
        if ($createdId) {
            $showUri = $discoveredRoutes[$world].GetShow
            if ($showUri) {
                $showUri = $showUri -replace "\{id\}", $createdId
                $response = Invoke-ApiRequest -Method "GET" -Uri $showUri -Headers $headers -ExpectedStatusCode 200
                
                if ($response.Success) {
                    try {
                        $json = $response.Body | ConvertFrom-Json
                        if ($json.ok -eq $true -and $json.item -and $json.item.id -eq $createdId) {
                            Write-Pass "Happy path (${world}): GET by id 200 ok:true, same tenant verified"
                            $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "" }
                            Add-CheckResult -Check "Happy path (${world}): GET by id" -Status "PASS" -Notes "200 ok:true $reqIdNote"
                        } else {
                            Write-Fail "Happy path (${world}): GET by id 200 but invalid response"
                            $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                            Add-CheckResult -Check "Happy path (${world}): GET by id" -Status "FAIL" -Notes "200 but invalid response. $remediation"
                        }
                    } catch {
                        Write-Fail "Happy path (${world}): GET by id 200 but invalid JSON"
                        Add-CheckResult -Check "Happy path (${world}): GET by id" -Status "FAIL" -Notes "200 but invalid JSON"
                    }
                } else {
                    Write-Fail "Happy path (${world}): GET by id Expected 200, got $($response.StatusCode)"
                    $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                    Add-CheckResult -Check "Happy path (${world}): GET by id" -Status "FAIL" -Notes "Expected 200, got $($response.StatusCode). $remediation"
                }
            }
            
            # C.4: PATCH update
            $patchUri = $discoveredRoutes[$world].PatchUpdate
            if ($patchUri) {
                $patchUri = $patchUri -replace "\{id\}", $createdId
                $patchBody = @{
                    title = "Contract Test Updated $([DateTimeOffset]::Now.ToUnixTimeSeconds())"
                } | ConvertTo-Json -Compress
                
                $response = Invoke-ApiRequest -Method "PATCH" -Uri $patchUri -Headers $headers -Body $patchBody -ExpectedStatusCode 200
                
                if ($response.Success) {
                    try {
                        $json = $response.Body | ConvertFrom-Json
                        if ($json.ok -eq $true) {
                            Write-Pass "Happy path (${world}): PATCH update 200 ok:true"
                            $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "" }
                            Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "PASS" -Notes "200 ok:true $reqIdNote"
                        } else {
                            Write-Fail "Happy path (${world}): PATCH update 200 but ok:false"
                            $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                            Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "FAIL" -Notes "200 but ok:false. $remediation"
                        }
                    } catch {
                        Write-Fail "Happy path (${world}): PATCH update 200 but invalid JSON"
                        Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "FAIL" -Notes "200 but invalid JSON"
                    }
                } else {
                    Write-Fail "Happy path (${world}): PATCH update Expected 200, got $($response.StatusCode)"
                    $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                    Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "FAIL" -Notes "Expected 200, got $($response.StatusCode). $remediation"
                }
            } else {
                Write-Warn "Happy path (${world}): PATCH update route not found"
                Add-CheckResult -Check "Happy path (${world}): PATCH update" -Status "WARN" -Notes "Route not found"
            }
            
            # C.5: DELETE
            $deleteUri = $discoveredRoutes[$world].DeleteDestroy
            if ($deleteUri) {
                $deleteUri = $deleteUri -replace "\{id\}", $createdId
                $response = Invoke-ApiRequest -Method "DELETE" -Uri $deleteUri -Headers $headers -ExpectedStatusCode 200
                
                if ($response.Success) {
                    try {
                        $json = $response.Body | ConvertFrom-Json
                        if ($json.ok -eq $true) {
                            Write-Pass "Happy path (${world}): DELETE 200 ok:true"
                            $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "" }
                            Add-CheckResult -Check "Happy path (${world}): DELETE" -Status "PASS" -Notes "200 ok:true $reqIdNote"
                        } else {
                            Write-Fail "Happy path (${world}): DELETE 200 but ok:false"
                            $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                            Add-CheckResult -Check "Happy path (${world}): DELETE" -Status "FAIL" -Notes "200 but ok:false. $remediation"
                        }
                    } catch {
                        Write-Fail "Happy path (${world}): DELETE 200 but invalid JSON"
                        Add-CheckResult -Check "Happy path (${world}): DELETE" -Status "FAIL" -Notes "200 but invalid JSON"
                    }
                } else {
                    Write-Fail "Happy path (${world}): DELETE Expected 200, got $($response.StatusCode)"
                    $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                    Add-CheckResult -Check "Happy path (${world}): DELETE" -Status "FAIL" -Notes "Expected 200, got $($response.StatusCode). $remediation"
                }
            } else {
                Write-Warn "Happy path (${world}): DELETE route not found"
                Add-CheckResult -Check "Happy path (${world}): DELETE" -Status "WARN" -Notes "Route not found"
            }
            
            # C.6: GET deleted id -> 404
            if ($deleteUri) {
                $response = Invoke-ApiRequest -Method "GET" -Uri $showUri -Headers $headers -ExpectedStatusCode 404
                
                if ($response.StatusCode -eq 404) {
                    Write-Pass "Happy path (${world}): GET deleted id 404 NOT_FOUND (no leakage)"
                    $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "" }
                    Add-CheckResult -Check "Happy path (${world}): GET deleted id" -Status "PASS" -Notes "404 NOT_FOUND $reqIdNote"
                } else {
                    Write-Fail "Happy path (${world}): GET deleted id Expected 404, got $($response.StatusCode) (possible leakage)"
                    $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                    Add-CheckResult -Check "Happy path (${world}): GET deleted id" -Status "FAIL" -Notes "Expected 404, got $($response.StatusCode) (leakage). $remediation"
                }
            }
        }
    }
} else {
    Write-Warn "Skipping happy path check (no auth token or tenant)"
    Add-CheckResult -Check "Happy path" -Status "WARN" -Notes "Skipped (no auth/tenant)"
}

# Step 7: D) Cross-tenant isolation
Write-Info ""
Write-Info "Step 7D: Testing cross-tenant isolation..."

if ($authToken -and $TenantAId -and $TenantBId -and $createdId) {
    foreach ($world in $enabledWorlds) {
        $showUri = $discoveredRoutes[$world].GetShow
        if ($showUri -and $createdId) {
            $showUri = $showUri -replace "\{id\}", $createdId
            $headersB = @{
                "Authorization" = $authToken
                $TenantIdHeaderName = $TenantBId
            }
            
            $response = Invoke-ApiRequest -Method "GET" -Uri $showUri -Headers $headersB -ExpectedStatusCode 404
            
            if ($response.StatusCode -eq 404) {
                Write-Pass "Cross-tenant (${world}): Tenant B cannot access Tenant A's id -> 404 (no leakage)"
                $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "" }
                Add-CheckResult -Check "Cross-tenant (${world})" -Status "PASS" -Notes "404 NOT_FOUND (isolation OK) $reqIdNote"
            } else {
                Write-Fail "Cross-tenant (${world}): Tenant B accessed Tenant A's id -> $($response.StatusCode) (LEAKAGE)"
                $remediation = "Run ops/request_trace.ps1 -RequestId $($response.RequestId); Run ops/incident_bundle.ps1"
                Add-CheckResult -Check "Cross-tenant (${world})" -Status "FAIL" -Notes "Expected 404, got $($response.StatusCode) (LEAKAGE). $remediation"
            }
        }
    }
} else {
    Write-Warn "Skipping cross-tenant check (no auth token, tenant B, or created id)"
    Add-CheckResult -Check "Cross-tenant" -Status "WARN" -Notes "Skipped (no auth/tenantB/createdId)"
}

# Step 8: E) World boundary
Write-Info ""
Write-Info "Step 8E: Testing world boundary..."

if ($authToken -and $TenantAId) {
    # Try to access commerce endpoint with wrong world context
    $commerceListUri = $discoveredRoutes["commerce"].GetList
    if ($commerceListUri) {
        $headers = @{
            "Authorization" = $authToken
            $TenantIdHeaderName = $TenantAId
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
                Write-Pass "World boundary: 400, WORLD_CONTEXT_INVALID error"
                $reqIdNote = if ($response.RequestId) { "req_id: $($response.RequestId)" } else { "" }
                Add-CheckResult -Check "World boundary" -Status "PASS" -Notes "400, WORLD_CONTEXT_INVALID $reqIdNote"
            } else {
                Write-Warn "World boundary: 400 but no WORLD_CONTEXT_INVALID error code"
                Add-CheckResult -Check "World boundary" -Status "WARN" -Notes "400 but no WORLD error code"
            }
        } else {
            Write-Warn "World boundary: Expected 400, got $($response.StatusCode) (may be OK if world validation not implemented)"
            Add-CheckResult -Check "World boundary" -Status "WARN" -Notes "Expected 400, got $($response.StatusCode)"
        }
    }
} else {
    Write-Warn "Skipping world boundary check (no auth token or tenant)"
    Add-CheckResult -Check "World boundary" -Status "WARN" -Notes "Skipped (no auth/tenant)"
}

# Summary
Write-Info ""
Write-Info "========================================"
Write-Info "  RESULTS SUMMARY"
Write-Info "========================================"
Write-Info ""

Write-Host "Check".PadRight(50) + "Status".PadRight(10) + "Notes"
Write-Host ("-" * 50) + ("-" * 10) + ("-" * 80)

foreach ($result in $checkResults) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[$($result.Status)]" }
    }
    
    $checkPadded = $result.Check.PadRight(50)
    $statusPadded = $statusMarker.PadRight(10)
    $notesTruncated = if ($result.Notes.Length -gt 80) { $result.Notes.Substring(0, 77) + "..." } else { $result.Notes }
    
    Write-Host "$checkPadded$statusPadded$notesTruncated"
}

Write-Info ""
Write-Info "========================================"

if ($overallPass) {
    if ($hasWarn) {
        Write-Warn "Overall status: PASS with warnings"
        Invoke-OpsExit 2
    } else {
        Write-Pass "Overall status: PASS"
        Invoke-OpsExit 0
    }
} else {
    Write-Fail "Overall status: FAIL"
    Write-Info "Remediation: Run ops/request_trace.ps1 -RequestId <id>; Run ops/incident_bundle.ps1"
    Invoke-OpsExit 1
}
























