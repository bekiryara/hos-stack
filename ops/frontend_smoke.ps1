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
    
    # Check for prototype-launcher marker (aligned with prototype_smoke.ps1)
    # Accept any of these marker variants (OR logic):
    # 1) HTML comment marker: <!-- prototype-launcher --> or <!-- prototype-launcher-marker -->
    # 2) data attribute marker: data-prototype="launcher" OR data-marker="prototype-launcher" OR data-test="prototype-launcher"
    # 3) visible heading/text containing: prototype-launcher
    $bodyContent = $hosWebResponse.Content
    $markerFound = $false
    
    # Variant 1: HTML comment marker
    if ($bodyContent -match '<!--\s*prototype-launcher' -or $bodyContent -match 'prototype-launcher-marker') {
        $markerFound = $true
    }
    
    # Variant 2: data attribute marker
    if (-not $markerFound) {
        if ($bodyContent -match 'data-prototype="launcher"' -or $bodyContent -match 'data-marker="prototype-launcher"' -or $bodyContent -match 'data-test="prototype-launcher"') {
            $markerFound = $true
        }
    }
    
    # Variant 3: visible heading/text containing prototype-launcher
    if (-not $markerFound) {
        if ($bodyContent -match 'prototype-launcher' -and ($bodyContent -match '<h[1-6]' -or $bodyContent -match '<div' -or $bodyContent -match '<span')) {
            $markerFound = $true
        }
    }
    
    if ($markerFound) {
        Write-Host "PASS: HOS Web body contains prototype-launcher marker" -ForegroundColor Green
    } else {
        Write-Host "FAIL: HOS Web body missing prototype-launcher marker" -ForegroundColor Red
        Write-Host "  Expected marker (any of):" -ForegroundColor Yellow
        Write-Host "    1) HTML comment: <!-- prototype-launcher --> or <!-- prototype-launcher-marker -->" -ForegroundColor Yellow
        Write-Host "    2) data attribute: data-prototype=`"launcher`" OR data-marker=`"prototype-launcher`" OR data-test=`"prototype-launcher`"" -ForegroundColor Yellow
        Write-Host "    3) visible text containing: prototype-launcher" -ForegroundColor Yellow
        # Print first ~200 chars of body (ASCII-sanitized) for debugging
        $bodyPreview = $bodyContent.Substring(0, [Math]::Min(200, $bodyContent.Length)) -replace '[^\x00-\x7F]', ''
        Write-Host "  Body preview (first 200 chars, ASCII-only): $bodyPreview" -ForegroundColor Gray
        Write-Host "  Remediation: Confirm HOS Web contains marker; check served HTML at http://localhost:3002" -ForegroundColor Yellow
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
    
    # Check for demo-dashboard marker (Vue SPA renders client-side, so check for Vue app mount or title)
    $bodyContent = $marketplaceDemoResponse.Content
    $markerFound = $false
    
    # Check for data-test attribute in HTML (may be in template)
    if ($bodyContent -match 'data-test="demo-dashboard"') {
        $markerFound = $true
    }
    
    # Check for "Demo Dashboard" text (may be in template or rendered)
    if (-not $markerFound -and $bodyContent -match 'Demo Dashboard') {
        $markerFound = $true
    }
    
    # Check for Vue app mount point (id="app" is standard)
    if (-not $markerFound -and $bodyContent -match 'id="app"') {
        $markerFound = $true
    }
    
    if ($markerFound) {
        Write-Host "PASS: Marketplace demo page contains demo-dashboard marker or Vue app mount" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Marketplace demo page missing demo-dashboard marker" -ForegroundColor Red
        Write-Host "  Expected marker: data-test=`"demo-dashboard`", text 'Demo Dashboard', or id=`"app`"" -ForegroundColor Yellow
        $hasFailures = $true
    }
} catch {
    Write-Host "FAIL: Marketplace demo page unreachable: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check if HOS Web is running and marketplace build is included: docker compose ps hos-web" -ForegroundColor Yellow
    $hasFailures = $true
}

# Step D: Check marketplace-web build
Write-Host ""
Write-Host "[C] Checking marketplace-web build..." -ForegroundColor Yellow
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
    Write-Host "  - HOS Web: PASS" -ForegroundColor Gray
    Write-Host "  - Marketplace demo page: PASS" -ForegroundColor Gray
    Write-Host "  - marketplace-web build: PASS" -ForegroundColor Gray
    exit 0
}

