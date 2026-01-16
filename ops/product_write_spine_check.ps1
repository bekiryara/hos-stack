# product_write_spine_check.ps1 - Product Write Spine Check
# Validates Commerce POST create endpoint: auth, tenant, world boundaries, read-after-write, cross-tenant isolation
# PowerShell 5.1 compatible, ASCII-only output

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$TenantId = $null,
    [string]$TenantBId = $null,
    [string]$AuthToken = $null,
    [string]$World = "commerce"
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

Write-Host "=== PRODUCT WRITE SPINE CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "World: $World" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()
$overallStatus = "PASS"
$overallExitCode = 0
$hasWarn = $false
$hasFail = $false

# Helper: Add check result
function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$Notes,
        [int]$ExitCode = 0
    )
    
    $results += [PSCustomObject]@{
        Check = $CheckName
        Status = $Status
        Notes = $Notes
    }
    
    if ($Status -eq "PASS") {
        Write-Host "  [PASS] $CheckName" -ForegroundColor Green
    } elseif ($Status -eq "WARN") {
        Write-Host "  [WARN] ${CheckName}: ${Notes}" -ForegroundColor Yellow
        $script:hasWarn = $true
        if ($script:overallStatus -eq "PASS") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    } else {
        Write-Host "  [FAIL] ${CheckName}: ${Notes}" -ForegroundColor Red
        $script:hasFail = $true
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    }
}

# Get auth token from env or params
$testToken = $AuthToken
if (-not $testToken) {
    $testToken = $env:PRODUCT_TEST_TOKEN
}
if (-not $testToken) {
    $testEmail = $env:PRODUCT_TEST_EMAIL
    $testPassword = $env:PRODUCT_TEST_PASSWORD
    if ($testEmail -and $testPassword) {
        try {
            $loginBody = @{ email = $testEmail; password = $testPassword } | ConvertTo-Json
            $loginResponse = Invoke-WebRequest -Uri "${BaseUrl}/auth/login" `
                -Method "POST" `
                -Headers @{ "Content-Type" = "application/json"; "Accept" = "application/json" } `
                -Body $loginBody `
                -UseBasicParsing `
                -TimeoutSec 10 `
                -ErrorAction Stop
            $loginJson = $loginResponse.Content | ConvertFrom-Json
            $testToken = $loginJson.token
        } catch {
            # Login failed - skip
        }
    }
}

# Get tenant ID from env or params
$testTenantId = $TenantId
if (-not $testTenantId) {
    $testTenantId = $env:TENANT_TEST_ID
}
if (-not $testTenantId) {
    $testTenantId = $env:PRODUCT_TEST_TENANT_ID
}

# Get tenant B ID (for cross-tenant test)
$testTenantBId = $TenantBId
if (-not $testTenantBId) {
    $testTenantBId = $env:TENANT_B_TEST_ID
}

Write-Host "Step 1: Unauthorized POST (401/403 proof)" -ForegroundColor Cyan

