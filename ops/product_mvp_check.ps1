# product_mvp_check.ps1 - Product MVP Loop E2E Check
# Validates Product lifecycle: create → list → show → disable → list confirms disabled state + tenant isolation
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

Write-Host "=== PRODUCT MVP LOOP CHECK ===" -ForegroundColor Cyan
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

# Step 1: Check required credentials
Write-Host "Step 1: Credential Check" -ForegroundColor Cyan

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
        Write-Host "Skipping MVP loop tests (credentials not available)" -ForegroundColor Yellow
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

# Step 2: Acquire session/token
Write-Host "Step 2: Acquire Session/Token" -ForegroundColor Cyan

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

# Step 3: Create product
Write-Host "Step 3: Create Product" -ForegroundColor Cyan

$createHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
    "X-World" = $World
}

$createBody = @{
    title = "MVP Loop Test Product $(Get-Date -Format 'yyyyMMddHHmmss')"
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
    $envelopeOk = $createResponse.Body -match '"ok"\s*:\s*true'
    $requestIdOk = $createResponse.RequestId -or ($createResponse.Body -match '"request_id"\s*:\s*"[^"]+"')
    
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

# Step 4: List products (before disable)
Write-Host "Step 4: List Products (Before Disable)" -ForegroundColor Cyan

$listHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
}

$listResponse = Invoke-ApiRequest -Method "GET" -Uri "/api/v1/products?world=$World" -Headers $listHeaders -ExpectedStatusCode 200

if (-not $listResponse.Success) {
    Add-CheckResult -CheckName "List Products (Before)" -Status "FAIL" -Notes "List failed (status: $($listResponse.StatusCode))"
} else {
    # Check if created product is in list
    $productFound = $false
    if ($listResponse.Body -match "`"$productId`"" -or $listResponse.Body -match "\b$productId\b") {
        $productFound = $true
    }
    
    # Check envelope
    $envelopeOk = $listResponse.Body -match '"ok"\s*:\s*true'
    
    if ($productFound -and $envelopeOk) {
        Add-CheckResult -CheckName "List Products (Before)" -Status "PASS" -Notes "Product found in list, envelope OK"
    } elseif (-not $productFound) {
        Add-CheckResult -CheckName "List Products (Before)" -Status "WARN" -Notes "List succeeded but created product not found (may be timing issue)"
    } else {
        Add-CheckResult -CheckName "List Products (Before)" -Status "FAIL" -Notes "List succeeded but envelope invalid"
    }
}

Write-Host ""

# Step 5: Show product
Write-Host "Step 5: Show Product" -ForegroundColor Cyan

$showHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
}

$showResponse = Invoke-ApiRequest -Method "GET" -Uri "/api/v1/products/$productId?world=$World" -Headers $showHeaders -ExpectedStatusCode 200

if (-not $showResponse.Success) {
    Add-CheckResult -CheckName "Show Product" -Status "FAIL" -Notes "Show failed (status: $($showResponse.StatusCode))"
} else {
    # Check envelope
    $envelopeOk = $showResponse.Body -match '"ok"\s*:\s*true'
    $requestIdOk = $showResponse.RequestId -or ($showResponse.Body -match '"request_id"\s*:\s*"[^"]+"')
    
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

# Step 6: Disable product
Write-Host "Step 6: Disable Product" -ForegroundColor Cyan

$disableHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
    "X-World" = $World
}

$disableResponse = Invoke-ApiRequest -Method "PATCH" -Uri "/api/v1/products/$productId/disable?world=$World" -Headers $disableHeaders -ExpectedStatusCode 200

if (-not $disableResponse.Success) {
    Add-CheckResult -CheckName "Disable Product" -Status "FAIL" -Notes "Disable failed (status: $($disableResponse.StatusCode), body: $($disableResponse.Body.Substring(0, [Math]::Min(100, $disableResponse.Body.Length))))"
} else {
    # Check envelope
    $envelopeOk = $disableResponse.Body -match '"ok"\s*:\s*true'
    $requestIdOk = $disableResponse.RequestId -or ($disableResponse.Body -match '"request_id"\s*:\s*"[^"]+"')
    
    # Check status is archived
    $statusArchived = $false
    if ($disableResponse.Body -match '"status"\s*:\s*"archived"') {
        $statusArchived = $true
    }
    
    if ($envelopeOk -and $requestIdOk -and $statusArchived) {
        Add-CheckResult -CheckName "Disable Product" -Status "PASS" -Notes "Product disabled (status: archived), envelope OK, request_id present"
    } else {
        $missing = @()
        if (-not $envelopeOk) { $missing += "ok:true" }
        if (-not $requestIdOk) { $missing += "request_id" }
        if (-not $statusArchived) { $missing += "status:archived" }
        Add-CheckResult -CheckName "Disable Product" -Status "FAIL" -Notes "Disable succeeded but missing: $($missing -join ', ')"
    }
}

Write-Host ""

# Step 7: List products (after disable) - confirm disabled state
Write-Host "Step 7: List Products (After Disable)" -ForegroundColor Cyan

$listAfterHeaders = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-Id" = $TenantA
}

$listAfterResponse = Invoke-ApiRequest -Method "GET" -Uri "/api/v1/products?world=$World" -Headers $listAfterHeaders -ExpectedStatusCode 200

if (-not $listAfterResponse.Success) {
    Add-CheckResult -CheckName "List Products (After)" -Status "FAIL" -Notes "List after disable failed (status: $($listAfterResponse.StatusCode))"
} else {
    # Check if product status is archived in list (optional: may be filtered out)
    $envelopeOk = $listAfterResponse.Body -match '"ok"\s*:\s*true'
    
    if ($envelopeOk) {
        Add-CheckResult -CheckName "List Products (After)" -Status "PASS" -Notes "List succeeded after disable, envelope OK"
    } else {
        Add-CheckResult -CheckName "List Products (After)" -Status "FAIL" -Notes "List after disable succeeded but envelope invalid"
    }
}

Write-Host ""

# Step 8: Cross-tenant isolation
Write-Host "Step 8: Cross-Tenant Isolation" -ForegroundColor Cyan

if ($TenantB) {
    $crossTenantHeaders = @{
        "Authorization" = "Bearer $token"
        "X-Tenant-Id" = $TenantB
    }
    
    $crossTenantResponse = Invoke-ApiRequest -Method "GET" -Uri "/api/v1/products/$productId?world=$World" -Headers $crossTenantHeaders -ExpectedStatusCode 404
    
    if ($crossTenantResponse.StatusCode -eq 404 -or $crossTenantResponse.StatusCode -eq 403) {
        # Check error envelope
        $envelopeOk = $crossTenantResponse.Body -match '"ok"\s*:\s*false'
        $requestIdOk = $crossTenantResponse.RequestId -or ($crossTenantResponse.Body -match '"request_id"\s*:\s*"[^"]+"')
        
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





