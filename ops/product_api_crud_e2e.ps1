# product_api_crud_e2e.ps1 - Product API CRUD E2E Gate
# Validates listing CRUD operations for enabled worlds (commerce/food/rentals)
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [string]$BaseUrl = $env:BASE_URL,
    [string]$AuthToken = $env:PRODUCT_TEST_AUTH,
    [string]$TenantA = $env:TENANT_A_SLUG,
    [string]$TenantAId = $env:TENANT_A_ID,
    [string]$TenantB = $env:TENANT_B_SLUG,
    [string]$TenantBId = $env:TENANT_B_ID,
    [switch]$Verbose
)

if ([string]::IsNullOrEmpty($BaseUrl)) {
    $BaseUrl = "http://localhost:8080"
}

$ErrorActionPreference = "Continue"

# Dot-source shared helpers
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\_lib\ops_output.ps1"
. "$ScriptDir\_lib\ops_exit.ps1"
. "$ScriptDir\_lib\worlds_config.ps1"

Initialize-OpsOutput

Write-Info "=== PRODUCT API CRUD E2E GATE ==="
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
        [int]$ExitCode,
        [string]$Notes = ""
    )
    $script:checkResults += [PSCustomObject]@{
        Check = $Check
        Status = $Status
        ExitCode = $ExitCode
        Notes = $Notes
    }
    if ($Status -eq "FAIL") {
        $script:overallPass = $false
    } elseif ($Status -eq "WARN") {
        $script:hasWarn = $true
    }
}

# Helper: Invoke HTTP request and return structured result
function Invoke-HttpJson {
    param(
        [string]$Method,
        [string]$Url,
        [hashtable]$Headers = @{},
        [string]$BodyJson = $null
    )
    
    $result = @{
        StatusCode = 0
        Headers = @{}
        BodyText = ""
        Json = $null
        RequestIdFromHeader = $null
        RequestIdFromBody = $null
        Error = $null
    }
    
    try {
        # Build curl command
        $curlArgs = @("-sS", "-i", "-X", $Method)
        
        # Add headers
        foreach ($key in $Headers.Keys) {
            $curlArgs += "-H"
            $curlArgs += "${key}: $($Headers[$key])"
        }
        
        # Add body if provided
        if ($BodyJson) {
            $curlArgs += "-H"
            $curlArgs += "Content-Type: application/json"
            $curlArgs += "-d"
            $curlArgs += $BodyJson
        }
        
        $curlArgs += $Url
        
        # Execute curl
        $response = & curl.exe $curlArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            $result.Error = "curl failed with exit code ${LASTEXITCODE}: $response"
            return $result
        }
        
        # Parse response
        $responseText = $response -join "`n"
        $parts = $responseText -split "`r?`n`r?`n", 2
        $headerBlock = $parts[0]
        $bodyBlock = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        
        # Parse status code
        if ($headerBlock -match "HTTP/\d\.\d\s+(\d+)") {
            $result.StatusCode = [int]$matches[1]
        }
        
        # Parse headers
        $headerLines = $headerBlock -split "`r?`n"
        foreach ($line in $headerLines) {
            if ($line -match "^([^:]+):\s*(.+)$") {
                $headerName = $matches[1].Trim()
                $headerValue = $matches[2].Trim()
                $result.Headers[$headerName] = $headerValue
                
                if ($headerName -eq "X-Request-Id") {
                    $result.RequestIdFromHeader = $headerValue
                }
            }
        }
        
        # Parse body
        $result.BodyText = $bodyBlock
        
        # Try to parse JSON
        if ($bodyBlock -and $bodyBlock.Trim().StartsWith("{")) {
            try {
                $result.Json = $bodyBlock | ConvertFrom-Json
                
                # Extract request_id from body
                if ($result.Json.request_id) {
                    $result.RequestIdFromBody = $result.Json.request_id
                } elseif ($result.Json.requestId) {
                    $result.RequestIdFromBody = $result.Json.requestId
                }
            } catch {
                # Not JSON or parse failed, ignore
            }
        }
        
    } catch {
        $result.Error = "Exception: $($_.Exception.Message)"
    }
    
    return $result
}

