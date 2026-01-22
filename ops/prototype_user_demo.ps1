# Prototype User Demo (WP-51)
# Single entrypoint for user-like prototype demo: prepares data + prints clickable URLs + checklist
# PowerShell 5.1 compatible, ASCII-only outputs

param(
    [string]$HosWebUrl = "http://localhost:3002",
    [string]$HosApiUrl = "http://localhost:3000",
    [string]$PazarUrl = "http://localhost:8080",
    [string]$MsgUrl = "",
    [switch]$StartStack = $false,
    [int]$WaitSec = 90,
    [switch]$OpenBrowser = $false
)

$ErrorActionPreference = "Stop"

# Set MsgUrl default if not provided
if (-not $MsgUrl -or $MsgUrl -eq "") {
    if ($env:MESSAGING_PUBLIC_URL) {
        $MsgUrl = $env:MESSAGING_PUBLIC_URL
    } else {
        $MsgUrl = "http://localhost:8090"
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

Write-Host "=== PROTOTYPE USER DEMO (WP-51) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$tenantId = $null
$listingId = $null
$threadId = $null

# Step 1: Optional Docker stack start
if ($StartStack) {
    Write-Host "[1] Starting Docker stack..." -ForegroundColor Yellow
    try {
        Push-Location $PSScriptRoot\..
        docker compose up -d 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose up -d failed with exit code $LASTEXITCODE"
        }
        Write-Host "PASS: Docker stack started" -ForegroundColor Green
        Pop-Location
    } catch {
        Write-Sanitized "FAIL: Docker stack start failed: $($_.Exception.Message)" "Red"
        Pop-Location
        $hasFailures = $true
        exit 1
    }
} else {
    Write-Host "[1] Skipping Docker stack start (use -StartStack to enable)" -ForegroundColor Gray
}

# Step 2: Wait for services (quick check, non-blocking)
Write-Host ""
Write-Host "[2] Checking service readiness..." -ForegroundColor Yellow
$hosReady = $false
$pazarReady = $false

# Quick check (don't wait long if services are already up)
$maxAttempts = 5
$attempt = 0
while ($attempt -lt $maxAttempts -and (-not $hosReady -or -not $pazarReady)) {
    if (-not $hosReady) {
        try {
            $response = Invoke-WebRequest -Uri "$HosApiUrl/world/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $hosReady = $true
                Write-Host "PASS: HOS API ready" -ForegroundColor Green
            }
        } catch {
            # Continue
        }
    }
    
    if (-not $pazarReady) {
        try {
            $response = Invoke-WebRequest -Uri "$PazarUrl/api/world/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $pazarReady = $true
                Write-Host "PASS: Pazar API ready" -ForegroundColor Green
            }
        } catch {
            # Continue
        }
    }
    
    if (-not $hosReady -or -not $pazarReady) {
        $attempt++
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 2
        }
    }
}

if (-not $hosReady) {
    Write-Host "WARN: HOS API not responding (continuing anyway)" -ForegroundColor Yellow
}

if (-not $pazarReady) {
    Write-Host "WARN: Pazar API not responding (continuing anyway)" -ForegroundColor Yellow
}

# Step 3: Run existing scripts
Write-Host ""
Write-Host "[3] Running demo preparation scripts..." -ForegroundColor Yellow

# 3.1: Ensure demo membership
Write-Host "  [3.1] Ensuring demo membership..." -ForegroundColor Gray
try {
    $bootstrapScript = Join-Path $PSScriptRoot "ensure_demo_membership.ps1"
    if (Test-Path $bootstrapScript) {
        $bootstrapOutput = & $bootstrapScript -HosBaseUrl $HosApiUrl 2>&1
        $bootstrapExitCode = $LASTEXITCODE
        if ($bootstrapExitCode -ne 0) {
            Write-Host "FAIL: ensure_demo_membership.ps1 returned exit code $bootstrapExitCode" -ForegroundColor Red
            $hasFailures = $true
        } else {
            Write-Host "PASS: Demo membership ensured" -ForegroundColor Green
        }
    } else {
        Write-Host "  Script not found, skipping (prototype_flow_smoke will handle bootstrap)" -ForegroundColor Gray
    }
} catch {
    Write-Sanitized "FAIL: Membership bootstrap failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
}

