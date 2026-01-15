# product_spine_governance.ps1 - Product Spine Governance Gate
# Validates API spine surface + middleware posture for enabled/disabled worlds
# PowerShell 5.1 compatible, ASCII-only output, snapshot-driven (no Docker required)

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

Write-Host "=== PRODUCT SPINE GOVERNANCE CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
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
        [string]$World,
        [string]$Surface,
        [string]$Middleware,
        [string]$Status,
        [string]$Notes
    )
    
    $results += [PSCustomObject]@{
        World = $World
        Surface = $Surface
        Middleware = $Middleware
        Status = $Status
        Notes = $Notes
    }
    
    if ($Status -eq "PASS") {
        Write-Host "  [PASS] $World - $Surface" -ForegroundColor Green
    } elseif ($Status -eq "WARN") {
        Write-Host "  [WARN] ${World} - ${Surface}: ${Notes}" -ForegroundColor Yellow
        $script:hasWarn = $true
        if ($script:overallStatus -eq "PASS") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    } else {
        Write-Host "  [FAIL] ${World} - ${Surface}: ${Notes}" -ForegroundColor Red
        $script:hasFail = $true
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    }
}

# Step 1: Read enabled/disabled worlds from config/worlds.php
Write-Host "Step 1: Reading worlds configuration" -ForegroundColor Cyan

$enabledWorlds = @()
$disabledWorlds = @()
$configPath = "work\pazar\config\worlds.php"

if (-not (Test-Path $configPath)) {
    Write-Host "  [FAIL] config/worlds.php not found: $configPath" -ForegroundColor Red
    Add-CheckResult -World "CONFIG" -Surface "config/worlds.php" -Middleware "" -Status "FAIL" -Notes "Config file not found"
    Invoke-OpsExit 1
    return 1
}

try {
    # Use canonical worlds config parser
    $worldsConfig = Get-WorldsConfig -WorldsConfigPath $configPath
    $enabledWorlds = $worldsConfig.Enabled
    $disabledWorlds = $worldsConfig.Disabled
    
    Write-Info "Found $($enabledWorlds.Count) enabled world(s): $($enabledWorlds -join ', ')"
    Write-Info "Found $($disabledWorlds.Count) disabled world(s): $($disabledWorlds -join ', ')"
} catch {
    Write-Fail "Error parsing config/worlds.php: $($_.Exception.Message)"
    Add-CheckResult -World "CONFIG" -Surface "config/worlds.php" -Middleware "" -Status "FAIL" -Notes "Error parsing config: $($_.Exception.Message)"
    Invoke-OpsExit 1
    return 1
}

Write-Host ""

# Step 2: Read routes snapshot
Write-Host "Step 2: Reading routes snapshot" -ForegroundColor Cyan

$snapshotPath = "ops\snapshots\routes.pazar.json"
$allRoutes = $null
$routesFromSnapshot = $false

