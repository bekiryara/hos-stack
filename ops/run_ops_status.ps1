# run_ops_status.ps1 - Safe Ops Status Runner
# Executes ops_status.ps1 in a child PowerShell process to prevent terminal closing
# PowerShell 5.1 compatible

param(
    [switch]$Ci,
    [switch]$Pause
)

# Load shared helpers if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

$ErrorActionPreference = "Continue"

# Ensure we're in repo root
$repoRoot = Split-Path -Parent $scriptDir
Push-Location $repoRoot
try {
    # Resolve ops_status.ps1 path from script's own location
    $opsStatusPath = Join-Path $scriptDir "ops_status.ps1"
    
    if (-not (Test-Path $opsStatusPath)) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "ops_status.ps1 not found: $opsStatusPath"
        } else {
            Write-Host "[FAIL] ops_status.ps1 not found: $opsStatusPath" -ForegroundColor Red
        }
        
        # Search for similar scripts in the same directory as a hint
        $similarScripts = Get-ChildItem -Path $scriptDir -Filter "*status*.ps1" -ErrorAction SilentlyContinue
        if ($similarScripts.Count -gt 0) {
            Write-Host ""
            Write-Host "Hint: Found similar scripts in ${scriptDir}:" -ForegroundColor Yellow
            foreach ($script in $similarScripts) {
                Write-Host "  - $($script.Name)" -ForegroundColor Gray
            }
        }
        
        $global:LASTEXITCODE = 1
        if ($Pause) {
            Write-Host ""
            Write-Host "Press Enter to close..." -ForegroundColor Gray
            Read-Host | Out-Null
        }
        Invoke-OpsExit 1
        return 1
    }
    
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Info "=== Running Ops Status (Safe Mode) ==="
    } else {
        Write-Host "=== Running Ops Status (Safe Mode) ===" -ForegroundColor Cyan
    }
    if ($Ci) {
        Write-Host "CI Mode: Exit code will terminate job on failure" -ForegroundColor Gray
    } else {
        Write-Host "Local Mode: Terminal will remain open" -ForegroundColor Gray
    }
    Write-Host "Executing in child PowerShell process..." -ForegroundColor Gray
    Write-Host ""
    
    # Determine PowerShell executable (pwsh preferred, fallback to powershell)
    $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    
    # Run script in separate process using Start-Process (more reliable for exit code capture)
    try {
        $args = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", "`"$opsStatusPath`""
        )
        if ($Ci) {
            $args += "-Ci"
        }
        $process = Start-Process -FilePath $psExe -ArgumentList $args -WorkingDirectory $repoRoot -Wait -PassThru -NoNewWindow
        
        $code = $process.ExitCode
        
        Write-Host ""
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Info "=== Ops Status Completed ==="
        } else {
            Write-Host "=== Ops Status Completed ===" -ForegroundColor Cyan
        }
        Write-Host "ExitCode=$code" -ForegroundColor $(if ($code -eq 0) { "Green" } elseif ($code -eq 2) { "Yellow" } else { "Red" })
        
        # Set global LASTEXITCODE for PowerShell compatibility
        $global:LASTEXITCODE = $code
        
        # Optional pause for double-click runs
        if ($Pause) {
            Write-Host ""
            Write-Host "Press Enter to close..." -ForegroundColor Gray
            Read-Host | Out-Null
        }
        
        # Use safe exit (terminal stays open in interactive, exits in CI)
        Invoke-OpsExit $code
        return $code
    } catch {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "run_ops_status runner failed: $($_.Exception.Message)"
        } else {
            Write-Host "[FAIL] run_ops_status runner failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        $global:LASTEXITCODE = 1
        if ($Pause) {
            Write-Host ""
            Write-Host "Press Enter to close..." -ForegroundColor Gray
            Read-Host | Out-Null
        }
        Invoke-OpsExit 1
        return 1
    }
} finally {
    Pop-Location
}
