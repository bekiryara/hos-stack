# HOS-DB DEV RESET + CORE RESTORE
# Copy-paste this entire block into PowerShell

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== HOS-DB DEV RESET + CORE RESTORE ===" -ForegroundColor Cyan

# Start hos-db if needed
Write-Host "[1] Ensuring hos-db is running..." -ForegroundColor Yellow
docker compose up -d hos-db
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start hos-db" -ForegroundColor Red
    exit 1
}

# Detect hos-db container ID
Write-Host "[2] Detecting hos-db container ID..." -ForegroundColor Yellow
$hosDbContainerId = docker compose ps -q hos-db
if (-not $hosDbContainerId) {
    Write-Host "[ERROR] hos-db container not found" -ForegroundColor Red
    exit 1
}
Write-Host "Container ID: $hosDbContainerId" -ForegroundColor Gray

# Detect the EXACT volume mounted at /var/lib/postgresql/data
Write-Host "[3] Detecting hos-db data volume..." -ForegroundColor Yellow
$inspectOutput = docker inspect $hosDbContainerId --format "{{json .Mounts}}" | ConvertFrom-Json
$hosDbVolume = $null
foreach ($mount in $inspectOutput) {
    if ($mount.Destination -eq "/var/lib/postgresql/data" -and $mount.Type -eq "volume") {
        $hosDbVolume = $mount.Name
        break
    }
}

if (-not $hosDbVolume) {
    Write-Host "[ERROR] Could not find volume mounted at /var/lib/postgresql/data" -ForegroundColor Red
    exit 1
}

Write-Host "Detected volume: $hosDbVolume" -ForegroundColor Gray

# Safety guard: if volume name contains "pazar" => abort
if ($hosDbVolume -match "pazar") {
    Write-Host "[ERROR] SAFETY CHECK FAILED: Volume name contains 'pazar': $hosDbVolume" -ForegroundColor Red
    Write-Host "[ERROR] Aborting to prevent data loss. This is the wrong volume." -ForegroundColor Red
    exit 1
}

Write-Host "[PASS] Safety check: Volume does not contain 'pazar'" -ForegroundColor Green

# Stop only hos-api hos-db hos-web
Write-Host "[4] Stopping HOS services..." -ForegroundColor Yellow
docker compose stop hos-api hos-db hos-web
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Some services may not have been running" -ForegroundColor Yellow
}

# Remove ONLY the detected hos-db volume
Write-Host "[5] Removing hos-db volume: $hosDbVolume" -ForegroundColor Yellow
Write-Host "[WARNING] This will DELETE all HOS database data (DEV reset)" -ForegroundColor Red
docker volume rm $hosDbVolume
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to remove volume. Check if containers are stopped." -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] Volume removed: $hosDbVolume" -ForegroundColor Green

# Bring up hos-db, then hos-api + hos-web
Write-Host "[6] Starting hos-db..." -ForegroundColor Yellow
docker compose up -d hos-db
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start hos-db" -ForegroundColor Red
    exit 1
}

Write-Host "Waiting for hos-db to become healthy (max 2 minutes)..." -ForegroundColor Gray
$maxWait = 120
$waited = 0
$healthy = $false
while ($waited -lt $maxWait -and -not $healthy) {
    Start-Sleep -Seconds 5
    $waited += 5
    $healthStatus = docker inspect hos-db --format "{{.State.Health.Status}}" 2>&1
    if ($healthStatus -eq "healthy") {
        $healthy = $true
        Write-Host "[PASS] hos-db is healthy" -ForegroundColor Green
    } else {
        Write-Host "  Waiting... ($waited/$maxWait seconds) - Status: $healthStatus" -ForegroundColor Gray
    }
}

if (-not $healthy) {
    Write-Host "[WARN] hos-db did not become healthy within timeout" -ForegroundColor Yellow
}

Write-Host "[7] Starting hos-api and hos-web..." -ForegroundColor Yellow
docker compose up -d hos-api hos-web
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start hos-api/hos-web" -ForegroundColor Red
    exit 1
}
Start-Sleep -Seconds 10

# Verify: curl.exe -i http://localhost:3000/v1/health returns 200
Write-Host "[8] Verifying core availability..." -ForegroundColor Yellow
$healthResponse = curl.exe -i http://localhost:3000/v1/health 2>&1
$healthResponse
if ($healthResponse -match "HTTP.*200" -and $healthResponse -match '"ok"\s*:\s*true') {
    Write-Host "[PASS] Core is available" -ForegroundColor Green
} else {
    Write-Host "[WARN] Core health check did not return expected response" -ForegroundColor Yellow
}

# Run rc0_check and ops_status
Write-Host "[9] Running rc0_check.ps1..." -ForegroundColor Yellow
.\ops\rc0_check.ps1

Write-Host "[10] Running ops_status.ps1..." -ForegroundColor Yellow
.\ops\ops_status.ps1

Write-Host "=== RESET COMPLETE ===" -ForegroundColor Green











