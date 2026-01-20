param(
  [string]$ProjectRoot = "C:\xampp\htdocs\pazar",
  [string]$BaseUrl = "http://localhost/pazar/index.php",
  [string]$TenantSlug = "demo",
  [switch]$IncludeHos,
  [string]$HosRepoPath = (Join-Path $env:USERPROFILE "Desktop\h-os"),
  [switch]$ExportToHos,
  [switch]$HosBootstrap,
  [switch]$HosStopAfter,
  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

Set-Location $ProjectRoot
if (-not (Test-Path "artisan")) { throw "artisan not found. ProjectRoot is wrong: $ProjectRoot" }

$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')

Write-Host "== Pazar Delivery (One Command) =="
Write-Host "ProjectRoot: $ProjectRoot"
Write-Host "BaseUrl: $BaseUrl"
Write-Host "TenantSlug: $TenantSlug"
Write-Host "IncludeHos: $IncludeHos"
Write-Host "HosRepoPath: $HosRepoPath"
Write-Host ""

if ($ExportToHos) {
  Write-Host "-> 0) Export docs to H-OS (keep agents aligned)"
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File ".\\docs\\export_to_hos.ps1" -HosRepoPath $HosRepoPath
  } catch {
    Write-Host "WARN: export_to_hos failed. Continue delivery without export." -ForegroundColor Yellow
    Write-Host ("  " + $_.Exception.Message) -ForegroundColor Yellow
  }
  Write-Host ""
}

Write-Host "-> 1) Proof bundle"
$proofArgs = @(
  "-NoProfile","-ExecutionPolicy","Bypass",
  "-File",".\docs\proof_bundle.ps1",
  "-BaseUrl",$BaseUrl,
  "-TenantSlug",$TenantSlug
)
if ($IncludeHos) { $proofArgs += @("-IncludeHos") }
if ($HosBootstrap) { $proofArgs += @("-HosBootstrap") }
if ($HosStopAfter) { $proofArgs += @("-HosStopAfter") }
& powershell @proofArgs

# Detect latest proof dir (for manual screenshot drop).
$proofsRoot = Join-Path $ProjectRoot "proofs"
$latestProof = $null
if (Test-Path $proofsRoot) {
  $latestProof = Get-ChildItem -Path $proofsRoot -Directory -Filter "proof_*" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}

if ($latestProof) {
  $manualNote = @(
    "MANUAL PROOFS (drop files into this folder):",
    "",
    "- Postman Runner screenshots:",
    "  - Local Quickstart: PASS",
    "  - Hourly Quickstart: PASS",
    "- H-OS Admin screenshot: Session -> Status: ok (if IncludeHos is used)",
    "",
    "Tip: name files like:",
    "  postman_local_quickstart.png",
    "  postman_hourly_quickstart.png",
    "  hos_admin_status_ok.png",
    "",
    ("Generated at: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  ) -join "`r`n"
  Set-Content -Encoding UTF8 -Path (Join-Path $latestProof.FullName "MANUAL_PROOFS_DROP_HERE.txt") -Value $manualNote
  Write-Host ("Manual proof drop folder: " + $latestProof.FullName)
}

Write-Host ""
Write-Host "-> 2) Package delivery (include latest proof)"
$pkgOut = Join-Path $ProjectRoot ("dist\delivery_" + $ts)
$pkgArgs = @(
  "-NoProfile","-ExecutionPolicy","Bypass",
  "-File",".\docs\package_delivery.ps1",
  "-OutDir",$pkgOut,
  "-IncludeLatestProof"
)
if ($OpenFolder) { $pkgArgs += @("-OpenFolder") }
& powershell @pkgArgs

Write-Host ""
Write-Host "-> 3) Zip delivery folder"
$zipPath = $pkgOut + ".zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path (Join-Path $pkgOut "*") -DestinationPath $zipPath -Force

Write-Host ""
Write-Host "DONE."
Write-Host "Delivery folder: $pkgOut"
Write-Host "Delivery zip:    $zipPath"
Write-Host ""
Write-Host "MANUAL (only remaining proof items):"
Write-Host "- Postman Runner screenshots:"
Write-Host "  - Local Quickstart: PASS"
Write-Host "  - Hourly Quickstart: PASS"
Write-Host "- H-OS Admin screenshot: Session -> Status: ok (if IncludeHos is used)"
Write-Host "Place screenshots into the latest proof folder under: $ProjectRoot\proofs\proof_*"
if ($ExportToHos) {
  Write-Host ""
  Write-Host "Docs were also exported to H-OS: $HosRepoPath\\docs\\pazar"
}

if ($OpenFolder) {
  try {
    if ($latestProof) { Invoke-Item $latestProof.FullName }
  } catch { }
  try { Invoke-Item $pkgOut } catch { }
}


