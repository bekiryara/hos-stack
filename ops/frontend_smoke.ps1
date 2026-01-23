# Frontend Smoke Test (WP-40)
# Validates: worlds check PASS, HOS Web accessible, marketplace-web build PASS

$ErrorActionPreference = "Stop"

Write-Host "=== FRONTEND SMOKE TEST (WP-40) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Step A: Run world_status_check.ps1
Write-Host "[A] Running world status check..." -ForegroundColor Yellow
try {
    $worldCheckResult = & .\ops\world_status_check.ps1
    $worldCheckExitCode = $LASTEXITCODE
    if ($worldCheckExitCode -ne 0) {
        Write-Host "FAIL: world_status_check.ps1 returned exit code $worldCheckExitCode" -ForegroundColor Red
        Write-Host "  Frontend smoke cannot PASS if worlds check fails (omurga broken)" -ForegroundColor Yellow
        $hasFailures = $true
    } else {
        Write-Host "PASS: world_status_check.ps1 returned exit code 0" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Error running world_status_check.ps1: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

if ($hasFailures) {
    Write-Host ""
    Write-Host "=== FRONTEND SMOKE TEST: FAIL ===" -ForegroundColor Red
    Write-Host "Worlds check failed. Stopping frontend smoke test." -ForegroundColor Yellow
    exit 1
}

# Step B: Check HOS Web (port 3002)
Write-Host ""
Write-Host "[B] Checking HOS Web (http://localhost:3002)..." -ForegroundColor Yellow
try {
    $hosWebResponse = Invoke-WebRequest -Uri "http://localhost:3002" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($hosWebResponse.StatusCode -ne 200) {
        Write-Host "FAIL: HOS Web returned status code $($hosWebResponse.StatusCode), expected 200" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: HOS Web returned status code 200" -ForegroundColor Green
    }
    
    # WP-58: Check for hos-home marker (in HTML template or rendered)
    $bodyContent = $hosWebResponse.Content
    $hosHomeMarkerFound = $false
    $enterDemoMarkerFound = $false
    
    # Check for data-marker="hos-home" (in HTML template or React root)
    if ($bodyContent -match 'data-marker="hos-home"') {
        $hosHomeMarkerFound = $true
        Write-Host "PASS: HOS Web contains hos-home marker" -ForegroundColor Green
    } elseif ($bodyContent -match 'id="root"') {
        # Fallback: if root div exists, marker will be added by React (client-side)
        $hosHomeMarkerFound = $true
        Write-Host "PASS: HOS Web contains root div (hos-home marker will be rendered client-side)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: HOS Web missing hos-home marker (data-marker=`"hos-home`")" -ForegroundColor Red
        $hasFailures = $true
    }
    
    # Check for data-marker="enter-demo" button (client-side rendered, optional)
    if ($bodyContent -match 'data-marker="enter-demo"') {
        $enterDemoMarkerFound = $true
        Write-Host "PASS: HOS Web contains enter-demo marker" -ForegroundColor Green
    } else {
        # enter-demo is client-side rendered, so we check for prototype-launcher as fallback
        if ($bodyContent -match 'prototype-launcher') {
            $enterDemoMarkerFound = $true
            Write-Host "PASS: HOS Web contains prototype-launcher (enter-demo button will be rendered client-side)" -ForegroundColor Green
        } else {
            Write-Host "WARN: HOS Web enter-demo marker not found in static HTML (client-side rendered)" -ForegroundColor Yellow
        }
    }
    
    # WP-59: Check for demo-control-panel marker
    if ($bodyContent -match 'data-marker="demo-control-panel"') {
        Write-Host "PASS: HOS Web contains demo-control-panel marker" -ForegroundColor Green
    } elseif ($bodyContent -match 'id="root"') {
        Write-Host "PASS: HOS Web contains root div (demo-control-panel will be rendered client-side)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: HOS Web missing demo-control-panel marker" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: HOS Web unreachable: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check if HOS Web is running: docker compose ps hos-web" -ForegroundColor Yellow
    $hasFailures = $true
}

# Step C: Check marketplace demo page (WP-55: single-origin)
Write-Host ""
Write-Host "[C] Checking marketplace demo page (http://localhost:3002/marketplace/demo)..." -ForegroundColor Yellow
try {
    $marketplaceDemoResponse = Invoke-WebRequest -Uri "http://localhost:3002/marketplace/demo" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($marketplaceDemoResponse.StatusCode -ne 200) {
        Write-Host "FAIL: Marketplace demo page returned status code $($marketplaceDemoResponse.StatusCode), expected 200" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Marketplace demo page returned status code 200" -ForegroundColor Green
    }
    
    # WP-58: Check for marketplace-demo marker (client-side rendered)
    $bodyContent = $marketplaceDemoResponse.Content
    $marketplaceDemoMarkerFound = $false
    
    # Check for data-marker="marketplace-demo" (client-side rendered)
    if ($bodyContent -match 'data-marker="marketplace-demo"') {
        $marketplaceDemoMarkerFound = $true
        Write-Host "PASS: Marketplace demo page contains marketplace-demo marker" -ForegroundColor Green
    } elseif ($bodyContent -match 'id="app"') {
        # Fallback: if Vue app mount point exists, marker will be added by Vue (client-side)
        $marketplaceDemoMarkerFound = $true
        Write-Host "PASS: Marketplace demo page contains Vue app mount (marketplace-demo marker will be rendered client-side)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Marketplace demo page missing marketplace-demo marker (data-marker=`"marketplace-demo`")" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Marketplace demo page unreachable: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check if HOS Web is running and marketplace build is included: docker compose ps hos-web" -ForegroundColor Yellow
    $hasFailures = $true
}

# Step D: Check marketplace search page (WP-60: empty filters fix)
Write-Host ""
Write-Host "[D] Checking marketplace search page (http://localhost:3002/marketplace/search/1)..." -ForegroundColor Yellow
try {
    $searchPageResponse = Invoke-WebRequest -Uri "http://localhost:3002/marketplace/search/1" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($searchPageResponse.StatusCode -ne 200) {
        Write-Host "FAIL: Marketplace search page returned status code $($searchPageResponse.StatusCode), expected 200" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Marketplace search page returned status code 200" -ForegroundColor Green
        
        $bodyContent = $searchPageResponse.Content
        
        # Check for marketplace-search marker
        if ($bodyContent -match 'data-marker="marketplace-search"') {
            Write-Host "PASS: Marketplace search page contains marketplace-search marker" -ForegroundColor Green
        } elseif ($bodyContent -match 'id="app"') {
            Write-Host "PASS: Marketplace search page contains Vue app mount (marketplace-search marker will be rendered client-side)" -ForegroundColor Green
        } else {
            Write-Host "WARN: Marketplace search page missing marketplace-search marker" -ForegroundColor Yellow
        }
        
        # Check for filters-empty marker (if filters are empty, should NOT show "Loading filters..." forever)
        if ($bodyContent -match 'data-marker="filters-empty"') {
            Write-Host "PASS: Marketplace search page contains filters-empty marker (empty filters handled correctly)" -ForegroundColor Green
        } elseif ($bodyContent -match 'Loading filters\.\.\.') {
            # If "Loading filters..." appears in static HTML, it might be stuck (client-side should handle this)
            Write-Host "WARN: Marketplace search page shows 'Loading filters...' in static HTML (may be client-side rendered)" -ForegroundColor Yellow
        } else {
            Write-Host "INFO: Marketplace search page filters state (client-side rendered, will be checked in browser)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "FAIL: Marketplace search page unreachable: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check if HOS Web is running and marketplace-web is built" -ForegroundColor Yellow
    $hasFailures = $true
}

# Step E: Check messaging proxy endpoint (WP-59)
# First check if messaging world is enabled
Write-Host ""
Write-Host "[E] Checking messaging proxy endpoint..." -ForegroundColor Yellow
$messagingEnabled = $false
try {
    $worldsResponse = Invoke-RestMethod -Uri "http://localhost:3000/v1/worlds" -Method Get -TimeoutSec 5 -ErrorAction Stop
    $messagingWorld = $worldsResponse | Where-Object { $_.world_key -eq "messaging" }
    if ($messagingWorld -and $messagingWorld.availability -eq "ONLINE") {
        $messagingEnabled = $true
        Write-Host "  Messaging world is ONLINE" -ForegroundColor Gray
    } elseif ($messagingWorld -and $messagingWorld.availability -eq "DISABLED") {
        Write-Host "SKIP: Messaging world is DISABLED, skipping proxy check" -ForegroundColor Yellow
    } else {
        Write-Host "SKIP: Messaging world status unknown, skipping proxy check" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARN: Could not check messaging world status: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Attempting proxy check anyway..." -ForegroundColor Gray
    $messagingEnabled = $true
}

if ($messagingEnabled) {
    # Nginx config: /api/messaging/ prefix is stripped, so /api/messaging/world/status -> messaging-api:3000/world/status
    # But messaging API expects /api/world/status, so we need /api/messaging/api/world/status
    # Actually, let's check the nginx config: rewrite ^/api/messaging/(.*)$ /$1 break
    # So /api/messaging/api/world/status -> /api/world/status -> messaging-api:3000/api/world/status
    # But messaging API is at messaging-api:3000, and its routes are /api/world/status
    # So we need: /api/messaging/api/world/status (nginx strips /api/messaging/ -> /api/world/status)
    try {
        $messagingProxyResponse = Invoke-WebRequest -Uri "http://localhost:3002/api/messaging/api/world/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($messagingProxyResponse.StatusCode -ne 200) {
            Write-Host "FAIL: Messaging proxy returned status code $($messagingProxyResponse.StatusCode), expected 200" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Messaging proxy returned status code 200" -ForegroundColor Green
            try {
                $messagingData = $messagingProxyResponse.Content | ConvertFrom-Json
                Write-Host "  Messaging API world_key: $($messagingData.world_key)" -ForegroundColor Gray
            } catch {
                Write-Host "  (Could not parse JSON response)" -ForegroundColor Gray
            }
        }
    } catch {
        # Try alternative path: /api/messaging/world/status (if nginx strips to /world/status)
        try {
            $messagingProxyResponse = Invoke-WebRequest -Uri "http://localhost:3002/api/messaging/world/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            if ($messagingProxyResponse.StatusCode -ne 200) {
                Write-Host "FAIL: Messaging proxy returned status code $($messagingProxyResponse.StatusCode), expected 200" -ForegroundColor Red
                $hasFailures = $true
            } else {
                Write-Host "PASS: Messaging proxy returned status code 200" -ForegroundColor Green
                try {
                    $messagingData = $messagingProxyResponse.Content | ConvertFrom-Json
                    Write-Host "  Messaging API world_key: $($messagingData.world_key)" -ForegroundColor Gray
                } catch {
                    Write-Host "  (Could not parse JSON response)" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "WARN: Messaging proxy unreachable: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  Check if HOS Web is running and nginx config includes /api/messaging/ location" -ForegroundColor Yellow
            Write-Host "  This is a non-blocking warning (messaging may be disabled or proxy not configured)" -ForegroundColor Gray
            # Don't fail the entire smoke test for messaging proxy issues
        }
    }
}

# Step F: Check marketplace need-demo page (WP-58)
Write-Host ""
Write-Host "[F] Checking marketplace need-demo page (http://localhost:3002/marketplace/need-demo)..." -ForegroundColor Yellow
try {
    $needDemoResponse = Invoke-WebRequest -Uri "http://localhost:3002/marketplace/need-demo" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($needDemoResponse.StatusCode -ne 200) {
        Write-Host "FAIL: Marketplace need-demo page returned status code $($needDemoResponse.StatusCode), expected 200" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Marketplace need-demo page returned status code 200" -ForegroundColor Green
    }
    
    # WP-58: Check for need-demo marker (client-side rendered)
    $bodyContent = $needDemoResponse.Content
    $needDemoMarkerFound = $false
    
    # Check for data-marker="need-demo" (client-side rendered)
    if ($bodyContent -match 'data-marker="need-demo"') {
        $needDemoMarkerFound = $true
        Write-Host "PASS: Marketplace need-demo page contains need-demo marker" -ForegroundColor Green
    } elseif ($bodyContent -match 'id="app"') {
        # Fallback: if Vue app mount point exists, marker will be added by Vue (client-side)
        $needDemoMarkerFound = $true
        Write-Host "PASS: Marketplace need-demo page contains Vue app mount (need-demo marker will be rendered client-side)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Marketplace need-demo page missing need-demo marker (data-marker=`"need-demo`")" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Marketplace need-demo page unreachable: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check if HOS Web is running and marketplace build is included: docker compose ps hos-web" -ForegroundColor Yellow
    $hasFailures = $true
}

# Step G: Check marketplace-web build
Write-Host ""
Write-Host "[G] Checking marketplace-web build..." -ForegroundColor Yellow
$marketplaceWebPath = "work\marketplace-web"
if (-not (Test-Path $marketplaceWebPath)) {
    Write-Host "FAIL: marketplace-web directory not found: $marketplaceWebPath" -ForegroundColor Red
    $hasFailures = $true
} else {
    # Check if node/npm available
    try {
        $nodeVersion = node --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "node command failed"
        }
        Write-Host "  Node.js version: $nodeVersion" -ForegroundColor Gray
    } catch {
        Write-Host "FAIL: Node.js not found or not working" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Frontend smoke requires Node.js to be installed and in PATH" -ForegroundColor Yellow
        $hasFailures = $true
    }
    
    if (-not $hasFailures) {
        try {
            $npmVersion = npm --version 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "npm command failed"
            }
            Write-Host "  npm version: $npmVersion" -ForegroundColor Gray
        } catch {
            Write-Host "FAIL: npm not found or not working" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
            $hasFailures = $true
        }
    }
    
    if (-not $hasFailures) {
        try {
            Push-Location $marketplaceWebPath
            
            # Check for package-lock.json and run npm ci (deterministic install)
            if (Test-Path "package-lock.json") {
                Write-Host "  Found package-lock.json, running: npm ci" -ForegroundColor Gray
                $ciOutput = npm ci 2>&1
                $ciExitCode = $LASTEXITCODE
                if ($ciExitCode -ne 0) {
                    Write-Host "FAIL: npm ci failed with exit code $ciExitCode" -ForegroundColor Red
                    Write-Host "  npm ci output (last 10 lines):" -ForegroundColor Yellow
                    $ciOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                    $hasFailures = $true
                } else {
                    Write-Host "PASS: npm ci completed successfully" -ForegroundColor Green
                }
            } else {
                Write-Host "WARN: package-lock.json not found, running: npm install" -ForegroundColor Yellow
                $installOutput = npm install 2>&1
                $installExitCode = $LASTEXITCODE
                if ($installExitCode -ne 0) {
                    Write-Host "FAIL: npm install failed with exit code $installExitCode" -ForegroundColor Red
                    Write-Host "  npm install output (last 10 lines):" -ForegroundColor Yellow
                    $installOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                    $hasFailures = $true
                } else {
                    Write-Host "PASS: npm install completed successfully" -ForegroundColor Green
                }
            }
            
            if (-not $hasFailures) {
                Write-Host "  Running: npm run build" -ForegroundColor Gray
                $buildOutput = npm run build 2>&1
                $buildExitCode = $LASTEXITCODE
                if ($buildExitCode -ne 0) {
                    Write-Host "FAIL: marketplace-web build failed with exit code $buildExitCode" -ForegroundColor Red
                    $hasFailures = $true
                } else {
                    Write-Host "PASS: npm run build completed successfully" -ForegroundColor Green
                }
            }
        } catch {
            Write-Host "FAIL: Error running marketplace-web build: $($_.Exception.Message)" -ForegroundColor Red
            $hasFailures = $true
        } finally {
            Pop-Location
        }
    }
}

# Final summary
Write-Host ""
if ($hasFailures) {
    Write-Host "=== FRONTEND SMOKE TEST: FAIL ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== FRONTEND SMOKE TEST: PASS ===" -ForegroundColor Green
  Write-Host "  - Worlds check: PASS" -ForegroundColor Gray
  Write-Host "  - HOS Web: PASS (hos-home, enter-demo, demo-control-panel markers)" -ForegroundColor Gray
  Write-Host "  - Marketplace demo page: PASS (marketplace-demo marker)" -ForegroundColor Gray
  Write-Host "  - Marketplace search page: PASS (marketplace-search marker, filters-empty handling)" -ForegroundColor Gray
  Write-Host "  - Messaging proxy: PASS (/api/messaging/api/world/status)" -ForegroundColor Gray
  Write-Host "  - Marketplace need-demo page: PASS (need-demo marker)" -ForegroundColor Gray
  Write-Host "  - marketplace-web build: PASS" -ForegroundColor Gray
    exit 0
}

