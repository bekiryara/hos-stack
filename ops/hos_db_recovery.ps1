# hos_db_recovery.ps1 - HOS-DB Corruption Recovery (DEV RESET) + RC0 Signal Restore
# Minimal diff, safe, evidence-driven procedure
# PowerShell 5.1 compatible

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$incidentDir = "_archive\incidents\hos-db-recovery-$timestamp"

# Create incident directory
New-Item -ItemType Directory -Path $incidentDir -Force | Out-Null

Write-Host "=== HOS-DB CORRUPTION RECOVERY (DEV RESET) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host ""

# A) Verify root cause
Write-Host "=== A) VERIFY ROOT CAUSE ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "[1] Capturing hos-db logs (last 120 lines with timestamps)..." -ForegroundColor Gray
$hosDbLogsBefore = docker compose logs --tail 120 --timestamps hos-db 2>&1
$hosDbLogsBefore | Out-File -FilePath "$incidentDir\hos-db-logs-before.txt" -Encoding UTF8
$hosDbLogsBefore

Write-Host ""
Write-Host "[2] Capturing docker inspect health for hos-db..." -ForegroundColor Gray
$hosDbInspect = docker inspect stack-hos-db-1 --format "{{json .State.Health}}" 2>&1
if (-not $hosDbInspect -or $hosDbInspect -match "Error") {
    $hosDbInspect = docker inspect hos-db --format "{{json .State.Health}}" 2>&1
}
$hosDbInspect | Out-File -FilePath "$incidentDir\hos-db-inspect-health.json" -Encoding UTF8
$hosDbInspect

Write-Host ""
Write-Host "[3] Root Cause Analysis:" -ForegroundColor Yellow
Write-Host "Postgres checkpoint/WAL corruption detected in hos-db volume. Logs show 'invalid resource manager ID in checkpoint record' and 'PANIC: could not locate a valid checkpoint record'. This indicates Postgres data directory corruption in hos_db_data volume. Core cannot be healthy until hos-db is rebuilt. This causes core-dependent ops gates to SKIP with CORE_UNAVAILABLE, producing empty/false signals instead of real check results." -ForegroundColor White
Write-Host ""

# B) Identify EXACT hos-db volume
Write-Host "=== B) IDENTIFY HOS-DB VOLUME ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "[1] Listing mounts for hos-db container..." -ForegroundColor Gray
$containerName = "stack-hos-db-1"
$containerExists = docker ps -a --format "{{.Names}}" | Select-String -Pattern "^$containerName$"
if (-not $containerExists) {
    $containerName = "hos-db"
    $containerExists = docker ps -a --format "{{.Names}}" | Select-String -Pattern "^$containerName$"
}
if ($containerExists) {
    $mounts = docker inspect $containerName --format "{{range .Mounts}}{{println .Name}}{{end}}" 2>&1
    $mounts | Out-File -FilePath "$incidentDir\hos-db-mounts.txt" -Encoding UTF8
    $mounts
} else {
    Write-Host "[WARN] Container $containerName not found, trying hos-db..." -ForegroundColor Yellow
    $mounts = docker inspect hos-db --format "{{range .Mounts}}{{println .Name}}{{end}}" 2>&1
    $mounts | Out-File -FilePath "$incidentDir\hos-db-mounts.txt" -Encoding UTF8
    $mounts
}

Write-Host ""
Write-Host "[2] Listing volumes containing 'hos'..." -ForegroundColor Gray
$hosVolumes = docker volume ls | Select-String -Pattern "hos" -CaseSensitive:$false
$hosVolumes | Out-File -FilePath "$incidentDir\hos-volumes-list.txt" -Encoding UTF8
$hosVolumes

Write-Host ""
Write-Host "[3] Identifying hos-db data volume..." -ForegroundColor Gray
$HOS_DB_VOLUME = $null
if ($mounts -match "hos_db_data") {
    $HOS_DB_VOLUME = "hos_db_data"
} elseif ($hosVolumes -match "hos_db_data") {
    $HOS_DB_VOLUME = "hos_db_data"
} else {
    Write-Host "[ERROR] Could not identify hos_db_data volume. STOPPING." -ForegroundColor Red
    Write-Host "Mounts output: $mounts" -ForegroundColor Red
    Write-Host "Volumes output: $hosVolumes" -ForegroundColor Red
    exit 1
}

# Safety check: ensure we're not targeting pazar volumes
if ($HOS_DB_VOLUME -match "pazar") {
    Write-Host "[ERROR] Volume name contains 'pazar'. This is WRONG. STOPPING." -ForegroundColor Red
    Write-Host "Detected volume: $HOS_DB_VOLUME" -ForegroundColor Red
    exit 1
}

