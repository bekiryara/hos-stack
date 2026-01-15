# pazar_ui_smoke.ps1 - UI Smoke Test + Logging Regression Check
# Verifies /ui/admin/control-center is accessible and logs show no permission denied errors
# PowerShell 5.1 compatible, ASCII-only output

param(
    [switch]$Ci
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
    Write-Info "=== Pazar UI Smoke Test ==="
    
    $baseUrl = "http://localhost:8080"
    $uiEndpoint = "${baseUrl}/ui/admin/control-center"
    
    # Check if Docker stack is available
    $dockerAvailable = $false
    try {
        $null = docker compose ps 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dockerAvailable = $true
        }
    } catch {
        # Docker not available
    }
    
    if (-not $dockerAvailable) {
        Write-Warn "Docker stack not available (SKIP)"
        Write-Info ""
        Write-Info "Check                                    Status Notes"
        Write-Info "--------------------------------------------------------------------------------"
        Write-Info "UI Smoke Test                             WARN   Docker stack not running"
        Write-Info ""
        Write-Info "OVERALL STATUS: WARN"
        Pop-Location
        Invoke-OpsExit 2
        return 2
    }
    
    # Check if pazar-app container is running
    $containerName = "stack-pazar-app-1"
    $containerExists = docker ps --format "{{.Names}}" | Select-String -Pattern "^${containerName}$" -Quiet
    if (-not $containerExists) {
        # Try alternative naming
        $containerExists = docker ps --format "{{.Names}}" | Select-String -Pattern "pazar-app" -Quiet
        if ($containerExists) {
            $containerName = (docker ps --format "{{.Names}}" | Select-String -Pattern "pazar-app").Line
        }
    }
    
    if (-not $containerExists) {
        Write-Warn "pazar-app container not found or not running (SKIP)"
        Write-Info ""
        Write-Info "Check                                    Status Notes"
        Write-Info "--------------------------------------------------------------------------------"
        Write-Info "UI Smoke Test                             WARN   pazar-app container not running"
        Write-Info ""
        Write-Info "OVERALL STATUS: WARN"
        Pop-Location
        Invoke-OpsExit 2
        return 2
    }
    
    Write-Info "Testing UI endpoint: $uiEndpoint"
    
    # Make HTTP request to UI endpoint
    $response = $null
    $statusCode = $null
    $errorOccurred = $false
    
    try {
        # Use Invoke-WebRequest with error handling
        $response = Invoke-WebRequest -Uri $uiEndpoint -Method GET -TimeoutSec 10 -ErrorAction Stop
        $statusCode = $response.StatusCode
    } catch {
        $errorOccurred = $true
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
        } else {
            $statusCode = 0
        }
    }
    
    # Check if status code is 500 (Internal Server Error)
    if ($statusCode -eq 500) {
        Write-Fail "UI endpoint returned 500 Internal Server Error"
        Write-Info "This likely indicates a logging permission denied regression."
        Write-Info "Action: Inspect pazar-app logs for 'Permission denied' or 'laravel.log' errors"
        Write-Info ""
        Write-Info "Check                                    Status Notes"
        Write-Info "--------------------------------------------------------------------------------"
        Write-Info "UI Smoke Test                             FAIL   UI endpoint returned 500"
        Write-Info ""
        Write-Info "OVERALL STATUS: FAIL"
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
    
    # Check if status code is acceptable (200 OK or 302 Redirect for login)
    if ($statusCode -ne 200 -and $statusCode -ne 302) {
        if ($statusCode -eq 0) {
            Write-Fail "UI endpoint is not reachable"
            Write-Info "Action: Ensure Docker stack is running and pazar-app is healthy"
        } else {
            Write-Fail "UI endpoint returned unexpected status code: $statusCode"
        }
        Write-Info ""
        Write-Info "Check                                    Status Notes"
        Write-Info "--------------------------------------------------------------------------------"
        Write-Info "UI Smoke Test                             FAIL   Unexpected status code: $statusCode"
        Write-Info ""
        Write-Info "OVERALL STATUS: FAIL"
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
    
    Write-Pass "UI endpoint returned $statusCode (acceptable)"
    
    # Check logs for permission denied errors
    Write-Info "Scanning pazar-app logs for permission denied errors..."
    
    $logLines = docker compose logs --tail=100 pazar-app 2>&1 | Out-String
    $logLinesArray = $logLines -split "`n"
    
    # Check for permission denied indicators
    $permissionDeniedFound = $false
    $laravelLogErrorFound = $false
    $unexpectedValueExceptionFound = $false
    
    foreach ($line in $logLinesArray) {
        if ($line -match "Permission denied" -or $line -match "permission denied") {
            $permissionDeniedFound = $true
        }
        if ($line -match "laravel\.log" -and ($line -match "could not be opened" -or $line -match "failed to open")) {
            $laravelLogErrorFound = $true
        }
        if ($line -match "UnexpectedValueException") {
            $unexpectedValueExceptionFound = $true
        }
    }
    
    if ($permissionDeniedFound -or $laravelLogErrorFound -or $unexpectedValueExceptionFound) {
        Write-Fail "Logging regression detected in pazar-app logs"
        if ($permissionDeniedFound) {
            Write-Info "  - Found 'Permission denied' in logs"
        }
        if ($laravelLogErrorFound) {
            Write-Info "  - Found 'laravel.log' error in logs"
        }
        if ($unexpectedValueExceptionFound) {
            Write-Info "  - Found 'UnexpectedValueException' in logs"
        }
        Write-Info "Action: Check HOS_LARAVEL_LOG_STDOUT=1 is set and docker-entrypoint.sh symlinks laravel.log to stdout"
        Write-Info ""
        Write-Info "Check                                    Status Notes"
        Write-Info "--------------------------------------------------------------------------------"
        Write-Info "UI Smoke Test                             FAIL   Logging regression detected"
        Write-Info ""
        Write-Info "OVERALL STATUS: FAIL"
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
    
    Write-Pass "No logging regression detected in logs"
    
    Write-Info ""
    Write-Info "Check                                    Status Notes"
    Write-Info "--------------------------------------------------------------------------------"
    Write-Info "UI Smoke Test                             PASS   UI accessible, no logging errors"
    Write-Info ""
    Write-Info "OVERALL STATUS: PASS"
    
    Pop-Location
    Invoke-OpsExit 0
    return 0
} catch {
    Write-Fail "Unexpected error: $($_.Exception.Message)"
    Write-Info ""
    Write-Info "Check                                    Status Notes"
    Write-Info "--------------------------------------------------------------------------------"
    Write-Info "UI Smoke Test                             FAIL   Unexpected error: $($_.Exception.Message)"
    Write-Info ""
    Write-Info "OVERALL STATUS: FAIL"
    Pop-Location
    Invoke-OpsExit 1
    return 1
}


















