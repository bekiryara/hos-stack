# pazar_route_surface_diag.ps1 - Route Surface Diagnostic (Read-Only)
# Collects deterministic, read-only evidence to explain low route count
# PowerShell 5.1 compatible, ASCII-only output

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
if (Test-Path "${scriptDir}\_lib\routes_json.ps1") {
    . "${scriptDir}\_lib\routes_json.ps1"
}

Write-Host "=== PAZAR ROUTE SURFACE DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host "READ-ONLY DIAGNOSTIC - No changes will be made" -ForegroundColor Yellow
Write-Host ""

$containerName = "pazar-app"
$findings = @()
$warnings = @()

# Helper: Execute read-only command in container
function Invoke-ContainerReadOnly {
    param(
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "[INFO] $Description..." -ForegroundColor Yellow
    try {
        $output = docker compose exec -T ${containerName} sh -lc "$Command" 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            return $output
        } else {
            $warnings += "$Description failed (exit code: $exitCode)"
            return "ERROR: Command failed with exit code $exitCode"
        }
    } catch {
        $warnings += "$Description error: $($_.Exception.Message)"
        return "ERROR: $($_.Exception.Message)"
    }
}

# Section 1: Container identity / working dir
Write-Host "=== [1] Container Identity / Working Directory ===" -ForegroundColor Cyan
Write-Host ""

$whoami = Invoke-ContainerReadOnly "whoami" "Checking container user"
Write-Host "  User: $($whoami.Trim())" -ForegroundColor Gray

$pwd = Invoke-ContainerReadOnly "pwd" "Checking current directory"
Write-Host "  Current directory: $($pwd.Trim())" -ForegroundColor Gray

$lsTop = Invoke-ContainerReadOnly "ls -la / 2>/dev/null | head -20" "Listing top-level directory"
Write-Host "  Top-level contents:" -ForegroundColor Gray
$lsTop -split "`n" | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

$phpVersion = Invoke-ContainerReadOnly "php -v 2>&1 | head -1" "Checking PHP version"
Write-Host "  PHP: $($phpVersion.Trim())" -ForegroundColor Gray

$artisanVersion = Invoke-ContainerReadOnly "php artisan --version 2>&1" "Checking artisan version"
Write-Host "  Artisan: $($artisanVersion.Trim())" -ForegroundColor Gray

# Detect app root
Write-Host ""
Write-Host "[INFO] Detecting app root..." -ForegroundColor Yellow
$appRoots = @("/var/www/html", "/var/www", "/app", "/")
$detectedRoot = $null

foreach ($root in $appRoots) {
    $artisanCheck = Invoke-ContainerReadOnly "test -f $root/artisan && echo 'EXISTS' || echo 'MISSING'" "Checking artisan at $root"
    if ($artisanCheck.Trim() -eq "EXISTS") {
        $detectedRoot = $root
        Write-Host "  [OK] Artisan found at: $root" -ForegroundColor Green
        break
    }
}

if (-not $detectedRoot) {
    $findings += "WARNING: Artisan file not found in common locations"
    Write-Host "  [WARN] Artisan not found in common locations" -ForegroundColor Yellow
} else {
    Write-Host "  Detected app root: $detectedRoot" -ForegroundColor Gray
}

Write-Host ""

# Section 2: Routes sources presence
Write-Host "=== [2] Routes Sources Presence ===" -ForegroundColor Cyan
Write-Host ""

if ($detectedRoot) {
    $routesDir = "$detectedRoot/routes"
} else {
    $routesDir = "routes"
}

$routesList = Invoke-ContainerReadOnly "find $routesDir -maxdepth 1 -type f -name '*.php' 2>/dev/null | head -20" "Listing routes directory files"
Write-Host "  Routes directory files:" -ForegroundColor Gray
if ($routesList -and $routesList.Trim() -ne "" -and $routesList -notmatch "ERROR") {
    $routesList -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
        $fileName = Split-Path -Leaf $_
        Write-Host "    - $fileName" -ForegroundColor DarkGray
    }
} else {
    $findings += "WARNING: Routes directory not found or empty"
    Write-Host "    [WARN] Routes directory not found or empty" -ForegroundColor Yellow
}

# Show first 40 lines of routes/api.php and routes/web.php
foreach ($routeFile in @("api.php", "web.php")) {
    $routePath = "$routesDir/$routeFile"
    $routeContent = Invoke-ContainerReadOnly "test -f $routePath && sed -n '1,40p' $routePath || echo 'FILE_NOT_FOUND'" "Checking $routeFile"
    Write-Host ""
    Write-Host "  $routeFile (first 40 lines):" -ForegroundColor Gray
    if ($routeContent -and $routeContent.Trim() -ne "FILE_NOT_FOUND" -and $routeContent -notmatch "ERROR") {
        $routeContent -split "`n" | Select-Object -First 40 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    } else {
        $findings += "WARNING: $routeFile not found"
        Write-Host "    [WARN] $routeFile not found" -ForegroundColor Yellow
    }
}

