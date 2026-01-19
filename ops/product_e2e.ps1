# product_e2e.ps1 - Product API E2E Gate
# Validates API contract + boundary + error envelope + request_id + metrics/basic health
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [string]$BaseUrl = $env:BASE_URL,
    [string]$HosBaseUrl = $env:HOS_BASE_URL,
    [string]$TenantId = $env:PRODUCT_TEST_TENANT_ID,
    [string]$AuthToken = $env:PRODUCT_TEST_AUTH_TOKEN,
    [string]$TenantBId = $env:PRODUCT_TEST_TENANT_B_ID,
    [string]$SampleId = $null,
    [switch]$Verbose
)

if ([string]::IsNullOrEmpty($BaseUrl)) {
    $BaseUrl = "http://localhost:8080"
}
if ([string]::IsNullOrEmpty($HosBaseUrl)) {
    $HosBaseUrl = "http://localhost:3000"
}

$ErrorActionPreference = "Continue"

# Dot-source shared helpers
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\_lib\ops_output.ps1"
. "$ScriptDir\_lib\ops_exit.ps1"

Initialize-OpsOutput

Write-Info "=== PRODUCT E2E GATE ==="
Write-Info "Base URL: ${BaseUrl}"
Write-Info "H-OS Base URL: ${HosBaseUrl}"
Write-Info ""

# WP-33: Wait-PazarReady function for cold-start warmup
function Wait-PazarReady {
    param(
        [string]$BaseUrl = "http://localhost:8080",
        [int]$TimeoutSec = 60,
        [int]$IntervalMs = 500,
        [int]$MaxIntervalMs = 3000,
        [switch]$Jitter
    )
    
    $startTime = Get-Date
    $currentInterval = $IntervalMs
    $attempt = 0
    
    Write-Info "Waiting for Pazar to be ready (timeout: ${TimeoutSec}s)..."
    
    while ($true) {
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        
        if ($elapsed -ge $TimeoutSec) {
            Write-Fail "Pazar readiness timeout after ${TimeoutSec}s"
            Write-Info "Last endpoint tested: $lastEndpoint"
            Write-Info "Last status code: $lastStatusCode"
            return $false
        }
        
        $attempt++
        $allReady = $true
        $lastEndpoint = ""
        $lastStatusCode = 0
        
        # Check 1: GET /up (must be 200)
        try {
            $upResponse = Invoke-WebRequest -Uri "${BaseUrl}/up" -Method "GET" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            $lastEndpoint = "/up"
            $lastStatusCode = $upResponse.StatusCode
            if ($upResponse.StatusCode -ne 200) {
                $allReady = $false
            }
        } catch {
            $allReady = $false
            $lastEndpoint = "/up"
            if ($_.Exception.Response) {
                $lastStatusCode = [int]$_.Exception.Response.StatusCode.value__
            } else {
                $lastStatusCode = 0
            }
        }
        
        if (-not $allReady) {
            Start-Sleep -Milliseconds $currentInterval
            $currentInterval = [Math]::Min($currentInterval * 1.5, $MaxIntervalMs)
            continue
        }
        
        # Check 2: GET /api/metrics (must be 200 AND body contains "pazar_up 1")
        try {
            $metricsResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/metrics" -Method "GET" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            $lastEndpoint = "/api/metrics"
            $lastStatusCode = $metricsResponse.StatusCode
            if ($metricsResponse.StatusCode -ne 200) {
                $allReady = $false
            } else {
                $body = $metricsResponse.Content
                if ($body -notmatch "pazar_up\s+1") {
                    $allReady = $false
                }
            }
        } catch {
            $allReady = $false
            $lastEndpoint = "/api/metrics"
            if ($_.Exception.Response) {
                $lastStatusCode = [int]$_.Exception.Response.StatusCode.value__
            } else {
                $lastStatusCode = 0
            }
        }
        
        if (-not $allReady) {
            Start-Sleep -Milliseconds $currentInterval
            $currentInterval = [Math]::Min($currentInterval * 1.5, $MaxIntervalMs)
            continue
        }
        
        # Check 3: GET /api/v1/categories (must be 200 OR at least not 404)
        try {
            $categoriesResponse = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/categories" -Method "GET" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            $lastEndpoint = "/api/v1/categories"
            $lastStatusCode = $categoriesResponse.StatusCode
            if ($categoriesResponse.StatusCode -eq 404) {
                $allReady = $false
            }
        } catch {
            $allReady = $false
            $lastEndpoint = "/api/v1/categories"
            if ($_.Exception.Response) {
                $lastStatusCode = [int]$_.Exception.Response.StatusCode.value__
                # Treat 404/502/503/500 as NOT READY
                if ($lastStatusCode -in @(404, 502, 503, 500)) {
                    # Continue retrying
                } else {
                    # Other errors might be OK (e.g., 401/403), but we'll retry anyway
                }
            } else {
                $lastStatusCode = 0
            }
        }
        
        if ($allReady) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            Write-Pass "Pazar ready after ${elapsed}s (attempt $attempt)"
            return $true
        }
        
        Start-Sleep -Milliseconds $currentInterval
        $currentInterval = [Math]::Min($currentInterval * 1.5, $MaxIntervalMs)
    }
}