# Helper: Validate error envelope
function Validate-ErrorEnvelope {
    param([object]$Json)
    
    if (-not $Json) {
        return $false
    }
    
    # Check ok:false
    if ($Json.ok -ne $false) {
        return $false
    }
    
    # Check error_code present
    if ([string]::IsNullOrEmpty($Json.error_code)) {
        return $false
    }
    
    # Check request_id non-empty
    if ([string]::IsNullOrEmpty($Json.request_id)) {
        return $false
    }
    
    return $true
}

# Helper: Validate ok envelope
function Validate-OkEnvelope {
    param(
        [object]$Json,
        [string]$RequestIdFromHeader = $null
    )
    
    if (-not $Json) {
        return $false
    }
    
    # Check ok:true
    if ($Json.ok -ne $true) {
        return $false
    }
    
    # Check request_id present
    if ([string]::IsNullOrEmpty($Json.request_id)) {
        return $false
    }
    
    return $true
}

# Step 1: Get enabled worlds
Write-Info "Step 1: Getting enabled worlds..."
$worldsConfig = Get-WorldsConfig
$enabledWorlds = $worldsConfig.Enabled

if ($enabledWorlds.Count -eq 0) {
    Write-Warn "No enabled worlds found. Using defaults: commerce, food, rentals"
    $enabledWorlds = @("commerce", "food", "rentals")
}

Write-Pass "Enabled worlds: $($enabledWorlds -join ', ')"

# Step 2: Check credentials
Write-Info ""
Write-Info "Step 2: Checking credentials..."

$hasAuth = $false
$hasTenantA = $false
$hasTenantB = $false
$tenantAId = $null
$tenantBId = $null

if (-not [string]::IsNullOrEmpty($AuthToken)) {
    $hasAuth = $true
    Write-Pass "Auth token provided"
} else {
    Write-Warn "No auth token (PRODUCT_TEST_AUTH) - auth-required tests will be skipped"
    Add-CheckResult -Check "Credentials" -Status "WARN" -ExitCode 2 -Notes "No auth token"
}

# Resolve tenant IDs
if (-not [string]::IsNullOrEmpty($TenantAId)) {
    $tenantAId = $TenantAId
    $hasTenantA = $true
} elseif (-not [string]::IsNullOrEmpty($TenantA)) {
    # Assume slug is the ID for now (or could resolve via API)
    $tenantAId = $TenantA
    $hasTenantA = $true
}

if (-not [string]::IsNullOrEmpty($TenantBId)) {
    $tenantBId = $TenantBId
    $hasTenantB = $true
} elseif (-not [string]::IsNullOrEmpty($TenantB)) {
    $tenantBId = $TenantB
    $hasTenantB = $true
}

if (-not $hasTenantA) {
    Write-Warn "TENANT_A_SLUG or TENANT_A_ID not provided - tenant-scoped tests will be skipped"
    Add-CheckResult -Check "Tenant A" -Status "WARN" -ExitCode 2 -Notes "TENANT_A_SLUG or TENANT_A_ID missing"
}

# Test A: Unauthorized access (no token)
Write-Info ""
Write-Info "Test A: Unauthorized access (no token)..."
foreach ($world in $enabledWorlds) {
    $listingsNoAuth = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${world}/listings"
    
    if ($listingsNoAuth.Error) {
        Write-Fail "${world} unauthorized: Request failed: $($listingsNoAuth.Error)"
        Add-CheckResult -Check "${world} Unauthorized" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
    } elseif ($listingsNoAuth.StatusCode -eq 401 -or $listingsNoAuth.StatusCode -eq 403) {
        if (Validate-ErrorEnvelope -Json $listingsNoAuth.Json) {
            Write-Pass "${world} unauthorized: $($listingsNoAuth.StatusCode) with error envelope"
            Add-CheckResult -Check "${world} Unauthorized" -Status "PASS" -ExitCode 0 -Notes "$($listingsNoAuth.StatusCode) with error envelope"
        } else {
            Write-Fail "${world} unauthorized: $($listingsNoAuth.StatusCode) but invalid error envelope"
            Add-CheckResult -Check "${world} Unauthorized" -Status "FAIL" -ExitCode 1 -Notes "$($listingsNoAuth.StatusCode) but missing error_code or request_id"
        }
    } else {
        Write-Fail "${world} unauthorized: Expected 401/403, got $($listingsNoAuth.StatusCode)"
        Add-CheckResult -Check "${world} Unauthorized" -Status "FAIL" -ExitCode 1 -Notes "Status: $($listingsNoAuth.StatusCode)"
    }
}

