param(
  [string]$ProjectRoot = "C:\xampp\htdocs\pazar",
  # If empty, auto-detect latest proof folder under proofs\proof_*
  [string]$ProofDir = "",
  # If empty, auto-detect latest delivery folder under dist\delivery_*
  [string]$DeliveryDir = "",
  # If empty, uses "$DeliveryDir.zip" if exists or creates it.
  [string]$DeliveryZip = "",
  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

Set-Location $ProjectRoot

function Find-LatestDir([string]$Root, [string]$Filter) {
  if (-not (Test-Path $Root)) { return $null }
  return Get-ChildItem -Path $Root -Directory -Filter $Filter -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}

if ([string]::IsNullOrWhiteSpace($ProofDir)) {
  $p = Find-LatestDir -Root (Join-Path $ProjectRoot "proofs") -Filter "proof_*"
  if ($p) { $ProofDir = $p.FullName }
}
if ([string]::IsNullOrWhiteSpace($DeliveryDir)) {
  $d = Find-LatestDir -Root (Join-Path $ProjectRoot "dist") -Filter "delivery_*"
  if ($d) { $DeliveryDir = $d.FullName }
}

if ([string]::IsNullOrWhiteSpace($ProofDir) -or -not (Test-Path $ProofDir)) { throw "ProofDir not found: $ProofDir" }
if ([string]::IsNullOrWhiteSpace($DeliveryDir) -or -not (Test-Path $DeliveryDir)) { throw "DeliveryDir not found: $DeliveryDir" }

if ([string]::IsNullOrWhiteSpace($DeliveryZip)) {
  $candidate = $DeliveryDir + ".zip"
  $DeliveryZip = $candidate
}

Write-Host "== Finalize Delivery =="
Write-Host "ProjectRoot:  $ProjectRoot"
Write-Host "ProofDir:     $ProofDir"
Write-Host "DeliveryDir:  $DeliveryDir"
Write-Host "DeliveryZip:  $DeliveryZip"
Write-Host ""

# Collect screenshot-like files from proof dir root
$images = Get-ChildItem -Path $ProofDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' }

if (-not $images -or $images.Count -lt 1) {
  Write-Host "WARN: No image files found in ProofDir root. Place screenshots into ProofDir and rerun." -ForegroundColor Yellow
} else {
  Write-Host ("Found {0} image(s) in proof folder." -f $images.Count)
  $images | Select-Object -First 10 | ForEach-Object { Write-Host ("  - " + $_.Name) }
  if ($images.Count -gt 10) { Write-Host "  ... (more)" }
}

# Copy images into delivery proof mirror if present
$proofLeaf = Split-Path $ProofDir -Leaf
$deliveryProofDir = Join-Path $DeliveryDir ("proofs\" + $proofLeaf)
if (Test-Path $deliveryProofDir) {
  if ($images) {
    foreach ($img in $images) {
      Copy-Item -Force -Path $img.FullName -Destination (Join-Path $deliveryProofDir $img.Name)
    }
    Write-Host ""
    Write-Host "Copied screenshots into delivery proof folder:"
    Write-Host "  $deliveryProofDir"
  }
} else {
  Write-Host ""
  Write-Host "WARN: Delivery proof folder not found (expected):" -ForegroundColor Yellow
  Write-Host "  $deliveryProofDir"
  Write-Host "This is OK if you packaged without -IncludeLatestProof."
}

# Re-zip delivery folder
Write-Host ""
Write-Host "Rebuilding zip..."
if (Test-Path $DeliveryZip) { Remove-Item -Force $DeliveryZip }
Compress-Archive -Path (Join-Path $DeliveryDir "*") -DestinationPath $DeliveryZip -Force
Write-Host "Zip updated: $DeliveryZip"

if ($OpenFolder) {
  try { Invoke-Item $ProofDir } catch { }
  try { Invoke-Item $DeliveryDir } catch { }
}