# WP-33: Wait for Pazar to be ready before running tests
Write-Info ""
if (-not (Wait-PazarReady -BaseUrl $BaseUrl -TimeoutSec 60)) {
    Write-Fail "Pazar readiness check failed - aborting E2E tests"
    Invoke-OpsExit 1
    return
}
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
    
    # Check request_id non-empty (UUID-ish)
    if ([string]::IsNullOrEmpty($Json.request_id)) {
        return $false
    }
    
    # Basic UUID format check (at least 8 chars)
    if ($Json.request_id.Length -lt 8) {
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
    
    # If header request_id present, must match body
    if ($RequestIdFromHeader -and $Json.request_id -ne $RequestIdFromHeader) {
        return $false
    }
    
    return $true
}

# Test 1: H-OS health
Write-Info "Test 1: H-OS health check..."
$hosHealth = Invoke-HttpJson -Method "GET" -Url "${HosBaseUrl}/v1/health"

if ($hosHealth.Error) {
    Write-Fail "H-OS health check failed: $($hosHealth.Error)"
    Add-CheckResult -Check "H-OS Health" -Status "FAIL" -ExitCode 1 -Notes "Request failed: $($hosHealth.Error)"
} elseif ($hosHealth.StatusCode -eq 200 -and $hosHealth.Json -and $hosHealth.Json.ok -eq $true) {
    Write-Pass "H-OS health: 200 OK"
    Add-CheckResult -Check "H-OS Health" -Status "PASS" -ExitCode 0 -Notes "200 OK, ok:true"
} else {
    Write-Fail "H-OS health: Expected 200 OK with ok:true, got $($hosHealth.StatusCode)"
    Add-CheckResult -Check "H-OS Health" -Status "FAIL" -ExitCode 1 -Notes "Status: $($hosHealth.StatusCode), ok: $($hosHealth.Json.ok)"
}

# Test 2: Pazar metrics
Write-Info ""
Write-Info "Test 2: Pazar metrics endpoint..."
$metrics = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/metrics"

if ($metrics.Error) {
    Write-Fail "Metrics check failed: $($metrics.Error)"
    Add-CheckResult -Check "Pazar Metrics" -Status "FAIL" -ExitCode 1 -Notes "Request failed: $($metrics.Error)"
} elseif ($metrics.StatusCode -eq 200) {
    $contentType = $metrics.Headers["Content-Type"]
    if ($contentType -and $contentType.StartsWith("text/plain")) {
        Write-Pass "Pazar metrics: 200 OK, Content-Type: text/plain"
        Add-CheckResult -Check "Pazar Metrics" -Status "PASS" -ExitCode 0 -Notes "200 OK, Content-Type: text/plain"
    } else {
        Write-Fail "Pazar metrics: Expected Content-Type text/plain, got $contentType"
        Add-CheckResult -Check "Pazar Metrics" -Status "FAIL" -ExitCode 1 -Notes "Content-Type: $contentType"
    }
} else {
    Write-Fail "Pazar metrics: Expected 200, got $($metrics.StatusCode)"
    Add-CheckResult -Check "Pazar Metrics" -Status "FAIL" -ExitCode 1 -Notes "Status: $($metrics.StatusCode)"
}

# Test 3: Product spine validation (world param required)
Write-Info ""
Write-Info "Test 3: Product spine validation (world param required)..."
$productNoWorld = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/products"