# Test B: Missing tenant context (auth but no X-Tenant-Id)
if ($hasAuth) {
    Write-Info ""
    Write-Info "Test B: Missing tenant context (auth but no X-Tenant-Id)..."
    foreach ($world in $enabledWorlds) {
        $authHeaders = @{
            "Authorization" = "Bearer ${AuthToken}"
        }
        $listingsNoTenant = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${world}/listings" -Headers $authHeaders
        
        if ($listingsNoTenant.Error) {
            Write-Fail "${world} no-tenant: Request failed: $($listingsNoTenant.Error)"
            Add-CheckResult -Check "${world} No-Tenant" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
        } elseif ($listingsNoTenant.StatusCode -eq 403) {
            if (Validate-ErrorEnvelope -Json $listingsNoTenant.Json) {
                Write-Pass "${world} no-tenant: 403 FORBIDDEN with error envelope"
                Add-CheckResult -Check "${world} No-Tenant" -Status "PASS" -ExitCode 0 -Notes "403 FORBIDDEN with error envelope"
            } else {
                Write-Fail "${world} no-tenant: 403 but invalid error envelope"
                Add-CheckResult -Check "${world} No-Tenant" -Status "FAIL" -ExitCode 1 -Notes "403 but missing error_code or request_id"
            }
        } else {
            Write-Warn "${world} no-tenant: Expected 403, got $($listingsNoTenant.StatusCode) (may be acceptable)"
            Add-CheckResult -Check "${world} No-Tenant" -Status "WARN" -ExitCode 2 -Notes "Status: $($listingsNoTenant.StatusCode)"
        }
    }
} else {
    Write-Warn "Skipping tenant missing check (no auth token)"
    Add-CheckResult -Check "Tenant Missing" -Status "WARN" -ExitCode 2 -Notes "Skipped (no auth token)"
}

