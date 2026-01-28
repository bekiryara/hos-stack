#!/usr/bin/env pwsh
# WP-74: Catalog Integrity Check Script
# Verifies category tree integrity: cycles, orphans, duplicates, schema consistency

$ErrorActionPreference = "Stop"

# Load safe exit helper if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== CATALOG INTEGRITY CHECK (WP-74) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Database connection (default Laravel/Pazar settings)
$dbHost = $env:DB_HOST
if (-not $dbHost) { $dbHost = "localhost" }

$dbPort = $env:DB_PORT
if (-not $dbPort) { $dbPort = "5432" }

$dbName = $env:DB_DATABASE
if (-not $dbName) { $dbName = "pazar" }

$dbUser = $env:DB_USERNAME
if (-not $dbUser) { $dbUser = "pazar" }

$dbPassword = $env:DB_PASSWORD
if (-not $dbPassword) { $dbPassword = "pazar_password" }

# Try to use psql via Docker if local psql not available
$useDocker = $false
$dockerContainer = $null
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue

if (-not $psqlPath) {
    # Find PostgreSQL container
    $containers = docker ps --format "{{.Names}}" 2>&1
    $pazarDbContainer = $containers | Where-Object { $_ -match "pazar.*db|postgres.*pazar|pazar.*postgres" } | Select-Object -First 1
    
    if (-not $pazarDbContainer) {
        # Try common container names
        $commonNames = @("pazar-db", "pazar_postgres", "stack-pazar-db-1", "pazar-postgres-1")
        foreach ($name in $commonNames) {
            $test = docker exec $name psql --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $pazarDbContainer = $name
                break
            }
        }
    }
    
    if ($pazarDbContainer) {
        $useDocker = $true
        $dockerContainer = $pazarDbContainer
        Write-Host "Using Docker exec for database queries (container: $dockerContainer)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: psql command not found and no PostgreSQL container found" -ForegroundColor Red
        Write-Host "  Install PostgreSQL client tools or ensure database container is running" -ForegroundColor Yellow
        Write-Host "  Run: docker ps to see available containers" -ForegroundColor Yellow
        exit 1
    }
}

