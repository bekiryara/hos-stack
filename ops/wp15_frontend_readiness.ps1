#!/usr/bin/env pwsh
# WP-15: Frontend Readiness Check
# Deterministic check to verify stack is ready for frontend integration
# Returns exit code 0 only if READY, else 1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load safe exit helper if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== WP-15 FRONTEND READINESS CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$failures = @()
$warnings = @()

# Step 1: Repo root sanity
Write-Host "[1] Checking repo root sanity..." -ForegroundColor Yellow
$repoRoot = Split-Path -Parent $scriptDir
if (-not (Test-Path (Join-Path $repoRoot "docker-compose.yml"))) {
    $failures += "docker-compose.yml not found in repo root"
    Write-Host "FAIL: docker-compose.yml not found" -ForegroundColor Red
} elseif (-not (Test-Path (Join-Path $repoRoot "ops"))) {
    $failures += "ops/ folder not found in repo root"
    Write-Host "FAIL: ops/ folder not found" -ForegroundColor Red
} else {
    Write-Host "PASS: Repo root sanity check" -ForegroundColor Green
}

# Step 2: World status check
Write-Host ""
Write-Host "[2] Running world status check..." -ForegroundColor Yellow
$worldStatusScript = Join-Path $repoRoot "ops\world_status_check.ps1"
if (Test-Path $worldStatusScript) {
    try {
        $worldStatusOutput = & $worldStatusScript 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $failures += "World status check failed (exit code $LASTEXITCODE)"
            Write-Host "FAIL: World status check returned exit code $LASTEXITCODE" -ForegroundColor Red
        } elseif ($worldStatusOutput -match "=== WORLD STATUS CHECK.*PASS ===" -or $worldStatusOutput -match "PASS:") {
            Write-Host "PASS: World status check" -ForegroundColor Green
        } else {
            # Fallback: check worlds endpoint directly
            try {
                $worldsResponse = Invoke-RestMethod -Uri "http://localhost:3000/v1/worlds" -Method Get -TimeoutSec 5 -ErrorAction Stop
                if ($worldsResponse -is [array] -and $worldsResponse.Count -ge 2) {
                    $worldKeys = $worldsResponse | ForEach-Object { $_.world_key }
                    if ($worldKeys -contains "core" -and $worldKeys -contains "marketplace") {
                        Write-Host "PASS: World status check (direct endpoint)" -ForegroundColor Green
                    } else {
                        $failures += "Worlds endpoint does not include core+marketplace"
                        Write-Host "FAIL: Worlds endpoint missing core or marketplace" -ForegroundColor Red
                    }
                } else {
                    $failures += "Worlds endpoint returned invalid response"
                    Write-Host "FAIL: Worlds endpoint returned invalid response" -ForegroundColor Red
                }
            } catch {
                $failures += "Worlds endpoint not accessible: $($_.Exception.Message)"
                Write-Host "FAIL: Worlds endpoint not accessible" -ForegroundColor Red
            }
        }
    } catch {
        $failures += "World status script execution failed: $($_.Exception.Message)"
        Write-Host "FAIL: World status script execution failed" -ForegroundColor Red
    }
} else {
    $warnings += "world_status_check.ps1 not found, skipping"
    Write-Host "WARN: world_status_check.ps1 not found" -ForegroundColor Yellow
}

# Step 3: Marketplace spine check
Write-Host ""
Write-Host "[3] Running marketplace spine check..." -ForegroundColor Yellow
$pazarSpineScript = Join-Path $repoRoot "ops\pazar_spine_check.ps1"
if (Test-Path $pazarSpineScript) {
    try {
        $spineOutput = & $pazarSpineScript 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $failures += "Marketplace spine check failed (exit code $LASTEXITCODE)"
            Write-Host "FAIL: Marketplace spine check returned exit code $LASTEXITCODE" -ForegroundColor Red
        } elseif ($spineOutput -match "=== PAZAR SPINE CHECK.*PASS ===" -or $spineOutput -match "PASS:") {
            Write-Host "PASS: Marketplace spine check" -ForegroundColor Green
        } else {
            $failures += "Marketplace spine check did not report PASS"
            Write-Host "FAIL: Marketplace spine check did not report PASS" -ForegroundColor Red
        }
    } catch {
        $failures += "Marketplace spine script execution failed: $($_.Exception.Message)"
        Write-Host "FAIL: Marketplace spine script execution failed" -ForegroundColor Red
    }
} else {
    $failures += "pazar_spine_check.ps1 not found"
    Write-Host "FAIL: pazar_spine_check.ps1 not found" -ForegroundColor Red
}

