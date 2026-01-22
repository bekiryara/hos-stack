#!/usr/bin/env pwsh
# WP-1.2: World Status Check Script
# Verifies HOS and Pazar world status endpoints

$ErrorActionPreference = "Stop"

# Load safe exit helper if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== WORLD STATUS CHECK (WP-1.2) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Test 1: HOS GET /v1/world/status
Write-Host "[1] Testing HOS GET /v1/world/status..." -ForegroundColor Yellow
$hosWorldStatusUrl = "http://localhost:3000/v1/world/status"
try {
    $response = Invoke-RestMethod -Uri $hosWorldStatusUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray

    # Validate response format
    if (-not $response.world_key) {
        Write-Host "FAIL: Missing 'world_key' in response" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($response.world_key -ne "core") {
        Write-Host "FAIL: Expected world_key='core', got '$($response.world_key)'" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($response.availability -ne "ONLINE") {
        Write-Host "FAIL: Expected availability='ONLINE', got '$($response.availability)'" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.phase) {
        Write-Host "FAIL: Missing 'phase' in response" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.version) {
        Write-Host "FAIL: Missing 'version' in response" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: HOS /v1/world/status returns valid response" -ForegroundColor Green
        Write-Host "  world_key: $($response.world_key)" -ForegroundColor Gray
        Write-Host "  availability: $($response.availability)" -ForegroundColor Gray
        Write-Host "  phase: $($response.phase)" -ForegroundColor Gray
        Write-Host "  version: $($response.version)" -ForegroundColor Gray
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
            try {
                $statusCode = $_.Exception.Response.StatusCode
            } catch {
            }
        }
    }
    
    if ($statusCode -eq 404) {
        Write-Host "FAIL: 404 Not Found - Endpoint does not exist: $hosWorldStatusUrl" -ForegroundColor Red
        Write-Host "  Expected: GET $hosWorldStatusUrl" -ForegroundColor Yellow
        Write-Host "  Check: HOS API app.js should have app.get('/world/status', ...) registered with /v1 prefix" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: HOS /v1/world/status request failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  URL: $hosWorldStatusUrl" -ForegroundColor Yellow
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

Write-Host ""

# Test 2: HOS GET /v1/worlds
Write-Host "[2] Testing HOS GET /v1/worlds..." -ForegroundColor Yellow
$hosWorldsUrl = "http://localhost:3000/v1/worlds"
try {
    $response = Invoke-RestMethod -Uri $hosWorldsUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray

    # Validate response format
    if (-not ($response -is [Array])) {
        Write-Host "FAIL: Expected array response, got $($response.GetType().Name)" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $worldKeys = $response | ForEach-Object { $_.world_key }
        $hasCore = $worldKeys -contains "core"
        $hasMarketplace = $worldKeys -contains "marketplace"
        $hasMessaging = $worldKeys -contains "messaging"
        $hasSocial = $worldKeys -contains "social"

        if (-not $hasCore) {
            Write-Host "FAIL: Response array missing 'core' world" -ForegroundColor Red
            $hasFailures = $true
        } elseif (-not $hasMarketplace) {
            Write-Host "FAIL: Response array missing 'marketplace' world" -ForegroundColor Red
            $hasFailures = $true
        } elseif (-not $hasMessaging) {
            Write-Host "FAIL: Response array missing 'messaging' world" -ForegroundColor Red
            $hasFailures = $true
        } elseif (-not $hasSocial) {
            Write-Host "FAIL: Response array missing 'social' world" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: HOS /v1/worlds returns valid array with all worlds" -ForegroundColor Green
            foreach ($world in $response) {
                Write-Host "  - $($world.world_key): $($world.availability) ($($world.phase), v$($world.version))" -ForegroundColor Gray
            }
            
            # Availability rules validation (WP-37)
            $coreWorld = $response | Where-Object { $_.world_key -eq "core" }
            $marketplaceWorld = $response | Where-Object { $_.world_key -eq "marketplace" }
            $messagingWorld = $response | Where-Object { $_.world_key -eq "messaging" }
            $socialWorld = $response | Where-Object { $_.world_key -eq "social" }

            # Rule 1: core.availability MUST be "ONLINE"
            if (-not $coreWorld -or $coreWorld.availability -ne "ONLINE") {
                Write-Host "FAIL: core.availability MUST be 'ONLINE', got '$($coreWorld.availability)'" -ForegroundColor Red
                $hasFailures = $true
            }

            # Rule 2: marketplace.availability MUST be "ONLINE"
            if (-not $marketplaceWorld -or $marketplaceWorld.availability -ne "ONLINE") {
                Write-Host "FAIL: marketplace.availability MUST be 'ONLINE', got '$($marketplaceWorld.availability)'" -ForegroundColor Red
                Write-Host "  [DEBUG] Check PAZAR_STATUS_URL env var and pazar-app service" -ForegroundColor Yellow
                Write-Host "  [DEBUG] Expected: http://pazar-app:80 (Docker Compose service name)" -ForegroundColor Gray
                $hasFailures = $true
            }

            # Rule 3: messaging.availability MUST be "ONLINE"
            if (-not $messagingWorld -or $messagingWorld.availability -ne "ONLINE") {
                Write-Host "FAIL: messaging.availability MUST be 'ONLINE', got '$($messagingWorld.availability)'" -ForegroundColor Red
                Write-Host "  [DEBUG] Check MESSAGING_STATUS_URL env var and messaging-api service" -ForegroundColor Yellow
                Write-Host "  [DEBUG] Expected: http://messaging-api:3000 (Docker Compose service name)" -ForegroundColor Gray
                $hasFailures = $true
            }

            # Rule 4: social.availability MUST be "DISABLED"
            if (-not $socialWorld -or $socialWorld.availability -ne "DISABLED") {
                Write-Host "FAIL: social.availability MUST be 'DISABLED', got '$($socialWorld.availability)'" -ForegroundColor Red
                $hasFailures = $true
            }

            # Debug: Check marketplace status specifically
            if ($marketplaceWorld) {
                Write-Host "  [DEBUG] Marketplace status from HOS: $($marketplaceWorld.availability)" -ForegroundColor Cyan
                if ($marketplaceWorld.availability -eq "ONLINE") {
                    Write-Host "  [DEBUG] HOS successfully pinged Pazar (marketplace ONLINE)" -ForegroundColor Green
                } elseif ($marketplaceWorld.availability -eq "OFFLINE") {
                    Write-Host "  [DEBUG] WARN: HOS reports marketplace OFFLINE (check PAZAR_STATUS_URL env var)" -ForegroundColor Yellow
                    Write-Host "  [DEBUG] Expected: http://pazar-app:80 (Docker Compose service name)" -ForegroundColor Gray
                }
            }

            # Debug: Check messaging status specifically
            if ($messagingWorld) {
                Write-Host "  [DEBUG] Messaging status from HOS: $($messagingWorld.availability)" -ForegroundColor Cyan
                if ($messagingWorld.availability -eq "ONLINE") {
                    Write-Host "  [DEBUG] HOS successfully pinged Messaging API (messaging ONLINE)" -ForegroundColor Green
                } elseif ($messagingWorld.availability -eq "OFFLINE") {
                    Write-Host "  [DEBUG] WARN: HOS reports messaging OFFLINE (check MESSAGING_STATUS_URL env var)" -ForegroundColor Yellow
                    Write-Host "  [DEBUG] Expected: http://messaging-api:3000 (Docker Compose service name)" -ForegroundColor Gray
                }
            }
        }
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
            try {
                $statusCode = $_.Exception.Response.StatusCode
            } catch {
            }
        }
    }
    
    if ($statusCode -eq 404) {
        Write-Host "FAIL: 404 Not Found - Endpoint does not exist: $hosWorldsUrl" -ForegroundColor Red
        Write-Host "  Expected: GET $hosWorldsUrl" -ForegroundColor Yellow
        Write-Host "  Check: HOS API app.js should have app.get('/worlds', ...) registered with /v1 prefix" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: HOS /v1/worlds request failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  URL: $hosWorldsUrl" -ForegroundColor Yellow
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

Write-Host ""

# Test 3: Pazar GET /api/world/status
Write-Host "[3] Testing Pazar GET /api/world/status..." -ForegroundColor Yellow
$pazarWorldStatusUrl = "http://localhost:8080/api/world/status"
try {
    $response = Invoke-RestMethod -Uri $pazarWorldStatusUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray

    # Validate response format
    if (-not $response.world_key) {
        Write-Host "FAIL: Missing 'world_key' in response" -ForegroundColor Red
        $hasFailures = $true
    } elseif ($response.world_key -ne "marketplace") {
        Write-Host "FAIL: Expected world_key='marketplace', got '$($response.world_key)'" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.availability) {
        Write-Host "FAIL: Missing 'availability' in response" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.phase) {
        Write-Host "FAIL: Missing 'phase' in response" -ForegroundColor Red
        $hasFailures = $true
    } elseif (-not $response.version) {
        Write-Host "FAIL: Missing 'version' in response" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Pazar /api/world/status returns valid response" -ForegroundColor Green
        Write-Host "  world_key: $($response.world_key)" -ForegroundColor Gray
        Write-Host "  availability: $($response.availability)" -ForegroundColor Gray
        Write-Host "  phase: $($response.phase)" -ForegroundColor Gray
        Write-Host "  version: $($response.version)" -ForegroundColor Gray
    }
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
            try {
                $statusCode = $_.Exception.Response.StatusCode
            } catch {
            }
        }
    }
    
    if ($statusCode -eq 404) {
        Write-Host "FAIL: 404 Not Found - Endpoint does not exist: $pazarWorldStatusUrl" -ForegroundColor Red
        Write-Host "  Expected: GET $pazarWorldStatusUrl" -ForegroundColor Yellow
        Write-Host "  Check: Laravel routes/api.php should have Route::get('/world/status', ...)" -ForegroundColor Yellow
    } else {
        Write-Host "FAIL: Pazar /api/world/status request failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  URL: $pazarWorldStatusUrl" -ForegroundColor Yellow
        if ($statusCode) {
            Write-Host "  Status Code: $statusCode" -ForegroundColor Yellow
        }
    }
    $hasFailures = $true
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== WORLD STATUS CHECK: FAIL ===" -ForegroundColor Red
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 1
    } else {
        exit 1
    }
} else {
    Write-Host "=== WORLD STATUS CHECK: PASS ===" -ForegroundColor Green
    if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
        Invoke-OpsExit -ExitCode 0
    } else {
        exit 0
    }
}

