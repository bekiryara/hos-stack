# world_spine_check.ps1 - World Spine Governance Check
# Ensures enabled worlds have routes/controllers and ctx.world lock evidence

param(
    [string]$WORLD_REGISTRY_PATH = "",
    [string]$WORLDS_CONFIG_PATH = "",
    [string]$ROUTES_SNAPSHOT = ""
)

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\worlds_config.ps1") {
    . "${scriptDir}\_lib\worlds_config.ps1"
}
if (Test-Path "${scriptDir}\_lib\routes_json.ps1") {
    . "${scriptDir}\_lib\routes_json.ps1"
}

# Set defaults
if ($WORLD_REGISTRY_PATH -eq "") {
    if (Test-Path "work/pazar/WORLD_REGISTRY.md") {
        $WORLD_REGISTRY_PATH = "work/pazar/WORLD_REGISTRY.md"
    } elseif (Test-Path "WORLD_REGISTRY.md") {
        $WORLD_REGISTRY_PATH = "WORLD_REGISTRY.md"
    } else {
        Write-Host "WARN: WORLD_REGISTRY.md not found" -ForegroundColor Yellow
        $WORLD_REGISTRY_PATH = ""
    }
}

if ($WORLDS_CONFIG_PATH -eq "") {
    $WORLDS_CONFIG_PATH = "work/pazar/config/worlds.php"
}

if ($ROUTES_SNAPSHOT -eq "") {
    $ROUTES_SNAPSHOT = "ops/snapshots/routes.pazar.json"
}

Write-Host "=== WORLD SPINE GOVERNANCE CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host "Config: $WORLDS_CONFIG_PATH" -ForegroundColor Gray
Write-Host "Routes: $ROUTES_SNAPSHOT" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()

# Parse worlds config
if (-not (Test-Path $WORLDS_CONFIG_PATH)) {
    Write-Host "FAIL: Worlds config not found: $WORLDS_CONFIG_PATH" -ForegroundColor Red
    Invoke-OpsExit 1
    return
}

Write-Info "Parsing worlds config..."
$worldsConfig = Get-WorldsConfig -WorldsConfigPath $WORLDS_CONFIG_PATH
$enabledWorlds = $worldsConfig.Enabled
$disabledWorlds = $worldsConfig.Disabled

Write-Info "Enabled worlds: $($enabledWorlds -join ', ')"
Write-Info "Disabled worlds: $($disabledWorlds -join ', ')"
Write-Info ""

# Read routes snapshot
$routes = @()
if (Test-Path $ROUTES_SNAPSHOT) {
    Write-Host "Reading routes snapshot..." -ForegroundColor Yellow
    try {
        $snapshotContent = Get-Content $ROUTES_SNAPSHOT -Raw -Encoding UTF8
        $routes = Convert-RoutesJsonToCanonicalArray -RawJsonText $snapshotContent
    } catch {
        Write-Host "WARN: Failed to parse routes snapshot: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Falling back to filesystem check..." -ForegroundColor Gray
        $routes = @()
    }
} else {
    Write-Host "WARN: Routes snapshot not found: $ROUTES_SNAPSHOT" -ForegroundColor Yellow
    Write-Host "Falling back to filesystem check..." -ForegroundColor Gray
}

# Helper: Check if world has route surface
function Test-WorldRouteSurface {
    param([string]$WorldId)
    
    # Check routes snapshot first
    if ($routes.Count -gt 0) {
        # Look for routes containing world path (e.g., /commerce, /food, /rentals)
        $worldRoute = $routes | Where-Object { 
            $_.uri -eq $WorldId -or 
            $_.uri -like "/$WorldId" -or
            $_.uri -like "/$WorldId/*" -or
            $_.uri -like "*/world/$WorldId*"
        } | Select-Object -First 1
        
        if ($worldRoute) {
            return $true
        }
    }
    
    # Fallback: Check filesystem
    $routeFile = "work/pazar/routes/world_$WorldId.php"
    if (Test-Path $routeFile) {
        return $true
    }
    
    # Check controller directory
    $controllerDir = "work/pazar/app/Http/Controllers/World/$($WorldId.Substring(0,1).ToUpper() + $WorldId.Substring(1))"
    if (Test-Path $controllerDir) {
        return $true
    }
    
    return $false
}

