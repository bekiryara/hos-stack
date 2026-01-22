# Prototype Smoke Test (WP-44)
# Validates: Docker services, HTTP endpoints, HOS Web UI marker

$ErrorActionPreference = "Stop"

Write-Host "=== PROTOTYPE SMOKE (WP-44) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Section [1] Docker services
Write-Host "[1] Checking Docker services..." -ForegroundColor Yellow
try {
    $dockerPsOutput = docker compose ps 2>&1
    $dockerPsExitCode = $LASTEXITCODE
    if ($dockerPsExitCode -ne 0) {
        Write-Host "FAIL: docker compose ps failed with exit code $dockerPsExitCode" -ForegroundColor Red
        Write-Host "  Error: $dockerPsOutput" -ForegroundColor Yellow
        Write-Host "  Remediation: Ensure Docker is running and docker-compose.yml is valid" -ForegroundColor Yellow
        $hasFailures = $true
    } else {
        if ([string]::IsNullOrWhiteSpace($dockerPsOutput)) {
            Write-Host "FAIL: docker compose ps returned empty output" -ForegroundColor Red
            Write-Host "  Remediation: Check if services are running: docker compose up -d" -ForegroundColor Yellow
            $hasFailures = $true
        } else {
            Write-Host "PASS: docker compose ps executed successfully" -ForegroundColor Green
            Write-Host "  Output (first 5 lines):" -ForegroundColor Gray
            $dockerPsOutput | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    }
} catch {
    Write-Host "FAIL: Error running docker compose ps: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Remediation: Ensure Docker is installed and running" -ForegroundColor Yellow
    $hasFailures = $true
}

# Section [2] HTTP endpoint checks
Write-Host ""
Write-Host "[2] Checking HTTP endpoints..." -ForegroundColor Yellow

# 2.1 HOS core status
Write-Host "  [2.1] HOS core status (http://localhost:3000/v1/world/status)..." -ForegroundColor Gray
try {
    $hosCoreResponse = Invoke-WebRequest -Uri "http://localhost:3000/v1/world/status" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($hosCoreResponse.StatusCode -ne 200) {
        Write-Host "FAIL: HOS core status returned status code $($hosCoreResponse.StatusCode), expected 200" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $hosCoreData = $hosCoreResponse.Content | ConvertFrom-Json
        if ($hosCoreData.world_key -eq "core" -and $hosCoreData.availability -eq "ONLINE") {
            Write-Host "PASS: HOS core status - world_key: $($hosCoreData.world_key), availability: $($hosCoreData.availability)" -ForegroundColor Green
        } else {
            Write-Host "FAIL: HOS core status validation failed - world_key: $($hosCoreData.world_key), availability: $($hosCoreData.availability)" -ForegroundColor Red
            $hasFailures = $true
        }
    }
} catch {
    Write-Host "FAIL: HOS core status unreachable: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

# 2.2 HOS worlds
Write-Host "  [2.2] HOS worlds (http://localhost:3000/v1/worlds)..." -ForegroundColor Gray
try {
    $hosWorldsResponse = Invoke-WebRequest -Uri "http://localhost:3000/v1/worlds" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($hosWorldsResponse.StatusCode -ne 200) {
        Write-Host "FAIL: HOS worlds returned status code $($hosWorldsResponse.StatusCode), expected 200" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $hosWorldsData = $hosWorldsResponse.Content | ConvertFrom-Json
        $worldKeys = $hosWorldsData | ForEach-Object { $_.world_key }
        $hasCore = $worldKeys -contains "core"
        $hasMarketplace = $worldKeys -contains "marketplace"
        $hasMessaging = $worldKeys -contains "messaging"
        $hasSocial = $worldKeys -contains "social"
        
        $socialWorld = $hosWorldsData | Where-Object { $_.world_key -eq "social" }
        $socialDisabled = $socialWorld -and $socialWorld.availability -eq "DISABLED"
        
        if ($hasCore -and $hasMarketplace -and $hasMessaging -and $hasSocial -and $socialDisabled) {
            Write-Host "PASS: HOS worlds - core, marketplace, messaging, social (social: DISABLED)" -ForegroundColor Green
        } else {
            Write-Host "FAIL: HOS worlds validation failed" -ForegroundColor Red
            Write-Host "    Expected: core, marketplace, messaging, social (social: DISABLED)" -ForegroundColor Yellow
            Write-Host "    Found: $($worldKeys -join ', ')" -ForegroundColor Yellow
            if ($socialWorld) {
                Write-Host "    Social availability: $($socialWorld.availability)" -ForegroundColor Yellow
            }
            $hasFailures = $true
        }
    }
} catch {
    Write-Host "FAIL: HOS worlds unreachable: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

# 2.3 Pazar status
Write-Host "  [2.3] Pazar status (http://localhost:8080/api/world/status)..." -ForegroundColor Gray
try {
    $pazarResponse = Invoke-WebRequest -Uri "http://localhost:8080/api/world/status" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($pazarResponse.StatusCode -ne 200) {
        Write-Host "FAIL: Pazar status returned status code $($pazarResponse.StatusCode), expected 200" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $pazarData = $pazarResponse.Content | ConvertFrom-Json
        if ($pazarData.world_key -eq "marketplace" -and $pazarData.availability -eq "ONLINE") {
            Write-Host "PASS: Pazar status - world_key: $($pazarData.world_key), availability: $($pazarData.availability)" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Pazar status validation failed - world_key: $($pazarData.world_key), availability: $($pazarData.availability)" -ForegroundColor Red
            $hasFailures = $true
        }
    }
} catch {
    Write-Host "FAIL: Pazar status unreachable: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

# 2.4 Messaging status
Write-Host "  [2.4] Messaging status..." -ForegroundColor Gray
$messagingUrl = if ($env:MESSAGING_PUBLIC_URL) {
    "$($env:MESSAGING_PUBLIC_URL)/api/world/status"
} else {
    "http://localhost:8090/api/world/status"
}
Write-Host "    URL: $messagingUrl" -ForegroundColor Gray
try {
    $messagingResponse = Invoke-WebRequest -Uri $messagingUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($messagingResponse.StatusCode -ne 200) {
        Write-Host "FAIL: Messaging status returned status code $($messagingResponse.StatusCode), expected 200" -ForegroundColor Red
        Write-Host "  V1 prototype requires messaging ONLINE" -ForegroundColor Yellow
        $hasFailures = $true
    } else {
        $messagingData = $messagingResponse.Content | ConvertFrom-Json
        Write-Host "PASS: Messaging status - world_key: $($messagingData.world_key), availability: $($messagingData.availability)" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Messaging status unreachable: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  V1 prototype requires messaging ONLINE" -ForegroundColor Yellow
    $hasFailures = $true
}

# Section [3] HOS Web shell check
Write-Host ""
Write-Host "[3] Checking HOS Web UI marker (http://localhost:3002)..." -ForegroundColor Yellow
try {
    $hosWebResponse = Invoke-WebRequest -Uri "http://localhost:3002" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($hosWebResponse.StatusCode -ne 200) {
        Write-Host "FAIL: HOS Web returned status code $($hosWebResponse.StatusCode), expected 200" -ForegroundColor Red
        $hasFailures = $true
    } else {
        $bodyContent = $hosWebResponse.Content
        # React SPA renders client-side, so check for HTML comment marker or rendered content
        if ($bodyContent -match 'prototype-launcher-marker' -or $bodyContent -match 'data-test="prototype-launcher"' -or $bodyContent -match 'Prototype Launcher') {
            Write-Host "PASS: HOS Web UI contains prototype-launcher marker" -ForegroundColor Green
        } else {
            Write-Host "FAIL: HOS Web UI missing prototype-launcher marker" -ForegroundColor Red
            Write-Host "  Hint: Verify index.html and App.tsx changes - marker should be: prototype-launcher-marker comment or data-test=`"prototype-launcher`"" -ForegroundColor Yellow
            $hasFailures = $true
        }
    }
} catch {
    Write-Host "FAIL: HOS Web unreachable: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check if HOS Web is running: docker compose ps hos-web" -ForegroundColor Yellow
    $hasFailures = $true
}

# Summary
Write-Host ""
if ($hasFailures) {
    Write-Host "=== PROTOTYPE SMOKE: FAIL ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== PROTOTYPE SMOKE: PASS ===" -ForegroundColor Green
    exit 0
}

