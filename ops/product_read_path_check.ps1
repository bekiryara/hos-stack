# product_read_path_check.ps1 - Product Read Path Check
# Validates that all enabled worlds have read-path endpoints (GET /api/v1/{world}/listings) with correct controllers
# PowerShell 5.1 compatible, ASCII-only output, snapshot-driven (no Docker required by default)

param(
    [string]$RoutesSnapshotPath = "ops\snapshots\routes.pazar.json",
    [string]$WorldsConfigPath = "work\pazar\config\worlds.php",
    [string]$BaseUrl = "http://localhost:8080",
    [string]$TestTenantId = $env:PRODUCT_TEST_TENANT_ID,
    [string]$TestAuth = $env:PRODUCT_TEST_AUTH
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
if (Test-Path "${scriptDir}\_lib\worlds_config.ps1") {
    . "${scriptDir}\_lib\worlds_config.ps1"
}

Write-Host "=== PRODUCT READ PATH CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()
$overallStatus = "PASS"
$overallExitCode = 0
$hasWarn = $false
$hasFail = $false

function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$Notes = ""
    )
    $results += [PSCustomObject]@{
        Check = $CheckName
        Status = $Status
        Notes = $Notes
    }
    if ($Status -eq "FAIL") {
        $script:hasFail = $true
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    } elseif ($Status -eq "WARN") {
        $script:hasWarn = $true
        if ($script:overallStatus -ne "FAIL") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    }
}

# Check 1: Parse enabled worlds from config
Write-Info "Check 1: Parse enabled worlds from config"
try {
    if (-not (Test-Path $WorldsConfigPath)) {
        Add-CheckResult -CheckName "Worlds Config Exists" -Status "FAIL" -Notes "Worlds config not found: $WorldsConfigPath"
        Write-Fail "Worlds config not found: $WorldsConfigPath"
        Invoke-OpsExit 1
        return
    }
    
    # Use canonical worlds config parser
    $worldsConfig = Get-WorldsConfig -WorldsConfigPath $WorldsConfigPath
    $enabledWorlds = $worldsConfig.Enabled
    
    if ($enabledWorlds.Count -eq 0) {
            Add-CheckResult -CheckName "Parse Enabled Worlds" -Status "FAIL" -Notes "No enabled worlds found in config"
            Write-Fail "No enabled worlds found in config"
            Invoke-OpsExit 1
            return
        }
        
        Write-Pass "Found enabled worlds: $($enabledWorlds -join ', ')"
        Add-CheckResult -CheckName "Parse Enabled Worlds" -Status "PASS" -Notes "Found $($enabledWorlds.Count) enabled worlds"
    } else {
        Add-CheckResult -CheckName "Parse Enabled Worlds" -Status "FAIL" -Notes "Could not parse enabled worlds from config"
        Write-Fail "Could not parse enabled worlds from config"
        Invoke-OpsExit 1
        return
    }
} catch {
    Add-CheckResult -CheckName "Parse Enabled Worlds" -Status "FAIL" -Notes "Error parsing config: $($_.Exception.Message)"
    Write-Fail "Error parsing config: $($_.Exception.Message)"
    Invoke-OpsExit 1
    return
}

# Check 2: Validate routes snapshot exists (optional, WARN if missing)
Write-Info "Check 2: Validate routes snapshot exists"
if (-not (Test-Path $RoutesSnapshotPath)) {
    Write-Warn "Routes snapshot not found: $RoutesSnapshotPath (will skip route validation)"
    Add-CheckResult -CheckName "Routes Snapshot Exists" -Status "WARN" -Notes "Routes snapshot not found, skipping route validation"
} else {
    Write-Pass "Routes snapshot found: $RoutesSnapshotPath"
    Add-CheckResult -CheckName "Routes Snapshot Exists" -Status "PASS" -Notes "Routes snapshot found"
    
    # Check 3: Validate routes for each enabled world
    Write-Info "Check 3: Validate routes for each enabled world"
    try {
        $routesContent = Get-Content $RoutesSnapshotPath -Raw -Encoding UTF8
        $routes = $routesContent | ConvertFrom-Json
        
        foreach ($world in $enabledWorlds) {
            $indexRoute = $routes | Where-Object { 
                $_.uri -like "*v1/$world/listings" -and 
                $_.method -eq "GET" -and 
                -not ($_.uri -like "*{id}*")
            }
            $showRoute = $routes | Where-Object { 
                $_.uri -like "*v1/$world/listings/{id}*" -and 
                $_.method -eq "GET"
            }
            
            if ($indexRoute) {
                Write-Pass "Found GET /api/v1/$world/listings route"
                Add-CheckResult -CheckName "Route: GET /api/v1/$world/listings" -Status "PASS" -Notes "Route exists"
            } else {
                Write-Fail "Missing GET /api/v1/$world/listings route"
                Add-CheckResult -CheckName "Route: GET /api/v1/$world/listings" -Status "FAIL" -Notes "Route not found in snapshot"
            }
            
            if ($showRoute) {
                Write-Pass "Found GET /api/v1/$world/listings/{id} route"
                Add-CheckResult -CheckName "Route: GET /api/v1/$world/listings/{id}" -Status "PASS" -Notes "Route exists"
            } else {
                Write-Fail "Missing GET /api/v1/$world/listings/{id} route"
                Add-CheckResult -CheckName "Route: GET /api/v1/$world/listings/{id}" -Status "FAIL" -Notes "Route not found in snapshot"
            }
        }
    } catch {
        Write-Warn "Error parsing routes snapshot: $($_.Exception.Message)"
        Add-CheckResult -CheckName "Parse Routes Snapshot" -Status "WARN" -Notes "Error parsing routes: $($_.Exception.Message)"
    }
}

