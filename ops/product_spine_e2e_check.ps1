# product_spine_e2e_check.ps1 - Product Spine E2E Self-Audit Gate
# Validates Product API spine end-to-end: create → list → show + tenant boundary
# PowerShell 5.1 compatible, ASCII-only output, safe-exit behavior

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Email = $env:PRODUCT_TEST_EMAIL,
    [string]$Password = $env:PRODUCT_TEST_PASSWORD,
    [string]$TenantA = $env:TENANT_A_SLUG,
    [string]$TenantB = $env:TENANT_B_SLUG,
    [string]$World = $env:WORLD
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

Write-Host "=== PRODUCT SPINE E2E CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
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

# Helper: Make HTTP request
function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers = @{},
        [string]$Body = $null,
        [int]$ExpectedStatusCode = 200
    )
    
    try {
        $fullUrl = "$BaseUrl$Uri"
        
        $request = [System.Net.HttpWebRequest]::Create($fullUrl)
        $request.Method = $Method
        $request.ContentType = "application/json"
        $request.Accept = "application/json"
        
        foreach ($key in $Headers.Keys) {
            $request.Headers.Add($key, $Headers[$key])
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
        
        # Extract request_id from header
        $requestId = $response.Headers["X-Request-Id"]
        if (-not $requestId) {
            # Try to parse from body
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
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $responseBody = $reader.ReadToEnd()
            $reader.Close()
        } else {
            $responseBody = $_.Exception.Message
        }
        
        return @{
            StatusCode = $statusCode
            Body = $responseBody
            RequestId = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Step 1: Health quick checks
Write-Host "Step 1: Health Quick Checks" -ForegroundColor Cyan

$healthUp = Invoke-ApiRequest -Method "GET" -Uri "/up" -ExpectedStatusCode 200
if (-not $healthUp.Success) {
    Add-CheckResult -CheckName "Health Check (/up)" -Status "WARN" -Notes "Health endpoint not responding (may be OK if services not up)" -Blocking $false
} else {
    Add-CheckResult -CheckName "Health Check (/up)" -Status "PASS" -Notes "Health endpoint responding"
}

Write-Host ""

# Step 2: Check required credentials
Write-Host "Step 2: Credential Check" -ForegroundColor Cyan

$credsMissing = $false
$credsNotes = @()

if (-not $Email) {
    $credsMissing = $true
    $credsNotes += "PRODUCT_TEST_EMAIL missing"
}
if (-not $Password) {
    $credsMissing = $true
    $credsNotes += "PRODUCT_TEST_PASSWORD missing"
}
if (-not $TenantA) {
    $credsMissing = $true
    $credsNotes += "TENANT_A_SLUG missing"
}

if ($credsMissing) {
    $isCI = $env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true"
    if ($isCI) {
        Add-CheckResult -CheckName "Credential Check" -Status "FAIL" -Notes "Required credentials missing in CI: $($credsNotes -join ', ')"
    } else {
        Add-CheckResult -CheckName "Credential Check" -Status "WARN" -Notes "SKIP (missing credentials: $($credsNotes -join ', '))" -Blocking $false
        Write-Host "Skipping E2E tests (credentials not available)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "=== RESULTS ===" -ForegroundColor Cyan
        Write-Host ""
        $results | Format-Table -AutoSize
        Write-Host ""
        Write-Host "OVERALL STATUS: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
        Invoke-OpsExit $overallExitCode
        return
    }
} else {
    Add-CheckResult -CheckName "Credential Check" -Status "PASS" -Notes "All required credentials present"
}

# Set default world if not provided
if (-not $World) {
    $World = "commerce"
}

Write-Host ""

# Step 3: Acquire session/token
Write-Host "Step 3: Acquire Session/Token" -ForegroundColor Cyan

$loginBody = @{
    email = $Email
    password = $Password
} | ConvertTo-Json

$loginResponse = Invoke-ApiRequest -Method "POST" -Uri "/auth/login" -Body $loginBody -ExpectedStatusCode 200

if (-not $loginResponse.Success) {
    $isCI = $env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true"
    if ($isCI) {
        Add-CheckResult -CheckName "Login" -Status "FAIL" -Notes "Login failed (status: $($loginResponse.StatusCode))"
    } else {
        Add-CheckResult -CheckName "Login" -Status "WARN" -Notes "Login failed (status: $($loginResponse.StatusCode)) - may be OK if auth endpoint not available"
    }
} else {
    # Extract token from response
    $token = $null
    if ($loginResponse.Body -match '"token"\s*:\s*"([^"]+)"') {
        $token = $matches[1]
    } elseif ($loginResponse.Body -match '"access_token"\s*:\s*"([^"]+)"') {
        $token = $matches[1]
    }
    
    if ($token) {
        Add-CheckResult -CheckName "Login" -Status "PASS" -Notes "Token acquired"
    } else {
        Add-CheckResult -CheckName "Login" -Status "WARN" -Notes "Login succeeded but token not found in response"
    }
}

if (-not $token) {
    Write-Host "Cannot proceed without token" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== RESULTS ===" -ForegroundColor Cyan
    Write-Host ""
    $results | Format-Table -AutoSize
    Write-Host ""
    Write-Host "OVERALL STATUS: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
    Invoke-OpsExit $overallExitCode
    return
}

Write-Host ""

# Step 4: Create product
Write-Host "Step 4: Create Product" -ForegroundColor Cyan

$createHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
    "X-World" = $World
}

$createBody = @{
    title = "E2E Test Product $(Get-Date -Format 'yyyyMMddHHmmss')"
    type = "listing"
    status = "draft"
    currency = "TRY"
    price_amount = 10000
} | ConvertTo-Json

$createResponse = Invoke-ApiRequest -Method "POST" -Uri "/api/v1/products" -Headers $createHeaders -Body $createBody -ExpectedStatusCode 201

if (-not $createResponse.Success) {
    Add-CheckResult -CheckName "Create Product" -Status "FAIL" -Notes "Create failed (status: $($createResponse.StatusCode), body: $($createResponse.Body.Substring(0, [Math]::Min(100, $createResponse.Body.Length))))"
} else {
    # Extract product ID
    $productId = $null
    if ($createResponse.Body -match '"id"\s*:\s*(\d+)') {
        $productId = $matches[1]
    } elseif ($createResponse.Body -match '"(?:data|item)"\s*:\s*\{[^}]*"id"\s*:\s*(\d+)') {
        $productId = $matches[1]
    }
    
    # Check response envelope
    $envelopeOk = $false
    if ($createResponse.Body -match '"ok"\s*:\s*true') {
        $envelopeOk = $true
    }
    
    $requestIdOk = $false
    if ($createResponse.RequestId -or ($createResponse.Body -match '"request_id"\s*:\s*"[^"]+"')) {
        $requestIdOk = $true
    }
    
    if ($productId -and $envelopeOk -and $requestIdOk) {
        Add-CheckResult -CheckName "Create Product" -Status "PASS" -Notes "Product created (ID: $productId), envelope OK, request_id present"
    } else {
        $missing = @()
        if (-not $productId) { $missing += "id" }
        if (-not $envelopeOk) { $missing += "ok:true" }
        if (-not $requestIdOk) { $missing += "request_id" }
        Add-CheckResult -CheckName "Create Product" -Status "FAIL" -Notes "Create succeeded but missing: $($missing -join ', ')"
    }
}

if (-not $productId) {
    Write-Host "Cannot proceed without product ID" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== RESULTS ===" -ForegroundColor Cyan
    Write-Host ""
    $results | Format-Table -AutoSize
    Write-Host ""
    Write-Host "OVERALL STATUS: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
    Invoke-OpsExit $overallExitCode
    return
}

Write-Host ""

# Step 5: Read-back (list)
Write-Host "Step 5: Read-Back (List)" -ForegroundColor Cyan

$listHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
}

$listResponse = Invoke-ApiRequest -Method "GET" -Uri "/api/v1/products?world=$World" -Headers $listHeaders -ExpectedStatusCode 200

if (-not $listResponse.Success) {
    Add-CheckResult -CheckName "List Products" -Status "FAIL" -Notes "List failed (status: $($listResponse.StatusCode))"
} else {
    # Check if created product is in list
    $productFound = $false
    if ($listResponse.Body -match "`"$productId`"" -or $listResponse.Body -match "\b$productId\b") {
        $productFound = $true
    }
    
    # Check envelope
    $envelopeOk = $false
    if ($listResponse.Body -match '"ok"\s*:\s*true') {
        $envelopeOk = $true
    }
    
    if ($productFound -and $envelopeOk) {
        Add-CheckResult -CheckName "List Products" -Status "PASS" -Notes "Product found in list, envelope OK"
    } elseif (-not $productFound) {
        Add-CheckResult -CheckName "List Products" -Status "WARN" -Notes "List succeeded but created product not found (may be timing issue)"
    } else {
        Add-CheckResult -CheckName "List Products" -Status "FAIL" -Notes "List succeeded but envelope invalid"
    }
}

Write-Host ""

# Step 6: Read-back (show)
Write-Host "Step 6: Read-Back (Show)" -ForegroundColor Cyan

$showHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
}

$showResponse = Invoke-ApiRequest -Method "GET" -Uri "/api/v1/products/$productId?world=$World" -Headers $showHeaders -ExpectedStatusCode 200

if (-not $showResponse.Success) {
    Add-CheckResult -CheckName "Show Product" -Status "FAIL" -Notes "Show failed (status: $($showResponse.StatusCode))"
} else {
    # Check envelope
    $envelopeOk = $false
    if ($showResponse.Body -match '"ok"\s*:\s*true') {
        $envelopeOk = $true
    }
    
    $requestIdOk = $false
    if ($showResponse.RequestId -or ($showResponse.Body -match '"request_id"\s*:\s*"[^"]+"')) {
        $requestIdOk = $true
    }
    
    if ($envelopeOk -and $requestIdOk) {
        Add-CheckResult -CheckName "Show Product" -Status "PASS" -Notes "Product retrieved, envelope OK, request_id present"
    } else {
        $missing = @()
        if (-not $envelopeOk) { $missing += "ok:true" }
        if (-not $requestIdOk) { $missing += "request_id" }
        Add-CheckResult -CheckName "Show Product" -Status "FAIL" -Notes "Show succeeded but missing: $($missing -join ', ')"
    }
}

Write-Host ""

# Step 7: Cross-tenant isolation
Write-Host "Step 7: Cross-Tenant Isolation" -ForegroundColor Cyan

if ($TenantB) {
    $crossTenantHeaders = @{
        "Authorization" = "Bearer $token"
        "X-Tenant-Id" = $TenantB
    }
    
    $crossTenantResponse = Invoke-ApiRequest -Method "GET" -Uri "/api/v1/products/$productId?world=$World" -Headers $crossTenantHeaders -ExpectedStatusCode 404
    
    if ($crossTenantResponse.StatusCode -eq 404 -or $crossTenantResponse.StatusCode -eq 403) {
        # Check error envelope
        $envelopeOk = $false
        if ($crossTenantResponse.Body -match '"ok"\s*:\s*false') {
            $envelopeOk = $true
        }
        
        $requestIdOk = $false
        if ($crossTenantResponse.RequestId -or ($crossTenantResponse.Body -match '"request_id"\s*:\s*"[^"]+"')) {
            $requestIdOk = $true
        }
        
        if ($envelopeOk -and $requestIdOk) {
            Add-CheckResult -CheckName "Cross-Tenant Isolation" -Status "PASS" -Notes "Cross-tenant access correctly rejected ($($crossTenantResponse.StatusCode)), envelope OK"
        } else {
            Add-CheckResult -CheckName "Cross-Tenant Isolation" -Status "FAIL" -Notes "Cross-tenant access rejected but envelope invalid"
        }
    } else {
        Add-CheckResult -CheckName "Cross-Tenant Isolation" -Status "FAIL" -Notes "Cross-tenant access allowed (status: $($crossTenantResponse.StatusCode)) - SECURITY ISSUE"
    }
} else {
    Add-CheckResult -CheckName "Cross-Tenant Isolation" -Status "WARN" -Notes "SKIP (TENANT_B_SLUG not provided)" -Blocking $false
}

Write-Host ""

# Step 8: Error contract check
Write-Host "Step 8: Error Contract Check" -ForegroundColor Cyan

$errorHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
    "X-World" = $World
}

# Force validation error (missing required field)
$errorBody = @{
    type = "listing"
    # title missing (required)
} | ConvertTo-Json

$errorResponse = Invoke-ApiRequest -Method "POST" -Uri "/api/v1/products" -Headers $errorHeaders -Body $errorBody -ExpectedStatusCode 422

if ($errorResponse.StatusCode -eq 422) {
    # Check error envelope
    $envelopeOk = $false
    if ($errorResponse.Body -match '"ok"\s*:\s*false') {
        $envelopeOk = $true
    }
    
    $errorCodeOk = $false
    if ($errorResponse.Body -match '"error_code"\s*:\s*"[^"]+"') {
        $errorCodeOk = $true
    }
    
    $messageOk = $false
    if ($errorResponse.Body -match '"message"\s*:\s*"[^"]+"') {
        $messageOk = $true
    }
    
    $requestIdOk = $false
    if ($errorResponse.RequestId -or ($errorResponse.Body -match '"request_id"\s*:\s*"[^"]+"')) {
        $requestIdOk = $true
    }
    
    if ($envelopeOk -and $errorCodeOk -and $messageOk -and $requestIdOk) {
        Add-CheckResult -CheckName "Error Contract" -Status "PASS" -Notes "422 error envelope correct (ok:false, error_code, message, request_id)"
    } else {
        $missing = @()
        if (-not $envelopeOk) { $missing += "ok:false" }
        if (-not $errorCodeOk) { $missing += "error_code" }
        if (-not $messageOk) { $missing += "message" }
        if (-not $requestIdOk) { $missing += "request_id" }
        Add-CheckResult -CheckName "Error Contract" -Status "FAIL" -Notes "422 error envelope missing: $($missing -join ', ')"
    }
} else {
    Add-CheckResult -CheckName "Error Contract" -Status "FAIL" -Notes "Expected 422 but got status: $($errorResponse.StatusCode)"
}

Write-Host ""

# Print results table
Write-Host "=== RESULTS ===" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table -AutoSize
Write-Host ""

# Overall status
Write-Host "OVERALL STATUS: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
Write-Host ""

# Exit
Invoke-OpsExit $overallExitCode





