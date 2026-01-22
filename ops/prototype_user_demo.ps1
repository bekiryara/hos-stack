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
    # Capture all output (stdout + stderr) - Write-Output goes to stdout, Write-Host goes to host
    $flowOutputLines = @()
    & (Join-Path $PSScriptRoot "prototype_flow_smoke.ps1") 2>&1 | ForEach-Object {
        $lineStr = if ($_ -is [string]) { $_ } else { $_.ToString() }
        $flowOutputLines += $lineStr
    }
    $flowExitCode = $LASTEXITCODE
    
    if ($flowExitCode -ne 0) {
        Write-Host "FAIL: prototype_flow_smoke.ps1 returned exit code $flowExitCode" -ForegroundColor Red
        $hasFailures = $true
    } else {
        # WP-52: Extract RESULT_JSON line (machine-readable, deterministic)
        $resultJsonLine = $flowOutputLines | Where-Object { $_ -match '^RESULT_JSON:' } | Select-Object -Last 1
        
        if ($resultJsonLine) {
            # Extract JSON substring after 'RESULT_JSON:'
            $jsonStr = $resultJsonLine -replace '^RESULT_JSON:', ''
            try {
                $resultObj = $jsonStr | ConvertFrom-Json
                
                # Validate artifacts
                $tenantId = $resultObj.tenant_id
                $listingId = $resultObj.listing_id
                $threadId = $resultObj.thread_id
                $listingUrl = $resultObj.listing_url
                $threadUrl = $resultObj.thread_url
                
                # Validate tenant_id is UUID
                $guidResult = [System.Guid]::Empty
                if (-not $tenantId -or -not [System.Guid]::TryParse($tenantId, [ref]$guidResult)) {
                    throw "tenant_id is not a valid UUID: $tenantId"
                }
                
                # Validate listing_id and thread_id are non-empty
                if (-not $listingId -or $listingId.Trim().Length -eq 0) {
                    throw "listing_id is empty"
                }
                if (-not $threadId -or $threadId.Trim().Length -eq 0) {
                    throw "thread_id is empty"
                }
                
                Write-Host "PASS: Prototype flow smoke PASS, artifacts extracted" -ForegroundColor Green
            } catch {
                Write-Host "FAIL: Failed to parse or validate RESULT_JSON: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "  JSON line: $($resultJsonLine.Substring(0, [Math]::Min(100, $resultJsonLine.Length)))" -ForegroundColor Gray
                $hasFailures = $true
            }
        } else {
            Write-Host "FAIL: prototype_flow_smoke did not emit RESULT_JSON" -ForegroundColor Red
            Write-Host "  Ensure you are on WP-52 and the script PASSed" -ForegroundColor Yellow
            Write-Host "  Last 20 lines of output (ASCII-sanitized):" -ForegroundColor Gray
            $lastLines = $flowOutputLines | Select-Object -Last 20
            foreach ($line in $lastLines) {
                $sanitized = Sanitize-Ascii $line
                Write-Host "    $sanitized" -ForegroundColor Gray
            }
            $hasFailures = $true
        }
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

# Step 4: Print demo artifacts and direct links
Write-Host ""
Write-Host "[4] DEMO ARTIFACTS" -ForegroundColor Cyan
if ($tenantId -and $listingId -and $threadId) {
    Write-Host "  tenant_id: $tenantId" -ForegroundColor White
    Write-Host "  listing_id: $listingId" -ForegroundColor White
    Write-Host "  thread_id: $threadId" -ForegroundColor White
} else {
    Write-Host "  (Artifacts not available)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[5] DIRECT LINKS" -ForegroundColor Cyan
Write-Host "  HOS Web: $HosWebUrl" -ForegroundColor White
Write-Host "  HOS Worlds: $HosApiUrl/v1/worlds" -ForegroundColor White
Write-Host "  Pazar Status: $PazarUrl/api/world/status" -ForegroundColor White
Write-Host "  Messaging Status: $MsgUrl/api/world/status" -ForegroundColor White
if ($listingUrl) {
    Write-Host "  Pazar Listing: $listingUrl" -ForegroundColor White
}
if ($threadUrl) {
    Write-Host "  Messaging Thread: $threadUrl" -ForegroundColor White
}

Write-Host ""
Write-Host "[6] USER DEMO CHECKLIST" -ForegroundColor Cyan
Write-Host "  1. Open HOS Web ($HosWebUrl) and verify Prototype Launcher section is visible" -ForegroundColor White
Write-Host "  2. Click 'HOS Worlds' link or navigate to $HosApiUrl/v1/worlds to verify world directory" -ForegroundColor White
Write-Host "  3. Verify Pazar status at $PazarUrl/api/world/status (should show ONLINE)" -ForegroundColor White
Write-Host "  4. Verify Messaging status at $MsgUrl/api/world/status (should show ONLINE)" -ForegroundColor White
if ($listingUrl) {
    Write-Host "  5. Verify listing exists: $listingUrl" -ForegroundColor White
}
if ($threadUrl) {
    Write-Host "  6. Verify messaging thread exists: $threadUrl" -ForegroundColor White
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