# Test C: Happy path CRUD (if credentials available)
if ($hasAuth -and $hasTenantA) {
    Write-Info ""
    Write-Info "Test C: Happy path CRUD (authenticated)..."
    
    $authHeaders = @{
        "Authorization" = "Bearer ${AuthToken}"
        "X-Tenant-Id" = $tenantAId
    }
    
    $createdIds = @{}
    
    foreach ($world in $enabledWorlds) {
        Write-Info "  Testing ${world} CRUD flow..."
        
        # C1: POST create
        $createBody = @{
            title = "CRUD Test ${world} $(Get-Date -Format 'yyyyMMddHHmmss')"
            status = "draft"
            currency = "TRY"
            price_amount = 10000
        } | ConvertTo-Json -Compress
        
        $createResponse = Invoke-HttpJson -Method "POST" -Url "${BaseUrl}/api/v1/${world}/listings" -Headers $authHeaders -BodyJson $createBody
        
        if ($createResponse.Error) {
            Write-Fail "${world} POST create: Request failed: $($createResponse.Error)"
            Add-CheckResult -Check "${world} POST Create" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
            continue
        } elseif ($createResponse.StatusCode -eq 200 -or $createResponse.StatusCode -eq 201) {
            if (Validate-OkEnvelope -Json $createResponse.Json -RequestIdFromHeader $createResponse.RequestIdFromHeader) {
                # Extract id from response
                $createdId = $null
                if ($createResponse.Json.item -and $createResponse.Json.item.id) {
                    $createdId = $createResponse.Json.item.id
                } elseif ($createResponse.Json.data -and $createResponse.Json.data.id) {
                    $createdId = $createResponse.Json.data.id
                } elseif ($createResponse.Json.id) {
                    $createdId = $createResponse.Json.id
                }
                
                if ($createdId) {
                    $createdIds[$world] = $createdId
                    Write-Pass "${world} POST create: $($createResponse.StatusCode) OK, id: $createdId"
                    Add-CheckResult -Check "${world} POST Create" -Status "PASS" -ExitCode 0 -Notes "$($createResponse.StatusCode) OK, id: $createdId"
                } else {
                    Write-Fail "${world} POST create: $($createResponse.StatusCode) but id not found in response"
                    Add-CheckResult -Check "${world} POST Create" -Status "FAIL" -ExitCode 1 -Notes "$($createResponse.StatusCode) but id missing"
                    continue
                }
            } else {
                Write-Fail "${world} POST create: $($createResponse.StatusCode) but invalid ok envelope"
                Add-CheckResult -Check "${world} POST Create" -Status "FAIL" -ExitCode 1 -Notes "$($createResponse.StatusCode) but invalid envelope"
                continue
            }
        } else {
            Write-Fail "${world} POST create: Expected 200/201, got $($createResponse.StatusCode)"
            Add-CheckResult -Check "${world} POST Create" -Status "FAIL" -ExitCode 1 -Notes "Status: $($createResponse.StatusCode)"
            continue
        }
        
        # C2: GET index (list)
        $listResponse = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${world}/listings" -Headers $authHeaders
        
        if ($listResponse.Error) {
            Write-Fail "${world} GET index: Request failed: $($listResponse.Error)"
            Add-CheckResult -Check "${world} GET Index" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
        } elseif ($listResponse.StatusCode -eq 200) {
            if (Validate-OkEnvelope -Json $listResponse.Json -RequestIdFromHeader $listResponse.RequestIdFromHeader) {
                # Check if created item appears in list
                $foundInList = $false
                if ($listResponse.Json.items) {
                    foreach ($item in $listResponse.Json.items) {
                        if ($item.id -eq $createdIds[$world]) {
                            $foundInList = $true
                            break
                        }
                    }
                } elseif ($listResponse.Json.data) {
                    foreach ($item in $listResponse.Json.data) {
                        if ($item.id -eq $createdIds[$world]) {
                            $foundInList = $true
                            break
                        }
                    }
                }
                
                if ($foundInList) {
                    Write-Pass "${world} GET index: 200 OK, created item found in list"
                    Add-CheckResult -Check "${world} GET Index" -Status "PASS" -ExitCode 0 -Notes "200 OK, item found in list"
                } else {
                    Write-Warn "${world} GET index: 200 OK but created item not found in list (may be pagination)"
                    Add-CheckResult -Check "${world} GET Index" -Status "WARN" -ExitCode 2 -Notes "200 OK but item not in list"
                }
            } else {
                Write-Fail "${world} GET index: 200 but invalid ok envelope"
                Add-CheckResult -Check "${world} GET Index" -Status "FAIL" -ExitCode 1 -Notes "200 but invalid envelope"
            }
        } else {
            Write-Fail "${world} GET index: Expected 200, got $($listResponse.StatusCode)"
            Add-CheckResult -Check "${world} GET Index" -Status "FAIL" -ExitCode 1 -Notes "Status: $($listResponse.StatusCode)"
        }
        
        # C3: GET show (detail)
        if ($createdIds[$world]) {
            $showResponse = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${world}/listings/$($createdIds[$world])" -Headers $authHeaders
            
            if ($showResponse.Error) {
                Write-Fail "${world} GET show: Request failed: $($showResponse.Error)"
                Add-CheckResult -Check "${world} GET Show" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
            } elseif ($showResponse.StatusCode -eq 200) {
                if (Validate-OkEnvelope -Json $showResponse.Json -RequestIdFromHeader $showResponse.RequestIdFromHeader) {
                    Write-Pass "${world} GET show: 200 OK"
                    Add-CheckResult -Check "${world} GET Show" -Status "PASS" -ExitCode 0 -Notes "200 OK"
                } else {
                    Write-Fail "${world} GET show: 200 but invalid ok envelope"
                    Add-CheckResult -Check "${world} GET Show" -Status "FAIL" -ExitCode 1 -Notes "200 but invalid envelope"
                }
            } else {
                Write-Fail "${world} GET show: Expected 200, got $($showResponse.StatusCode)"
                Add-CheckResult -Check "${world} GET Show" -Status "FAIL" -ExitCode 1 -Notes "Status: $($showResponse.StatusCode)"
            }
        }
        
        # C4: PATCH update
        if ($createdIds[$world]) {
            $updateBody = @{
                title = "CRUD Test Updated ${world} $(Get-Date -Format 'yyyyMMddHHmmss')"
            } | ConvertTo-Json -Compress
            
            $updateResponse = Invoke-HttpJson -Method "PATCH" -Url "${BaseUrl}/api/v1/${world}/listings/$($createdIds[$world])" -Headers $authHeaders -BodyJson $updateBody
            
            if ($updateResponse.Error) {
                Write-Fail "${world} PATCH update: Request failed: $($updateResponse.Error)"
                Add-CheckResult -Check "${world} PATCH Update" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
            } elseif ($updateResponse.StatusCode -eq 200) {
                if (Validate-OkEnvelope -Json $updateResponse.Json -RequestIdFromHeader $updateResponse.RequestIdFromHeader) {
                    Write-Pass "${world} PATCH update: 200 OK"
                    Add-CheckResult -Check "${world} PATCH Update" -Status "PASS" -ExitCode 0 -Notes "200 OK"
                } else {
                    Write-Fail "${world} PATCH update: 200 but invalid ok envelope"
                    Add-CheckResult -Check "${world} PATCH Update" -Status "FAIL" -ExitCode 1 -Notes "200 but invalid envelope"
                }
            } else {
                Write-Fail "${world} PATCH update: Expected 200, got $($updateResponse.StatusCode)"
                Add-CheckResult -Check "${world} PATCH Update" -Status "FAIL" -ExitCode 1 -Notes "Status: $($updateResponse.StatusCode)"
            }
        }
        
        # C5: DELETE
        if ($createdIds[$world]) {
            $deleteResponse = Invoke-HttpJson -Method "DELETE" -Url "${BaseUrl}/api/v1/${world}/listings/$($createdIds[$world])" -Headers $authHeaders
            
            if ($deleteResponse.Error) {
                Write-Fail "${world} DELETE: Request failed: $($deleteResponse.Error)"
                Add-CheckResult -Check "${world} DELETE" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
            } elseif ($deleteResponse.StatusCode -eq 200 -or $deleteResponse.StatusCode -eq 204) {
                Write-Pass "${world} DELETE: $($deleteResponse.StatusCode) OK"
                Add-CheckResult -Check "${world} DELETE" -Status "PASS" -ExitCode 0 -Notes "$($deleteResponse.StatusCode) OK"
                
                # C6: GET after delete should be 404
                $getAfterDelete = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${world}/listings/$($createdIds[$world])" -Headers $authHeaders
                
                if ($getAfterDelete.StatusCode -eq 404) {
                    if (Validate-ErrorEnvelope -Json $getAfterDelete.Json) {
                        Write-Pass "${world} GET after delete: 404 NOT_FOUND with error envelope"
                        Add-CheckResult -Check "${world} GET After Delete" -Status "PASS" -ExitCode 0 -Notes "404 NOT_FOUND with error envelope"
                    } else {
                        Write-Fail "${world} GET after delete: 404 but invalid error envelope"
                        Add-CheckResult -Check "${world} GET After Delete" -Status "FAIL" -ExitCode 1 -Notes "404 but missing error_code or request_id"
                    }
                } else {
                    Write-Fail "${world} GET after delete: Expected 404, got $($getAfterDelete.StatusCode)"
                    Add-CheckResult -Check "${world} GET After Delete" -Status "FAIL" -ExitCode 1 -Notes "Status: $($getAfterDelete.StatusCode)"
                }
            } else {
                Write-Fail "${world} DELETE: Expected 200/204, got $($deleteResponse.StatusCode)"
                Add-CheckResult -Check "${world} DELETE" -Status "FAIL" -ExitCode 1 -Notes "Status: $($deleteResponse.StatusCode)"
            }
        }
    }
} else {
    Write-Warn "Skipping happy path CRUD tests (no auth token or tenant)"
    Add-CheckResult -Check "Happy Path CRUD" -Status "WARN" -ExitCode 2 -Notes "Skipped (no auth/tenant)"
}

