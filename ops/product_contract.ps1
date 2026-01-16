# product_contract.ps1 - Product API Contract Gate
# Validates docs/product/PRODUCT_API_SPINE.md matches actual public surface (routes snapshot)
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [string]$SpinePath = "docs\product\PRODUCT_API_SPINE.md",
    [string]$RoutesSnapshotPath = "ops\snapshots\routes.pazar.json",
    [string]$RoutesFallbackPath = "work\pazar\routes\api.php"
)

$ErrorActionPreference = "Continue"

# Dot-source shared helpers
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\_lib\ops_output.ps1"
. "$ScriptDir\_lib\ops_exit.ps1"
. "$ScriptDir\_lib\routes_json.ps1"

Initialize-OpsOutput

Write-Info "=== PRODUCT CONTRACT GATE ==="
Write-Info "Spine: ${SpinePath}"
Write-Info "Routes Snapshot: ${RoutesSnapshotPath}"
Write-Info ""

# Result tracking
$checkResults = @()
$overallPass = $true
$hasWarn = $false

function Add-CheckResult {
    param(
        [string]$Check,
        [string]$Status,
        [string]$Notes = ""
    )
    $script:checkResults += [PSCustomObject]@{
        Check = $Check
        Status = $Status
        Notes = $Notes
    }
    if ($Status -eq "FAIL") {
        $script:overallPass = $false
    } elseif ($Status -eq "WARN") {
        $script:hasWarn = $true
    }
}

# Step 1: Check spine file exists
Write-Info "Step 1: Checking spine file..."
if (-not (Test-Path $SpinePath)) {
    Write-Fail "Spine file not found: ${SpinePath}"
    Add-CheckResult -Check "Spine File" -Status "FAIL" -Notes "File not found"
    Invoke-OpsExit 1
    return
}

$spineContent = Get-Content $SpinePath -Raw
Write-Pass "Spine file found"
Add-CheckResult -Check "Spine File" -Status "PASS" -Notes "File exists"

# Step 2: Extract implemented endpoints from spine per world
Write-Info ""
Write-Info "Step 2: Extracting implemented endpoints from spine..."

$enabledWorlds = @("commerce", "food", "rentals")
$spineEndpoints = @{}