Write-Host ""

# Section 3: Route cache status (read-only)
Write-Host "=== [3] Route Cache Status (Read-Only) ===" -ForegroundColor Cyan
Write-Host ""

if ($detectedRoot) {
    $cacheDir = "$detectedRoot/bootstrap/cache"
} else {
    $cacheDir = "bootstrap/cache"
}

$routeCacheFiles = Invoke-ContainerReadOnly "ls -la $cacheDir 2>/dev/null | grep -i route || echo 'NO_ROUTE_CACHE'" "Checking route cache files"
Write-Host "  Route cache files:" -ForegroundColor Gray
if ($routeCacheFiles -and $routeCacheFiles.Trim() -ne "NO_ROUTE_CACHE" -and $routeCacheFiles -notmatch "ERROR") {
    Write-Host "    [YES] Route cache files exist" -ForegroundColor Yellow
    $routeCacheFiles -split "`n" | Where-Object { $_ -match "route" } | ForEach-Object {
        Write-Host "      $_" -ForegroundColor DarkGray
    }
    $findings += "INFO: Route cache files detected (may affect route discovery)"
} else {
    Write-Host "    [NO] No route cache files found" -ForegroundColor Green
}

Write-Host ""

# Section 4: Raw route list output shape + count
Write-Host "=== [4] Raw Route List Output Shape + Count ===" -ForegroundColor Cyan
Write-Host ""

