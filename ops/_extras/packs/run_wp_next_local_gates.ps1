# run_wp_next_local_gates.ps1 - WP-NEXT yerel gate paketi
# Akis: env_preflight -> frontend_smoke -> verify -> conformance -> update_code_index
# Tum stdout docs/PROOFS/_logs/wp_next_gates_YYYYMMDD_HHMMSS.log dosyasina yazilir.

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$opsRoot = Split-Path -Parent (Split-Path -Parent $scriptDir) # .../ops
$repoRoot = Split-Path -Parent $opsRoot
$logsDir = Join-Path $repoRoot "docs\PROOFS\_logs"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logsDir "wp_next_gates_$timestamp.log"

# _logs klasoru yoksa olustur
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# Script ciktisini log + konsola yaz; cikis kodunu koru
function Run-Gate {
    param([string]$ScriptPath)
    $out = & $ScriptPath 2>&1
    $code = $LASTEXITCODE
    $out | ForEach-Object { Write-Host $_; $_ | Out-File -FilePath $logFile -Append }
    return $code
}

# Script'lari repo root'tan calistir (ops script'leri genelde repo root'tan cagrilir)
Push-Location $repoRoot | Out-Null
try {
    "=== WP-NEXT LOCAL GATES ===" | Out-File -FilePath $logFile
    "Timestamp: $timestamp" | Out-File -FilePath $logFile -Append
    "Log: $logFile" | Out-File -FilePath $logFile -Append
    ""

    # 1) env_preflight
    $code = Run-Gate -ScriptPath "$scriptDir\env_preflight.ps1"
    if ($code -ne 0) {
        Write-Host "FAIL: env_preflight.ps1 returned $code - gate paketi durduruldu." -ForegroundColor Red
        Pop-Location
        exit 1
    }

    # 2) frontend_smoke
    $code = Run-Gate -ScriptPath "$scriptDir\frontend_smoke.ps1"
    if ($code -ne 0) {
        Write-Host "FAIL: frontend_smoke.ps1 returned $code" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    # 3) verify
    $code = Run-Gate -ScriptPath "$scriptDir\verify.ps1"
    if ($code -ne 0) {
        Write-Host "FAIL: verify.ps1 returned $code" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    # 4) conformance
    $code = Run-Gate -ScriptPath "$scriptDir\conformance.ps1"
    if ($code -ne 0) {
        Write-Host "FAIL: conformance.ps1 returned $code" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    # 5) update_code_index
    $code = Run-Gate -ScriptPath "$scriptDir\update_code_index.ps1"
    if ($code -ne 0) {
        Write-Host "FAIL: update_code_index.ps1 returned $code" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    Write-Host "`n=== WP-NEXT LOCAL GATES: PASS ===" -ForegroundColor Green
    "`n=== WP-NEXT LOCAL GATES: PASS ===" | Out-File -FilePath $logFile -Append
    Pop-Location
    exit 0
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    $_ | Out-File -FilePath $logFile -Append
    Pop-Location
    exit 1
}
