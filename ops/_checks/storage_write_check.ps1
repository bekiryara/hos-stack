# storage_write_check.ps1 - Storage Write Check (Worker Perspective)
# Validates log append works from container runtime context (www-data user)
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

Write-Host "=== STORAGE WRITE CHECK ===" -ForegroundColor Cyan
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
    Write-Host "[WARN] Docker not available. Skipping storage write check." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check                                    Status Notes" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Storage Write Check                       WARN   Docker not available" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Invoke-OpsExit 2
}

# Check if pazar-app container is running
$containerName = "stack-pazar-app-1"
$containerExists = docker ps --format "{{.Names}}" | Select-String -Pattern "^${containerName}$" -Quiet
if (-not $containerExists) {
    # Try alternative naming (project name might be different)
    $allContainers = docker ps --format "{{.Names}}"
    $pazarContainer = $allContainers | Select-String -Pattern "pazar-app" | Select-Object -First 1
    if ($pazarContainer) {
        $containerName = $pazarContainer.Line.Trim()
        $containerExists = $true
    }
}

if (-not $containerExists) {
    Write-Host "[WARN] pazar-app container not found or not running (SKIP)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check                                    Status Notes" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Storage Write Check                       WARN   pazar-app container not running" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Invoke-OpsExit 2
}

# Check 1: Verify paths exist
Write-Host "Checking paths exist..." -ForegroundColor Yellow
$pathsCheck = docker exec $containerName sh -c "test -d /var/www/html/storage && test -d /var/www/html/storage/logs && test -d /var/www/html/bootstrap/cache && echo 'EXISTS' || echo 'MISSING'" 2>&1
if ($pathsCheck -match "EXISTS") {
    $results += [PSCustomObject]@{ Check = "Paths exist"; Status = "PASS"; Notes = "storage, storage/logs, bootstrap/cache exist" }
} else {
    $results += [PSCustomObject]@{ Check = "Paths exist"; Status = "FAIL"; Notes = "One or more paths missing" }
    $script:hasFail = $true
}

# Check 2: Verify laravel.log exists
Write-Host "Checking laravel.log exists..." -ForegroundColor Yellow
$logExistsCheck = docker exec $containerName sh -c "test -f /var/www/html/storage/logs/laravel.log && echo 'EXISTS' || echo 'MISSING'" 2>&1
if ($logExistsCheck -match "EXISTS") {
    $results += [PSCustomObject]@{ Check = "laravel.log exists"; Status = "PASS"; Notes = "File exists" }
} else {
    $results += [PSCustomObject]@{ Check = "laravel.log exists"; Status = "FAIL"; Notes = "File does not exist" }
    $script:hasFail = $true
}

# Check 3: Worker perspective append test (www-data user)
Write-Host "Checking worker append (www-data user)..." -ForegroundColor Yellow
$appendTest = docker exec $containerName sh -lc "su -s /bin/sh www-data -c 'echo test_append_`$(date +%s) >> /var/www/html/storage/logs/laravel.log && echo APPEND_OK' 2>&1" 2>&1
$appendExitCode = $LASTEXITCODE

if ($appendExitCode -eq 0 -and $appendTest -match "APPEND_OK") {
    $results += [PSCustomObject]@{ Check = "Worker append (www-data)"; Status = "PASS"; Notes = "www-data user can append to laravel.log" }
} else {
    # Check if su is missing
    $suCheck = docker exec $containerName sh -c "command -v su >/dev/null 2>&1 && echo 'SU_EXISTS' || echo 'SU_MISSING'" 2>&1
    if ($suCheck -match "SU_MISSING") {
        $results += [PSCustomObject]@{ Check = "Worker append (www-data)"; Status = "WARN"; Notes = "su command missing; check permissions manually (chmod 0666 laravel.log)" }
        $script:hasWarn = $true
    } else {
        $results += [PSCustomObject]@{ Check = "Worker append (www-data)"; Status = "FAIL"; Notes = "www-data user cannot append to laravel.log" }
        $script:hasFail = $true
    }
}

# Print results table
Write-Host ""
Write-Host "=== STORAGE WRITE CHECK RESULTS ===" -ForegroundColor Cyan
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
    Write-Host "1. Ensure entrypoint script runs: docker compose logs pazar-app | Select-String 'FAIL|WARN'" -ForegroundColor Gray
    Write-Host "2. Check laravel.log permissions: docker compose exec -T pazar-app ls -la /var/www/html/storage/logs/laravel.log" -ForegroundColor Gray
    Write-Host "3. Manually fix: docker compose exec -T pazar-app chmod 0666 /var/www/html/storage/logs/laravel.log" -ForegroundColor Gray
    Write-Host "4. Recreate container: docker compose down pazar-app && docker compose up -d --force-recreate pazar-app" -ForegroundColor Gray
    Invoke-OpsExit 1
} elseif ($script:hasWarn) {
    Write-Host "OVERALL STATUS: WARN" -ForegroundColor Yellow
    Invoke-OpsExit 2
} else {
    Write-Host "OVERALL STATUS: PASS" -ForegroundColor Green
    Invoke-OpsExit 0
}





