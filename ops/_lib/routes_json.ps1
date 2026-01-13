# routes_json.ps1 - Route JSON Normalization Helper
# Normalizes Laravel route:list --json output to canonical array format
# Handles multiple Laravel JSON output formats (array, object with headers/rows, data/rows, etc.)
# PowerShell 5.1 compatible

# Get raw route JSON from Laravel artisan
function Get-RawPazarRouteListJson {
    param(
        [string]$ContainerName = "pazar-app"
    )
    
    $rawJson = docker compose exec -T $ContainerName sh -lc "php artisan route:list --json" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch routes from $ContainerName: $rawJson"
    }
    
    return $rawJson
}

# Convert route JSON to canonical array format
function Convert-RoutesJsonToCanonicalArray {
    param(
        [string]$RawJsonText
    )
    
    # Trim leading BOM (U+FEFF) and whitespace
    $trimmed = $RawJsonText.TrimStart([char]0xFEFF).Trim()
    
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return @()
    }
    
    # Parse JSON
    try {
        $obj = $trimmed | ConvertFrom-Json
    } catch {
        throw "Failed to parse route JSON: $($_.Exception.Message)"
    }
    
    $canonicalRoutes = @()
    
    # Case 1: Already an array
    if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string] -and $obj -isnot [System.Collections.Hashtable]) {
        $routeArray = @($obj)
        foreach ($route in $routeArray) {
            $canonicalRoutes += Convert-RouteToCanonicalObject -Route $route
        }
    }
    # Case 2: Object with headers/rows or columns
    elseif ($obj -is [PSCustomObject] -or $obj -is [System.Collections.Hashtable]) {
        # Check for headers/rows format
        if ($obj.PSObject.Properties.Name -contains "headers" -and $obj.PSObject.Properties.Name -contains "rows") {
            $headers = $obj.headers
            $rows = $obj.rows
            
            # Build index map (case-insensitive)
            $indexMap = @{}
            for ($i = 0; $i -lt $headers.Count; $i++) {
                $headerName = $headers[$i].ToLower()
                $indexMap[$headerName] = $i
            }
            
            # Map common header names to canonical fields
            $methodIndex = $null
            $uriIndex = $null
            $nameIndex = $null
            $actionIndex = $null
            $middlewareIndex = $null
            $domainIndex = $null
            
            foreach ($key in $indexMap.Keys) {
                if ($key -eq "method" -or $key -eq "verb") {
                    $methodIndex = $indexMap[$key]
                } elseif ($key -eq "uri" -or $key -eq "path" -or $key -eq "url") {
                    $uriIndex = $indexMap[$key]
                } elseif ($key -eq "name" -or $key -eq "route") {
                    $nameIndex = $indexMap[$key]
                } elseif ($key -eq "action" -or $key -eq "controller") {
                    $actionIndex = $indexMap[$key]
                } elseif ($key -eq "middleware" -or $key -eq "middlewares") {
                    $middlewareIndex = $indexMap[$key]
                } elseif ($key -eq "domain") {
                    $domainIndex = $indexMap[$key]
                }
            }
            
            # Convert rows to canonical objects
            foreach ($row in $rows) {
                $routeObj = [PSCustomObject]@{
                    method = if ($methodIndex -ne $null -and $row.Count -gt $methodIndex) { $row[$methodIndex] } else { $null }
                    uri = if ($uriIndex -ne $null -and $row.Count -gt $uriIndex) { $row[$uriIndex] } else { $null }
                    name = if ($nameIndex -ne $null -and $row.Count -gt $nameIndex) { $row[$nameIndex] } else { $null }
                    action = if ($actionIndex -ne $null -and $row.Count -gt $actionIndex) { $row[$actionIndex] } else { $null }
                    middleware = if ($middlewareIndex -ne $null -and $row.Count -gt $middlewareIndex) { $row[$middlewareIndex] } else { $null }
                    domain = if ($domainIndex -ne $null -and $row.Count -gt $domainIndex) { $row[$domainIndex] } else { $null }
                }
                $canonicalRoutes += Convert-RouteToCanonicalObject -Route $routeObj
            }
        }
        # Check for data array
        elseif ($obj.PSObject.Properties.Name -contains "data" -and $obj.data -is [System.Collections.IEnumerable]) {
            $routeArray = @($obj.data)
            foreach ($route in $routeArray) {
                $canonicalRoutes += Convert-RouteToCanonicalObject -Route $route
            }
        }
        # Check for routes array
        elseif ($obj.PSObject.Properties.Name -contains "routes" -and $obj.routes -is [System.Collections.IEnumerable]) {
            $routeArray = @($obj.routes)
            foreach ($route in $routeArray) {
                $canonicalRoutes += Convert-RouteToCanonicalObject -Route $route
            }
        }
        # Fallback: treat object as single route
        else {
            $canonicalRoutes += Convert-RouteToCanonicalObject -Route $obj
        }
    }
    else {
        throw "Unexpected route JSON format: $($obj.GetType().Name)"
    }
    
    # Normalize method (extract primary method from "GET|HEAD" format)
    foreach ($route in $canonicalRoutes) {
        if ($route.method -and $route.method -match '^([A-Z]+)') {
            $route | Add-Member -MemberType NoteProperty -Name "method_primary" -Value $matches[1] -Force
        } else {
            $route | Add-Member -MemberType NoteProperty -Name "method_primary" -Value $route.method -Force
        }
    }
    
    # Deterministic ordering: sort by uri, then method_primary, then name
    $canonicalRoutes = $canonicalRoutes | Sort-Object -Property @{Expression = { if ($_.uri) { $_.uri } else { "" } }}, @{Expression = { if ($_.method_primary) { $_.method_primary } else { "" } }}, @{Expression = { if ($_.name) { $_.name } else { "" } }}
    
    return $canonicalRoutes
}

# Convert a single route object to canonical format
function Convert-RouteToCanonicalObject {
    param(
        [object]$Route
    )
    
    $canonical = [PSCustomObject]@{
        method = $null
        uri = $null
        name = $null
        action = $null
        middleware = $null
        domain = $null
    }
    
    if ($Route -is [PSCustomObject] -or $Route -is [System.Collections.Hashtable]) {
        # Try to get properties (case-insensitive)
        $props = if ($Route -is [PSCustomObject]) { $Route.PSObject.Properties } else { $Route.Keys }
        
        foreach ($prop in $props) {
            $propName = if ($Route -is [PSCustomObject]) { $prop.Name } else { $prop }
            $propValue = if ($Route -is [PSCustomObject]) { $prop.Value } else { $Route[$prop] }
            $propNameLower = $propName.ToLower()
            
            if ($propNameLower -eq "method" -or $propNameLower -eq "verb") {
                $canonical.method = $propValue
            } elseif ($propNameLower -eq "uri" -or $propNameLower -eq "path" -or $propNameLower -eq "url") {
                $canonical.uri = $propValue
            } elseif ($propNameLower -eq "name" -or $propNameLower -eq "route") {
                $canonical.name = $propValue
            } elseif ($propNameLower -eq "action" -or $propNameLower -eq "controller") {
                $canonical.action = $propValue
            } elseif ($propNameLower -eq "middleware" -or $propNameLower -eq "middlewares") {
                $canonical.middleware = $propValue
            } elseif ($propNameLower -eq "domain") {
                $canonical.domain = $propValue
            }
        }
    }
    
    return $canonical
}