# Step 4: Optional contract checks
Write-Host ""
Write-Host "[4] Running optional contract checks..." -ForegroundColor Yellow

$optionalChecks = @(
    @{ Name = "Order Contract Check"; Script = "order_contract_check.ps1" },
    @{ Name = "Messaging Contract Check"; Script = "messaging_contract_check.ps1" }
)

foreach ($check in $optionalChecks) {
    $checkScript = Join-Path $repoRoot "ops\$($check.Script)"
    if (Test-Path $checkScript) {
        try {
            $checkOutput = & $checkScript 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                $warnings += "$($check.Name) failed (exit code $LASTEXITCODE)"
                Write-Host "WARN: $($check.Name) returned exit code $LASTEXITCODE" -ForegroundColor Yellow
            } else {
                Write-Host "PASS: $($check.Name)" -ForegroundColor Green
            }
        } catch {
            $warnings += "$($check.Name) execution failed: $($_.Exception.Message)"
            Write-Host "WARN: $($check.Name) execution failed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "INFO: $($check.Script) not found, skipping" -ForegroundColor Gray
    }
}

# Step 5: Frontend presence check
Write-Host ""
Write-Host "[5] Checking frontend presence..." -ForegroundColor Yellow

$frontendCandidates = @(
    "work\marketplace-web",
    "work\web",
    "apps\web",
    "frontend",
    "web"
)

$frontendFound = $false
$frontendPath = $null

foreach ($candidate in $frontendCandidates) {
    $candidatePath = Join-Path $repoRoot $candidate
    if (Test-Path $candidatePath) {
        $packageJsonPath = Join-Path $candidatePath "package.json"
        if (Test-Path $packageJsonPath) {
            $frontendFound = $true
            $frontendPath = $candidate
            Write-Host "INFO: Frontend found at $candidate" -ForegroundColor Gray
            Write-Host "INFO: package.json exists" -ForegroundColor Gray
            break
        }
    }
}

if (-not $frontendFound) {
    Write-Host "INFO: Frontend not present in repo (this is OK)" -ForegroundColor Gray
} else {
    # Check frontend dev server port (if documented in CURRENT.md)
    $currentDocPath = Join-Path $repoRoot "docs\CURRENT.md"
    if (Test-Path $currentDocPath) {
        $currentDocContent = Get-Content $currentDocPath -Raw
        if ($currentDocContent -match "5173.*Frontend") {
            try {
                $tcpTest = Test-NetConnection -ComputerName localhost -Port 5173 -WarningAction SilentlyContinue -InformationLevel Quiet -ErrorAction Stop
                if ($tcpTest) {
                    Write-Host "INFO: Frontend dev server port 5173 is LISTENING" -ForegroundColor Gray
                } else {
                    $warnings += "Frontend dev server port 5173 is NOT LISTENING (frontend may not be started)"
                    Write-Host "WARN: Frontend dev server port 5173 is NOT LISTENING" -ForegroundColor Yellow
                }
            } catch {
                $warnings += "Could not check frontend dev server port 5173"
                Write-Host "WARN: Could not check frontend dev server port 5173" -ForegroundColor Yellow
            }
        }
    }
}

# Final summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan

if ($failures.Count -eq 0) {
    Write-Host "PASS: READY FOR FRONTEND INTEGRATION" -ForegroundColor Green
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Warnings:" -ForegroundColor Yellow
        foreach ($warn in $warnings) {
            Write-Host "  - $warn" -ForegroundColor Yellow
        }
    }
    Read-Host "Press Enter to finish (window stays open)..."
    exit 0
} else {
    Write-Host "FAIL: NOT READY" -ForegroundColor Red
    Write-Host ""
    Write-Host "Failures:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Warnings:" -ForegroundColor Yellow
        foreach ($warn in $warnings) {
            Write-Host "  - $warn" -ForegroundColor Yellow
        }
    }
    Read-Host "Press Enter to finish (window stays open)..."
    exit 1
}