# Check 1a: POST without auth (must return 401/403)
try {
    $response = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/$World/listings" `
        -Method "POST" `
        -Headers @{ "Content-Type" = "application/json"; "Accept" = "application/json" } `
        -Body (@{ title = "Test" } | ConvertTo-Json) `
        -UseBasicParsing `
        -TimeoutSec 10 `
        -ErrorAction Stop
    
    # Got 200/201 - should not happen without auth
    Add-CheckResult -CheckName "Unauthorized POST" -Status "FAIL" -Notes "HTTP $($response.StatusCode) (expected 401/403)"
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        if ($statusCode -in @(401, 403)) {
            try {
                $stream = $webException.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
                
                $json = $responseBody | ConvertFrom-Json
                if ($json.ok -eq $false -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                    Add-CheckResult -CheckName "Unauthorized POST" -Status "PASS" -Notes "HTTP $statusCode with JSON envelope (ok:false, request_id present)"
                } else {
                    Add-CheckResult -CheckName "Unauthorized POST" -Status "WARN" -Notes "HTTP $statusCode but JSON envelope incomplete (missing ok:false or request_id)"
                }
            } catch {
                Add-CheckResult -CheckName "Unauthorized POST" -Status "WARN" -Notes "HTTP $statusCode but response is not JSON"
            }
        } else {
            Add-CheckResult -CheckName "Unauthorized POST" -Status "FAIL" -Notes "HTTP $statusCode (expected 401/403)"
        }
    } else {
        Add-CheckResult -CheckName "Unauthorized POST" -Status "FAIL" -Notes "Request failed: $($_.Exception.Message)"
    }
}

Write-Host "Step 2: Auth without tenant (403 proof)" -ForegroundColor Cyan

# Check 2: POST with auth but missing tenant (must return 403)
if ($testToken) {
    try {
        $response = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/$World/listings" `
            -Method "POST" `
            -Headers @{
                "Authorization" = "Bearer $testToken"
                "Content-Type" = "application/json"
                "Accept" = "application/json"
            } `
            -Body (@{ title = "Test Item" } | ConvertTo-Json) `
            -UseBasicParsing `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        if ($response.StatusCode -eq 403) {
            try {
                $json = $response.Content | ConvertFrom-Json
                if ($json.ok -eq $false -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                    Add-CheckResult -CheckName "Auth without Tenant" -Status "PASS" -Notes "HTTP 403 with JSON envelope (ok:false, request_id present)"
                } else {
                    Add-CheckResult -CheckName "Auth without Tenant" -Status "WARN" -Notes "HTTP 403 but JSON envelope incomplete"
                }
            } catch {
                Add-CheckResult -CheckName "Auth without Tenant" -Status "WARN" -Notes "HTTP 403 but response is not JSON"
            }
        } else {
            Add-CheckResult -CheckName "Auth without Tenant" -Status "FAIL" -Notes "HTTP $($response.StatusCode) (expected 403)"
        }
    } catch {
        $webException = $_.Exception
        if ($webException.Response) {
            $statusCode = [int]$webException.Response.StatusCode.value__
            if ($statusCode -eq 403) {
                try {
                    $stream = $webException.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                    $json = $responseBody | ConvertFrom-Json
                    if ($json.ok -eq $false -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                        Add-CheckResult -CheckName "Auth without Tenant" -Status "PASS" -Notes "HTTP 403 with JSON envelope (ok:false, request_id present)"
                    } else {
                        Add-CheckResult -CheckName "Auth without Tenant" -Status "WARN" -Notes "HTTP 403 but JSON envelope incomplete"
                    }
                } catch {
                    Add-CheckResult -CheckName "Auth without Tenant" -Status "WARN" -Notes "HTTP 403 but response is not JSON"
                }
            } else {
                Add-CheckResult -CheckName "Auth without Tenant" -Status "FAIL" -Notes "HTTP $statusCode (expected 403)"
            }
        } else {
            Add-CheckResult -CheckName "Auth without Tenant" -Status "FAIL" -Notes "Request failed: $($_.Exception.Message)"
        }
    }
} else {
    Add-CheckResult -CheckName "Auth without Tenant" -Status "WARN" -Notes "Auth token not available (set PRODUCT_TEST_TOKEN or PRODUCT_TEST_EMAIL + PRODUCT_TEST_PASSWORD)"
}

Write-Host "Step 3: Auth + tenant create (201 proof)" -ForegroundColor Cyan

# Check 3: POST with auth + tenant (must return 201 ok:true with id)
$createdListingId = $null

if ($testToken -and $testTenantId) {
    try {
        $createBody = @{
            title = "Write Spine Test Item $(Get-Date -Format 'yyyyMMddHHmmss')"
            description = "Test description for write spine check"
            price_amount = 12500
            currency = "TRY"
            status = "draft"
        } | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/$World/listings" `
            -Method "POST" `
            -Headers @{
                "Authorization" = "Bearer $testToken"
                "X-Tenant-Id" = $testTenantId
                "Content-Type" = "application/json"
                "Accept" = "application/json"
            } `
            -Body $createBody `
            -UseBasicParsing `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        if ($response.StatusCode -eq 201) {
            try {
                $json = $response.Content | ConvertFrom-Json
                if ($json.ok -eq $true -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                    # Verify envelope shape includes data.id and data.item
                    if (($json.PSObject.Properties.Name -contains "data") -and $json.data) {
                        if (($json.data.PSObject.Properties.Name -contains "id") -and ($json.data.PSObject.Properties.Name -contains "item")) {
                            $createdListingId = $json.data.id
                            Add-CheckResult -CheckName "Auth + Tenant Create" -Status "PASS" -Notes "HTTP 201 with JSON envelope (ok:true, data.id, data.item, request_id present)"
                        } else {
                            Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP 201 but envelope shape invalid (missing data.id or data.item)"
                        }
                    } else {
                        Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP 201 but envelope shape invalid (missing data)"
                    }
                } else {
                    Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP 201 but JSON envelope invalid (ok != true or request_id missing)"
                }
            } catch {
                Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP 201 but response is not JSON"
            }
        } else {
            Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP $($response.StatusCode) (expected 201)"
        }
    } catch {
        $webException = $_.Exception
        if ($webException.Response) {
            $statusCode = [int]$webException.Response.StatusCode.value__
            if ($statusCode -eq 201) {
                try {
                    $stream = $webException.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                    $json = $responseBody | ConvertFrom-Json
                    if ($json.ok -eq $true -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                        if (($json.PSObject.Properties.Name -contains "data") -and $json.data) {
                            if (($json.data.PSObject.Properties.Name -contains "id") -and ($json.data.PSObject.Properties.Name -contains "item")) {
                                $createdListingId = $json.data.id
                                Add-CheckResult -CheckName "Auth + Tenant Create" -Status "PASS" -Notes "HTTP 201 with JSON envelope (ok:true, data.id, data.item, request_id present)"
                            } else {
                                Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP 201 but envelope shape invalid (missing data.id or data.item)"
                            }
                        } else {
                            Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP 201 but envelope shape invalid (missing data)"
                        }
                    } else {
                        Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP 201 but JSON envelope invalid (ok != true or request_id missing)"
                    }
                } catch {
                    Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP 201 but response is not JSON"
                }
            } else {
                Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "HTTP $statusCode (expected 201)"
            }
        } else {
            Add-CheckResult -CheckName "Auth + Tenant Create" -Status "FAIL" -Notes "Request failed: $($_.Exception.Message)"
        }
    }
} else {
    Add-CheckResult -CheckName "Auth + Tenant Create" -Status "WARN" -Notes "Auth token or tenant ID not available (set TENANT_TEST_ID or PRODUCT_TEST_TOKEN and PRODUCT_TEST_TENANT_ID)"
}

