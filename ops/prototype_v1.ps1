# Prototype V1 Runner (WP-46)
# One command local verification: optionally start stack, wait for endpoints, run smokes

param(
    [switch]$StartStack = $false,
    [int]$WaitSec = 90,
    [string]$HosBaseUrl = "http://localhost:3000",
    [string]$PazarBaseUrl = "http://localhost:8080",
    [string]$MessagingBaseUrl = $null
)

$ErrorActionPreference = "Stop"

# Set default MessagingBaseUrl if not provided
if (-not $MessagingBaseUrl) {
    $MessagingBaseUrl = $env:MESSAGING_PUBLIC_URL
    if (-not $MessagingBaseUrl) {
        $MessagingBaseUrl = "http://localhost:8090"
    }
}

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

# Helper: Print sanitized
function Write-Sanitized {
    param([string]$text, [string]$Color = "White")
    $sanitized = Sanitize-Ascii $text
    Write-Host $sanitized -ForegroundColor $Color
}

# Helper: Mask token (show last 6 chars max)
function Mask-Token {
    param([string]$token)
    if (-not $token) { return "" }
    if ($token.Length -le 6) { return "***" }
    return "***" + $token.Substring($token.Length - 6)
}

Write-Host "=== PROTOTYPE V1 RUNNER (WP-46) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Step 1: Optionally start stack
if ($StartStack) {
    Write-Host "[1] Starting stack (docker compose up -d)..." -ForegroundColor Yellow
    try {
        $dockerOutput = docker compose up -d 2>&1
        $dockerExitCode = $LASTEXITCODE
        if ($dockerExitCode -ne 0) {
            Write-Sanitized "FAIL: docker compose up -d failed with exit code $dockerExitCode" "Red"
            $dockerOutput | ForEach-Object { Write-Sanitized $_ "Gray" }
            exit 1
        }
        Write-Host "PASS: Stack started" -ForegroundColor Green
        Write-Host "  Waiting 5 seconds for services to initialize..." -ForegroundColor Gray
        Start-Sleep -Seconds 5
    } catch {
        Write-Sanitized "FAIL: Error starting stack: $($_.Exception.Message)" "Red"
        exit 1
    }
    Write-Host ""
}

# Step 2: Wait for endpoints to be reachable
Write-Host "[2] Waiting for core endpoints (max $WaitSec seconds)..." -ForegroundColor Yellow

$startTime = Get-Date
$hosReady = $false
$pazarReady = $false

while (((Get-Date) - $startTime).TotalSeconds -lt $WaitSec) {
    $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
    
    # Check HOS
    if (-not $hosReady) {
        try {
            $hosResponse = Invoke-WebRequest -Uri "$HosBaseUrl/v1/world/status" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($hosResponse.StatusCode -eq 200) {
                $hosReady = $true
                Write-Host "  HOS ready (${elapsed}s)" -ForegroundColor Green
            }
        } catch {
            # Continue polling
        }
    }
    
    # Check Pazar
    if (-not $pazarReady) {
        try {
            $pazarResponse = Invoke-WebRequest -Uri "$PazarBaseUrl/api/world/status" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($pazarResponse.StatusCode -eq 200) {
                $pazarReady = $true
                Write-Host "  Pazar ready (${elapsed}s)" -ForegroundColor Green
            }
        } catch {
            # Continue polling
        }
    }
    
    if ($hosReady -and $pazarReady) {
        Write-Host "PASS: All core endpoints reachable" -ForegroundColor Green
        break
    }
    
    Start-Sleep -Seconds 2
}

if (-not ($hosReady -and $pazarReady)) {
    Write-Host "FAIL: Timeout waiting for endpoints (${WaitSec}s)" -ForegroundColor Red
    Write-Host "  HOS ready: $hosReady" -ForegroundColor Yellow
    Write-Host "  Pazar ready: $pazarReady" -ForegroundColor Yellow
    Write-Host "  Remediation: Check docker compose ps, ensure services are running" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 3: Run existing smokes in order
Write-Host "[3] Running smoke tests..." -ForegroundColor Yellow

$smokeScripts = @()
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check if world_status_check exists
if (Test-Path "$scriptDir\world_status_check.ps1") {
    $smokeScripts += "$scriptDir\world_status_check.ps1"
}

$smokeScripts += @(
    "$scriptDir\frontend_smoke.ps1",
    "$scriptDir\prototype_smoke.ps1",
    "$scriptDir\prototype_flow_smoke.ps1"
)

$smokeIndex = 1
$hasFailures = $false

foreach ($script in $smokeScripts) {
    $scriptName = Split-Path $script -Leaf
    if (-not (Test-Path $script)) {
        Write-Host "  [$smokeIndex] SKIP: $scriptName (not found)" -ForegroundColor Yellow
        $smokeIndex++
        continue
    }
    
    Write-Host "  [$smokeIndex] Running $scriptName..." -ForegroundColor Gray
    try {
        $output = & $script 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Host "FAIL: $scriptName returned exit code $exitCode" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: $scriptName" -ForegroundColor Green
        }
    } catch {
        Write-Sanitized "FAIL: $scriptName failed: $($_.Exception.Message)" "Red"
        $hasFailures = $true
    }
    $smokeIndex++
}

if ($hasFailures) {
    Write-Host ""
    Write-Host "=== PROTOTYPE V1 RUNNER: FAIL ===" -ForegroundColor Red
    Write-Host "  One or more smoke tests failed. See output above." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "PASS: All smoke tests completed" -ForegroundColor Green

# Step 4: Print manual checks
Write-Host ""
Write-Host "=== NEXT MANUAL CHECKS ===" -ForegroundColor Cyan
Write-Host "  HOS Web UI: http://localhost:3002" -ForegroundColor Gray
Write-Host "    - Verify Prototype Launcher section is visible" -ForegroundColor DarkGray
Write-Host "    - Check Quick Links are clickable" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  HOS Worlds API: $HosBaseUrl/v1/worlds" -ForegroundColor Gray
Write-Host "    - Verify all worlds (core, marketplace, messaging, social)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Pazar API: $PazarBaseUrl/api/world/status" -ForegroundColor Gray
Write-Host "    - Verify marketplace world is ONLINE" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Messaging API: $MessagingBaseUrl/api/world/status" -ForegroundColor Gray
Write-Host "    - Verify messaging world is ONLINE" -ForegroundColor DarkGray
Write-Host ""

Write-Host "=== PROTOTYPE V1 RUNNER: PASS ===" -ForegroundColor Green
exit 0

