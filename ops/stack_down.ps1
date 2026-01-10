# stack_down.ps1 - Stack Shutdown Wrapper
# Single entry point for safely shutting down core and/or observability stacks
# PowerShell 5.1 compatible

param(
    [ValidateSet("core", "obs", "all")]
    [string]$Profile = "all" # Default to 'all' for shutdown
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
        Write-Info "=== Stack Shutdown ==="
    } else {
        Write-Host "=== Stack Shutdown ===" -ForegroundColor Cyan
    }
    Write-Host "Profile: $Profile" -ForegroundColor Gray
    Write-Host ""
    
    $overallSuccess = $true
    $warnings = @()
    
    # Observability stack (shutdown first due to potential dependencies on core services)
    if ($Profile -eq "obs" -or $Profile -eq "all") {
        Write-Host "[Obs] Shutting down observability stack..." -ForegroundColor Yellow
        $obsComposeFile = "work\hos\docker-compose.yml"
        Write-Host "  Using: $obsComposeFile (with --profile obs)" -ForegroundColor Gray
        
        if (-not (Test-Path $obsComposeFile)) {
            $warnings += "Observability compose file not found: $obsComposeFile (skipping shutdown)"
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Warn "Observability compose file not found: $obsComposeFile (skipping shutdown)"
            } else {
                Write-Host "[WARN] Observability compose file not found: $obsComposeFile (skipping shutdown)" -ForegroundColor Yellow
            }
        } else {
            try {
                $obsResult = docker compose -f $obsComposeFile --profile obs down --remove-orphans 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $warnings += "Observability stack failed to stop cleanly"
                    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                        Write-Warn "Observability stack failed to stop cleanly"
                    } else {
                        Write-Host "[WARN] Observability stack failed to stop cleanly" -ForegroundColor Yellow
                    }
                    Write-Host $obsResult -ForegroundColor Yellow
                } else {
                    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                        Write-Pass "Observability stack stopped"
                    } else {
                        Write-Host "[PASS] Observability stack stopped" -ForegroundColor Green
                    }
                }
            } catch {
                $warnings += "Observability stack error during shutdown: $($_.Exception.Message)"
                if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                    Write-Warn "Observability stack error during shutdown: $($_.Exception.Message)"
                } else {
                    Write-Host "[WARN] Observability stack error during shutdown: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
        Write-Host ""
    }
    
    # Core stack
    if ($Profile -eq "core" -or $Profile -eq "all") {
        Write-Host "[Core] Shutting down core stack..." -ForegroundColor Yellow
        Write-Host "  Using: docker-compose.yml (root)" -ForegroundColor Gray
        
        try {
            $coreResult = docker compose down --remove-orphans 2>&1
            if ($LASTEXITCODE -ne 0) {
                $warnings += "Core stack failed to stop cleanly"
                if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                    Write-Warn "Core stack failed to stop cleanly"
                } else {
                    Write-Host "[WARN] Core stack failed to stop cleanly" -ForegroundColor Yellow
                }
                Write-Host $coreResult -ForegroundColor Yellow
            } else {
                if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                    Write-Pass "Core stack stopped"
                } else {
                    Write-Host "[PASS] Core stack stopped" -ForegroundColor Green
                }
            }
        } catch {
            $warnings += "Core stack error during shutdown: $($_.Exception.Message)"
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Warn "Core stack error during shutdown: $($_.Exception.Message)"
            } else {
                Write-Host "[WARN] Core stack error during shutdown: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }
    
    # Summary
    if ($warnings.Count -eq 0) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Pass "OVERALL STATUS: PASS (All requested stacks stopped)"
        } else {
            Write-Host "[PASS] OVERALL STATUS: PASS (All requested stacks stopped)" -ForegroundColor Green
        }
        $global:LASTEXITCODE = 0
        return 0
    } else {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Warn "OVERALL STATUS: WARN (Some issues during shutdown)"
        } else {
            Write-Host "[WARN] OVERALL STATUS: WARN (Some issues during shutdown)" -ForegroundColor Yellow
        }
        foreach ($warning in $warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
        $global:LASTEXITCODE = 2
        return 2
    }
} finally {
    Pop-Location
}
