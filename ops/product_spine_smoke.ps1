# product_spine_smoke.ps1 - Product Spine E2E Smoke Test
# Validates Product API spine read-path and write-stub governance across all enabled worlds
# PowerShell 5.1 compatible, ASCII-only output, safe-exit behavior

param(
    [string]$BaseUrl = "http://localhost:8080"
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

Write-Host "=== PRODUCT SPINE E2E SMOKE TEST ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()
$overallStatus = "PASS"
$overallExitCode = 0
$hasWarn = $false
$hasFail = $false

# Enabled worlds
$worlds = @("commerce", "food", "rentals")

# Helper: Add check result
function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$Notes,
        [bool]$Blocking = $true
    )
    
    $exitCode = 0
    if ($Status -eq "FAIL") {
        $exitCode = 1
        $script:hasFail = $true
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    } elseif ($Status -eq "WARN") {
        $exitCode = 2
        $script:hasWarn = $true
        if ($script:overallStatus -eq "PASS") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    }
    
    $script:results += [PSCustomObject]@{
        Check = $CheckName
        Status = $Status
        Notes = $Notes
        ExitCode = $exitCode
        Blocking = $Blocking
    }
}

# Helper: Test HTTP response with JSON envelope validation
function Test-ApiResponse {
    param(
        [string]$CheckName,
        [string]$Method,
        [string]$Url,
        [int[]]$ExpectedStatusCodes,
        [hashtable]$Headers = @{},
        [bool]$ExpectJsonEnvelope = $true,
        [bool]$ExpectOkTrue = $false,
        [bool]$ExpectOkFalse = $false,
        [string]$ExpectedErrorCode = $null
    )
    
    $status = "PASS"
    $notes = ""
    
    try {
        $requestHeaders = @{
            "Accept" = "application/json"
        }
        foreach ($key in $Headers.Keys) {
            $requestHeaders[$key] = $Headers[$key]
        }
        
        $body = $null
        if ($Method -eq "POST" -or $Method -eq "PATCH") {
            $body = "{}"
            $requestHeaders["Content-Type"] = "application/json"
        }
        
        $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $requestHeaders -Body $body -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $statusCode = $response.StatusCode
        
        if ($ExpectedStatusCodes -contains $statusCode) {
            if ($ExpectJsonEnvelope) {
                try {
                    $json = $response.Content | ConvertFrom-Json
                    
                    # Validate JSON envelope structure
                    if (-not ($json.PSObject.Properties.Name -contains "ok")) {
                        $status = "FAIL"
                        $notes = "Status $statusCode, but JSON envelope missing 'ok' field"
                        $script:hasFail = $true
                        $script:overallStatus = "FAIL"
                        $script:overallExitCode = 1
                    } elseif (-not ($json.PSObject.Properties.Name -contains "request_id")) {
                        $status = "FAIL"
                        $notes = "Status $statusCode, but JSON envelope missing 'request_id' field"
                        $script:hasFail = $true
                        $script:overallStatus = "FAIL"
                        $script:overallExitCode = 1
                    } elseif ($ExpectOkTrue -and $json.ok -ne $true) {
                        $status = "FAIL"
                        $notes = "Status $statusCode, but ok != true (got: $($json.ok))"
                        $script:hasFail = $true
                        $script:overallStatus = "FAIL"
                        $script:overallExitCode = 1
                    } elseif ($ExpectOkFalse -and $json.ok -ne $false) {
                        $status = "FAIL"
                        $notes = "Status $statusCode, but ok != false (got: $($json.ok))"
                        $script:hasFail = $true
                        $script:overallStatus = "FAIL"
                        $script:overallExitCode = 1
                    } elseif ($ExpectedErrorCode -and (-not ($json.PSObject.Properties.Name -contains "error_code") -or $json.error_code -ne $ExpectedErrorCode)) {
                        $status = "FAIL"
                        $notes = "Status $statusCode, but error_code != '$ExpectedErrorCode' (got: $($json.error_code))"
                        $script:hasFail = $true
                        $script:overallStatus = "FAIL"
                        $script:overallExitCode = 1
                    } else {
                        if ($ExpectOkTrue) {
                            $notes = "Status $statusCode, JSON envelope correct (ok:true, request_id present)"
                        } elseif ($ExpectOkFalse) {
                            $notes = "Status $statusCode, JSON envelope correct (ok:false, error_code: $($json.error_code), request_id present)"
                        } else {
                            $notes = "Status $statusCode, JSON envelope correct (request_id present)"
                        }
                    }
                } catch {
                    $status = "FAIL"
                    $notes = "Status $statusCode, but not valid JSON: $($_.Exception.Message)"
                    $script:hasFail = $true
                    $script:overallStatus = "FAIL"
                    $script:overallExitCode = 1
                }
            } else {
                $notes = "Status $statusCode (expected)"
            }
        } else {
            $status = "FAIL"
            $notes = "Status $statusCode (expected one of: $($ExpectedStatusCodes -join ', '))"
            $script:hasFail = $true
            $script:overallStatus = "FAIL"
            $script:overallExitCode = 1
        }
    } catch {
        $webException = $_.Exception
        if ($webException.Response) {
            $statusCode = [int]$webException.Response.StatusCode.value__
            if ($ExpectedStatusCodes -contains $statusCode) {
                # Expected status code (e.g., 401, 403, 404, 501)
                try {
                    $stream = $webException.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                    
                    if ($ExpectJsonEnvelope) {
                        try {
                            $json = $responseBody | ConvertFrom-Json
                            if (-not ($json.PSObject.Properties.Name -contains "ok") -or $json.ok -ne $false) {
                                $status = "FAIL"
                                $notes = "Status $statusCode, but JSON envelope invalid (ok != false)"
                                $script:hasFail = $true
                                $script:overallStatus = "FAIL"
                                $script:overallExitCode = 1
                            } elseif (-not ($json.PSObject.Properties.Name -contains "request_id")) {
                                $status = "FAIL"
                                $notes = "Status $statusCode, but JSON envelope missing 'request_id'"
                                $script:hasFail = $true
                                $script:overallStatus = "FAIL"
                                $script:overallExitCode = 1
                            } elseif ($ExpectedErrorCode -and (-not ($json.PSObject.Properties.Name -contains "error_code") -or $json.error_code -ne $ExpectedErrorCode)) {
                                $status = "FAIL"
                                $notes = "Status $statusCode, but error_code != '$ExpectedErrorCode' (got: $($json.error_code))"
                                $script:hasFail = $true
                                $script:overallStatus = "FAIL"
                                $script:overallExitCode = 1
                            } else {
                                $notes = "Status $statusCode, JSON envelope correct (ok:false, request_id present)"
                            }
                        } catch {
                            $status = "FAIL"
                            $notes = "Status $statusCode, but response is not JSON: $($_.Exception.Message)"
                            $script:hasFail = $true
                            $script:overallStatus = "FAIL"
                            $script:overallExitCode = 1
                        }
                    } else {
                        $notes = "Status $statusCode (expected)"
                    }
                } catch {
                    $status = "FAIL"
                    $notes = "Status $statusCode, but could not read response body: $($_.Exception.Message)"
                    $script:hasFail = $true
                    $script:overallStatus = "FAIL"
                    $script:overallExitCode = 1
                }
            } else {
                $status = "FAIL"
                $notes = "Status $statusCode (expected one of: $($ExpectedStatusCodes -join ', '))"
                $script:hasFail = $true
                $script:overallStatus = "FAIL"
                $script:overallExitCode = 1
            }
        } else {
            $status = "FAIL"
            $notes = "Request failed: $($_.Exception.Message)"
            $script:hasFail = $true
            $script:overallStatus = "FAIL"
            $script:overallExitCode = 1
        }
    }
    
    Add-CheckResult -CheckName $CheckName -Status $status -Notes $notes
}