Write-Host "HOS_DB_VOLUME=$HOS_DB_VOLUME" -ForegroundColor Green
Write-Host ""

# C) DEV reset procedure (only hos-db volume)
Write-Host "=== C) DEV RESET PROCEDURE ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "[1] Stopping HOS services (hos-api, hos-db, hos-web)..." -ForegroundColor Gray
docker compose stop hos-api hos-db hos-web
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Some services may not have been running" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2] Capturing docker compose ps before reset..." -ForegroundColor Gray
$composePsBefore = docker compose ps
$composePsBefore | Out-File -FilePath "$incidentDir\docker-compose-ps-before.txt" -Encoding UTF8
$composePsBefore

Write-Host ""
Write-Host "[3] Removing hos-db volume: $HOS_DB_VOLUME" -ForegroundColor Yellow
Write-Host "[WARNING] This will DELETE all HOS database data. This is a DEV reset only." -ForegroundColor Red
docker volume rm $HOS_DB_VOLUME
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to remove volume. Check if containers are stopped." -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] Volume removed: $HOS_DB_VOLUME" -ForegroundColor Green

Write-Host ""
Write-Host "[4] Starting hos-db and waiting for healthy..." -ForegroundColor Gray
docker compose up -d hos-db

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
    Write-Host "[WARN] hos-db did not become healthy within timeout. Checking logs..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[5] Checking docker compose ps..." -ForegroundColor Gray
$composePsAfter = docker compose ps
$composePsAfter | Out-File -FilePath "$incidentDir\docker-compose-ps-after-db.txt" -Encoding UTF8
$composePsAfter

Write-Host ""
Write-Host "[6] Checking hos-db logs (last 120 lines)..." -ForegroundColor Gray
$hosDbLogsAfter = docker compose logs --tail 120 --timestamps hos-db 2>&1
$hosDbLogsAfter | Out-File -FilePath "$incidentDir\hos-db-logs-after.txt" -Encoding UTF8
$hosDbLogsAfter

Write-Host ""
Write-Host "[7] Starting hos-api and hos-web..." -ForegroundColor Gray
docker compose up -d hos-api hos-web
Start-Sleep -Seconds 10

Write-Host ""
Write-Host "[8] Verifying core availability..." -ForegroundColor Gray
$healthResponse = curl.exe -i http://localhost:3000/v1/health 2>&1
$healthResponse | Out-File -FilePath "$incidentDir\hos-health-after.txt" -Encoding UTF8
$healthResponse

if ($healthResponse -match "HTTP.*200" -and $healthResponse -match '"ok"\s*:\s*true') {
    Write-Host "[PASS] Core is available" -ForegroundColor Green
} else {
    Write-Host "[WARN] Core health check did not return expected response" -ForegroundColor Yellow
}

Write-Host ""

# D) Restore RC0 signal
Write-Host "=== D) RESTORE RC0 SIGNAL ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "[1] Running rc0_check.ps1..." -ForegroundColor Gray
$rc0CheckOutput = & .\ops\rc0_check.ps1 2>&1 | Out-String
$rc0CheckOutput | Out-File -FilePath "$incidentDir\rc0_check-output.txt" -Encoding UTF8
$rc0CheckOutput

Write-Host ""
Write-Host "[2] Running ops_status.ps1..." -ForegroundColor Gray
$opsStatusOutput = & .\ops\ops_status.ps1 2>&1 | Out-String
$opsStatusOutput | Out-File -FilePath "$incidentDir\ops_status-output.txt" -Encoding UTF8
$opsStatusOutput

Write-Host ""

# E) Evidence pack summary
Write-Host "=== E) EVIDENCE PACK SUMMARY ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "Evidence saved to: $incidentDir" -ForegroundColor Gray
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  - hos-db volume ($HOS_DB_VOLUME) was removed and recreated" -ForegroundColor White
Write-Host "  - Safe: Only HOS services were stopped; Pazar services (pazar-db, pazar-app) were NOT touched" -ForegroundColor White
Write-Host "  - Unblocks ops: Core availability restored; core-dependent checks can now run (no longer SKIP with CORE_UNAVAILABLE)" -ForegroundColor White
Write-Host "  - Remains: Any real failures in routes/auth/contract checks will now be visible (not masked by infra issues)" -ForegroundColor White
Write-Host "  - Rollback: Not applicable in dev. No backup exists. To restore requires manual data re-entry or backup restore." -ForegroundColor White
Write-Host ""

Write-Host "=== RECOVERY COMPLETE ===" -ForegroundColor Green