# Check 4: Validate controller files exist
Write-Info "Check 4: Validate controller files exist"
$controllerMap = @{
    "commerce" = "work\pazar\app\Http\Controllers\Api\Commerce\ListingController.php"
    "food" = "work\pazar\app\Http\Controllers\Api\Food\FoodListingController.php"
    "rentals" = "work\pazar\app\Http\Controllers\Api\Rentals\RentalsListingController.php"
}

foreach ($world in $enabledWorlds) {
    if ($controllerMap.ContainsKey($world)) {
        $controllerPath = $controllerMap[$world]
        if (Test-Path $controllerPath) {
            # Validate PHP syntax
            try {
                $phpCheck = php -l $controllerPath 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Pass "Controller exists and PHP syntax valid: $controllerPath"
                    Add-CheckResult -CheckName "Controller: $world" -Status "PASS" -Notes "File exists, PHP syntax valid"
                } else {
                    Write-Fail "Controller PHP syntax error: $controllerPath"
                    Add-CheckResult -CheckName "Controller: $world" -Status "FAIL" -Notes "PHP syntax error: $phpCheck"
                }
            } catch {
                Write-Warn "Could not validate PHP syntax (php not in PATH): $controllerPath"
                Add-CheckResult -CheckName "Controller: $world" -Status "WARN" -Notes "File exists, but PHP syntax check skipped (php not in PATH)"
            }
        } else {
            Write-Fail "Controller not found: $controllerPath"
            Add-CheckResult -CheckName "Controller: $world" -Status "FAIL" -Notes "File not found: $controllerPath"
        }
    } else {
        Write-Warn "No controller mapping for world: $world"
        Add-CheckResult -CheckName "Controller: $world" -Status "WARN" -Notes "No controller mapping defined"
    }
}

# Check 5: Validate controllers import ListingReadDTO and Cursor
Write-Info "Check 5: Validate controllers import DTO and Cursor helpers"
foreach ($world in $enabledWorlds) {
    if ($controllerMap.ContainsKey($world)) {
        $controllerPath = $controllerMap[$world]
        if (Test-Path $controllerPath) {
            $controllerContent = Get-Content $controllerPath -Raw
            $hasListingReadDTO = $controllerContent -match "ListingReadDTO"
            $hasCursor = $controllerContent -match "use.*Cursor"
            $hasListingQuery = $controllerContent -match "ListingQuery"
            
            if ($hasListingReadDTO -and $hasCursor -and $hasListingQuery) {
                Write-Pass "Controller $world imports ListingReadDTO, Cursor, and ListingQuery"
                Add-CheckResult -CheckName "Controller ${world}: DTO imports" -Status "PASS" -Notes "All required imports present"
            } else {
                $missing = @()
                if (-not $hasListingReadDTO) { $missing += "ListingReadDTO" }
                if (-not $hasCursor) { $missing += "Cursor" }
                if (-not $hasListingQuery) { $missing += "ListingQuery" }
                Write-Fail "Controller $world missing imports: $($missing -join ', ')"
                Add-CheckResult -CheckName "Controller ${world}: DTO imports" -Status "FAIL" -Notes "Missing imports: $($missing -join ', ')"
            }
        }
    }
}

# Check 6: Validate documentation has response schema indicators
Write-Info "Check 6: Validate documentation has response schema indicators"
$docsPath = "docs\product\PRODUCT_API_SPINE.md"
if (Test-Path $docsPath) {
    $docsContent = Get-Content $docsPath -Raw
    $hasCursorNext = $docsContent -match "cursor.*next" -or $docsContent -match "cursor\.next"
    $hasMetaLimit = $docsContent -match "meta.*limit" -or $docsContent -match "meta\.limit"
    $hasItems = $docsContent -match "\bitems\b"
    
    if ($hasCursorNext -and $hasMetaLimit -and $hasItems) {
        Write-Pass "Documentation has response schema indicators (items, cursor.next, meta.limit)"
        Add-CheckResult -CheckName "Documentation: Response Schema" -Status "PASS" -Notes "Schema indicators present"
    } else {
        $missing = @()
        if (-not $hasCursorNext) { $missing += "cursor.next" }
        if (-not $hasMetaLimit) { $missing += "meta.limit" }
        if (-not $hasItems) { $missing += "items" }
        Write-Warn "Documentation missing schema indicators: $($missing -join ', ')"
        Add-CheckResult -CheckName "Documentation: Response Schema" -Status "WARN" -Notes "Missing indicators: $($missing -join ', ')"
    }
} else {
    Write-Warn "Documentation file not found: $docsPath"
    Add-CheckResult -CheckName "Documentation: Response Schema" -Status "WARN" -Notes "Documentation file not found"
}