# Step 1: Read-path surface exists (unauthorized)
Write-Host "Step 1: Read-path surface (unauthorized access)" -ForegroundColor Cyan

foreach ($world in $worlds) {
    Test-ApiResponse -CheckName "GET /api/v1/$world/listings (unauthorized)" `
        -Method "GET" `
        -Url "${BaseUrl}/api/v1/$world/listings" `
        -ExpectedStatusCodes @(401, 403) `
        -ExpectJsonEnvelope $true `
        -ExpectOkFalse $true
}

Write-Host ""

# Step 2: Write governance exists (unauthorized)
Write-Host "Step 2: Write governance (unauthorized access)" -ForegroundColor Cyan

foreach ($world in $worlds) {
    Test-ApiResponse -CheckName "POST /api/v1/$world/listings (unauthorized)" `
        -Method "POST" `
        -Url "${BaseUrl}/api/v1/$world/listings" `
        -ExpectedStatusCodes @(401, 403) `
        -ExpectJsonEnvelope $true `
        -ExpectOkFalse $true
    
    Test-ApiResponse -CheckName "PATCH /api/v1/$world/listings/1 (unauthorized)" `
        -Method "PATCH" `
        -Url "${BaseUrl}/api/v1/$world/listings/1" `
        -ExpectedStatusCodes @(401, 403) `
        -ExpectJsonEnvelope $true `
        -ExpectOkFalse $true
    
    Test-ApiResponse -CheckName "DELETE /api/v1/$world/listings/1 (unauthorized)" `
        -Method "DELETE" `
        -Url "${BaseUrl}/api/v1/$world/listings/1" `
        -ExpectedStatusCodes @(401, 403) `
        -ExpectJsonEnvelope $true `
        -ExpectOkFalse $true
}

Write-Host ""

# Step 3: Authenticated checks (if credentials available)
Write-Host "Step 3: Authenticated checks (read-path + write-stub)" -ForegroundColor Cyan

$testToken = $env:PRODUCT_TEST_TOKEN
$testEmail = $env:PRODUCT_TEST_EMAIL
$testPassword = $env:PRODUCT_TEST_PASSWORD
$testTenantId = $env:PRODUCT_TEST_TENANT_ID

