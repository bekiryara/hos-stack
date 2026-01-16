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

# 4) Repo integrity check
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[4] Repo Integrity" -ForegroundColor Yellow
}
try {
    # Check if we're in a git repo
    $gitRoot = git rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] Not in a git repository" -ForegroundColor Yellow
    } else {
        # Check for uncommitted changes (warning only, not a failure)
        $gitStatus = git status --porcelain 2>&1
        if ($gitStatus) {
            if (-not $Quiet) {
                Write-Host "  [WARN] Uncommitted changes detected (not blocking)" -ForegroundColor Yellow
            }
        } else {
            if (-not $Quiet) {
                Write-Host "  [PASS] Git working directory clean" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Host "  [WARN] Could not check repo integrity: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 5) Forbidden files check (only tracked files)
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[5] Forbidden Files Check (tracked only)" -ForegroundColor Yellow
}
$foundForbidden = $false
try {
    # Check if .env is tracked
    $envTracked = git ls-files .env 2>&1
    if ($LASTEXITCODE -eq 0 -and $envTracked) {
        Write-Host "  [FAIL] .env is tracked in git (should be in .gitignore)" -ForegroundColor Red
        $foundForbidden = $true
        $overallPass = $false
    }
    # Check if secrets are tracked
    $secretsTracked = git ls-files work/hos/secrets/*.txt 2>&1
    if ($LASTEXITCODE -eq 0 -and $secretsTracked) {
        Write-Host "  [FAIL] Secrets are tracked in git (should be in .gitignore)" -ForegroundColor Red
        $foundForbidden = $true
        $overallPass = $false
    }
    if (-not $foundForbidden) {
        if (-not $Quiet) {
            Write-Host "  [PASS] No forbidden tracked files" -ForegroundColor Green
        }
    }
} catch {
    if (-not $Quiet) {
        Write-Host "  [WARN] Could not check forbidden files: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 6) Snapshot integrity (check if daily snapshot dir exists and is recent)
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[6] Snapshot Integrity" -ForegroundColor Yellow
}
$snapshotDir = "_archive/daily"
if (Test-Path $snapshotDir) {
    $latestSnapshot = Get-ChildItem -Path $snapshotDir -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestSnapshot) {
        $age = (Get-Date) - $latestSnapshot.LastWriteTime
        if ($age.TotalDays -lt 7) {
            if (-not $Quiet) {
                Write-Host "  [PASS] Recent snapshot found: $($latestSnapshot.Name) ($([math]::Round($age.TotalDays, 1)) days old)" -ForegroundColor Green
            }
        } else {
            if (-not $Quiet) {
                Write-Host "  [WARN] Snapshot is old: $($latestSnapshot.Name) ($([math]::Round($age.TotalDays, 1)) days old)" -ForegroundColor Yellow
            }
        }
    } else {
        if (-not $Quiet) {
            Write-Host "  [WARN] No snapshots found in $snapshotDir" -ForegroundColor Yellow
        }
    }
} else {
    if (-not $Quiet) {
        Write-Host "  [WARN] Snapshot directory not found: $snapshotDir" -ForegroundColor Yellow
    }
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