# Check 7: Optional live endpoint checks (only if credentials provided)
Write-Info "Check 7: Optional live endpoint checks"
if ($TestTenantId -and $TestAuth) {
    Write-Info "Live checks enabled (credentials provided)"
    
    # Check if docker is reachable
    try {
        $dockerCheck = docker compose ps 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Pass "Docker is reachable"
            
            foreach ($world in $enabledWorlds) {
                # Test unauthorized access (should return 401/403)
                try {
                    $unauthResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$world/listings" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                    if ($unauthResponse.StatusCode -eq 200) {
                        Write-Warn "Unauthorized access to /api/v1/$world/listings returned 200 (expected 401/403)"
                        Add-CheckResult -CheckName "Live: Unauthorized /api/v1/$world/listings" -Status "WARN" -Notes "Returned 200 instead of 401/403"
                    } else {
                        Write-Pass "Unauthorized access to /api/v1/$world/listings returned $($unauthResponse.StatusCode)"
                        Add-CheckResult -CheckName "Live: Unauthorized /api/v1/$world/listings" -Status "PASS" -Notes "Returned $($unauthResponse.StatusCode)"
                    }
                } catch {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                    if ($statusCode -eq 401 -or $statusCode -eq 403) {
                        Write-Pass "Unauthorized access to /api/v1/$world/listings returned $statusCode (expected)"
                        Add-CheckResult -CheckName "Live: Unauthorized /api/v1/$world/listings" -Status "PASS" -Notes "Returned $statusCode (expected)"
                    } else {
                        Write-Warn "Unauthorized access to /api/v1/$world/listings returned $statusCode (unexpected)"
                        Add-CheckResult -CheckName "Live: Unauthorized /api/v1/$world/listings" -Status "WARN" -Notes "Returned $statusCode (unexpected)"
                    }
                }
                
                # Test authorized access (if token provided)
                if ($TestAuth) {
                    try {
                        $headers = @{
                            "Authorization" = "Bearer $TestAuth"
                            "X-Tenant-Id" = $TestTenantId
                            "Accept" = "application/json"
                        }
                        $authResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/$world/listings" -Method GET -Headers $headers -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                        if ($authResponse.StatusCode -eq 200) {
                            $jsonBody = $authResponse.Content | ConvertFrom-Json
                            if ($jsonBody.ok -eq $true) {
                                Write-Pass "Authorized access to /api/v1/$world/listings returned 200 ok:true"
                                Add-CheckResult -CheckName "Live: Authorized /api/v1/$world/listings" -Status "PASS" -Notes "Returned 200 ok:true"
                            } else {
                                Write-Warn "Authorized access to /api/v1/$world/listings returned 200 but ok:false"
                                Add-CheckResult -CheckName "Live: Authorized /api/v1/$world/listings" -Status "WARN" -Notes "Returned 200 but ok:false"
                            }
                        } else {
                            Write-Warn "Authorized access to /api/v1/$world/listings returned $($authResponse.StatusCode)"
                            Add-CheckResult -CheckName "Live: Authorized /api/v1/$world/listings" -Status "WARN" -Notes "Returned $($authResponse.StatusCode)"
                        }
                    } catch {
                        $statusCode = $_.Exception.Response.StatusCode.value__
                        Write-Warn "Authorized access to /api/v1/$world/listings failed: $statusCode"
                        Add-CheckResult -CheckName "Live: Authorized /api/v1/$world/listings" -Status "WARN" -Notes "Failed with $statusCode"
                    }
                }
            }
        } else {
            Write-Warn "Docker not reachable, skipping live checks"
            Add-CheckResult -CheckName "Live Checks" -Status "WARN" -Notes "Docker not reachable, skipped"
        }
    } catch {
        Write-Warn "Docker check failed, skipping live checks: $($_.Exception.Message)"
        Add-CheckResult -CheckName "Live Checks" -Status "WARN" -Notes "Docker check failed, skipped"
    }
} else {
    Write-Info "Live checks skipped (PRODUCT_TEST_TENANT_ID and PRODUCT_TEST_AUTH not provided)"
    Add-CheckResult -CheckName "Live Checks" -Status "WARN" -Notes "Skipped (credentials not provided)"
}

# Summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host ""
if ($hasFail) {
    Write-Fail "OVERALL STATUS: FAIL"
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