foreach ($world in $enabledWorlds) {
    $spineEndpoints[$world] = @()
    
    # Look for "Status: IMPLEMENTED" sections for this world
    # Pattern: Look for endpoint sections with "Status: IMPLEMENTED" and world context
    $worldPattern = "(?s)(?:###|####)\s+(?:List|Show|Create|Update|Delete|Disable)\s+(?:Listing|Product).*?Status:\s*IMPLEMENTED.*?(?=###|####|$)"
    $matches = [regex]::Matches($spineContent, $worldPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    foreach ($match in $matches) {
        $section = $match.Value
        
        # Extract method and path
        if ($section -match "- \*\*Method:\*\*\s*`([A-Z]+)`") {
            $method = $matches[1]
        } elseif ($section -match "- \*\*Method:\*\*\s*([A-Z]+)") {
            $method = $matches[1]
        } else {
            continue
        }
        
        if ($section -match "- \*\*Path:\*\*\s*`([^`]+)`") {
            $path = $matches[1]
        } elseif ($section -match "- \*\*Path:\*\*\s*([^\n]+)") {
            $path = $matches[1].Trim()
        } else {
            continue
        }
        
        # Normalize path (remove query params, normalize /api/v1/{world}/listings patterns)
        $path = $path -replace '\?.*$', ''  # Remove query params
        $path = $path -replace '\{world\}', $world  # Replace {world} placeholder
        
        # Check if this endpoint is for this world
        if ($path -match "/api/v1/$world/" -or $path -match "/api/v1/products") {
            $spineEndpoints[$world] += [PSCustomObject]@{
                Method = $method
                Path = $path
                World = $world
            }
        }
    }
    
    # Also check for world-specific listings endpoints
    $listingsPattern = "- \*\*Path:\*\*\s*`/api/v1/\{world\}/listings[^`]*`"
    $listingsMatches = [regex]::Matches($spineContent, $listingsPattern)
    foreach ($listingsMatch in $listingsMatches) {
        $section = $spineContent.Substring([Math]::Max(0, $listingsMatch.Index - 500), [Math]::Min(1000, $spineContent.Length - [Math]::Max(0, $listingsMatch.Index - 500)))
        if ($section -match "Status:\s*IMPLEMENTED" -and $section -match "- \*\*Method:\*\*\s*`?([A-Z]+)`?") {
            $method = $matches[1]
            $path = "/api/v1/$world/listings"
            if ($listingsMatch.Value -match "/listings/\{id\}") {
                $path = "/api/v1/$world/listings/{id}"
            } elseif ($listingsMatch.Value -match "/listings/\{id\}/disable") {
                $path = "/api/v1/$world/listings/{id}/disable"
            }
            $spineEndpoints[$world] += [PSCustomObject]@{
                Method = $method
                Path = $path
                World = $world
            }
        }
    }
}

$totalSpineEndpoints = ($spineEndpoints.Values | Measure-Object).Count
Write-Info "Extracted $totalSpineEndpoints endpoints from spine"
foreach ($world in $enabledWorlds) {
    Write-Info "  ${world}: $($spineEndpoints[$world].Count) endpoints"
}

if ($totalSpineEndpoints -eq 0) {
    Write-Warn "No IMPLEMENTED endpoints found in spine (check spine format)"
    Add-CheckResult -Check "Spine Endpoints" -Status "WARN" -Notes "No IMPLEMENTED endpoints extracted"
} else {
    Add-CheckResult -Check "Spine Endpoints" -Status "PASS" -Notes "Extracted $totalSpineEndpoints endpoints"
}

# Step 3: Load routes from snapshot (preferred) or fallback
Write-Info ""
Write-Info "Step 3: Loading routes from snapshot..."

$routes = @()
$routesLoaded = $false

if (Test-Path $RoutesSnapshotPath) {
    try {
        $snapshotContent = Get-Content $RoutesSnapshotPath -Raw
        $routes = Convert-RoutesJsonToCanonicalArray -RawJsonText $snapshotContent
        $routesLoaded = $true
        Write-Pass "Routes loaded from snapshot: $($routes.Count) routes"
        Add-CheckResult -Check "Routes Snapshot" -Status "PASS" -Notes "Loaded $($routes.Count) routes"
    } catch {
        Write-Warn "Failed to parse snapshot: $($_.Exception.Message)"
        Add-CheckResult -Check "Routes Snapshot" -Status "WARN" -Notes "Parse failed, using fallback"
    }
}

if (-not $routesLoaded -and (Test-Path $RoutesFallbackPath)) {
    Write-Info "Using fallback: parsing routes file..."
    # Fallback: basic grep-based extraction (simplified)
    $routesContent = Get-Content $RoutesFallbackPath -Raw
    # This is a simplified fallback - in practice, snapshot should always be available
    Write-Warn "Fallback routes parsing not fully implemented (snapshot preferred)"
    Add-CheckResult -Check "Routes Fallback" -Status "WARN" -Notes "Fallback used (snapshot preferred)"
}

if ($routes.Count -eq 0) {
    Write-Fail "No routes loaded (snapshot missing or invalid)"
    Add-CheckResult -Check "Routes Load" -Status "FAIL" -Notes "No routes available"
    Invoke-OpsExit 1
    return
}

# Step 4: Validate spine endpoints exist in routes
Write-Info ""
Write-Info "Step 4: Validating spine endpoints exist in routes..."

$missingEndpoints = @()
foreach ($world in $enabledWorlds) {
    foreach ($spineEndpoint in $spineEndpoints[$world]) {
        $method = $spineEndpoint.Method
        $path = $spineEndpoint.Path
        
        # Normalize path for comparison
        $normalizedPath = $path -replace '\{id\}', '{id}'  # Keep {id} as-is for matching
        
        # Find matching route
        $found = $false
        foreach ($route in $routes) {
            $routeMethod = $route.method_primary
            $routeUri = $route.uri
            
            # Match method (handle GET|HEAD)
            $methodMatch = $false
            if ($routeMethod -eq $method -or ($method -eq "GET" -and $routeMethod -like "GET*")) {
                $methodMatch = $true
            }
            
            # Match path (normalize {id} and world)
            $pathMatch = $false
            $routePathNormalized = $routeUri -replace '^/api/v1/', '/api/v1/'
            if ($normalizedPath -eq $routePathNormalized) {
                $pathMatch = $true
            } elseif ($normalizedPath -match '\{id\}' -and $routePathNormalized -match '\{id\}') {
                # Both have {id}, compare base paths
                $basePath = $normalizedPath -replace '/\{id\}.*$', ''
                $routeBasePath = $routePathNormalized -replace '/\{id\}.*$', ''
                if ($basePath -eq $routeBasePath) {
                    $pathMatch = $true
                }
            }
            
            if ($methodMatch -and $pathMatch) {
                $found = $true
                break
            }
        }
        
        if (-not $found) {
            $missingEndpoints += "${method} ${path} (${world})"
        }
    }
}

if ($missingEndpoints.Count -gt 0) {
    Write-Fail "Missing endpoints in routes: $($missingEndpoints.Count)"
    foreach ($missing in $missingEndpoints) {
        Write-Host "  - $missing" -ForegroundColor Red
    }
    Add-CheckResult -Check "Spine-Routes Alignment" -Status "FAIL" -Notes "$($missingEndpoints.Count) endpoints missing: $($missingEndpoints -join '; ')"
    $overallPass = $false
} else {
    Write-Pass "All spine endpoints found in routes"
    Add-CheckResult -Check "Spine-Routes Alignment" -Status "PASS" -Notes "All endpoints present"
}

# Step 5: Validate routes under /api/v1/<world>/listings* are in spine
Write-Info ""
Write-Info "Step 5: Validating routes are documented in spine..."

$undocumentedRoutes = @()
foreach ($route in $routes) {
    $uri = $route.uri
    $method = $route.method_primary
    
    # Check if this is a product/listings route for enabled worlds
    foreach ($world in $enabledWorlds) {
        if ($uri -match "^/api/v1/$world/listings" -or $uri -match "^api/v1/$world/listings") {
            # Check if this route is in spine
            $found = $false
            foreach ($spineEndpoint in $spineEndpoints[$world]) {
                $spinePath = $spineEndpoint.Path
                $spineMethod = $spineEndpoint.Method
                
                # Normalize for comparison
                $routePathNormalized = $uri -replace '^/api/v1/', '/api/v1/'
                $spinePathNormalized = $spinePath -replace '\{id\}', '{id}'
                
                if ($routePathNormalized -eq $spinePathNormalized -or 
                    ($routePathNormalized -match '\{id\}' -and $spinePathNormalized -match '\{id\}' -and
                     ($routePathNormalized -replace '/\{id\}.*$', '') -eq ($spinePathNormalized -replace '/\{id\}.*$', ''))) {
                    if ($method -eq $spineMethod -or ($method -like "GET*" -and $spineMethod -eq "GET")) {
                        $found = $true
                        break
                    }
                }
            }
            
            if (-not $found) {
                $undocumentedRoutes += "${method} ${uri}"
            }
        }
    }
}

if ($undocumentedRoutes.Count -gt 0) {
    Write-Fail "Undocumented routes found: $($undocumentedRoutes.Count)"
    foreach ($undoc in $undocumentedRoutes) {
        Write-Host "  - $undoc" -ForegroundColor Red
    }
    Add-CheckResult -Check "Routes Documentation" -Status "FAIL" -Notes "$($undocumentedRoutes.Count) undocumented routes: $($undocumentedRoutes -join '; ')"
    $overallPass = $false
} else {
    Write-Pass "All routes are documented in spine"
    Add-CheckResult -Check "Routes Documentation" -Status "PASS" -Notes "All routes documented"
}

# Step 6: Validate middleware posture
Write-Info ""
Write-Info "Step 6: Validating middleware posture..."

$requiredMiddleware = @("auth.any", "resolve.tenant", "tenant.user")
$middlewareIssues = @()

foreach ($route in $routes) {
    $uri = $route.uri
    $method = $route.method_primary
    
    # Only check write endpoints (POST, PATCH, DELETE) and protected GET endpoints
    if ($uri -match "^/api/v1/(commerce|food|rentals)/listings" -or $uri -match "^api/v1/(commerce|food|rentals)/listings") {
        $routeMiddleware = @()
        if ($route.middleware) {
            if ($route.middleware -is [string]) {
                $routeMiddleware = @($route.middleware)
            } elseif ($route.middleware -is [System.Collections.IEnumerable]) {
                $routeMiddleware = @($route.middleware)
            }
        }
        
        # Check if middleware info is present
        if ($routeMiddleware.Count -eq 0) {
            $middlewareIssues += "WARN: ${method} ${uri} - middleware info missing"
            continue
        }
        
        # Check required middleware
        $missingMw = @()
        foreach ($reqMw in $requiredMiddleware) {
            $found = $false
            foreach ($mw in $routeMiddleware) {
                if ($mw -eq $reqMw -or $mw -like "*$reqMw*") {
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                $missingMw += $reqMw
            }
        }
        
        if ($missingMw.Count -gt 0) {
            $middlewareIssues += "FAIL: ${method} ${uri} - missing middleware: $($missingMw -join ', ')"
        }
    }
}

$failMw = ($middlewareIssues | Where-Object { $_ -match "^FAIL:" }).Count
$warnMw = ($middlewareIssues | Where-Object { $_ -match "^WARN:" }).Count

if ($failMw -gt 0) {
    Write-Fail "Middleware issues: $failMw FAIL, $warnMw WARN"
    foreach ($issue in $middlewareIssues) {
        Write-Host "  $issue" -ForegroundColor $(if ($issue -match "^FAIL:") { "Red" } else { "Yellow" })
    }
    Add-CheckResult -Check "Middleware Posture" -Status "FAIL" -Notes "$failMw routes missing required middleware"
    $overallPass = $false
} elseif ($warnMw -gt 0) {
    Write-Warn "Middleware info missing for $warnMw routes (WARN only)"
    Add-CheckResult -Check "Middleware Posture" -Status "WARN" -Notes "Middleware info missing for $warnMw routes"
} else {
    Write-Pass "Middleware posture valid"
    Add-CheckResult -Check "Middleware Posture" -Status "PASS" -Notes "All routes have required middleware"
}

# Step 7: Error-contract posture smoke (check spine declares error envelope format)
Write-Info ""
Write-Info "Step 7: Validating error-contract posture..."

if ($spineContent -match "Error Envelope Contract" -or $spineContent -match "error envelope") {
    Write-Pass "Error envelope format declared in spine"
    Add-CheckResult -Check "Error Contract" -Status "PASS" -Notes "Error envelope format documented"
} else {
    Write-Warn "Error envelope format not explicitly declared in spine"
    Add-CheckResult -Check "Error Contract" -Status "WARN" -Notes "Error envelope format not found in spine"
}

# Optional: Live checks if docker available
$dockerAvailable = $false
try {
    $null = docker compose ps 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerAvailable = $true
    }
} catch {
    # Docker not available
}

if ($dockerAvailable) {
    Write-Info "Docker available - performing live error-contract checks..."
    # TODO: Implement live checks (unauthorized → 401/403, not found → 404)
    # For now, just note that docker is available
    Write-Info "Live checks skipped (non-blocking)"
}

# Summary
Write-Info ""
Write-Info "=== Summary ==="
$passCount = ($checkResults | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($checkResults | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($checkResults | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Info "PASS: ${passCount}, WARN: ${warnCount}, FAIL: ${failCount}"

Write-Info ""
Write-Info "=== Check Results ==="
Write-Host "Check | Status | Notes" -ForegroundColor Cyan
Write-Host ("-" * 80) -ForegroundColor Gray
foreach ($result in $checkResults) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[?]" }
    }
    Write-Host "$($result.Check.PadRight(30)) $statusMarker $($result.Notes)" -ForegroundColor $(if ($result.Status -eq "PASS") { "Green" } elseif ($result.Status -eq "WARN") { "Yellow" } else { "Red" })
}

if (-not $overallPass) {
    Write-Info ""
    Write-Fail "Product Contract Gate FAILED (${failCount} failure(s))"
    Invoke-OpsExit 1
    return
}

if ($hasWarn) {
    Write-Info ""
    Write-Warn "Product Contract Gate passed with warnings (${warnCount} warning(s))"
    Invoke-OpsExit 2
    return
}

Write-Info ""
Write-Pass "Product Contract Gate PASSED"
Invoke-OpsExit 0
