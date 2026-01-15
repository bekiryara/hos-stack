# baseline_status.ps1 - Read-only baseline status check

param(
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"

# Load safe exit helper if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

function Invoke-SafeExit {
    param([int]$Code)
    if (Get-Command Invoke-OpsExit -ErrorAction SilentlyContinue) {
        Invoke-OpsExit $Code
    } else {
        exit $Code
    }
}

if (-not $Quiet) {
    Write-Host "=== Baseline Status Check ===" -ForegroundColor Cyan
    Write-Host ""
}

$overallPass = $true

# 1) Docker compose ps
if (-not $Quiet) {
    Write-Host "[1] Container Status" -ForegroundColor Yellow
}
try {
    $psOutput = docker compose ps --format json 2>&1 | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $psOutput) {
        Write-Host "  [FAIL] docker compose ps failed" -ForegroundColor Red
        $overallPass = $false
    } else {
        $requiredServices = @("hos-db", "hos-api", "hos-web", "pazar-db", "pazar-app")
        $missingServices = @()
        foreach ($svc in $requiredServices) {
            $found = $psOutput | Where-Object { $_.Service -eq $svc -and $_.State -eq "running" }
            if (-not $found) {
                $missingServices += $svc
            }
        }
        if ($missingServices.Count -gt 0) {
            Write-Host "  [FAIL] Missing services: $($missingServices -join ', ')" -ForegroundColor Red
            $overallPass = $false
        } else {
            if (-not $Quiet) {
                Write-Host "  [PASS] All required services running" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Host "  [FAIL] Error checking containers: $($_.Exception.Message)" -ForegroundColor Red
    $overallPass = $false
}

# 2) H-OS health check
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[2] H-OS Health (http://localhost:3000/v1/health)" -ForegroundColor Yellow
}
try {
    $hosHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:3000/v1/health" -TimeoutSec 5 -ErrorAction Stop
    if ($hosHealth.StatusCode -eq 200) {
        $content = $hosHealth.Content | ConvertFrom-Json
        if ($content.ok -eq $true) {
            if (-not $Quiet) {
                Write-Host "  [PASS] HTTP $($hosHealth.StatusCode) $($hosHealth.Content)" -ForegroundColor Green
            }
        } else {
            Write-Host "  [FAIL] HTTP 200 but ok!=true" -ForegroundColor Red
            $overallPass = $false
        }
    } else {
        Write-Host "  [FAIL] HTTP $($hosHealth.StatusCode)" -ForegroundColor Red
        $overallPass = $false
    }
} catch {
    Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    $overallPass = $false
}

# 3) Pazar health check
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[3] Pazar Health (http://localhost:8080/up)" -ForegroundColor Yellow
}
try {
    $pazarHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8080/up" -TimeoutSec 5 -ErrorAction Stop
    if ($pazarHealth.StatusCode -eq 200) {
        if ($pazarHealth.Content.Trim() -eq "ok") {
            if (-not $Quiet) {
                Write-Host "  [PASS] HTTP $($pazarHealth.StatusCode) $($pazarHealth.Content.Trim())" -ForegroundColor Green
            }
        } else {
            Write-Host "  [FAIL] HTTP 200 but content != 'ok'" -ForegroundColor Red
            $overallPass = $false
        }
    } else {
        Write-Host "  [FAIL] HTTP $($pazarHealth.StatusCode)" -ForegroundColor Red
        $overallPass = $false
    }
} catch {
    Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    $overallPass = $false
}

# Summary
if (-not $Quiet) {
    Write-Host ""
    if ($overallPass) {
        Write-Host "=== BASELINE STATUS: PASS ===" -ForegroundColor Green
        Invoke-SafeExit 0
    } else {
        Write-Host "=== BASELINE STATUS: FAIL ===" -ForegroundColor Red
        Invoke-SafeExit 1
    }
} else {
    # Quiet mode: just exit
    if ($overallPass) {
        Invoke-SafeExit 0
    } else {
        Invoke-SafeExit 1
    }
}