if ($productNoWorld.Error) {
    Write-Fail "Product spine validation failed: $($productNoWorld.Error)"
    Add-CheckResult -Check "Product Spine Validation" -Status "FAIL" -ExitCode 1 -Notes "Request failed: $($productNoWorld.Error)"
} elseif ($productNoWorld.StatusCode -eq 422) {
    if (Validate-ErrorEnvelope -Json $productNoWorld.Json) {
        Write-Pass "Product spine validation: 422 VALIDATION_ERROR with request_id"
        Add-CheckResult -Check "Product Spine Validation" -Status "PASS" -ExitCode 0 -Notes "422 VALIDATION_ERROR, request_id present"
    } else {
        Write-Fail "Product spine validation: 422 but invalid error envelope"
        Add-CheckResult -Check "Product Spine Validation" -Status "FAIL" -ExitCode 1 -Notes "422 but missing error_code or request_id"
    }
} else {
    Write-Fail "Product spine validation: Expected 422, got $($productNoWorld.StatusCode)"
    Add-CheckResult -Check "Product Spine Validation" -Status "FAIL" -ExitCode 1 -Notes "Status: $($productNoWorld.StatusCode)"
}

# Test 3b: Product with world but no auth
Write-Info ""
Write-Info "Test 3b: Product with world but no auth..."
$productNoAuth = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/products?world=commerce"

if ($productNoAuth.Error) {
    Write-Fail "Product no-auth check failed: $($productNoAuth.Error)"
    Add-CheckResult -Check "Product No-Auth" -Status "FAIL" -ExitCode 1 -Notes "Request failed: $($productNoAuth.Error)"
} elseif ($productNoAuth.StatusCode -eq 401 -or $productNoAuth.StatusCode -eq 403) {
    if (Validate-ErrorEnvelope -Json $productNoAuth.Json) {
        Write-Pass "Product no-auth: $($productNoAuth.StatusCode) with error envelope"
        Add-CheckResult -Check "Product No-Auth" -Status "PASS" -ExitCode 0 -Notes "$($productNoAuth.StatusCode) with error envelope"
    } else {
        Write-Fail "Product no-auth: $($productNoAuth.StatusCode) but invalid error envelope"
        Add-CheckResult -Check "Product No-Auth" -Status "FAIL" -ExitCode 1 -Notes "$($productNoAuth.StatusCode) but missing error_code or request_id"
    }
} else {
    Write-Fail "Product no-auth: Expected 401/403, got $($productNoAuth.StatusCode)"
    Add-CheckResult -Check "Product No-Auth" -Status "FAIL" -ExitCode 1 -Notes "Status: $($productNoAuth.StatusCode)"
}

# Test 4: Listings per enabled world (unauthorized)
Write-Info ""
Write-Info "Test 4: Listings per enabled world (unauthorized)..."
$enabledWorlds = @("commerce", "food", "rentals")

foreach ($world in $enabledWorlds) {
    Write-Info "  Checking ${world}..."
    $listingsNoAuth = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${world}/listings"
    
    if ($listingsNoAuth.Error) {
        Write-Fail "${world} listings no-auth: Request failed: $($listingsNoAuth.Error)"
        Add-CheckResult -Check "${world} Listings No-Auth" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
    } elseif ($listingsNoAuth.StatusCode -eq 401 -or $listingsNoAuth.StatusCode -eq 403) {
        if (Validate-ErrorEnvelope -Json $listingsNoAuth.Json) {
            Write-Pass "${world} listings no-auth: $($listingsNoAuth.StatusCode) with error envelope"
            Add-CheckResult -Check "${world} Listings No-Auth" -Status "PASS" -ExitCode 0 -Notes "$($listingsNoAuth.StatusCode) with error envelope"
        } else {
            Write-Fail "${world} listings no-auth: $($listingsNoAuth.StatusCode) but invalid error envelope"
            Add-CheckResult -Check "${world} Listings No-Auth" -Status "FAIL" -ExitCode 1 -Notes "$($listingsNoAuth.StatusCode) but missing error_code or request_id"
        }
    } else {
        Write-Fail "${world} listings no-auth: Expected 401/403, got $($listingsNoAuth.StatusCode)"
        Add-CheckResult -Check "${world} Listings No-Auth" -Status "FAIL" -ExitCode 1 -Notes "Status: $($listingsNoAuth.StatusCode)"
    }
}

