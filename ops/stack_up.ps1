# stack_up.ps1 - Stack Bring-Up Wrapper
# Single entry point for bringing up core and/or observability stacks
# PowerShell 5.1 compatible

param(
    [ValidateSet("core", "obs", "all")]
    [string]$Profile = "core"
)

# Load shared output helper if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}

$ErrorActionPreference = "Continue"

# Ensure we're in repo root
$repoRoot = Split-Path -Parent $scriptDir
Push-Location $repoRoot
try {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "=== Stack Bring-Up ==="
    } else {
        Write-Host "=== Stack Bring-Up ===" -ForegroundColor Cyan
    }
    Write-Host "Profile: $Profile" -ForegroundColor Gray
    Write-Host ""
    
    $overallSuccess = $true
    $errors = @()
    
    # Core stack
    if ($Profile -eq "core" -or $Profile -eq "all") {
        Write-Host "[Core] Bringing up core stack..." -ForegroundColor Yellow
        Write-Host "  Using: docker-compose.yml (root)" -ForegroundColor Gray
        
        try {
            $coreResult = docker compose up -d --build 2>&1
            if ($LASTEXITCODE -ne 0) {
                $overallSuccess = $false
                $errors += "Core stack failed to start"
                if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                    Write-Fail "Core stack failed to start"
                } else {
                    Write-Host "[FAIL] Core stack failed to start" -ForegroundColor Red
                }
                Write-Host $coreResult -ForegroundColor Red
            } else {
                if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                    Write-Pass "Core stack started"
                } else {
                    Write-Host "[PASS] Core stack started" -ForegroundColor Green
                }
            }
        } catch {
            $overallSuccess = $false
            $errors += "Core stack error: $($_.Exception.Message)"
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Fail "Core stack error: $($_.Exception.Message)"
            } else {
                Write-Host "[FAIL] Core stack error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
    
    # Observability stack
    if ($Profile -eq "obs" -or $Profile -eq "all") {
        Write-Host "[Obs] Bringing up observability stack..." -ForegroundColor Yellow
        $obsComposeFile = "work\hos\docker-compose.yml"
        Write-Host "  Using: $obsComposeFile (with --profile obs)" -ForegroundColor Gray
        Write-Host "  Obs bring-up: starting only observability services (no api/web/db)" -ForegroundColor Gray
        
        if (-not (Test-Path $obsComposeFile)) {
            $overallSuccess = $false
            $errors += "Observability compose file not found: $obsComposeFile"
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Fail "Observability compose file not found: $obsComposeFile"
            } else {
                Write-Host "[FAIL] Observability compose file not found: $obsComposeFile" -ForegroundColor Red
            }
        } else {
            try {
                # Only start observability services to avoid port conflicts with core stack
                # Explicit service list: prometheus, alertmanager, grafana, loki, promtail, tempo, otel-collector, postgres-exporter, alert-webhook
                $obsServices = @("prometheus", "alertmanager", "grafana", "loki", "promtail", "tempo", "otel-collector", "postgres-exporter", "alert-webhook")
                $obsResult = docker compose -f $obsComposeFile --profile obs up -d --build $obsServices 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $overallSuccess = $false
                    $errors += "Observability stack failed to start"
                    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                        Write-Fail "Observability stack failed to start"
                    } else {
                        Write-Host "[FAIL] Observability stack failed to start" -ForegroundColor Red
                    }
                    Write-Host $obsResult -ForegroundColor Red
                } else {
                    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                        Write-Pass "Observability stack started"
                    } else {
                        Write-Host "[PASS] Observability stack started" -ForegroundColor Green
                    }
                }
            } catch {
                $overallSuccess = $false
                $errors += "Observability stack error: $($_.Exception.Message)"
                if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                    Write-Fail "Observability stack error: $($_.Exception.Message)"
                } else {
                    Write-Host "[FAIL] Observability stack error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        Write-Host ""
    }
    
    # Summary
    if ($overallSuccess) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Pass "OVERALL STATUS: PASS (All requested stacks started)"
        } else {
            Write-Host "[PASS] OVERALL STATUS: PASS (All requested stacks started)" -ForegroundColor Green
        }
        $global:LASTEXITCODE = 0
        return 0
    } else {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "OVERALL STATUS: FAIL (Some stacks failed to start)"
        } else {
            Write-Host "[FAIL] OVERALL STATUS: FAIL (Some stacks failed to start)" -ForegroundColor Red
        }
        foreach ($error in $errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
        $global:LASTEXITCODE = 1
        return 1
    }
} finally {
    Pop-Location
}
