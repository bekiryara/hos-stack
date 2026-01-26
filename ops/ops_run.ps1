param(
    [ValidateSet('Prototype', 'Full')]
    [string]$Profile = 'Prototype'
)

# WP-68: OPS Run Entrypoint
# Purpose: Single entrypoint for daily ops checks
# Orchestrates existing scripts, does NOT reimplement checks
# PowerShell 5.1 compatible, ASCII-only

$ErrorActionPreference = "Stop"

Write-Host "=== OPS RUN (WP-68) ===" -ForegroundColor Cyan
Write-Host "Profile: $Profile" -ForegroundColor Yellow
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$results = @()

# Prototype profile: minimal daily checks
if ($Profile -eq 'Prototype') {
    Write-Host "Running Prototype profile (minimal daily checks)..." -ForegroundColor Yellow
    Write-Host ""
    
    # 1. Secret Scan
    Write-Host "[1/4] Running secret scan..." -ForegroundColor Yellow
    try {
        & .\ops\secret_scan.ps1
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
        & .\ops\public_ready_check.ps1
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
        & .\ops\conformance.ps1
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
    
    # 4. Prototype Verification
    Write-Host "[4/4] Running prototype verification..." -ForegroundColor Yellow
    try {
        & .\ops\prototype_v1.ps1
        if ($LASTEXITCODE -eq 0) {
            $results += [PSCustomObject]@{ Check = 'Prototype Verification'; Status = 'PASS' }
            Write-Host "PASS: Prototype verification" -ForegroundColor Green
        } else {
            $results += [PSCustomObject]@{ Check = 'Prototype Verification'; Status = 'FAIL' }
            Write-Host "FAIL: Prototype verification" -ForegroundColor Red
            $hasFailures = $true
        }
    } catch {
        $results += [PSCustomObject]@{ Check = 'Prototype Verification'; Status = 'ERROR' }
        Write-Host "ERROR: Prototype verification failed: $($_.Exception.Message)" -ForegroundColor Red
        $hasFailures = $true
    }
    Write-Host ""
}

# Full profile: Prototype + ops_status
if ($Profile -eq 'Full') {
    Write-Host "Running Full profile (Prototype + ops_status)..." -ForegroundColor Yellow
    Write-Host ""
    
    # First run Prototype set
    Write-Host "=== Running Prototype checks ===" -ForegroundColor Cyan
    & .\ops\ops_run.ps1 -Profile Prototype
    $prototypeExitCode = $LASTEXITCODE
    Write-Host ""
    
    # Then run ops_status
    Write-Host "=== Running ops_status ===" -ForegroundColor Cyan
    & .\ops\ops_status.ps1
    $opsStatusExitCode = $LASTEXITCODE
    Write-Host ""
    
    if ($prototypeExitCode -ne 0 -or $opsStatusExitCode -ne 0) {
        $hasFailures = $true
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