if (-not $testToken -and (-not $testEmail -or -not $testPassword)) {
    Add-CheckResult -CheckName "Authenticated checks" -Status "WARN" -Notes "Credentials not set (PRODUCT_TEST_TOKEN or PRODUCT_TEST_EMAIL + PRODUCT_TEST_PASSWORD required), skipping authenticated checks" -Blocking $false
    Write-Host "  [WARN] Credentials not set, skipping authenticated checks" -ForegroundColor Yellow
    Write-Host "  Set PRODUCT_TEST_TOKEN (Bearer token) OR PRODUCT_TEST_EMAIL + PRODUCT_TEST_PASSWORD environment variables to enable." -ForegroundColor Gray
    Write-Host "  Set PRODUCT_TEST_TENANT_ID environment variable (UUID)." -ForegroundColor Gray
} elseif (-not $testTenantId) {
    Add-CheckResult -CheckName "Authenticated checks" -Status "WARN" -Notes "PRODUCT_TEST_TENANT_ID not set, skipping authenticated checks" -Blocking $false
    Write-Host "  [WARN] PRODUCT_TEST_TENANT_ID not set, skipping authenticated checks" -ForegroundColor Yellow
    Write-Host "  Set PRODUCT_TEST_TENANT_ID environment variable (UUID)." -ForegroundColor Gray
} else {
    # Obtain token if needed (login flow)
    if (-not $testToken -and $testEmail -and $testPassword) {
        Write-Host "  Obtaining token via login..." -ForegroundColor DarkGray
        try {
            $loginBody = @{
                email = $testEmail
                password = $testPassword
            } | ConvertTo-Json
            
            $loginResponse = Invoke-WebRequest -Uri "${BaseUrl}/auth/login" `
                -Method "POST" `
                -Headers @{
                    "Content-Type" = "application/json"
                    "Accept" = "application/json"
                } `
                -Body $loginBody `
                -UseBasicParsing `
                -TimeoutSec 10 `
                -ErrorAction Stop
            
            $loginJson = $loginResponse.Content | ConvertFrom-Json
            $testToken = $loginJson.token
            
            if (-not $testToken) {
                Add-CheckResult -CheckName "Authenticated checks (login)" -Status "FAIL" -Notes "Login succeeded but no token in response"
                Write-Host "  [FAIL] Login succeeded but no token in response" -ForegroundColor Red
            }
        } catch {
            Add-CheckResult -CheckName "Authenticated checks (login)" -Status "FAIL" -Notes "Login failed: $($_.Exception.Message)"
            Write-Host "  [FAIL] Login failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Run authenticated checks only if we have a token
    if ($testToken) {
        $authHeaders = @{
            "Authorization" = "Bearer $testToken"
            "X-Tenant-Id" = $testTenantId
        }
        
        # Read-path checks (should return 200 ok:true)
        foreach ($world in $worlds) {
            Test-ApiResponse -CheckName "GET /api/v1/$world/listings (authenticated)" `
                -Method "GET" `
                -Url "${BaseUrl}/api/v1/$world/listings" `
                -Headers $authHeaders `
                -ExpectedStatusCodes @(200) `
                -ExpectJsonEnvelope $true `
                -ExpectOkTrue $true
        }
        
        # Write-stub checks (should return 501 NOT_IMPLEMENTED)
        foreach ($world in $worlds) {
            Test-ApiResponse -CheckName "POST /api/v1/$world/listings (authenticated, stub)" `
                -Method "POST" `
                -Url "${BaseUrl}/api/v1/$world/listings" `
                -Headers $authHeaders `
                -ExpectedStatusCodes @(501) `
                -ExpectJsonEnvelope $true `
                -ExpectOkFalse $true `
                -ExpectedErrorCode "NOT_IMPLEMENTED"
            
            Test-ApiResponse -CheckName "PATCH /api/v1/$world/listings/1 (authenticated, stub)" `
                -Method "PATCH" `
                -Url "${BaseUrl}/api/v1/$world/listings/1" `
                -Headers $authHeaders `
                -ExpectedStatusCodes @(501) `
                -ExpectJsonEnvelope $true `
                -ExpectOkFalse $true `
                -ExpectedErrorCode "NOT_IMPLEMENTED"
            
            Test-ApiResponse -CheckName "DELETE /api/v1/$world/listings/1 (authenticated, stub)" `
                -Method "DELETE" `
                -Url "${BaseUrl}/api/v1/$world/listings/1" `
                -Headers $authHeaders `
                -ExpectedStatusCodes @(501) `
                -ExpectJsonEnvelope $true `
                -ExpectOkFalse $true `
                -ExpectedErrorCode "NOT_IMPLEMENTED"
        }
    }
}

Write-Host ""

# Print results table
Write-Host "=== PRODUCT SPINE SMOKE TEST RESULTS ===" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table -Property Check, Status, Notes -AutoSize
Write-Host ""

# Overall status
Write-Host "OVERALL STATUS: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
Write-Host ""

# Exit
Invoke-OpsExit $overallExitCode





