#!/usr/bin/env pwsh
# BOUNDARY CONTRACT CHECK (Boundary Contract Pack v1)
# Validates service boundaries: no cross-database access, required headers, context-only integration.

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== BOUNDARY CONTRACT CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$repoRoot = Split-Path -Parent $scriptDir

# Check 1: No cross-database access (static checks)
Write-Host "[1] Checking for cross-database access violations..." -ForegroundColor Yellow

$pazarDir = Join-Path $repoRoot "work\pazar"
$messagingDir = Join-Path $repoRoot "work\messaging"
$hosDir = Join-Path $repoRoot "work\hos"

# Check Pazar code does not reference messaging-db
$pazarFiles = Get-ChildItem -Path $pazarDir -Recurse -Include *.php -File | Where-Object { $_.FullName -notmatch 'vendor|node_modules' }
$violations = @()

foreach ($file in $pazarFiles) {
    $content = Get-Content $file.FullName -Raw
    
    # Check for messaging-db connection string patterns
    if ($content -match "messaging-db|messaging_db|MESSAGING_DB|messaging.*connection|DB_CONNECTION.*messaging") {
        $violations += "Pazar file references messaging-db: $($file.FullName)"
    }
    
    # Check for direct messaging DB access (DB::connection('messaging'))
    if ($content -match "DB::connection\(['""]messaging") {
        $violations += "Pazar file uses messaging DB connection: $($file.FullName)"
    }
}

# Check Messaging service does not import Pazar migrations
if (Test-Path $messagingDir) {
    $messagingFiles = Get-ChildItem -Path $messagingDir -Recurse -Include *.js,*.sql,*.ts -File | Where-Object { $_.FullName -notmatch 'node_modules' }
    
    foreach ($file in $messagingFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Check for Pazar table references
        if ($content -match "listings|reservations|orders|rentals|pazar") {
            # Skip if it's just context references (e.g., "context_type = 'reservation'")
            if ($content -match "create.*table.*(listings|reservations|orders|rentals)" -or $content -match "migration.*pazar") {
                $violations += "Messaging file imports Pazar schema: $($file.FullName)"
            }
        }
    }
}