# 3.2: Run prototype flow smoke (this creates listing + thread)
Write-Host "  [3.2] Running prototype flow smoke..." -ForegroundColor Gray
try {
    # Capture all output including Write-Host
    $flowOutput = & (Join-Path $PSScriptRoot "prototype_flow_smoke.ps1") 2>&1 | Out-String
    $flowExitCode = $LASTEXITCODE
    
    # Extract RESULT line from output
    $resultMatch = [regex]::Match($flowOutput, "RESULT:\s*tenant_id=([^\s]+)\s+listing_id=([^\s]+)\s+thread_id=([^\s]+)")
    if ($resultMatch.Success) {
        $tenantId = $resultMatch.Groups[1].Value
        $listingId = $resultMatch.Groups[2].Value
        $threadId = $resultMatch.Groups[3].Value
        Write-Host "PASS: Prototype flow smoke PASS, artifacts extracted" -ForegroundColor Green
        Write-Host "  tenant_id: $tenantId" -ForegroundColor Gray
        Write-Host "  listing_id: $listingId" -ForegroundColor Gray
        Write-Host "  thread_id: $threadId" -ForegroundColor Gray
    } elseif ($flowExitCode -eq 0) {
        Write-Host "WARN: Prototype flow smoke PASS but RESULT line not found in output" -ForegroundColor Yellow
        Write-Host "  (This is OK if artifacts are not needed for demo)" -ForegroundColor Gray
    } else {
        Write-Host "FAIL: prototype_flow_smoke.ps1 returned exit code $flowExitCode" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Sanitized "FAIL: Prototype flow smoke failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
}

# 3.3: Run frontend smoke
Write-Host "  [3.3] Running frontend smoke..." -ForegroundColor Gray
try {
    $frontendOutput = & (Join-Path $PSScriptRoot "frontend_smoke.ps1") 2>&1 | Out-String
    $frontendExitCode = $LASTEXITCODE
    if ($frontendExitCode -ne 0) {
        Write-Host "FAIL: frontend_smoke.ps1 returned exit code $frontendExitCode" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Frontend smoke PASS" -ForegroundColor Green
    }
} catch {
    Write-Sanitized "FAIL: Frontend smoke failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
}

if ($hasFailures) {
    Write-Host ""
    Write-Host "=== PROTOTYPE USER DEMO: FAIL ===" -ForegroundColor Red
    exit 1
}

# Step 4: Print click targets and checklist
Write-Host ""
Write-Host "[4] CLICK TARGETS" -ForegroundColor Cyan
Write-Host "  HOS Web: $HosWebUrl" -ForegroundColor White
Write-Host "  HOS Worlds: $HosApiUrl/v1/worlds" -ForegroundColor White
Write-Host "  Pazar Status: $PazarUrl/api/world/status" -ForegroundColor White
Write-Host "  Messaging Status: $MsgUrl/api/world/status" -ForegroundColor White
if ($listingId) {
    Write-Host "  Pazar Listing: $PazarUrl/api/v1/listings/$listingId" -ForegroundColor White
}
if ($threadId) {
    Write-Host "  Messaging Thread: $MsgUrl/api/v1/threads/by-context?context_type=listing&context_id=$listingId" -ForegroundColor White
}

Write-Host ""
Write-Host "[5] USER DEMO CHECKLIST" -ForegroundColor Cyan
Write-Host "  1. Open HOS Web ($HosWebUrl) and verify Prototype Launcher section is visible" -ForegroundColor White
Write-Host "  2. Click 'HOS Worlds' link or navigate to $HosApiUrl/v1/worlds to verify world directory" -ForegroundColor White
Write-Host "  3. Verify Pazar status at $PazarUrl/api/world/status (should show ONLINE)" -ForegroundColor White
Write-Host "  4. Verify Messaging status at $MsgUrl/api/world/status (should show ONLINE)" -ForegroundColor White
if ($listingId) {
    Write-Host "  5. Verify listing exists: $PazarUrl/api/v1/listings/$listingId" -ForegroundColor White
    Write-Host "  6. Verify messaging thread exists: $MsgUrl/api/v1/threads/by-context?context_type=listing&context_id=$listingId" -ForegroundColor White
} else {
    Write-Host "  5. (Listing ID not available - check prototype_flow_smoke output)" -ForegroundColor Gray
}

Write-Host ""
if ($tenantId) {
    Write-Host "Demo Artifacts:" -ForegroundColor Gray
    Write-Host "  tenant_id: $tenantId" -ForegroundColor Gray
    if ($listingId) {
        Write-Host "  listing_id: $listingId" -ForegroundColor Gray
    }
    if ($threadId) {
        Write-Host "  thread_id: $threadId" -ForegroundColor Gray
    }
}

# Step 5: Optional browser open
if ($OpenBrowser) {
    Write-Host ""
    Write-Host "[6] Opening browser..." -ForegroundColor Yellow
    try {
        Start-Process $HosWebUrl
        Write-Host "PASS: Browser opened to $HosWebUrl" -ForegroundColor Green
    } catch {
        Write-Sanitized "WARN: Failed to open browser: $($_.Exception.Message)" "Yellow"
    }
}

Write-Host ""
Write-Host "=== PROTOTYPE USER DEMO: PASS ===" -ForegroundColor Green
exit 0