# Helper: Check ctx.world lock evidence
function Test-WorldCtxLock {
    param([string]$WorldId)
    
    # Search patterns for ctx.world lock evidence
    $patterns = @(
        "ctx\.world\s*=\s*['\`"]$WorldId['\`"]",
        "ctx\.world\s*==\s*['\`"]$WorldId['\`"]",
        "world\s*=\s*['\`"]$WorldId['\`"]",
        "world\s*==\s*['\`"]$WorldId['\`"]",
        "world_id\s*=\s*['\`"]$WorldId['\`"]",
        "world_id\s*==\s*['\`"]$WorldId['\`"]",
        "Spine lock.*ctx\.world.*$WorldId",
        "ctx\.world.*$WorldId.*lock"
    )
    
    # Search in tests
    $testFiles = Get-ChildItem -Path "work/pazar/tests" -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $testFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            foreach ($pattern in $patterns) {
                if ($content -match $pattern) {
                    return $true
                }
            }
        }
    }
    
    # Search in docs
    $docFiles = Get-ChildItem -Path "work/pazar/docs" -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $docFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            foreach ($pattern in $patterns) {
                if ($content -match $pattern) {
                    return $true
                }
            }
        }
    }
    
    # Search in root docs
    $rootDocFiles = Get-ChildItem -Path "docs" -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $rootDocFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            foreach ($pattern in $patterns) {
                if ($content -match $pattern) {
                    return $true
                }
            }
        }
    }
    
    return $false
}

# Helper: Check if disabled world has controller directory
function Test-DisabledWorldController {
    param([string]$WorldId)
    
    $controllerDir = "work/pazar/app/Http/Controllers/World/$($WorldId.Substring(0,1).ToUpper() + $WorldId.Substring(1))"
    if (Test-Path $controllerDir) {
        return $true
    }
    
    return $false
}

# Check enabled worlds
Write-Host "=== Checking Enabled Worlds ===" -ForegroundColor Cyan
Write-Host ""

foreach ($world in $enabledWorlds) {
    Write-Host "Checking world: $world" -ForegroundColor Yellow
    
    $hasRouteSurface = Test-WorldRouteSurface -WorldId $world
    $hasCtxLock = Test-WorldCtxLock -WorldId $world
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    
    if (-not $hasRouteSurface) {
        $status = "FAIL"
        $notes += "Missing route/controller surface; "
        $exitCode = 1
    } else {
        $notes += "Route surface OK; "
    }
    
    if (-not $hasCtxLock) {
        if ($status -eq "PASS") {
            $status = "WARN"
            $notes += "Missing ctx.world lock evidence (optional but recommended); "
            $exitCode = 2
        } else {
            $notes += "Missing ctx.world lock evidence; "
        }
    } else {
        $notes += "Ctx.world lock OK; "
    }
    
    $notes = $notes.TrimEnd('; ')
    
    $results += [PSCustomObject]@{
        World = $world
        Enabled = "Yes"
        RoutesSurface = if ($hasRouteSurface) { "Yes" } else { "No" }
        CtxWorldLock = if ($hasCtxLock) { "Yes" } else { "No" }
        Status = $status
        Notes = $notes
    }
}

# Check disabled worlds
Write-Host ""
Write-Host "=== Checking Disabled Worlds ===" -ForegroundColor Cyan
Write-Host ""

foreach ($world in $disabledWorlds) {
    Write-Host "Checking disabled world: $world" -ForegroundColor Yellow
    
    $hasController = Test-DisabledWorldController -WorldId $world
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    
    if ($hasController) {
        $status = "FAIL"
        $notes = "Controller directory exists for disabled world (should be removed)"
        $exitCode = 1
    } else {
        $notes = "No controller directory (OK for disabled world)"
    }
    
    $results += [PSCustomObject]@{
        World = $world
        Enabled = "No"
        RoutesSurface = "N/A"
        CtxWorldLock = "N/A"
        Status = $status
        Notes = $notes
    }
}

# Print results table
Write-Host ""
Write-Host "=== WORLD SPINE CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property World, Enabled, RoutesSurface, CtxWorldLock, Status, Notes -AutoSize

# Determine overall status
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" }).Count

Write-Host ""
if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Failures:" -ForegroundColor Yellow
    foreach ($result in ($results | Where-Object { $_.Status -eq "FAIL" })) {
        Write-Host "  - $($result.World): $($result.Notes)" -ForegroundColor Red
    }
    Invoke-OpsExit 1
    return
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($result in ($results | Where-Object { $_.Status -eq "WARN" })) {
        Write-Host "  - $($result.World): $($result.Notes)" -ForegroundColor Yellow
    }
    Invoke-OpsExit 2
    return
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    Invoke-OpsExit 0
    return
}