# Check HOS code does not access pazar-db or messaging-db
if (Test-Path $hosDir) {
    $hosFiles = Get-ChildItem -Path $hosDir -Recurse -Include *.js,*.sql,*.ts -File | Where-Object { $_.FullName -notmatch 'node_modules' }
    
    foreach ($file in $hosFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Check for Pazar/Messaging DB references
        if ($content -match "(pazar-db|messaging-db|pazar_db|messaging_db|PAZAR_DB|MESSAGING_DB)") {
            $violations += "HOS file references external DB: $($file.FullName)"
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host "FAIL: Cross-database access violations found:" -ForegroundColor Red
    foreach ($violation in $violations) {
        Write-Host "  - $violation" -ForegroundColor Red
    }
    $hasFailures = $true
} else {
    Write-Host "PASS: No cross-database access violations found" -ForegroundColor Green
}

Write-Host ""

# Check 2: Required headers on persona-scope endpoints (WP-8)
Write-Host "[2] Checking persona-scope endpoints for required headers (WP-8)..." -ForegroundColor Yellow

$writeSnapshot = Join-Path $repoRoot "contracts\api\marketplace.write.snapshot.json"
if (Test-Path $writeSnapshot) {
    try {
        $writeSnap = Get-Content $writeSnapshot -Raw | ConvertFrom-Json
        
        $pazarRoutesDir = Join-Path $repoRoot "work\pazar\routes\api"
        $routeFiles = Get-ChildItem -Path $pazarRoutesDir -Filter "*.php" -File
        
        $missingHeaderChecks = @()
        
        # WP-8: Check PERSONAL endpoints (require Authorization header)
        $personalEndpoints = @(
            @{ method = "POST"; path = "/api/v1/reservations" },
            @{ method = "POST"; path = "/api/v1/rentals" },
            @{ method = "POST"; path = "/api/v1/orders" }
        )
        
        foreach ($endpoint in $personalEndpoints) {
            $method = $endpoint.method
            $path = $endpoint.path
            $pathInRoute = $path -replace '^/api', ''
            
            # Find route file
            $foundInFile = $null
            $routeContent = $null
            
            foreach ($routeFile in $routeFiles) {
                $content = Get-Content $routeFile.FullName -Raw
                
                # Build regex pattern
                $pathTemp = $pathInRoute -replace '\{id\}', '___ID_PLACEHOLDER___'
                $pathEscaped = [regex]::Escape($pathTemp)
                $pathEscaped = $pathEscaped -replace '___ID_PLACEHOLDER___', '\{id\}'
                $methodLower = $method.ToLower()
                $pattern = "Route::(?:middleware\([^)]+\)->)?$methodLower\(['""]$pathEscaped['""]"
                
                if ($content -match $pattern) {
                    $foundInFile = $routeFile.FullName
                    $routeContent = $content
                    break
                }
            }
            
            if ($foundInFile) {
                # WP-8: Check for persona.scope:personal middleware OR Authorization header validation
                $hasPersonaScopeMiddleware = ($routeContent -match "middleware\(['""]persona\.scope:personal['""]|middleware\(\[[^]]*['""]persona\.scope:personal['""]")
                $hasAuthHeaderCheck = ($routeContent -match "Authorization|bearerToken|bearer\(\)")
                
                if (-not $hasPersonaScopeMiddleware -and -not $hasAuthHeaderCheck) {
                    $missingHeaderChecks += "$method $path - missing Authorization header check (no persona.scope:personal middleware or inline validation)"
                }
            } else {
                $missingHeaderChecks += "$method $path - route file not found (cannot verify header check)"
            }
        }
        
        # WP-8: Check STORE endpoints (require X-Active-Tenant-Id header)
        $storeScopeEndpoints = $writeSnap | Where-Object { $_.scope -eq "store" }
        
        foreach ($endpoint in $storeScopeEndpoints) {
            $method = $endpoint.method
            $path = $endpoint.path
            $requiredHeaders = $endpoint.required_headers
            
            # Find route file
            $foundInFile = $null
            $routeContent = $null
            
            foreach ($routeFile in $routeFiles) {
                $content = Get-Content $routeFile.FullName -Raw
                $pathInRoute = $path -replace '^/api', ''
                
                $pathTemp = $pathInRoute -replace '\{id\}', '___ID_PLACEHOLDER___'
                $pathEscaped = [regex]::Escape($pathTemp)
                $pathEscaped = $pathEscaped -replace '___ID_PLACEHOLDER___', '\{id\}'
                $methodLower = $method.ToLower()
                $pattern = "Route::(?:middleware\([^)]+\)->)?$methodLower\(['""]$pathEscaped['""]"
                
                if ($content -match $pattern) {
                    $foundInFile = $routeFile.FullName
                    $routeContent = $content
                    break
                }
            }
            
            if ($foundInFile) {
                # WP-8: Check for persona.scope:store OR tenant.scope middleware OR inline header validation
                $hasPersonaScopeMiddleware = ($routeContent -match "middleware\(['""]persona\.scope:store['""]|middleware\(\[[^]]*['""]persona\.scope:store['""]")
                $hasTenantScopeMiddleware = ($routeContent -match "middleware\(['""]tenant\.scope['""]|middleware\(\[[^]]*['""]tenant\.scope['""]")
                $hasInlineHeaderCheck = ($routeContent -match "X-Active-Tenant-Id|XActiveTenantId")
                
                if (-not $hasPersonaScopeMiddleware -and -not $hasTenantScopeMiddleware -and -not $hasInlineHeaderCheck -and "X-Active-Tenant-Id" -in $requiredHeaders) {
                    $missingHeaderChecks += "$method $path - missing X-Active-Tenant-Id header check (no persona.scope:store/tenant.scope middleware or inline validation)"
                }
            } else {
                if ("X-Active-Tenant-Id" -in $requiredHeaders) {
                    $missingHeaderChecks += "$method $path - route file not found (cannot verify header check)"
                }
            }
        }
        
        if ($missingHeaderChecks.Count -gt 0) {
            Write-Host "FAIL: Persona-scope endpoints missing header validation (WP-8):" -ForegroundColor Red
            foreach ($missing in $missingHeaderChecks) {
                Write-Host "  - $missing" -ForegroundColor Red
            }
            $hasFailures = $true
        } else {
            Write-Host "PASS: Persona-scope endpoints have required header validation (WP-8)" -ForegroundColor Green
        }
    } catch {
        Write-Host "WARN: Could not validate header checks: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "WARN: Write snapshot not found, skipping header validation check" -ForegroundColor Yellow
}

Write-Host ""

# Check 3: Context-only integration pattern (best-effort check)
Write-Host "[3] Checking context-only integration pattern..." -ForegroundColor Yellow

# Check Pazar uses MessagingClient (not direct DB access)
$messagingClientUsage = $false
$pazarRoutesFiles = Get-ChildItem -Path (Join-Path $repoRoot "work\pazar\routes\api") -Filter "*.php" -File

foreach ($file in $pazarRoutesFiles) {
    $content = Get-Content $file.FullName -Raw
    
    # Check for MessagingClient usage
    if ($content -match "MessagingClient|messagingClient|new.*MessagingClient") {
        $messagingClientUsage = $true
    }
}

if ($messagingClientUsage) {
    Write-Host "PASS: Pazar uses MessagingClient for context-only integration" -ForegroundColor Green
} else {
    Write-Host "WARN: MessagingClient usage not found (may not be using messaging integration)" -ForegroundColor Yellow
}

# Check Pazar uses MembershipClient (not hardcoded validation)
$membershipClientUsage = $false
foreach ($file in $pazarRoutesFiles) {
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match "MembershipClient|membershipClient|new.*MembershipClient") {
        $membershipClientUsage = $true
    }
}

if ($membershipClientUsage) {
    Write-Host "PASS: Pazar uses MembershipClient for HOS integration" -ForegroundColor Green
} else {
    Write-Host "WARN: MembershipClient usage not found" -ForegroundColor Yellow
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== BOUNDARY CONTRACT CHECK: FAIL ===" -ForegroundColor Red
    Write-Host "Cross-database access violations found. Fix issues and re-run." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "=== BOUNDARY CONTRACT CHECK: PASS ===" -ForegroundColor Green
    Write-Host "All boundary checks passed. No cross-database access violations." -ForegroundColor Gray
    exit 0
}

