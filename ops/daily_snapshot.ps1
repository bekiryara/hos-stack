# daily_snapshot.ps1 - Daily evidence snapshot

param(
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$snapshotDir = "_archive\daily\$timestamp"

if (-not $Quiet) {
    Write-Host "=== Daily Snapshot ===" -ForegroundColor Cyan
    Write-Host "Snapshot directory: $snapshotDir" -ForegroundColor Gray
    Write-Host ""
}

# Create snapshot directory
try {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
} catch {
    Write-Host "FAIL: Cannot create snapshot directory: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 1) Git status
if (-not $Quiet) {
    Write-Host "[1] Capturing git status..." -ForegroundColor Yellow
}
try {
    $gitStatus = git status --short 2>&1 | Out-String
    Set-Content -Path "$snapshotDir\git_status.txt" -Value $gitStatus -Encoding UTF8
} catch {
    Add-Content -Path "$snapshotDir\git_status.txt" -Value "Error: $($_.Exception.Message)" -Encoding UTF8
}

# 2) Git commit hash
if (-not $Quiet) {
    Write-Host "[2] Capturing git commit..." -ForegroundColor Yellow
}
try {
    $gitCommit = git rev-parse HEAD 2>&1 | Out-String
    Set-Content -Path "$snapshotDir\git_commit.txt" -Value $gitCommit -Encoding UTF8
} catch {
    Add-Content -Path "$snapshotDir\git_commit.txt" -Value "Error: $($_.Exception.Message)" -Encoding UTF8
}

# 3) Docker compose ps
if (-not $Quiet) {
    Write-Host "[3] Capturing docker compose ps..." -ForegroundColor Yellow
}
try {
    $composePs = docker compose ps 2>&1 | Out-String
    Set-Content -Path "$snapshotDir\compose_ps.txt" -Value $composePs -Encoding UTF8
} catch {
    Add-Content -Path "$snapshotDir\compose_ps.txt" -Value "Error: $($_.Exception.Message)" -Encoding UTF8
}

# 4) Docker compose logs (last 200 lines)
if (-not $Quiet) {
    Write-Host "[4] Capturing docker compose logs..." -ForegroundColor Yellow
}
$services = @("hos-api", "hos-db", "hos-web", "pazar-app", "pazar-db")
foreach ($svc in $services) {
    try {
        $logs = docker compose logs --tail 200 $svc 2>&1 | Out-String
        $logFile = "$snapshotDir\logs_$svc.txt"
        Set-Content -Path $logFile -Value $logs -Encoding UTF8
    } catch {
        Add-Content -Path "$snapshotDir\logs_$svc.txt" -Value "Error: $($_.Exception.Message)" -Encoding UTF8
    }
}

# 5) Health checks
if (-not $Quiet) {
    Write-Host "[5] Capturing health checks..." -ForegroundColor Yellow
}

# H-OS health
try {
    $hosHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:3000/v1/health" -TimeoutSec 5 -ErrorAction Stop
    $hosOutput = "HTTP $($hosHealth.StatusCode)`n$($hosHealth.Content)"
} catch {
    $hosOutput = "Error: $($_.Exception.Message)"
}
Set-Content -Path "$snapshotDir\health_hos.txt" -Value $hosOutput -Encoding UTF8

# Pazar health
try {
    $pazarHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8080/up" -TimeoutSec 5 -ErrorAction Stop
    $pazarOutput = "HTTP $($pazarHealth.StatusCode)`n$($pazarHealth.Content)"
} catch {
    $pazarOutput = "Error: $($_.Exception.Message)"
}
Set-Content -Path "$snapshotDir\health_pazar.txt" -Value $pazarOutput -Encoding UTF8

# 6) Ops status (if available)
if (-not $Quiet) {
    Write-Host "[6] Capturing ops status..." -ForegroundColor Yellow
}
if (Test-Path "ops\ops_status.ps1") {
    try {
        $opsStatus = & powershell -NoProfile -ExecutionPolicy Bypass -File "ops\ops_status.ps1" 2>&1 | Out-String
        Set-Content -Path "$snapshotDir\ops_status.txt" -Value $opsStatus -Encoding UTF8
    } catch {
        Add-Content -Path "$snapshotDir\ops_status.txt" -Value "Error: $($_.Exception.Message)" -Encoding UTF8
    }
} else {
    Set-Content -Path "$snapshotDir\ops_status.txt" -Value "ops_status.ps1 not found" -Encoding UTF8
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "SNAPSHOT_OK path=$snapshotDir" -ForegroundColor Green
} else {
    Write-Host "SNAPSHOT_OK path=$snapshotDir"
}

exit 0






