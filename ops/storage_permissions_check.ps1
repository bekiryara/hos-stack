# storage_permissions_check.ps1 - Storage Permissions Check
# Verifies Laravel storage permissions are correctly configured
# PowerShell 5.1 compatible

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

Write-Host "=== STORAGE PERMISSIONS CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()
$hasFail = $false
$hasWarn = $false

# Check if Docker is available
$dockerAvailable = $false
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerAvailable = $true
    }
} catch {
    # Docker not available
}

if (-not $dockerAvailable) {
    Write-Warn "Docker not available. Skipping storage permissions check."
    Write-Host ""
    Write-Host "Check                                    Status Notes" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Storage Permissions Check                  SKIP   Docker not available" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Invoke-OpsExit 2
}

# Check if pazar-app container is running
$pazarContainerRunning = $false
try {
    $containerStatus = docker compose ps pazar-app --format json 2>&1 | ConvertFrom-Json
    if ($containerStatus -and $containerStatus.State -eq "running") {
        $pazarContainerRunning = $true
    }
} catch {
    # Container not running or compose ps failed
}

if (-not $pazarContainerRunning) {
    Write-Warn "pazar-app container not running. Start services with 'docker compose up -d'."
    Write-Host ""
    Write-Host "Check                                    Status Notes" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Storage Permissions Check                  WARN   pazar-app container not running" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Invoke-OpsExit 2
}

# Helper: Test directory exists and is writable
function Test-StoragePath {
    param(
        [string]$CheckName,
        [string]$ContainerPath,
        [string]$Description
    )
    
    Write-Host "Checking $Description..." -ForegroundColor Yellow
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    
    try {
        # Check if path exists (with timeout)
        $existsCheck = docker compose exec -T pazar-app timeout 5 sh -c "test -d $ContainerPath" 2>&1
        $existsExitCode = $LASTEXITCODE
        
        if ($existsExitCode -ne 0) {
            $status = "FAIL"
            $notes = "Directory does not exist: $ContainerPath"
            $exitCode = 1
            $script:hasFail = $true
        } else {
            # Check if path is writable (try to create a test file, with timeout)
            $testFile = "${ContainerPath}/.permissions_probe"
            $touchCheck = docker compose exec -T pazar-app timeout 5 sh -c "touch $testFile 2>&1 && echo 'probe' >> $testFile 2>&1 && rm -f $testFile 2>&1" 2>&1
            $touchExitCode = $LASTEXITCODE
            
            if ($touchExitCode -ne 0) {
                $status = "FAIL"
                $notes = "Directory not writable: $ContainerPath (touch/write failed)"
                $exitCode = 1
                $script:hasFail = $true
            } else {
                # Check ownership (best-effort, may not always be available)
                $ownerCheck = docker compose exec -T pazar-app sh -c "stat -c '%U:%G' $ContainerPath 2>&1" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $owner = $ownerCheck.Trim()
                    if ($owner -match "www-data") {
                        $notes = "Path exists and writable (owner: $owner)"
                    } else {
                        $notes = "Path exists and writable (owner: $owner, expected www-data)"
                    }
                } else {
                    $notes = "Path exists and writable"
                }
            }
        }
    } catch {
        $status = "FAIL"
        $notes = "Error checking path: $($_.Exception.Message)"
        $exitCode = 1
        $script:hasFail = $true
    }
    
    $script:results += [PSCustomObject]@{
        Check = $CheckName
        Status = $status
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Check 1: Storage directory exists and writable
$storageResult = Test-StoragePath -CheckName "Storage Directory" `
    -ContainerPath "/var/www/html/storage" `
    -Description "storage directory"

# Check 2: Storage logs directory exists and writable
$logsResult = Test-StoragePath -CheckName "Storage Logs Directory" `
    -ContainerPath "/var/www/html/storage/logs" `
    -Description "storage/logs directory"

# Check 3: Laravel log file writable
Write-Host "Checking Laravel log file writability..." -ForegroundColor Yellow

$logStatus = "PASS"
$logNotes = ""
$logExitCode = 0

try {
    $logPath = "/var/www/html/storage/logs/laravel.log"
    
    # Try to touch and append to laravel.log (with timeout)
    $logCheck = docker compose exec -T pazar-app timeout 5 sh -c "touch $logPath 2>&1 && echo 'probe' >> $logPath 2>&1 && tail -1 $logPath 2>&1 | grep -q 'probe' && echo 'OK'" 2>&1
    $logExitCode = $LASTEXITCODE
    
    if ($logExitCode -ne 0) {
        $logStatus = "FAIL"
        $logNotes = "laravel.log not writable (touch/append failed)"
        $logExitCode = 1
        $script:hasFail = $true
    } else {
        $logNotes = "laravel.log exists and writable"
    }
} catch {
    $logStatus = "FAIL"
    $logNotes = "Error checking laravel.log: $($_.Exception.Message)"
    $logExitCode = 1
    $script:hasFail = $true
}

$script:results += [PSCustomObject]@{
    Check = "Laravel Log File"
    Status = $logStatus
    Notes = $logNotes
}

# Check 4: Bootstrap cache directory (if needed)
$cacheResult = Test-StoragePath -CheckName "Bootstrap Cache Directory" `
    -ContainerPath "/var/www/html/bootstrap/cache" `
    -Description "bootstrap/cache directory"

# Print results table
Write-Host ""
Write-Host "=== STORAGE PERMISSIONS CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Check                                    Status Notes" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

foreach ($result in $script:results) {
    $statusMarker = switch ($result.Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        default { "[$($result.Status)]" }
    }
    
    $checkPadded = $result.Check.PadRight(40)
    $statusPadded = $statusMarker.PadRight(8)
    
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "White" }
    }
    
    Write-Host "$checkPadded $statusPadded $($result.Notes)" -ForegroundColor $color
}

Write-Host ""

# Determine overall status
if ($script:hasFail) {
    Write-Host "OVERALL STATUS: FAIL" -ForegroundColor Red
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    Write-Host "1. Ensure pazar-perms-init service ran successfully: docker compose logs pazar-perms-init" -ForegroundColor Gray
    Write-Host "2. Check named volumes: docker volume inspect pazar_storage" -ForegroundColor Gray
    Write-Host "3. Manually fix permissions: docker compose exec -T pazar-app chown -R www-data:www-data /var/www/html/storage" -ForegroundColor Gray
    Write-Host "4. Restart pazar-app: docker compose restart pazar-app" -ForegroundColor Gray
    Invoke-OpsExit 1
} elseif ($script:hasWarn) {
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Invoke-OpsExit 2
} else {
    Write-Host "OVERALL STATUS: PASS" -ForegroundColor Green
    Invoke-OpsExit 0
}

