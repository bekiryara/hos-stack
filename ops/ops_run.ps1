param(
    [ValidateSet('Prototype', 'Full', 'Release')]
    [string]$Profile = 'Prototype'
)

# WP-68: OPS Run Entrypoint
# Purpose: Single entrypoint for daily ops checks (measurement only)
# Orchestrates canonical ops commands; does NOT reimplement checks.
# PowerShell 5.1 compatible, ASCII-only

$ErrorActionPreference = "Stop"

Write-Host "=== OPS RUN (WP-68) ===" -ForegroundColor Cyan
Write-Host "Profile: $Profile" -ForegroundColor Yellow
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$results = @()

$opsDir = Split-Path -Parent $MyInvocation.MyCommand.Path   # ops/
$repoRoot = Split-Path -Parent $opsDir                      # repo root
Push-Location $repoRoot
try {
    $opsEntry = ".\\ops\\ops.ps1"
    if (-not (Test-Path $opsEntry)) {
        throw "ops entrypoint not found: $opsEntry"
    }

# Prototype profile: minimal daily checks
if ($Profile -eq 'Prototype') {
    Write-Host "Running Prototype profile (minimal daily checks)..." -ForegroundColor Yellow
    Write-Host ""
    
    # 1. Secret Scan
    Write-Host "[1/4] Running secret scan..." -ForegroundColor Yellow
    try {
        & $opsEntry secret-scan
        if ($LASTEXITCODE -eq 0) {
            $results += [PSCustomObject]@{ Check = 'Secret Scan'; Status = 'PASS' }
            Write-Host "PASS: Secret scan" -ForegroundColor Green
        } else {
            $results += [PSCustomObject]@{ Check = 'Secret Scan'; Status = 'FAIL' }
            Write-Host "FAIL: Secret scan" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        $results += [PSCustomObject]@{ Check = 'Secret Scan'; Status = 'ERROR' }
        Write-Host "ERROR: Secret scan failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
    Write-Host ""
    
    # 2. Public Ready Check
    Write-Host "[2/4] Running public ready check..." -ForegroundColor Yellow
    try {
        & $opsEntry public-ready
        if ($LASTEXITCODE -eq 0) {
            $results += [PSCustomObject]@{ Check = 'Public Ready'; Status = 'PASS' }
            Write-Host "PASS: Public ready check" -ForegroundColor Green
        } else {
            $results += [PSCustomObject]@{ Check = 'Public Ready'; Status = 'FAIL' }
            Write-Host "FAIL: Public ready check" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        $results += [PSCustomObject]@{ Check = 'Public Ready'; Status = 'ERROR' }
        Write-Host "ERROR: Public ready check failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
    Write-Host ""
    
    # 3. Conformance
    Write-Host "[3/4] Running conformance check..." -ForegroundColor Yellow
    try {
        & $opsEntry conformance
        if ($LASTEXITCODE -eq 0) {
            $results += [PSCustomObject]@{ Check = 'Conformance'; Status = 'PASS' }
            Write-Host "PASS: Conformance check" -ForegroundColor Green
        } else {
            $results += [PSCustomObject]@{ Check = 'Conformance'; Status = 'FAIL' }
            Write-Host "FAIL: Conformance check" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        $results += [PSCustomObject]@{ Check = 'Conformance'; Status = 'ERROR' }
        Write-Host "ERROR: Conformance check failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
    Write-Host ""
    
    # 4. Frontend Smoke
    Write-Host "[4/4] Running frontend smoke..." -ForegroundColor Yellow
    try {
        & $opsEntry frontend-smoke
        if ($LASTEXITCODE -eq 0) {
            $results += [PSCustomObject]@{ Check = 'Frontend Smoke'; Status = 'PASS' }
            Write-Host "PASS: Frontend smoke" -ForegroundColor Green
        } else {
            $results += [PSCustomObject]@{ Check = 'Frontend Smoke'; Status = 'FAIL' }
            Write-Host "FAIL: Frontend smoke" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        $results += [PSCustomObject]@{ Check = 'Frontend Smoke'; Status = 'ERROR' }
        Write-Host "ERROR: Frontend smoke failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
    Write-Host ""
}

# Full profile: Prototype + spine + deep status
if ($Profile -eq 'Full') {
    Write-Host "Running Full profile (Prototype + pazar_spine + status -Ci)..." -ForegroundColor Yellow
    Write-Host ""
    
    # First run Prototype set
    Write-Host "=== Running Prototype checks ===" -ForegroundColor Cyan
    & .\ops\ops_run.ps1 -Profile Prototype
    $prototypeExitCode = $LASTEXITCODE
    Write-Host ""

    # Then run pazar spine (full API reality)
    Write-Host "=== Running pazar spine check ===" -ForegroundColor Cyan
    & $opsEntry pazar-spine
    $pazarSpineExitCode = $LASTEXITCODE
    Write-Host ""

    # Then run ops status deep (CI flavor)
    Write-Host "=== Running ops status deep (-Ci) ===" -ForegroundColor Cyan
    & $opsEntry status -Ci
    $opsStatusExitCode = $LASTEXITCODE
    Write-Host ""

    if ($prototypeExitCode -ne 0 -or $pazarSpineExitCode -ne 0 -or $opsStatusExitCode -ne 0) {
        $hasFailures = $true
    }
}

# Release profile: deterministic pre-release gate path
if ($Profile -eq 'Release') {
    Write-Host "Running Release profile (status -Ci + snapshots + release-check)..." -ForegroundColor Yellow
    Write-Host ""

    $hasWarnings = $false
    $steps = @(
        @{ Name = "Ops Status (-Ci)"; Command = { & $opsEntry status -Ci }; PassOnWarn = $true },
        @{ Name = "Routes Snapshot"; Command = { & $opsEntry routes-snapshot }; PassOnWarn = $false },
        @{ Name = "Schema Snapshot"; Command = { & $opsEntry schema-snapshot }; PassOnWarn = $false },
        @{ Name = "Release Check"; Command = { & $opsEntry release-check -Ci }; PassOnWarn = $true }
    )

    $idx = 1
    foreach ($step in $steps) {
        Write-Host "[$idx/$($steps.Count)] Running $($step.Name)..." -ForegroundColor Yellow
        try {
            & $step.Command
            $code = [int]$LASTEXITCODE
            if ($code -eq 0) {
                Write-Host "PASS: $($step.Name)" -ForegroundColor Green
                $results += [PSCustomObject]@{ Check = $step.Name; Status = 'PASS' }
            } elseif ($code -eq 2 -and $step.PassOnWarn) {
                Write-Host "WARN: $($step.Name)" -ForegroundColor Yellow
                $results += [PSCustomObject]@{ Check = $step.Name; Status = 'WARN' }
                $hasWarnings = $true
            } else {
                Write-Host "FAIL: $($step.Name) (exit=$code)" -ForegroundColor Red
                $results += [PSCustomObject]@{ Check = $step.Name; Status = 'FAIL' }
                $hasFailures = $true
            }
        } catch {
            Write-Host "ERROR: $($step.Name) failed: $($_.Exception.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{ Check = $step.Name; Status = 'ERROR' }
            $hasFailures = $true
        }
        Write-Host ""
        $idx++
    }

    if (-not $hasFailures -and $hasWarnings) {
        Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
        $results | Format-Table -AutoSize
        Write-Host ""
        Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
        Write-Host "Release profile completed with warnings." -ForegroundColor Yellow
        exit 2
    }
}

# Summary
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
if ($Profile -eq 'Prototype') {
    $results | Format-Table -AutoSize
}
Write-Host ""

if ($hasFailures) {
    Write-Host "OVERALL STATUS: FAIL" -ForegroundColor Red
    Write-Host "Some checks failed. Review output above." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "OVERALL STATUS: PASS" -ForegroundColor Green
    Write-Host "All checks passed." -ForegroundColor White
    exit 0
}

} finally {
    Pop-Location
}