# Test 5: Auth-required E2E (only if credentials provided)
Write-Info ""
if ([string]::IsNullOrEmpty($TenantId) -or [string]::IsNullOrEmpty($AuthToken)) {
    Write-Warn "Auth credentials not provided - skipping auth-required E2E tests"
    Add-CheckResult -Check "Auth-Required E2E" -Status "WARN" -ExitCode 2 -Notes "TenantId or AuthToken missing - tests skipped"
} else {
    Write-Info "Test 5: Auth-required E2E (credentials provided)..."
    
    $authHeaders = @{
        "Authorization" = "Bearer ${AuthToken}"
        "X-Tenant-Id" = $TenantId
    }
    
    $createdIds = @{}
    
    foreach ($world in $enabledWorlds) {
        Write-Info "  Testing ${world} E2E flow..."
        
        # 5a: POST create
        $createBody = @{
            title = "E2E Test Listing ${world} $(Get-Date -Format 'yyyyMMddHHmmss')"
            status = "draft"
            currency = "TRY"
            price_amount = 10000
            payload_json = $null
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
                }
            } else {
                Write-Fail "${world} POST create: $($createResponse.StatusCode) but invalid ok envelope"
                Add-CheckResult -Check "${world} POST Create" -Status "FAIL" -ExitCode 1 -Notes "$($createResponse.StatusCode) but invalid envelope"
            }
        } else {
            Write-Fail "${world} POST create: Expected 200/201, got $($createResponse.StatusCode)"
            Add-CheckResult -Check "${world} POST Create" -Status "FAIL" -ExitCode 1 -Notes "Status: $($createResponse.StatusCode)"
            continue
        }
        
        # 5b: GET show (use created id or SampleId)
        $showId = if ($createdIds[$world]) { $createdIds[$world] } elseif ($SampleId) { $SampleId } else { $null }
        
        if ($showId) {
            $showResponse = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${world}/listings/${showId}" -Headers $authHeaders
            
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
        } else {
            Write-Warn "${world} GET show: Skipped (no id available)"
            Add-CheckResult -Check "${world} GET Show" -Status "WARN" -ExitCode 2 -Notes "Skipped (no id)"
        }
        
        # 5c: PATCH update (use created id)
        if ($createdIds[$world]) {
            $updateBody = @{
                title = "E2E Test Updated ${world} $(Get-Date -Format 'yyyyMMddHHmmss')"
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
        } else {
            Write-Warn "${world} PATCH update: Skipped (no id available)"
            Add-CheckResult -Check "${world} PATCH Update" -Status "WARN" -ExitCode 2 -Notes "Skipped (no id)"
        }
        
        # 5d: DELETE (use created id)
        if ($createdIds[$world]) {
            $deleteResponse = Invoke-HttpJson -Method "DELETE" -Url "${BaseUrl}/api/v1/${world}/listings/$($createdIds[$world])" -Headers $authHeaders
            
            if ($deleteResponse.Error) {
                Write-Fail "${world} DELETE: Request failed: $($deleteResponse.Error)"
                Add-CheckResult -Check "${world} DELETE" -Status "FAIL" -ExitCode 1 -Notes "Request failed"
            } elseif ($deleteResponse.StatusCode -eq 200 -or $deleteResponse.StatusCode -eq 204) {
                Write-Pass "${world} DELETE: $($deleteResponse.StatusCode) OK"
                Add-CheckResult -Check "${world} DELETE" -Status "PASS" -ExitCode 0 -Notes "$($deleteResponse.StatusCode) OK"
                
                # 5e: GET after delete should be 404
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
        } else {
            Write-Warn "${world} DELETE: Skipped (no id available)"
            Add-CheckResult -Check "${world} DELETE" -Status "WARN" -ExitCode 2 -Notes "Skipped (no id)"
        }
    }
    
    # Cross-tenant leakage check (optional)
    if (-not [string]::IsNullOrEmpty($TenantBId) -and $createdIds.Count -gt 0) {
        Write-Info ""
        Write-Info "Test 5f: Cross-tenant leakage check..."
        
        $tenantBHeaders = @{
            "Authorization" = "Bearer ${AuthToken}"
            "X-Tenant-Id" = $TenantBId
        }
        
        $firstWorld = $enabledWorlds[0]
        $firstId = $createdIds[$firstWorld]
        
        if ($firstId) {
            $crossTenantResponse = Invoke-HttpJson -Method "GET" -Url "${BaseUrl}/api/v1/${firstWorld}/listings/${firstId}" -Headers $tenantBHeaders
            
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
            Write-Warn "Cross-tenant leakage: Skipped (no id available)"
            Add-CheckResult -Check "Cross-Tenant Leakage" -Status "WARN" -ExitCode 2 -Notes "Skipped (no id)"
        }
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
