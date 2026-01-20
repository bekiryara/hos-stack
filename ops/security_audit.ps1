# security_audit.ps1 - Route/Middleware Security Audit

$ErrorActionPreference = "Stop"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}
if (Test-Path "${scriptDir}\_lib\routes_json.ps1") {
    . "${scriptDir}\_lib\routes_json.ps1"
}

Write-Host "=== Security Audit (Route/Middleware) ===" -ForegroundColor Cyan

# Allowlist for state-changing routes that don't require auth
$ALLOWLIST = @(
    '/up',
    '/health',
    '/api/health',
    '/v1/health'
)

# Helper: Normalize middleware to array of strings
function Normalize-Middleware {
    param([object]$Middleware)
    
    if ($null -eq $Middleware) {
        return @()
    }
    
    if ($Middleware -is [string]) {
        return @($Middleware)
    }
    
    if ($Middleware -is [System.Collections.ICollection]) {
        $result = @()
        foreach ($item in $Middleware) {
            if ($item -is [string]) {
                $result += $item
            } elseif ($item -is [PSCustomObject] -and $item.name) {
                $result += $item.name
            }
        }
        return $result
    }
    
    return @()
}

# Helper: Check if route path matches pattern
function Test-RoutePattern {
    param([string]$Uri, [string]$Pattern)
    
    if ($Pattern -like '*/*') {
        return $Uri -like $Pattern
    }
    return $Uri.StartsWith($Pattern)
}

# Helper: Check if route is in allowlist
function Test-Allowlisted {
    param([string]$Path)
    
    foreach ($allowed in $ALLOWLIST) {
        if ($Path -eq $allowed -or $Path -like "$allowed*") {
            return $true
        }
    }
    return $false
}

# Get routes from Laravel
Write-Host "`n[1] Fetching routes from pazar-app..." -ForegroundColor Yellow

try {
    $rawJson = Get-RawPazarRouteListJson -ContainerName "pazar-app"
    $routes = Convert-RoutesJsonToCanonicalArray -RawJsonText $rawJson
    
    # Sanity check: route count should be reasonable (> 20)
    if ($routes.Count -lt 20) {
        Write-Host "[FAIL] FAIL: Route count too low ($($routes.Count)). Route JSON parse mismatch or artisan output changed." -ForegroundColor Red
        Invoke-OpsExit 1
        return
    }
    
    Write-Host "  [OK] Fetched $($routes.Count) routes" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] FAIL: Failed to fetch routes: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-OpsExit 1
    return
}
if ($null -eq $routes -or $routes.Count -eq 0) {
    Write-Host "FAIL: No routes found" -ForegroundColor Red
    Invoke-OpsExit 1
    return
}

Write-Host "Found $($routes.Count) routes" -ForegroundColor Gray

# Track violations
$violations = @()

# Audit each route
Write-Host "`n[2] Auditing routes..." -ForegroundColor Yellow

foreach ($route in $routes) {
    $method = $route.method
    $uri = $route.uri
    $middleware = Normalize-Middleware -Middleware $route.middleware
    
    $violationsForRoute = @()
    
    # Rule 1: Admin routes must have auth.any AND super.admin
    if ($uri -like '/admin*') {
        if ($middleware -notcontains 'auth.any') {
            $violationsForRoute += "Missing middleware: auth.any"
        }
        if ($middleware -notcontains 'super.admin') {
            $violationsForRoute += "Missing middleware: super.admin"
        }
    }
    
    # Rule 2: Panel routes must have auth.any
    if ($uri -like '/panel*') {
        if ($middleware -notcontains 'auth.any') {
            $violationsForRoute += "Missing middleware: auth.any"
        }
    }
    
    # Rule 3: Tenant-scoped panel routes must have tenant.resolve AND tenant.user
    if ($uri -like '/panel*' -and ($uri -match '\{tenant\}' -or $uri -match '\{tenant_slug\}')) {
        if ($middleware -notcontains 'tenant.resolve' -and $middleware -notcontains 'resolve.tenant') {
            $violationsForRoute += "Missing middleware: tenant.resolve or resolve.tenant"
        }
        if ($middleware -notcontains 'tenant.user') {
            $violationsForRoute += "Missing middleware: tenant.user"
        }
    }
    
    # Rule 4: State-changing routes must have auth.any OR be allowlisted
    $stateChangingMethods = @('POST', 'PUT', 'PATCH', 'DELETE')
    if ($stateChangingMethods -contains $method) {
        if (-not (Test-Allowlisted -Path $uri)) {
            if ($middleware -notcontains 'auth.any') {
                $violationsForRoute += "State-changing route missing auth.any (or not allowlisted)"
            }
        }
    }
    
    # If violations found, add to list
    if ($violationsForRoute.Count -gt 0) {
        $violations += [PSCustomObject]@{
            Method = $method
            Uri = $uri
            Middleware = ($middleware -join ', ')
            Violations = ($violationsForRoute -join '; ')
        }
    }
}

# Report results
Write-Host "`n[3] Security Audit Results" -ForegroundColor Yellow

if ($violations.Count -eq 0) {
    Write-Host "`n[OK] PASS: 0 violations found" -ForegroundColor Green
    Write-Host "All routes comply with security policy." -ForegroundColor Gray
    Invoke-OpsExit 0
    return
} else {
    Write-Host "`n[FAIL] FAIL: $($violations.Count) violation(s) found" -ForegroundColor Red
    Write-Host ""
    
    # Print violations table
    $violations | Format-Table -Property Method, Uri, Middleware, Violations -AutoSize
    
    Write-Host "Violations:" -ForegroundColor Yellow
    foreach ($v in $violations) {
        Write-Host "  - $($v.Method) $($v.Uri)" -ForegroundColor Red
        Write-Host "    Missing: $($v.Violations)" -ForegroundColor Gray
    }
    
    Write-Host "`nSecurity Policy:" -ForegroundColor Yellow
    Write-Host "  1. /admin/* routes must have: auth.any AND super.admin" -ForegroundColor Gray
    Write-Host "  2. /panel/* routes must have: auth.any" -ForegroundColor Gray
    Write-Host "  3. /panel/* routes with {tenant} must have: tenant.resolve AND tenant.user" -ForegroundColor Gray
    Write-Host "  4. POST/PUT/PATCH/DELETE routes must have: auth.any (or be allowlisted)" -ForegroundColor Gray
    
    Invoke-OpsExit 1
    return
}

