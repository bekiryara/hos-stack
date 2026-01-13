# product_contract.ps1 - Product API Contract Lock
# Validates enabled worlds have required routes + middleware posture
# Validates disabled worlds have NO routes (zero tolerance)
# PowerShell 5.1 compatible, ASCII-only output, safe exit pattern

param(
    [string]$RoutesPath = "work\pazar\routes\api.php",
    [string]$WorldsConfigPath = "work\pazar\config\worlds.php",
    [string]$RoutesSnapshotPath = "ops\snapshots\routes.pazar.json"
)

$ErrorActionPreference = "Continue"

# Dot-source shared helpers
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\_lib\ops_output.ps1"
. "$ScriptDir\_lib\ops_exit.ps1"

Initialize-OpsOutput

Write-Info "Product API Contract Lock"
Write-Info "Routes: ${RoutesPath}"
Write-Info "Worlds Config: ${WorldsConfigPath}"
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

# Step 1: Parse enabled/disabled worlds from config
Write-Info "Step 1: Parsing worlds configuration..."
$enabledWorlds = @()
$disabledWorlds = @()

if (-not (Test-Path $WorldsConfigPath)) {
    Write-Fail "Worlds config not found: ${WorldsConfigPath}"
    Add-CheckResult -Check "Worlds Config" -Status "FAIL" -Notes "Config file not found"
    Invoke-OpsExit 1
    return
}

$configContent = Get-Content $WorldsConfigPath -Raw

# Parse enabled worlds
if ($configContent -match "'enabled'\s*=>\s*\[(.*?)\]") {
    $enabledBlock = $matches[1]
    if ($enabledBlock -match "'commerce'") { $enabledWorlds += "commerce" }
    if ($enabledBlock -match "'food'") { $enabledWorlds += "food" }
    if ($enabledBlock -match "'rentals'") { $enabledWorlds += "rentals" }
}

# Parse disabled worlds
if ($configContent -match "'disabled'\s*=>\s*\[(.*?)\]") {
    $disabledBlock = $matches[1]
    if ($disabledBlock -match "'services'") { $disabledWorlds += "services" }
    if ($disabledBlock -match "'real_estate'") { $disabledWorlds += "real_estate" }
    if ($disabledBlock -match "'vehicle'") { $disabledWorlds += "vehicle" }
}

if ($enabledWorlds.Count -eq 0) {
    Write-Fail "No enabled worlds found in config"
    Add-CheckResult -Check "Worlds Config" -Status "FAIL" -Notes "No enabled worlds parsed"
    Invoke-OpsExit 1
    return
}

Write-Pass "Enabled worlds: $($enabledWorlds -join ', ')"
Write-Pass "Disabled worlds: $($disabledWorlds -join ', ')"
Add-CheckResult -Check "Worlds Config" -Status "PASS" -Notes "Found $($enabledWorlds.Count) enabled, $($disabledWorlds.Count) disabled"

# Step 2: Read routes file
Write-Info ""
Write-Info "Step 2: Reading routes file..."
if (-not (Test-Path $RoutesPath)) {
    Write-Fail "Routes file not found: ${RoutesPath}"
    Add-CheckResult -Check "Routes File" -Status "FAIL" -Notes "Routes file not found"
    Invoke-OpsExit 1
    return
}

$routesContent = Get-Content $RoutesPath -Raw
Write-Pass "Routes file read successfully"
Add-CheckResult -Check "Routes File" -Status "PASS" -Notes "Routes file exists"

# Step 3: Check enabled worlds route surface
Write-Info ""
Write-Info "Step 3: Validating enabled worlds route surface..."

$requiredRoutes = @(
    @{ Method = "GET"; Path = "/listings"; Name = "List Listings" },
    @{ Method = "GET"; Path = "/listings/{id}"; Name = "Show Listing" },
    @{ Method = "POST"; Path = "/listings"; Name = "Create Listing" },
    @{ Method = "PATCH"; Path = "/listings/{id}"; Name = "Update Listing" },
    @{ Method = "DELETE"; Path = "/listings/{id}"; Name = "Delete Listing" }
)

