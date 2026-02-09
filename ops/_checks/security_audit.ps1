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

# Helper: Normalize URI (ensure leading slash)
function Normalize-Uri {
    param([string]$Uri)
    if ([string]::IsNullOrWhiteSpace($Uri)) {
        return ""
    }
    $u = $Uri.Trim()
    if (-not $u.StartsWith("/")) {
        $u = "/" + $u
    }
    return $u
}

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

# Helper: Expand canonical middleware aliases from class names
function Expand-MiddlewareAliases {
    param([string[]]$MiddlewareList)
    
    $list = @()
    foreach ($m in ($MiddlewareList | Where-Object { $_ -ne $null })) {
        $s = [string]$m
        if ([string]::IsNullOrWhiteSpace($s)) { continue }
        $list += $s
        
        # Laravel route:list may emit fully-qualified class names.
        # Add canonical aliases expected by this audit.
        if ($s -match 'AuthAny') { $list += 'auth.any' }
        if ($s -match 'AuthContext') { $list += 'auth.ctx' }
        if ($s -match 'PersonaScope') { $list += 'persona.scope' }
        if ($s -match 'TenantScope') { $list += 'tenant.scope' }
        if ($s -match 'TenantMembershipStrict') { $list += 'tenant.membership_strict' }
        if ($s -match 'SuperAdmin') { $list += 'super.admin' }
        if ($s -match 'ResolveTenant' -or $s -match 'TenantResolve') { $list += 'tenant.resolve' }
        if ($s -match 'TenantUser') { $list += 'tenant.user' }
    }
    
    return ($list | Select-Object -Unique)
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
    $uri = Normalize-Uri -Uri $route.uri
    $middleware = Normalize-Middleware -Middleware $route.middleware
    $middleware = Expand-MiddlewareAliases -MiddlewareList $middleware
    
    $violationsForRoute = @()
    
    # Rule 1 (SSOT boundary): Pazar MUST NOT expose /admin* or /panel* routes.
    # Admin surface lives in H-OS only (/v1/admin/* + /ui/admin/*).
    if ($uri -like '/admin*' -or $uri -like '/panel*') {
        $violationsForRoute += "Forbidden surface: Pazar must not expose /admin or /panel (SSOT=H-OS)"
    }
    
    # Rule 2: State-changing routes must have auth.any OR be allowlisted
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
    Write-Host "  1. Pazar MUST NOT expose /admin* or /panel* (Admin SSOT = H-OS)" -ForegroundColor Gray
    Write-Host "  2. POST/PUT/PATCH/DELETE routes must have: auth.any (or be allowlisted)" -ForegroundColor Gray
    
    Invoke-OpsExit 1
    return
}

