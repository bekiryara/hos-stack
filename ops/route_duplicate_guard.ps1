# WP-17: Route Duplicate Guard
# Checks for duplicate METHOD+URI combinations using Laravel route:list
# PowerShell 5.1 compatible, ASCII-only output

$ErrorActionPreference = "Stop"

Write-Host "=== ROUTE DUPLICATE GUARD (WP-17) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Run Laravel route:list --json inside container
Write-Host "[1] Fetching route list from Laravel..." -ForegroundColor Yellow
try {
    $routeListJson = docker compose exec -T pazar-app php artisan route:list --json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: Laravel route:list failed" -ForegroundColor Red
        Write-Host $routeListJson -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "FAIL: Could not run route:list: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Parse JSON
try {
    $routes = $routeListJson | ConvertFrom-Json
} catch {
    Write-Host "FAIL: Could not parse route:list JSON output" -ForegroundColor Red
    Write-Host "Raw output: $routeListJson" -ForegroundColor Yellow
    exit 1
}

if (-not $routes) {
    Write-Host "FAIL: No routes found in route:list output" -ForegroundColor Red
    exit 1
}

# Build route key map (METHOD + URI)
$routeMap = @{}
$duplicates = @()

foreach ($route in $routes) {
    # Get method (handle array of methods, e.g., ["GET", "HEAD"])
    $method = $route.method
    if ($method -is [Array]) {
        # Use first method (typically GET for GET|HEAD pairs)
        $method = $method[0]
    }
    $method = $method.ToUpper()
    
    # Get URI
    $uri = $route.uri
    
    # Build key: METHOD + URI
    $key = "$method $uri"
    
    # Ignore HEAD if it's a duplicate of GET (Laravel auto-generates HEAD for GET routes)
    if ($method -eq "HEAD") {
        $getKey = "GET $uri"
        if ($routeMap.ContainsKey($getKey)) {
            # HEAD is auto-generated for GET, skip it
            continue
        }
    }
    
    if ($routeMap.ContainsKey($key)) {
        # Duplicate found
        $duplicates += @{
            Route = $key
            First = $routeMap[$key]
            Second = $route
        }
    } else {
        $routeMap[$key] = $route
    }
}

# Report results
Write-Host "[2] Checking for duplicates..." -ForegroundColor Yellow
Write-Host ""

if ($duplicates.Count -eq 0) {
    Write-Host "PASS: No duplicate routes found" -ForegroundColor Green
    Write-Host "Total unique routes: $($routeMap.Count)" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "FAIL: Found $($duplicates.Count) duplicate route(s):" -ForegroundColor Red
    Write-Host ""
    foreach ($dup in $duplicates) {
        Write-Host "  DUPLICATE: $($dup.Route)" -ForegroundColor Yellow
        Write-Host "    First definition: $($dup.First.name -or 'unnamed')" -ForegroundColor Gray
        Write-Host "    Second definition: $($dup.Second.name -or 'unnamed')" -ForegroundColor Gray
    }
    Write-Host ""
    exit 1
}