foreach ($world in $enabledWorlds) {
    Write-Info "Checking world: ${world}"
    $worldPass = $true
    $worldNotes = @()
    
    # Check each required route
    foreach ($route in $requiredRoutes) {
        $method = $route.Method
        $path = $route.Path
        $name = $route.Name
        
        # Pattern variations: prefix('v1/commerce'), prefix('v1')->prefix('commerce'), etc.
        # Check for world prefix group
        $worldPrefixPattern = "prefix\s*\(['\`"]v1[/\\]$world['\`"]\)|prefix\s*\(['\`"]v1['\`"]\)\s*->\s*prefix\s*\(['\`"]$world['\`"]\)"
        $hasWorldPrefix = $routesContent -match $worldPrefixPattern
        
        # Check for route within world prefix group
        $routeFound = $false
        if ($hasWorldPrefix) {
            # Find the world prefix block and check for route inside it
            $methodLower = $method.ToLower()
            $routePattern = "Route::$methodLower\s*\(['\`"]$path['\`"]"
            
            # Find all occurrences of the route pattern
            $routeMatches = [regex]::Matches($routesContent, $routePattern)
            foreach ($match in $routeMatches) {
                # Check if this route is within the world prefix block
                $routePos = $match.Index
                $prefixPos = $routesContent.LastIndexOf("prefix('v1/$world'", $routePos)
                if ($prefixPos -lt 0) {
                    $prefixPos = $routesContent.LastIndexOf("prefix(`"v1/$world`"", $routePos)
                }
                if ($prefixPos -lt 0) {
                    $prefixPos = $routesContent.LastIndexOf("prefix('v1/$world'", $routePos)
                }
                
                if ($prefixPos -ge 0 -and $prefixPos -lt $routePos) {
                    # Check if there's a closing brace or next prefix before the route
                    $blockEnd = $routesContent.IndexOf("});", $prefixPos)
                    if ($blockEnd -lt 0) {
                        $blockEnd = $routesContent.Length
                    }
                    if ($routePos -lt $blockEnd) {
                        $routeFound = $true
                        break
                    }
                }
            }
        }
        
        # Special handling: PATCH vs PUT (WARN if PUT instead of PATCH)
        if (-not $routeFound -and $method -eq "PATCH") {
            $putPattern = "Route::put\s*\(['\`"]$path['\`"]"
            if ($hasWorldPrefix -and $routesContent -match $putPattern) {
                $routeFound = $true
                $worldNotes += "PATCH route found as PUT (WARN)"
                $script:hasWarn = $true
            }
        }
        
        if (-not $routeFound) {
            $worldPass = $false
            $worldNotes += "Missing: ${method} ${path}"
        }
    }
    
    # Check middleware posture
    # Note: routes/api.php uses "resolve.tenant" not "tenant.resolve"
    $requiredMiddleware = @("auth.any", "resolve.tenant", "tenant.user")
    $optionalMiddleware = @("world.resolve")
    
    $middlewareFound = @()
    $middlewareMissing = @()
    $middlewareOptional = @()
    
    # Extract world prefix block for middleware check
    $worldPrefixPattern = "prefix\s*\(['\`"]v1[/\\]$world['\`"]\)"
    if ($routesContent -match $worldPrefixPattern) {
        $prefixMatch = [regex]::Match($routesContent, $worldPrefixPattern)
        if ($prefixMatch.Success) {
            $prefixPos = $prefixMatch.Index
            $remaining = $routesContent.Substring($prefixPos)
            $nextPrefixMatch = [regex]::Match($remaining, "prefix\s*\(['\`"]v1[/\\]")
            if ($nextPrefixMatch.Success -and $nextPrefixMatch.Index -gt $prefixMatch.Length) {
                $worldBlock = $remaining.Substring(0, $nextPrefixMatch.Index)
            } else {
                $worldBlock = $remaining
            }
            
            foreach ($mw in $requiredMiddleware) {
                # Normalize middleware name variations (resolve.tenant vs tenant.resolve)
                $mwVariations = @($mw)
                if ($mw -eq "resolve.tenant") {
                    $mwVariations += "tenant.resolve"
                }
                if ($mw -eq "tenant.user") {
                    $mwVariations += "ensure.tenant.user"
                }
                
                $found = $false
                foreach ($mwVar in $mwVariations) {
                    $mwPattern = $mwVar -replace "\.", "\."
                    if ($worldBlock -match "['\`"]$mwPattern['\`"]" -or $worldBlock -match "['\`"]$mwVar['\`"]") {
                        $found = $true
                        break
                    }
                }
                
                if ($found) {
                    $middlewareFound += $mw
                } else {
                    $middlewareMissing += $mw
                }
            }
            
            foreach ($mw in $optionalMiddleware) {
                $mwPattern = $mw -replace "\.", "\."
                if ($worldBlock -match "['\`"]$mwPattern['\`"]" -or $worldBlock -match "['\`"]$mw['\`"]") {
                    $middlewareOptional += $mw
                }
            }
        } else {
            # Fallback: check entire file
            foreach ($mw in $requiredMiddleware) {
                $mwVariations = @($mw)
                if ($mw -eq "resolve.tenant") {
                    $mwVariations += "tenant.resolve"
                }
                if ($mw -eq "tenant.user") {
                    $mwVariations += "ensure.tenant.user"
                }
                
                $found = $false
                foreach ($mwVar in $mwVariations) {
                    $mwPattern = $mwVar -replace "\.", "\."
                    if ($routesContent -match "['\`"]$mwPattern['\`"]" -or $routesContent -match "['\`"]$mwVar['\`"]") {
                        $found = $true
                        break
                    }
                }
                
                if ($found) {
                    $middlewareFound += $mw
                } else {
                    $middlewareMissing += $mw
                }
            }
        }
    } else {
        # Fallback: check entire file
        foreach ($mw in $requiredMiddleware) {
            $mwVariations = @($mw)
            if ($mw -eq "resolve.tenant") {
                $mwVariations += "tenant.resolve"
            }
            if ($mw -eq "tenant.user") {
                $mwVariations += "ensure.tenant.user"
            }
            
            $found = $false
            foreach ($mwVar in $mwVariations) {
                $mwPattern = $mwVar -replace "\.", "\."
                if ($routesContent -match "['\`"]$mwPattern['\`"]" -or $routesContent -match "['\`"]$mwVar['\`"]") {
                    $found = $true
                    break
                }
            }
            
            if ($found) {
                $middlewareFound += $mw
            } else {
                $middlewareMissing += $mw
            }
        }
    }
    
    if ($middlewareMissing.Count -gt 0) {
        $worldPass = $false
        $worldNotes += "Missing middleware: $($middlewareMissing -join ', ')"
    }
    
    if ($worldPass) {
        $notes = "All routes + middleware present"
        if ($middlewareOptional.Count -gt 0) {
            $notes += " (optional: $($middlewareOptional -join ', '))"
        }
        Write-Pass "World ${world}: PASS - ${notes}"
        Add-CheckResult -Check "Enabled World: ${world}" -Status "PASS" -Notes $notes
    } else {
        Write-Fail "World ${world}: FAIL - $($worldNotes -join '; ')"
        Add-CheckResult -Check "Enabled World: ${world}" -Status "FAIL" -Notes ($worldNotes -join '; ')
    }
}

# Step 4: Check disabled worlds (zero tolerance)
Write-Info ""
Write-Info "Step 4: Validating disabled worlds have NO routes..."

foreach ($world in $disabledWorlds) {
    Write-Info "Checking disabled world: ${world}"
    
    # Check for any route starting with /api/v1/<world>/
    $disabledPattern1 = "['\`"]/api/v1/$world/"
    $disabledPattern2 = "prefix\s*\(['\`"]v1[/\\]$world['\`"]\)"
    $disabledPattern3 = "prefix\s*\(['\`"]v1['\`"]\)\s*->\s*prefix\s*\(['\`"]$world['\`"]\)"
    
    $foundDisabledRoute = $false
    if ($routesContent -match $disabledPattern1 -or $routesContent -match $disabledPattern2 -or $routesContent -match $disabledPattern3) {
        $foundDisabledRoute = $true
    }
    
    if ($foundDisabledRoute) {
        Write-Fail "Disabled world ${world} has routes (ZERO TOLERANCE)"
        Add-CheckResult -Check "Disabled World: ${world}" -Status "FAIL" -Notes "Routes found for disabled world"
        $overallPass = $false
    } else {
        Write-Pass "Disabled world ${world}: No routes found"
        Add-CheckResult -Check "Disabled World: ${world}" -Status "PASS" -Notes "No routes found"
    }
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
foreach ($result in $checkResults) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[?]" }
    }
    Write-Host "$statusMarker $($result.Check): $($result.Notes)" -ForegroundColor $(if ($result.Status -eq "PASS") { "Green" } elseif ($result.Status -eq "WARN") { "Yellow" } else { "Red" })
}

if (-not $overallPass) {
    Write-Info ""
    Write-Fail "Product API Contract Lock FAILED (${failCount} failure(s))"
    Invoke-OpsExit 1
    return
}

if ($hasWarn) {
    Write-Info ""
    Write-Warn "Product API Contract Lock passed with warnings (${warnCount} warning(s))"
    Invoke-OpsExit 2
    return
}

Write-Info ""
Write-Pass "Product API Contract Lock PASSED"
Invoke-OpsExit 0