# Helper: Run SQL query and return result
function Invoke-PostgresQuery {
    param(
        [string]$Query,
        [string]$Description
    )
    
    try {
        if ($useDocker) {
            # Use Docker exec with -c flag (single command)
            # Convert multi-line query to single line and escape properly
            $singleLineQuery = ($Query -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }) -join " "
            # Escape single quotes for shell
            $escapedQuery = $singleLineQuery -replace "'", "'\''"
            $result = docker exec $dockerContainer sh -c "psql -U $dbUser -d $dbName -t -A -F '|' -c '$escapedQuery'" 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "FAIL: $Description" -ForegroundColor Red
                Write-Host "  Error: $result" -ForegroundColor Yellow
                return $null
            }
        } else {
            # Use local psql
            $env:PGPASSWORD = $dbPassword
            $result = $Query | & psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -t -A -F "|" 2>&1
            $env:PGPASSWORD = $null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "FAIL: $Description" -ForegroundColor Red
                Write-Host "  Error: $result" -ForegroundColor Yellow
                return $null
            }
        }
        
        return $result
    } catch {
        Write-Host "FAIL: $Description" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

# Test A: Cycle Check (no loops in parent chain)
Write-Host "[A] Testing cycle check (no loops in category parent chain)..." -ForegroundColor Yellow
$cycleQuery = @"
WITH RECURSIVE category_path AS (
    SELECT id, parent_id, ARRAY[id] as path, 0 as depth
    FROM categories
    WHERE parent_id IS NOT NULL
    
    UNION ALL
    
    SELECT c.id, c.parent_id, cp.path || c.id, cp.depth + 1
    FROM categories c
    INNER JOIN category_path cp ON c.parent_id = cp.id
    WHERE NOT (c.id = ANY(cp.path))
      AND cp.depth < 100
)
SELECT id, parent_id
FROM category_path
WHERE id = ANY(path[1:array_length(path,1)-1])
LIMIT 10;
"@

$cycleResult = Invoke-PostgresQuery -Query $cycleQuery -Description "Cycle check query failed"
if ($cycleResult -and $cycleResult.Trim().Length -gt 0) {
    Write-Host "FAIL: Found cycles in category parent chain" -ForegroundColor Red
    Write-Host "  Cycles detected (first 10):" -ForegroundColor Yellow
    $cycleResult -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
        $parts = $_ -split '\|'
        if ($parts.Count -ge 2) {
            Write-Host "    ID: $($parts[0]), Parent: $($parts[1])" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
} else {
    Write-Host "PASS: No cycles detected in category parent chain" -ForegroundColor Green
}

Write-Host ""

# Test B: Orphan Check (parent_id points to missing category)
Write-Host "[B] Testing orphan check (parent_id points to existing category)..." -ForegroundColor Yellow
$orphanQuery = @"
SELECT c.id, c.parent_id, c.slug
FROM categories c
WHERE c.parent_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM categories p WHERE p.id = c.parent_id
  )
LIMIT 10;
"@

$orphanResult = Invoke-PostgresQuery -Query $orphanQuery -Description "Orphan check query failed"
if ($orphanResult -and $orphanResult.Trim().Length -gt 0) {
    Write-Host "FAIL: Found orphan categories (parent_id points to missing category)" -ForegroundColor Red
    Write-Host "  Orphan categories (first 10):" -ForegroundColor Yellow
    $orphanResult -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
        $parts = $_ -split '\|'
        if ($parts.Count -ge 3) {
            Write-Host "    ID: $($parts[0]), Parent: $($parts[1]), Slug: $($parts[2])" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
} else {
    Write-Host "PASS: No orphan categories found" -ForegroundColor Green
}

Write-Host ""

# Test C: Duplicate Slug Check (slug unique)
Write-Host "[C] Testing duplicate slug check (slug must be unique)..." -ForegroundColor Yellow
$duplicateQuery = @"
SELECT slug, COUNT(*) as count
FROM categories
WHERE status = 'active' OR status IS NULL
GROUP BY slug
HAVING COUNT(*) > 1
LIMIT 10;
"@

$duplicateResult = Invoke-PostgresQuery -Query $duplicateQuery -Description "Duplicate slug check query failed"
if ($duplicateResult -and $duplicateResult.Trim().Length -gt 0) {
    Write-Host "FAIL: Found duplicate slugs" -ForegroundColor Red
    Write-Host "  Duplicate slugs (first 10):" -ForegroundColor Yellow
    $duplicateResult -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
        $parts = $_ -split '\|'
        if ($parts.Count -ge 2) {
            Write-Host "    Slug: $($parts[0]), Count: $($parts[1])" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
} else {
    Write-Host "PASS: No duplicate slugs found" -ForegroundColor Green
}

Write-Host ""

# Test D: Schema Integrity Check (category_filter_schema.attribute_key exists in attributes.key)
Write-Host "[D] Testing schema integrity (filter schema attributes must exist)..." -ForegroundColor Yellow
$schemaQuery = @"
SELECT cfs.category_id, cfs.attribute_key, c.slug
FROM category_filter_schema cfs
INNER JOIN categories c ON c.id = cfs.category_id
WHERE cfs.status = 'active'
  AND NOT EXISTS (
    SELECT 1 FROM attributes a WHERE a.key = cfs.attribute_key
  )
LIMIT 10;
"@

$schemaResult = Invoke-PostgresQuery -Query $schemaQuery -Description "Schema integrity check query failed"
if ($schemaResult -and $schemaResult.Trim().Length -gt 0) {
    Write-Host "FAIL: Found filter schema attributes that don't exist in attributes table" -ForegroundColor Red
    Write-Host "  Invalid attributes (first 10):" -ForegroundColor Yellow
    $schemaResult -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
        $parts = $_ -split '\|'
        if ($parts.Count -ge 3) {
            Write-Host "    Category: $($parts[2]) (ID: $($parts[0])), Attribute: $($parts[1])" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
} else {
    Write-Host "PASS: All filter schema attributes exist in attributes table" -ForegroundColor Green
}

Write-Host ""

# Test E: Root Invariants (vehicle/real-estate/service roots exist)
Write-Host "[E] Testing root invariants (required root categories exist)..." -ForegroundColor Yellow
$rootQuery = @"
SELECT slug, id, parent_id
FROM categories
WHERE parent_id IS NULL
  AND status = 'active'
ORDER BY slug;
"@

$rootResult = Invoke-PostgresQuery -Query $rootQuery -Description "Root invariants check query failed"
if ($rootResult) {
    $rootSlugs = ($rootResult -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
        ($_ -split '\|')[0]
    }) | Where-Object { $_ }
    
    $requiredRoots = @("real-estate", "service", "vehicle")
    $missingRoots = @()
    $extraRoots = @()
    
    foreach ($required in $requiredRoots) {
        if ($rootSlugs -notcontains $required) {
            $missingRoots += $required
        }
    }
    
    foreach ($found in $rootSlugs) {
        if ($requiredRoots -notcontains $found) {
            $extraRoots += $found
        }
    }
    
    if ($missingRoots.Count -gt 0 -or $extraRoots.Count -gt 0) {
        Write-Host "FAIL: Root category invariants violated" -ForegroundColor Red
        if ($missingRoots.Count -gt 0) {
            Write-Host "  Missing required roots: $($missingRoots -join ', ')" -ForegroundColor Yellow
        }
        if ($extraRoots.Count -gt 0) {
            Write-Host "  Extra roots found: $($extraRoots -join ', ')" -ForegroundColor Yellow
        }
        Write-Host "  Found roots: $($rootSlugs -join ', ')" -ForegroundColor Yellow
        $hasFailures = $true
    } else {
        Write-Host "PASS: All required root categories present (vehicle, real-estate, service)" -ForegroundColor Green
        Write-Host "  Found roots: $($rootSlugs -join ', ')" -ForegroundColor Gray
    }
} else {
    Write-Host "FAIL: Could not check root invariants" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Test F: Filter-schema reachability (active schema rows must belong to active categories)
Write-Host "[F] Testing filter-schema reachability (active schema categories must be active)..." -ForegroundColor Yellow
$schemaReachQuery = @"
SELECT cfs.category_id, c.slug, c.status, cfs.attribute_key
FROM category_filter_schema cfs
INNER JOIN categories c ON c.id = cfs.category_id
WHERE cfs.status = 'active'
  AND c.status <> 'active'
LIMIT 10;
"@

$schemaReachResult = Invoke-PostgresQuery -Query $schemaReachQuery -Description "Schema reachability check query failed"
if ($schemaReachResult -and $schemaReachResult.Trim().Length -gt 0) {
    Write-Host "FAIL: Found active filter-schema rows attached to non-active categories" -ForegroundColor Red
    Write-Host "  Offenders (first 10):" -ForegroundColor Yellow
    $schemaReachResult -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
        $parts = $_ -split '\|'
        if ($parts.Count -ge 4) {
            Write-Host "    Category: $($parts[1]) (ID: $($parts[0]), status: $($parts[2])) attr: $($parts[3])" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
} else {
    Write-Host "PASS: All active filter-schema rows belong to active categories" -ForegroundColor Green
}

Write-Host ""

# Test G: Allowed schema renderer types (number|range|boolean|string|select)
Write-Host "[G] Testing allowed schema renderer types (number|range|boolean|string|select)..." -ForegroundColor Yellow
$schemaTypeQuery = @"
SELECT c.slug, cfs.attribute_key, a.value_type, cfs.ui_component, cfs.filter_mode
FROM category_filter_schema cfs
INNER JOIN categories c ON c.id = cfs.category_id
INNER JOIN attributes a ON a.key = cfs.attribute_key
WHERE cfs.status = 'active'
ORDER BY c.slug, cfs.attribute_key;
"@

$schemaTypeResult = Invoke-PostgresQuery -Query $schemaTypeQuery -Description "Schema type check query failed"
if ($schemaTypeResult -eq $null) {
    Write-Host "FAIL: Could not check schema renderer types" -ForegroundColor Red
    $hasFailures = $true
} else {
    $bad = @()
    $lines = $schemaTypeResult -split "`n" | Where-Object { $_.Trim().Length -gt 0 }
    foreach ($line in $lines) {
        $parts = $line -split '\|'
        if ($parts.Count -lt 5) { continue }
        $slug = $parts[0]
        $attr = $parts[1]
        $valueType = $parts[2]
        $ui = $parts[3]
        $mode = $parts[4]

        $renderer = $null
        if ($mode -eq 'range') {
            $renderer = 'range'
            if ($valueType -ne 'number') {
                $bad += "Category=$slug attr=${attr}: range requires value_type=number (got $valueType)"
                continue
            }
        } elseif ($ui -eq 'select') {
            $renderer = 'select'
        } elseif ($valueType -eq 'boolean') {
            $renderer = 'boolean'
        } elseif ($valueType -eq 'number') {
            $renderer = 'number'
        } elseif ($valueType -eq 'string') {
            $renderer = 'string'
        } else {
            $bad += "Category=$slug attr=${attr}: unsupported value_type=$valueType (ui_component=$ui, filter_mode=$mode)"
            continue
        }

        $allowed = @('number','range','boolean','string','select')
        if ($allowed -notcontains $renderer) {
            $bad += "Category=$slug attr=${attr}: computed renderer=$renderer not allowed"
        }
    }

    if ($bad.Count -gt 0) {
        Write-Host "FAIL: Found invalid schema renderer/type combinations" -ForegroundColor Red
        $bad | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        if ($bad.Count -gt 10) {
            Write-Host "  ... ($($bad.Count) total)" -ForegroundColor Yellow
        }
        $hasFailures = $true
    } else {
        Write-Host "PASS: All active filter-schema rows map to allowed renderers" -ForegroundColor Green
    }
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== CATALOG INTEGRITY CHECK: FAIL ===" -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== CATALOG INTEGRITY CHECK: PASS ===" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

