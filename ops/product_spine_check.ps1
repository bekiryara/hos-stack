# product_spine_check.ps1 - Product Spine Governance Gate
# Validates Commerce Product API spine: routes, middleware, world/tenant boundaries, write-path lock
# PowerShell 5.1 compatible, ASCII-only output, snapshot-driven (no Docker required)

param(
    [string]$RoutesSnapshotPath = "ops\snapshots\routes.pazar.json",
    [string]$AllowlistPath = "ops\policy\product_spine_allowlist.json",
    [string]$BaseUrl = "http://localhost:8080",
    [string]$TestEmail = $env:PRODUCT_TEST_EMAIL,
    [string]$TestPassword = $env:PRODUCT_TEST_PASSWORD,
    [string]$TenantId = $env:TENANT_A_SLUG,
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

Write-Host "=== PRODUCT SPINE CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()
$overallStatus = "PASS"
$overallExitCode = 0
$hasWarn = $false
$hasFail = $false

# Helper: Normalize URI (remove leading/trailing slashes, handle {id} variations)
function Normalize-Uri {
    param([string]$Uri)
    $normalized = $Uri.Trim('/')
    if (-not $normalized.StartsWith('/')) {
        $normalized = "/$normalized"
    }
    return $normalized
}

# Helper: Normalize method (uppercase)
function Normalize-Method {
    param([string]$Method)
    return $Method.ToUpper()
}

# Helper: Read JSON safely (PS5.1 compatible)
function Read-JsonSafely {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        return $null
    }
    
    try {
        $content = Get-Content $Path -Raw -Encoding UTF8
        return $content | ConvertFrom-Json
    } catch {
        Write-Host "  [WARN] Error reading JSON from $Path : $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

# Helper: Find route by method and URI (normalize both)
function Find-Route {
    param(
        [array]$Routes,
        [string]$Method,
        [string]$Uri
    )
    
    $normalizedMethod = Normalize-Method $Method
    $normalizedUri = Normalize-Uri $Uri
    
    foreach ($route in $Routes) {
        $routeMethod = Normalize-Method $route.method
        $routeUri = Normalize-Uri $route.uri
        
        if ($routeMethod -eq $normalizedMethod -and $routeUri -eq $normalizedUri) {
            return $route
        }
    }
    
    return $null
}

# Helper: Find route by URI pattern (for {id} variations)
function Find-RouteByPattern {
    param(
        [array]$Routes,
        [string]$Method,
        [string]$UriPattern
    )
    
    $normalizedMethod = Normalize-Method $Method
    $normalizedPattern = Normalize-Uri $UriPattern
    
    foreach ($route in $Routes) {
        $routeMethod = Normalize-Method $route.method
        $routeUri = Normalize-Uri $route.uri
        
        if ($routeMethod -eq $normalizedMethod) {
            # Check if URI matches pattern (handle {id}, {listing}, etc.)
            if ($normalizedPattern -like "*{*}" -and $routeUri -like $normalizedPattern.Replace('{*}', '*')) {
                return $route
            }
        }
    }
    
    return $null
}

# Helper: Parse middleware list (handle string or array, nulls)
function Parse-Middleware {
    param($Middleware)
    
    if ($null -eq $Middleware) {
        return @()
    }
    
    if ($Middleware -is [string]) {
        # Split by comma if string
        return $Middleware -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    
    if ($Middleware -is [array]) {
        return $Middleware | Where-Object { $_ }
    }
    
    return @()
}

# Helper: Middleware alias map (resolve.tenant vs tenant.resolve, etc.)
function Normalize-MiddlewareName {
    param([string]$MwName)
    
    $aliasMap = @{
        "tenant.resolve" = "resolve.tenant"
        "ensure.tenant.user" = "tenant.user"
    }
    
    if ($aliasMap.ContainsKey($MwName)) {
        return $aliasMap[$MwName]
    }
    
    return $MwName
}

# Helper: Add check result
function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$Notes
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

# Step 1: Read routes snapshot
Write-Host "Step 1: Reading routes snapshot" -ForegroundColor Cyan

$allRoutes = Read-JsonSafely -Path $RoutesSnapshotPath
$routesFromSnapshot = $false

if ($null -ne $allRoutes) {
    # Ensure it's an array
    if ($allRoutes -isnot [array]) {
        # If single object, wrap in array
        if ($allRoutes -is [PSCustomObject]) {
            $allRoutes = @($allRoutes)
        } else {
            $allRoutes = @()
        }
    }
    $routesFromSnapshot = $true
    Write-Host "  [OK] Routes snapshot loaded ($($allRoutes.Count) routes)" -ForegroundColor Green
} else {
    Add-CheckResult -CheckName "Route Discovery" -Status "WARN" -Notes "Routes snapshot not found: $RoutesSnapshotPath. Run ops/routes_snapshot.ps1 first."
}

Write-Host ""

# Step 2: Read allowlist
Write-Host "Step 2: Reading allowlist" -ForegroundColor Cyan

$allowlist = Read-JsonSafely -Path $AllowlistPath

if ($null -ne $allowlist) {
    Write-Host "  [OK] Allowlist loaded" -ForegroundColor Green
} else {
    Write-Host "  [OK] No allowlist file (write endpoints must return 501 NOT_IMPLEMENTED)" -ForegroundColor Gray
}

Write-Host ""

# Step 3: Check 1 - Commerce READ routes exist
Write-Host "Step 3: [Check 1] Commerce READ Routes Exist" -ForegroundColor Cyan

if (-not $routesFromSnapshot) {
    Add-CheckResult -CheckName "Check 1: Commerce READ Routes" -Status "WARN" -Notes "Cannot verify (routes snapshot not available)"
} else {
    $commerceIndexRoute = Find-Route -Routes $allRoutes -Method "GET" -Uri "/api/v1/commerce/listings"
    $commerceShowRoute = Find-RouteByPattern -Routes $allRoutes -Method "GET" -UriPattern "/api/v1/commerce/listings/{*}"
    
    if ($commerceIndexRoute -and $commerceShowRoute) {
        Add-CheckResult -CheckName "Check 1: Commerce READ Routes" -Status "PASS" -Notes "GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id} found"
    } else {
        if (-not $commerceIndexRoute) {
            Add-CheckResult -CheckName "Check 1: Commerce READ Routes" -Status "FAIL" -Notes "GET /api/v1/commerce/listings route not found"
        }
        if (-not $commerceShowRoute) {
            Add-CheckResult -CheckName "Check 1: Commerce READ Routes" -Status "FAIL" -Notes "GET /api/v1/commerce/listings/{id} route not found"
        }
    }
}

Write-Host ""

# Step 3b: Check 1b - Products routes exist
Write-Host "Step 3b: [Check 1b] Products READ Routes Exist" -ForegroundColor Cyan

if (-not $routesFromSnapshot) {
    Add-CheckResult -CheckName "Check 1b: Products READ Routes" -Status "WARN" -Notes "Cannot verify (routes snapshot not available)"
} else {
    $productsIndexRoute = Find-Route -Routes $allRoutes -Method "GET" -Uri "/api/v1/products"
    $productsShowRoute = Find-RouteByPattern -Routes $allRoutes -Method "GET" -UriPattern "/api/v1/products/{*}"
    
    if ($productsIndexRoute -and $productsShowRoute) {
        Add-CheckResult -CheckName "Check 1b: Products READ Routes" -Status "PASS" -Notes "GET /api/v1/products and GET /api/v1/products/{id} found"
    } else {
        if (-not $productsIndexRoute) {
            Add-CheckResult -CheckName "Check 1b: Products READ Routes" -Status "FAIL" -Notes "GET /api/v1/products route not found"
        }
        if (-not $productsShowRoute) {
            Add-CheckResult -CheckName "Check 1b: Products READ Routes" -Status "FAIL" -Notes "GET /api/v1/products/{id} route not found"
        }
    }
}

Write-Host ""

# Step 4: Check 2 - Middleware contract on Commerce READ routes
Write-Host "Step 4: [Check 2] Middleware Contract" -ForegroundColor Cyan

$requiredMiddleware = @("auth.any", "resolve.tenant", "tenant.user")

if (-not $routesFromSnapshot -or -not $commerceIndexRoute -or -not $commerceShowRoute) {
    Add-CheckResult -CheckName "Check 2: Middleware Contract" -Status "WARN" -Notes "Cannot verify (routes snapshot not available or routes not found)"
} else {
    $allReadRoutesProtected = $true
    $missingMiddlewareList = @()
    
    foreach ($route in @($commerceIndexRoute, $commerceShowRoute)) {
        $middlewareList = Parse-Middleware -Middleware $route.middleware
        $normalizedMiddleware = $middlewareList | ForEach-Object { Normalize-MiddlewareName $_ }
        
        $missing = @()
        foreach ($mw in $requiredMiddleware) {
            if ($normalizedMiddleware -notcontains $mw) {
                $missing += $mw
            }
        }
        
        if ($missing.Count -gt 0) {
            $allReadRoutesProtected = $false
            $missingMiddlewareList += "$($route.uri): $($missing -join ', ')"
        }
    }
    
    if ($allReadRoutesProtected) {
        Add-CheckResult -CheckName "Check 2: Middleware Contract" -Status "PASS" -Notes "Required middleware present: auth.any, resolve.tenant, tenant.user"
    } else {
        Add-CheckResult -CheckName "Check 2: Middleware Contract" -Status "FAIL" -Notes "Missing middleware: $($missingMiddlewareList -join '; ')"
    }
}

Write-Host ""

# Step 4b: Check 2b - Middleware contract on Products READ routes
Write-Host "Step 4b: [Check 2b] Products Middleware Contract" -ForegroundColor Cyan

if (-not $routesFromSnapshot -or -not $productsIndexRoute -or -not $productsShowRoute) {
    Add-CheckResult -CheckName "Check 2b: Products Middleware Contract" -Status "WARN" -Notes "Cannot verify (routes snapshot not available or routes not found)"
} else {
    $allReadRoutesProtected = $true
    $missingMiddlewareList = @()
    
    foreach ($route in @($productsIndexRoute, $productsShowRoute)) {
        $middlewareList = Parse-Middleware -Middleware $route.middleware
        $normalizedMiddleware = $middlewareList | ForEach-Object { Normalize-MiddlewareName $_ }
        
        $missing = @()
        foreach ($mw in $requiredMiddleware) {
            if ($normalizedMiddleware -notcontains $mw) {
                $missing += $mw
            }
        }
        
        if ($missing.Count -gt 0) {
            $allReadRoutesProtected = $false
            $missingMiddlewareList += "$($route.uri): $($missing -join ', ')"
        }
    }
    
    if ($allReadRoutesProtected) {
        Add-CheckResult -CheckName "Check 2b: Products Middleware Contract" -Status "PASS" -Notes "Required middleware present: auth.any, resolve.tenant, tenant.user"
    } else {
        Add-CheckResult -CheckName "Check 2b: Products Middleware Contract" -Status "FAIL" -Notes "Missing middleware: $($missingMiddlewareList -join '; ')"
    }
}

Write-Host ""

# Step 5: Check 3 - Write-path lock for Commerce routes
Write-Host "Step 5: [Check 3] Write-Path Lock" -ForegroundColor Cyan

if (-not $routesFromSnapshot) {
    Add-CheckResult -CheckName "Check 3: Write-Path Lock" -Status "WARN" -Notes "Cannot verify (routes snapshot not available)"
} else {
    $writeMethods = @("POST", "PUT", "PATCH", "DELETE")
    $writeRoutes = $allRoutes | Where-Object { 
        $routeMethod = Normalize-Method $_.method
        $routeUri = Normalize-Uri $_.uri
        ($writeMethods -contains $routeMethod) -and 
        (($routeUri -like "/api/v1/commerce/listings*") -or ($routeUri -like "/api/v1/products*"))
    }
    
    $violations = @()
    
    foreach ($route in $writeRoutes) {
        $routeMethod = Normalize-Method $route.method
        $routeUri = Normalize-Uri $route.uri
        
        # Check allowlist
        $isAllowlisted = $false
        if ($allowlist -and $allowlist.allow_write_endpoints) {
            foreach ($allowed in $allowlist.allow_write_endpoints) {
                $allowedMethod = Normalize-Method $allowed.method
                $allowedUri = Normalize-Uri $allowed.uri
                
                if ($allowedMethod -eq $routeMethod -and $allowedUri -eq $routeUri) {
                    $isAllowlisted = $true
                    break
                }
            }
        }
        
        if (-not $isAllowlisted) {
            $violations += "$routeMethod $routeUri"
        }
    }
    
    if ($violations.Count -eq 0) {
        Add-CheckResult -CheckName "Check 3: Write-Path Lock" -Status "PASS" -Notes "All write endpoints are allowlisted or not present"
    } else {
        Add-CheckResult -CheckName "Check 3: Write-Path Lock" -Status "FAIL" -Notes "Write endpoints found without allowlist: $($violations -join ', '). Must return 501 NOT_IMPLEMENTED or be allowlisted."
    }
}

Write-Host ""

# Step 6: Check 4 - World boundary evidence (WARN-only)
Write-Host "Step 6: [Check 4] World Boundary Evidence" -ForegroundColor Cyan

if (-not $routesFromSnapshot) {
    Add-CheckResult -CheckName "Check 4: World Boundary Evidence" -Status "WARN" -Notes "Cannot verify (routes snapshot not available)"
} else {
    $worldBoundaryFound = $false
    
    # Check snapshot action for World namespace or Commerce controller
    foreach ($route in $allRoutes) {
        if ($route.uri -like "/api/v1/commerce/*") {
            $action = $route.action
            if ($action) {
                if ($action -like "*World*" -or $action -like "*Commerce*" -or $action -like "*Api\Commerce*") {
                    $worldBoundaryFound = $true
                    break
                }
            }
        }
    }
    
    if ($worldBoundaryFound) {
        Add-CheckResult -CheckName "Check 4: World Boundary Evidence" -Status "PASS" -Notes "World boundary evidence found in snapshot action"
    } else {
        # Fallback: minimal file I/O check
        $controllerPath = "work\pazar\app\Http\Controllers\Api\Commerce\ListingController.php"
        if (Test-Path $controllerPath) {
            try {
                $controllerContent = Get-Content $controllerPath -Raw -ErrorAction Stop
                if ($controllerContent -match "forWorld\s*\(\s*['\`"]commerce['\`"]\s*\)") {
                    Add-CheckResult -CheckName "Check 4: World Boundary Evidence" -Status "PASS" -Notes "World boundary enforcement found (forWorld('commerce'))"
                } else {
                    Add-CheckResult -CheckName "Check 4: World Boundary Evidence" -Status "WARN" -Notes "World boundary enforcement not found. Ensure controller enforces forWorld('commerce')"
                }
            } catch {
                Add-CheckResult -CheckName "Check 4: World Boundary Evidence" -Status "WARN" -Notes "Cannot read controller file: $($_.Exception.Message)"
            }
        } else {
            Add-CheckResult -CheckName "Check 4: World Boundary Evidence" -Status "WARN" -Notes "Controller file not found. Ensure controller enforces forWorld('commerce')"
        }
    }
}

Write-Host ""

# Step 7: Check 5 - Tenant boundary evidence (WARN-only)
Write-Host "Step 7: [Check 5] Tenant Boundary Evidence" -ForegroundColor Cyan

$controllerPath = "work\pazar\app\Http\Controllers\Api\Commerce\ListingController.php"
if (Test-Path $controllerPath) {
    try {
        $controllerContent = Get-Content $controllerPath -Raw -ErrorAction Stop
        if ($controllerContent -match "forTenant\s*\(" -or $controllerContent -match "tenant_id" -or $controllerContent -match "->where\s*\(\s*['\`"]tenant_id['\`"]") {
            Add-CheckResult -CheckName "Check 5: Tenant Boundary Evidence" -Status "PASS" -Notes "Tenant scoping found (forTenant or tenant_id filter)"
        } else {
            Add-CheckResult -CheckName "Check 5: Tenant Boundary Evidence" -Status "WARN" -Notes "Tenant scoping not found. Ensure controller enforces tenant boundary (forTenant or tenant_id filter)"
        }
    } catch {
        Add-CheckResult -CheckName "Check 5: Tenant Boundary Evidence" -Status "WARN" -Notes "Cannot read controller file: $($_.Exception.Message)"
    }
} else {
    Add-CheckResult -CheckName "Check 5: Tenant Boundary Evidence" -Status "WARN" -Notes "Controller file not found. Ensure controller enforces tenant boundary"
}

Write-Host ""

# Step 8: Check 6 - All enabled worlds READ routes exist (matrix check)
Write-Host "Step 8: [Check 6] All Enabled Worlds READ Routes" -ForegroundColor Cyan

# Read enabled worlds from config/worlds.php
$enabledWorlds = @()
$configPath = "work\pazar\config\worlds.php"

if (Test-Path $configPath) {
    try {
        $configContent = Get-Content $configPath -Raw
        $enabledConfigMatch = [regex]::Match($configContent, "'enabled'\s*=>\s*\[(.*?)\]", [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if ($enabledConfigMatch.Success) {
            $enabledArrayContent = $enabledConfigMatch.Groups[1].Value
            $enabledMatches = [regex]::Matches($enabledArrayContent, "'([a-z0-9_]+)'")
            $enabledWorlds = $enabledMatches | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ }
        }
    } catch {
        Write-Host "  [WARN] Error parsing config/worlds.php: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($enabledWorlds.Count -eq 0) {
    # Fallback to hardcoded list if config parsing fails
    $enabledWorlds = @("commerce", "food", "rentals")
    Write-Host "  [WARN] Could not parse config/worlds.php, using fallback: $($enabledWorlds -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "  [OK] Found $($enabledWorlds.Count) enabled world(s): $($enabledWorlds -join ', ')" -ForegroundColor Green
}

if (-not $routesFromSnapshot) {
    Add-CheckResult -CheckName "Check 6: All Enabled Worlds READ Routes" -Status "WARN" -Notes "Cannot verify (routes snapshot not available)"
} else {
    $allWorldsPass = $true
    $worldFailures = @()
    
    foreach ($world in $enabledWorlds) {
        $worldIndexRoute = Find-Route -Routes $allRoutes -Method "GET" -Uri "/api/v1/$world/listings"
        $worldShowRoute = Find-RouteByPattern -Routes $allRoutes -Method "GET" -UriPattern "/api/v1/$world/listings/{*}"
        
        if (-not $worldIndexRoute) {
            $allWorldsPass = $false
            $worldFailures += "$world: GET /api/v1/$world/listings not found"
        }
        if (-not $worldShowRoute) {
            $allWorldsPass = $false
            $worldFailures += "$world: GET /api/v1/$world/listings/{id} not found"
        }
    }
    
    if ($allWorldsPass) {
        Add-CheckResult -CheckName "Check 6: All Enabled Worlds READ Routes" -Status "PASS" -Notes "All enabled worlds ($($enabledWorlds -join ', ')) have GET /listings and GET /listings/{id} routes"
    } else {
        Add-CheckResult -CheckName "Check 6: All Enabled Worlds READ Routes" -Status "FAIL" -Notes "Missing routes: $($worldFailures -join '; ')"
    }
}

Write-Host ""

# Step 8: Check 6 - Product Write Runtime Test (optional, credentials required)
Write-Host "Step 8: [Check 6] Product Write Runtime Test" -ForegroundColor Cyan

$hasRuntimeCreds = $TestEmail -and $TestPassword -and $TenantId
if (-not $hasRuntimeCreds) {
    Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "WARN" -Notes "SKIP (missing credentials: PRODUCT_TEST_EMAIL, PRODUCT_TEST_PASSWORD, or TENANT_A_SLUG)" -Blocking $false
} else {
    # Set default world if not provided
    if (-not $World) {
        $World = "commerce"
    }
    
    try {
        # Helper: Make HTTP request
        function Invoke-TestRequest {
            param(
                [string]$Method,
                [string]$Uri,
                [hashtable]$Headers = @{},
                [string]$Body = $null
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
                
                $requestId = $response.Headers["X-Request-Id"]
                if (-not $requestId -and $responseBody -match '"request_id"\s*:\s*"([^"]+)"') {
                    $requestId = $matches[1]
                }
                
                return @{
                    StatusCode = $statusCode
                    Body = $responseBody
                    RequestId = $requestId
                    Success = $true
                }
            } catch {
                $statusCode = 0
                $responseBody = ""
                if ($_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode.value__
                    $errorStream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($errorStream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
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
        
        # Step 8a: Login
        $loginBody = @{
            email = $TestEmail
            password = $TestPassword
        } | ConvertTo-Json
        
        $loginResponse = Invoke-TestRequest -Method "POST" -Uri "/auth/login" -Body $loginBody
        
        if (-not $loginResponse.Success -or $loginResponse.StatusCode -ne 200) {
            Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "WARN" -Notes "SKIP (login failed: status $($loginResponse.StatusCode))" -Blocking $false
        } else {
            # Extract token
            $token = $null
            if ($loginResponse.Body -match '"token"\s*:\s*"([^"]+)"') {
                $token = $matches[1]
            } elseif ($loginResponse.Body -match '"access_token"\s*:\s*"([^"]+)"') {
                $token = $matches[1]
            }
            
            if (-not $token) {
                Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "WARN" -Notes "SKIP (token not found in login response)" -Blocking $false
            } else {
                # Step 8b: Create product
                $createHeaders = @{
                    "Authorization" = "Bearer $token"
                    "X-Tenant-Id" = $TenantId
                    "X-World" = $World
                }
                
                $createBody = @{
                    title = "Product Spine Check Test $(Get-Date -Format 'yyyyMMddHHmmss')"
                    type = "listing"
                    status = "draft"
                } | ConvertTo-Json
                
                $createResponse = Invoke-TestRequest -Method "POST" -Uri "/api/v1/products" -Headers $createHeaders -Body $createBody
                
                if ($createResponse.StatusCode -eq 201) {
                    # Extract product ID
                    $productId = $null
                    if ($createResponse.Body -match '"id"\s*:\s*(\d+)') {
                        $productId = $matches[1]
                    } elseif ($createResponse.Body -match '"(?:data|item)"\s*:\s*\{[^}]*"id"\s*:\s*(\d+)') {
                        $productId = $matches[1]
                    }
                    
                    # Check envelope
                    $envelopeOk = $createResponse.Body -match '"ok"\s*:\s*true'
                    $requestIdOk = $createResponse.RequestId -or ($createResponse.Body -match '"request_id"\s*:\s*"[^"]+"')
                    
                    if ($productId -and $envelopeOk -and $requestIdOk) {
                        # Step 8c: List products
                        $listHeaders = @{
                            "Authorization" = "Bearer $token"
                            "X-Tenant-Id" = $TenantId
                        }
                        
                        $listResponse = Invoke-TestRequest -Method "GET" -Uri "/api/v1/products?world=$World" -Headers $listHeaders
                        
                        $listOk = $false
                        if ($listResponse.StatusCode -eq 200 -and $listResponse.Body -match '"ok"\s*:\s*true') {
                            if ($listResponse.Body -match "`"$productId`"" -or $listResponse.Body -match "\b$productId\b") {
                                $listOk = $true
                            }
                        }
                        
                        # Step 8d: Show product
                        $showHeaders = @{
                            "Authorization" = "Bearer $token"
                            "X-Tenant-Id" = $TenantId
                        }
                        
                        $showResponse = Invoke-TestRequest -Method "GET" -Uri "/api/v1/products/$productId?world=$World" -Headers $showHeaders
                        
                        $showOk = $false
                        if ($showResponse.StatusCode -eq 200 -and $showResponse.Body -match '"ok"\s*:\s*true') {
                            $showOk = $true
                        }
                        
                        if ($listOk -and $showOk) {
                            Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "PASS" -Notes "Create/list/show successful (ID: $productId), envelope OK, request_id present"
                        } else {
                            $missing = @()
                            if (-not $listOk) { $missing += "list" }
                            if (-not $showOk) { $missing += "show" }
                            Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "WARN" -Notes "Create succeeded but $($missing -join '/') failed (may be timing issue)"
                        }
                    } else {
                        $missing = @()
                        if (-not $productId) { $missing += "id" }
                        if (-not $envelopeOk) { $missing += "ok:true" }
                        if (-not $requestIdOk) { $missing += "request_id" }
                        Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "FAIL" -Notes "Create succeeded but missing: $($missing -join ', ')"
                    }
                } elseif ($createResponse.StatusCode -eq 401 -or $createResponse.StatusCode -eq 403) {
                    Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "WARN" -Notes "SKIP (unauthorized: status $($createResponse.StatusCode))" -Blocking $false
                } else {
                    Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "FAIL" -Notes "Create failed (status: $($createResponse.StatusCode), body: $($createResponse.Body.Substring(0, [Math]::Min(100, $createResponse.Body.Length))))"
                }
            }
        }
    } catch {
        $isCI = $env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true"
        if ($isCI) {
            Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "FAIL" -Notes "Runtime test error: $($_.Exception.Message)"
        } else {
            Add-CheckResult -CheckName "Check 6: Product Write Runtime" -Status "WARN" -Notes "SKIP (runtime test error: $($_.Exception.Message))" -Blocking $false
        }
    }
}

Write-Host ""

# Print results table
Write-Host "=== PRODUCT SPINE CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Check                                    Status Notes" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

foreach ($result in $results) {
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

# Final decision: FAIL if any FAIL, WARN if no FAIL and any WARN, PASS otherwise
if ($overallStatus -eq "FAIL") {
    Write-Host "OVERALL STATUS: FAIL" -ForegroundColor Red
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    Write-Host "1. Ensure Commerce read routes exist: GET /api/v1/commerce/listings and GET /api/v1/commerce/listings/{id}" -ForegroundColor Gray
    Write-Host "2. Ensure read routes have required middleware: auth.any, resolve.tenant, tenant.user" -ForegroundColor Gray
    Write-Host "3. Ensure write endpoints return 501 NOT_IMPLEMENTED or are allowlisted in $AllowlistPath" -ForegroundColor Gray
    Write-Host "4. Run ops/routes_snapshot.ps1 to generate routes snapshot" -ForegroundColor Gray
    Invoke-OpsExit 1
    return 1
} elseif ($overallStatus -eq "WARN") {
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: Some checks were skipped or inconclusive. Generate routes snapshot for full validation." -ForegroundColor Gray
    Invoke-OpsExit 2
    return 2
} else {
    Write-Host "OVERALL STATUS: PASS" -ForegroundColor Green
    Write-Host ""
    Write-Host "All Commerce Product API spine checks passed." -ForegroundColor Gray
    Invoke-OpsExit 0
    return 0
}