# Test D: Cross-tenant leakage (if both tenants available)
if ($hasAuth -and $hasTenantA -and $hasTenantB -and $createdIds.Count -gt 0) {
    Write-Info ""
    Write-Info "Test D: Cross-tenant leakage check..."
    
    $tenantAHeaders = @{
        "Authorization" = "Bearer ${AuthToken}"
        "X-Tenant-Id" = $tenantAId
    }
    
    $tenantBHeaders = @{
        "Authorization" = "Bearer ${AuthToken}"
        "X-Tenant-Id" = $tenantBId
    }
    
    # Create item with Tenant A
    $firstWorld = $enabledWorlds[0]
    if ($createdIds[$firstWorld]) {
        # Item already created, try to access with Tenant B
        $crossTenantResponse = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${firstWorld}/listings/$($createdIds[$firstWorld])" -Headers $tenantBHeaders
        
        if ($crossTenantResponse.StatusCode -eq 404) {
            if (Validate-ErrorEnvelope -Json $crossTenantResponse.Json) {
                Write-Pass "Cross-tenant leakage: 404 NOT_FOUND (no leakage)"
                Add-CheckResult -Check "Cross-Tenant Leakage" -Status "PASS" -ExitCode 0 -Notes "404 NOT_FOUND, no leakage"
            } else {
                Write-Fail "Cross-tenant leakage: 404 but invalid error envelope"
                Add-CheckResult -Check "Cross-Tenant Leakage" -Status "FAIL" -ExitCode 1 -Notes "404 but missing error_code or request_id"
            }
        } elseif ($crossTenantResponse.StatusCode -eq 200) {
            Write-Fail "Cross-tenant leakage: 200 OK (LEAKAGE DETECTED)"
            Add-CheckResult -Check "Cross-Tenant Leakage" -Status "FAIL" -ExitCode 1 -Notes "200 OK - LEAKAGE DETECTED"
        } else {
            Write-Warn "Cross-tenant leakage: Unexpected status $($crossTenantResponse.StatusCode)"
            Add-CheckResult -Check "Cross-Tenant Leakage" -Status "WARN" -ExitCode 2 -Notes "Status: $($crossTenantResponse.StatusCode)"
        }
    } else {
        Write-Warn "Cross-tenant leakage: Skipped (no created item available)"
        Add-CheckResult -Check "Cross-Tenant Leakage" -Status "WARN" -ExitCode 2 -Notes "Skipped (no id)"
    }
} else {
    Write-Warn "Skipping cross-tenant leakage test (no auth or both tenants)"
    Add-CheckResult -Check "Cross-Tenant Leakage" -Status "WARN" -ExitCode 2 -Notes "Skipped (no auth/TENANT_B)"
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
Write-Host "Check | Status | ExitCode | Notes" -ForegroundColor Cyan
Write-Host ("-" * 100) -ForegroundColor Gray
foreach ($result in $checkResults) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[$($result.Status)]" }
    }
    Write-Host "$($result.Check.PadRight(40)) $statusMarker $($result.ExitCode.ToString().PadRight(8)) $($result.Notes)" -ForegroundColor $(if ($result.Status -eq "PASS") { "Green" } elseif ($result.Status -eq "WARN") { "Yellow" } else { "Red" })
}

Write-Info ""
if (-not $overallPass) {
    Write-Fail "OVERALL STATUS: FAIL"
    Write-Info "Remediation:"
    Write-Info "  - Run ops/request_trace.ps1 -RequestId <request_id> for failed requests"
    Write-Info "  - Run ops/incident_bundle.ps1 to collect diagnostics"
    Invoke-OpsExit 1
    return
} elseif ($hasWarn) {
    Write-Warn "OVERALL STATUS: WARN"
    Invoke-OpsExit 2
    return
} else {
    Write-Pass "OVERALL STATUS: PASS"
    Invoke-OpsExit 0
    return
}


