if (Test-Path $snapshotPath) {
    try {
        $allRoutes = Get-Content $snapshotPath | ConvertFrom-Json
        $routesFromSnapshot = $true
        Write-Host "  [OK] Routes snapshot loaded" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Error reading snapshot: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [WARN] Routes snapshot not found: $snapshotPath" -ForegroundColor Yellow
    Write-Host "  Remediation: Run ops/routes_snapshot.ps1 to generate snapshot" -ForegroundColor Gray
}

Write-Host ""

# Step 3: Validate enabled worlds (required routes + middleware)
Write-Host "Step 3: Validating enabled worlds" -ForegroundColor Cyan

$requiredRoutes = @(
    @{ Method = "GET"; Uri = "/api/v1/{world}/listings" },
    @{ Method = "GET"; Uri = "/api/v1/{world}/listings/{id}" },
    @{ Method = "POST"; Uri = "/api/v1/{world}/listings" },
    @{ Method = "PATCH"; Uri = "/api/v1/{world}/listings/{id}" },
    @{ Method = "DELETE"; Uri = "/api/v1/{world}/listings/{id}" }
)

$requiredMiddleware = @("auth.any", "resolve.tenant", "tenant.user")

foreach ($world in $enabledWorlds) {
    Write-Host "  Checking enabled world: $world" -ForegroundColor Yellow
    
    foreach ($requiredRoute in $requiredRoutes) {
        $routeUri = $requiredRoute.Uri -replace '\{world\}', $world
        $routeMethod = $requiredRoute.Method
        
        if ($routesFromSnapshot -and $allRoutes) {
            # Find route in snapshot
            $route = $allRoutes | Where-Object { 
                $_.uri -eq $routeUri -and 
                ($_.method -eq $routeMethod -or $_.method -like "${routeMethod}*")
            } | Select-Object -First 1
            
            if ($route) {
                # Check middleware
                $middleware = $route.middleware
                if ($null -eq $middleware) {
                    $middleware = @()
                }
                
                $missingMiddleware = @()
                foreach ($mw in $requiredMiddleware) {
                    if ($middleware -notcontains $mw) {
                        $missingMiddleware += $mw
                    }
                }
                
                if ($missingMiddleware.Count -eq 0) {
                    Add-CheckResult -World $world -Surface "$routeMethod $routeUri" -Middleware ($middleware -join ', ') -Status "PASS" -Notes "Route exists with required middleware"
                } else {
                    Add-CheckResult -World $world -Surface "$routeMethod $routeUri" -Middleware ($middleware -join ', ') -Status "FAIL" -Notes "Missing middleware: $($missingMiddleware -join ', ')"
                }
            } else {
                Add-CheckResult -World $world -Surface "$routeMethod $routeUri" -Middleware "" -Status "FAIL" -Notes "Route not found in snapshot"
            }
        } else {
            # Fallback: filesystem check (cannot verify middleware)
            $routesFile = "work\pazar\routes\api.php"
            if (Test-Path $routesFile) {
                $routesContent = Get-Content $routesFile -Raw
                if ($routesContent -match "v1/$world/listings") {
                    Add-CheckResult -World $world -Surface "$routeMethod $routeUri" -Middleware "?" -Status "WARN" -Notes "Route found in filesystem (middleware verification requires snapshot)"
                } else {
                    Add-CheckResult -World $world -Surface "$routeMethod $routeUri" -Middleware "" -Status "FAIL" -Notes "Route not found in filesystem"
                }
            } else {
                Add-CheckResult -World $world -Surface "$routeMethod $routeUri" -Middleware "" -Status "FAIL" -Notes "Routes file not found"
            }
        }
    }
}

Write-Host ""

# Step 4: Validate disabled worlds (no routes should exist)
Write-Host "Step 4: Validating disabled worlds (no routes)" -ForegroundColor Cyan

foreach ($world in $disabledWorlds) {
    Write-Host "  Checking disabled world: $world" -ForegroundColor Yellow
    
    if ($routesFromSnapshot -and $allRoutes) {
        # Check for any routes with this world
        $disabledRoutes = $allRoutes | Where-Object { 
            $_.uri -like "/api/v1/$world/*"
        }
        
        if ($disabledRoutes.Count -gt 0) {
            $routeUris = $disabledRoutes | ForEach-Object { "$($_.method) $($_.uri)" } | Select-Object -First 5
            Add-CheckResult -World $world -Surface "Any /api/v1/$world/* route" -Middleware "" -Status "FAIL" -Notes "Disabled world has routes: $($routeUris -join ', ')"
        } else {
            Add-CheckResult -World $world -Surface "No /api/v1/$world/* routes" -Middleware "" -Status "PASS" -Notes "No routes found (disabled world policy OK)"
        }
    } else {
        # Fallback: filesystem check
        $routesFile = "work\pazar\routes\api.php"
        if (Test-Path $routesFile) {
            $routesContent = Get-Content $routesFile -Raw
            if ($routesContent -match "v1/$world/") {
                Add-CheckResult -World $world -Surface "Any /api/v1/$world/* route" -Middleware "" -Status "FAIL" -Notes "Disabled world has routes in filesystem"
            } else {
                Add-CheckResult -World $world -Surface "No /api/v1/$world/* routes" -Middleware "" -Status "PASS" -Notes "No routes found (disabled world policy OK)"
            }
        } else {
            Add-CheckResult -World $world -Surface "No /api/v1/$world/* routes" -Middleware "" -Status "WARN" -Notes "Routes file not found, cannot verify"
        }
    }
}

Write-Host ""

# Print results table
Write-Host "=== PRODUCT SPINE GOVERNANCE RESULTS ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "World      Surface                              Middleware                    Status Notes" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

foreach ($result in $results) {
    $worldPadded = $result.World.PadRight(10)
    $surfacePadded = $result.Surface.PadRight(35)
    $middlewarePadded = if ($result.Middleware) { $result.Middleware.PadRight(28) } else { "".PadRight(28) }
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[$($result.Status)]" }
    }
    
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "White" }
    }
    
    Write-Host "$worldPadded $surfacePadded $middlewarePadded $statusMarker $($result.Notes)" -ForegroundColor $color
}

Write-Host ""

# Final status
if ($overallStatus -eq "FAIL") {
    Write-Host "OVERALL STATUS: FAIL" -ForegroundColor Red
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    Write-Host "1. Ensure all enabled worlds have required routes: GET/POST/PATCH/DELETE /api/v1/{world}/listings" -ForegroundColor Gray
    Write-Host "2. Ensure routes have required middleware: auth.any, resolve.tenant, tenant.user" -ForegroundColor Gray
    Write-Host "3. Ensure disabled worlds have NO routes (disabled-world policy)" -ForegroundColor Gray
    Write-Host "4. Run ops/routes_snapshot.ps1 to generate snapshot" -ForegroundColor Gray
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
    Write-Host "All enabled worlds have required routes and middleware. Disabled worlds have no routes." -ForegroundColor Gray
    Invoke-OpsExit 0
    return 0
}