try {
    $rawJson = Get-RawRouteListJson -ContainerName $containerName
    $rawLength = $rawJson.Length
    Write-Host "  Raw output length: $rawLength characters" -ForegroundColor Gray
    
    # Show first 200 chars (sanitized)
    $preview = $rawJson.Substring(0, [Math]::Min(200, $rawLength))
    $preview = $preview -replace '[^\x20-\x7E]', '?'  # Replace non-ASCII with ?
    Write-Host "  First 200 chars (sanitized):" -ForegroundColor Gray
    Write-Host "    $preview..." -ForegroundColor DarkGray
    
    # Parse using canonical helper
    $canonicalRoutes = Convert-RoutesJsonToCanonicalArray -RawJsonText $rawJson
    $routeCount = $canonicalRoutes.Count
    Write-Host ""
    Write-Host "  Canonical route count: $routeCount" -ForegroundColor $(if ($routeCount -gt 10) { "Green" } else { "Yellow" })
    
    if ($routeCount -le 10) {
        Write-Host ""
        Write-Host "  Top $routeCount routes:" -ForegroundColor Gray
        foreach ($route in $canonicalRoutes) {
            $method = if ($route.method_primary) { $route.method_primary } else { $route.method }
            $uri = if ($route.uri) { $route.uri } else { "(no uri)" }
            $name = if ($route.name) { $route.name } else { "(no name)" }
            $action = if ($route.action) { $route.action } else { "(no action)" }
            Write-Host "    $method $uri -> $name ($action)" -ForegroundColor DarkGray
        }
    }
    
    if ($routeCount -le 10) {
        $findings += "CRITICAL: Route count is abnormally low ($routeCount routes, expected > 20)"
    }
} catch {
    $findings += "ERROR: Failed to fetch/parse routes: $($_.Exception.Message)"
    Write-Host "  [ERROR] Failed to fetch/parse routes: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Section 5: Mount/Code reality checks
Write-Host "=== [5] Mount/Code Reality Checks ===" -ForegroundColor Cyan
Write-Host ""

if ($detectedRoot) {
    $checkRoot = $detectedRoot
} else {
    $checkRoot = "."
}

$composerJson = Invoke-ContainerReadOnly "test -f $checkRoot/composer.json && echo 'EXISTS' || echo 'MISSING'" "Checking composer.json"
Write-Host "  composer.json: $($composerJson.Trim())" -ForegroundColor $(if ($composerJson.Trim() -eq "EXISTS") { "Green" } else { "Yellow" })

$appDir = Invoke-ContainerReadOnly "test -d $checkRoot/app && echo 'EXISTS' || echo 'MISSING'" "Checking app/ directory"
Write-Host "  app/ directory: $($appDir.Trim())" -ForegroundColor $(if ($appDir.Trim() -eq "EXISTS") { "Green" } else { "Yellow" })

$vendorDir = Invoke-ContainerReadOnly "test -d $checkRoot/vendor && echo 'EXISTS' || echo 'MISSING'" "Checking vendor/ directory"
Write-Host "  vendor/ directory: $($vendorDir.Trim())" -ForegroundColor $(if ($vendorDir.Trim() -eq "EXISTS") { "Green" } else { "Yellow" })

if ($vendorDir.Trim() -eq "MISSING") {
    $findings += "WARNING: vendor/ directory missing (composer install may be needed, but NOT executed in this diag)"
}

Write-Host ""

# Summary
Write-Host "=== DIAGNOSTIC SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

if ($findings.Count -gt 0) {
    Write-Host "Findings:" -ForegroundColor Yellow
    foreach ($finding in $findings) {
        Write-Host "  - $finding" -ForegroundColor $(if ($finding -match "CRITICAL|ERROR") { "Red" } elseif ($finding -match "WARNING") { "Yellow" } else { "Gray" })
    }
} else {
    Write-Host "No significant findings detected." -ForegroundColor Green
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  - $warning" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== ROOT CAUSE HYPOTHESIS (Ranked) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. [HIGH] Wrong working directory / wrong app root inside container" -ForegroundColor Yellow
Write-Host "   - Artisan may be running from wrong path" -ForegroundColor Gray
Write-Host "   - Routes may not be loaded from expected location" -ForegroundColor Gray
Write-Host ""
Write-Host "2. [HIGH] Code mount not what we think (container has skeleton app)" -ForegroundColor Yellow
Write-Host "   - Volume mount may point to wrong directory" -ForegroundColor Gray
Write-Host "   - Container may have minimal Laravel skeleton" -ForegroundColor Gray
Write-Host ""
Write-Host "3. [MEDIUM] Routes files missing or not loaded" -ForegroundColor Yellow
Write-Host "   - routes/api.php or routes/web.php may be missing" -ForegroundColor Gray
Write-Host "   - Route service provider may not be loading routes" -ForegroundColor Gray
Write-Host ""
Write-Host "4. [LOW] Route cache stale (but do not clear; just detect)" -ForegroundColor Yellow
Write-Host "   - Route cache may be out of sync with actual routes" -ForegroundColor Gray
Write-Host "   - Cache may need clearing (NOT done in this diag)" -ForegroundColor Gray
Write-Host ""
Write-Host "5. [LOW] Artisan running against different project path" -ForegroundColor Yellow
Write-Host "   - Artisan may be executing from different working directory" -ForegroundColor Gray
Write-Host "   - Environment may be pointing to wrong app root" -ForegroundColor Gray

Write-Host ""
Write-Host "=== REMEDIATION OPTIONS (NON-DESTRUCTIVE) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. [LOW RISK] Verify docker-compose.yml volume mounts" -ForegroundColor Green
Write-Host "   - Check that work/pazar is correctly mounted to container" -ForegroundColor Gray
Write-Host "   - Verify mount path matches detected app root" -ForegroundColor Gray
Write-Host ""
Write-Host "2. [LOW RISK] Check Laravel route service provider" -ForegroundColor Green
Write-Host "   - Verify RouteServiceProvider loads all route files" -ForegroundColor Gray
Write-Host "   - Check if route files are conditionally loaded" -ForegroundColor Gray
Write-Host ""
Write-Host "3. [MEDIUM RISK] Clear route cache (requires container restart)" -ForegroundColor Yellow
Write-Host "   - Run: docker compose exec pazar-app php artisan route:clear" -ForegroundColor Gray
Write-Host "   - WARNING: This requires container to be running" -ForegroundColor Gray
Write-Host "   - NOTE: NOT executed in this diagnostic pack" -ForegroundColor Gray
Write-Host ""
Write-Host "4. [MEDIUM RISK] Verify composer autoload" -ForegroundColor Yellow
Write-Host "   - Check if vendor/autoload.php exists and is correct" -ForegroundColor Gray
Write-Host "   - May require composer install (NOT done in this diag)" -ForegroundColor Gray
Write-Host ""
Write-Host "5. [HIGH RISK] Rebuild container with correct mounts" -ForegroundColor Red
Write-Host "   - This would require docker compose down/up" -ForegroundColor Gray
Write-Host "   - NOT recommended without further investigation" -ForegroundColor Gray
Write-Host "   - NOTE: NOT executed in this diagnostic pack" -ForegroundColor Gray

Write-Host ""
Write-Host "=== EXPLICIT NOTE ===" -ForegroundColor Cyan
Write-Host "[INFO] No remediation executed in this pack. This is a read-only diagnostic." -ForegroundColor Yellow
Write-Host ""

Invoke-OpsExit 0