Write-Host "Step 4: Read-after-write (200 proof)" -ForegroundColor Cyan

# Check 4: Read-after-write (GET /listings/{id} with same tenant -> 200 ok:true)
if ($testToken -and $testTenantId -and $createdListingId) {
    try {
        $response = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/$World/listings/${createdListingId}" `
            -Method "GET" `
            -Headers @{
                "Authorization" = "Bearer $testToken"
                "X-Tenant-Id" = $testTenantId
                "Accept" = "application/json"
            } `
            -UseBasicParsing `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        if ($response.StatusCode -eq 200) {
            try {
                $json = $response.Content | ConvertFrom-Json
                if ($json.ok -eq $true -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                    if (($json.PSObject.Properties.Name -contains "data") -and $json.data -and ($json.data.PSObject.Properties.Name -contains "item")) {
                        Add-CheckResult -CheckName "Read-After-Write" -Status "PASS" -Notes "HTTP 200 with JSON envelope (ok:true, data.item, request_id present)"
                    } else {
                        Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "HTTP 200 but envelope shape invalid (missing data.item)"
                    }
                } else {
                    Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "HTTP 200 but JSON envelope invalid (ok != true or request_id missing)"
                }
            } catch {
                Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "HTTP 200 but response is not JSON"
            }
        } else {
            Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "HTTP $($response.StatusCode) (expected 200)"
        }
    } catch {
        $webException = $_.Exception
        if ($webException.Response) {
            $statusCode = [int]$webException.Response.StatusCode.value__
            if ($statusCode -eq 200) {
                try {
                    $stream = $webException.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                    $json = $responseBody | ConvertFrom-Json
                    if ($json.ok -eq $true -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                        if (($json.PSObject.Properties.Name -contains "data") -and $json.data -and ($json.data.PSObject.Properties.Name -contains "item")) {
                            Add-CheckResult -CheckName "Read-After-Write" -Status "PASS" -Notes "HTTP 200 with JSON envelope (ok:true, data.item, request_id present)"
                        } else {
                            Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "HTTP 200 but envelope shape invalid (missing data.item)"
                        }
                    } else {
                        Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "HTTP 200 but JSON envelope invalid (ok != true or request_id missing)"
                    }
                } catch {
                    Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "HTTP 200 but response is not JSON"
                }
            } else {
                Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "HTTP $statusCode (expected 200)"
            }
        } else {
            Add-CheckResult -CheckName "Read-After-Write" -Status "FAIL" -Notes "Request failed: $($_.Exception.Message)"
        }
    }
} else {
    if (-not $createdListingId) {
        Add-CheckResult -CheckName "Read-After-Write" -Status "WARN" -Notes "Skipped (create step did not produce listing ID)"
    } else {
        Add-CheckResult -CheckName "Read-After-Write" -Status "WARN" -Notes "Auth token or tenant ID not available"
    }
}

Write-Host "Step 5: Cross-tenant read test (404 proof)" -ForegroundColor Cyan

# Check 5: Cross-tenant read test (GET same id with tenant B -> 404 NOT_FOUND)
if ($testToken -and $testTenantBId -and $createdListingId) {
    try {
        $response = Invoke-WebRequest -Uri "${BaseUrl}/api/v1/$World/listings/${createdListingId}" `
            -Method "GET" `
            -Headers @{
                "Authorization" = "Bearer $testToken"
                "X-Tenant-Id" = $testTenantBId
                "Accept" = "application/json"
            } `
            -UseBasicParsing `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        if ($response.StatusCode -eq 404) {
            try {
                $json = $response.Content | ConvertFrom-Json
                if ($json.ok -eq $false -and $json.error_code -eq "NOT_FOUND" -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                    Add-CheckResult -CheckName "Cross-Tenant Read" -Status "PASS" -Notes "HTTP 404 with JSON envelope (ok:false, error_code:NOT_FOUND, request_id present, no leakage)"
                } else {
                    Add-CheckResult -CheckName "Cross-Tenant Read" -Status "FAIL" -Notes "HTTP 404 but JSON envelope invalid (ok != false or error_code != NOT_FOUND or request_id missing)"
                }
            } catch {
                Add-CheckResult -CheckName "Cross-Tenant Read" -Status "FAIL" -Notes "HTTP 404 but response is not JSON"
            }
        } else {
            Add-CheckResult -CheckName "Cross-Tenant Read" -Status "FAIL" -Notes "HTTP $($response.StatusCode) (expected 404 NOT_FOUND, possible cross-tenant leakage)"
        }
    } catch {
        $webException = $_.Exception
        if ($webException.Response) {
            $statusCode = [int]$webException.Response.StatusCode.value__
            if ($statusCode -eq 404) {
                try {
                    $stream = $webException.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                    $json = $responseBody | ConvertFrom-Json
                    if ($json.ok -eq $false -and $json.error_code -eq "NOT_FOUND" -and ($json.PSObject.Properties.Name -contains "request_id") -and $json.request_id) {
                        Add-CheckResult -CheckName "Cross-Tenant Read" -Status "PASS" -Notes "HTTP 404 with JSON envelope (ok:false, error_code:NOT_FOUND, request_id present, no leakage)"
                    } else {
                        Add-CheckResult -CheckName "Cross-Tenant Read" -Status "FAIL" -Notes "HTTP 404 but JSON envelope invalid (ok != false or error_code != NOT_FOUND or request_id missing)"
                    }
                } catch {
                    Add-CheckResult -CheckName "Cross-Tenant Read" -Status "FAIL" -Notes "HTTP 404 but response is not JSON"
                }
            } else {
                Add-CheckResult -CheckName "Cross-Tenant Read" -Status "FAIL" -Notes "HTTP $statusCode (expected 404 NOT_FOUND, possible cross-tenant leakage)"
            }
        } else {
            Add-CheckResult -CheckName "Cross-Tenant Read" -Status "FAIL" -Notes "Request failed: $($_.Exception.Message)"
        }
    }
} else {
    if (-not $createdListingId) {
        Add-CheckResult -CheckName "Cross-Tenant Read" -Status "WARN" -Notes "Skipped (create step did not produce listing ID)"
    } elseif (-not $testTenantBId) {
        Add-CheckResult -CheckName "Cross-Tenant Read" -Status "WARN" -Notes "Tenant B ID not available (set TENANT_B_TEST_ID for cross-tenant test)"
    } else {
        Add-CheckResult -CheckName "Cross-Tenant Read" -Status "WARN" -Notes "Auth token not available"
    }
}

# Print results table
Write-Host ""
Write-Host "=== PRODUCT WRITE SPINE CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Check                                    Status Notes" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

foreach ($result in $script:results) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[$($result.Status)]" }
    }
    
    $checkPadded = $result.Check.PadRight(40)
    $statusPadded = $statusMarker.PadRight(8)
    
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "White" }
    }
    
    Write-Host "$checkPadded $statusPadded $($result.Notes)" -ForegroundColor $color
}

Write-Host ""

# Determine overall status
if ($script:hasFail) {
    Write-Host "OVERALL STATUS: FAIL" -ForegroundColor Red
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    Write-Host "1. Verify Commerce POST endpoint is implemented: curl -X POST http://localhost:8080/api/v1/commerce/listings" -ForegroundColor Gray
    Write-Host "2. Check tenant boundary enforcement: ensure tenant_id is set from resolved context, not request body" -ForegroundColor Gray
    Write-Host "3. Check world boundary enforcement: ensure world='commerce' is enforced" -ForegroundColor Gray
    Write-Host "4. Verify response envelope: { ok:true, data:{ id, item }, request_id }" -ForegroundColor Gray
    Invoke-OpsExit 1
} elseif ($script:hasWarn) {
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: Some checks were skipped due to missing credentials. Set TENANT_TEST_ID and PRODUCT_TEST_TOKEN for full validation." -ForegroundColor Gray
    Invoke-OpsExit 2
} else {
    Write-Host "OVERALL STATUS: PASS" -ForegroundColor Green
    Invoke-OpsExit 0
}





