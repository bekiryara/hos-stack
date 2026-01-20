param(
  [switch]$SkipAuth,
  [switch]$SkipAlerts,
  [switch]$SkipEmailAlerts,
  [switch]$SkipRestoreSmoke
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Stamp {
  return (Get-Date -Format "yyyyMMdd-HHmmss")
}

$outDir = "proofs"
Ensure-Dir $outDir
$outFile = Join-Path $outDir ("proof-" + (Stamp) + ".txt")

Write-Host "Writing proof transcript -> $outFile"
Start-Transcript -Path $outFile -Force | Out-Null

try {
  Write-Host "=== H-OS PROOF START ==="
  Write-Host "Time: $(Get-Date -Format o)"
  Write-Host "CWD:  $(Get-Location)"
  Write-Host ""

  Write-Host "== 1) Check (health/ready/metrics) =="
  if ($SkipAuth) {
    & "$PSScriptRoot\check.ps1" -SkipAuth
  } else {
    & "$PSScriptRoot\check.ps1"
  }
  Write-Host ""

  if (-not $SkipAuth) {
    Write-Host "== 2) Smoke (auth flow) =="
    & "$PSScriptRoot\smoke.ps1"
    Write-Host ""
  }

  if (-not $SkipAlerts) {
    Write-Host "== 3) Alert webhook proof =="
    & "$PSScriptRoot\alert_test.ps1"
    Write-Host ""
  }

  if (-not $SkipEmailAlerts) {
    Write-Host "== 4) Email alert proof (Mailpit) =="
    & "$PSScriptRoot\alert_email_test.ps1"
    Write-Host ""
  }

  if (-not $SkipRestoreSmoke) {
    Write-Host "== 5) Restore smoke proof =="
    & "$PSScriptRoot\restore_smoke.ps1"
    Write-Host ""
  }

  Write-Host "=== H-OS PROOF OK ==="
} finally {
  Stop-Transcript | Out-Null
  Write-Host "Proof transcript written: $outFile"
}


