param(
  [switch]$BackupsTest,
  [switch]$Tmp,
  [switch]$All,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Add-Targets {
  param(
    [System.Collections.Generic.List[string]]$List,
    [string]$Path
  )
  if (-not $Path) { return }
  if (-not (Test-Path $Path)) { return }
  $List.Add($Path) | Out-Null
}

function Add-GlobTargets {
  param(
    [System.Collections.Generic.List[string]]$List,
    [string]$Glob
  )
  if (-not $Glob) { return }
  $items = @(Get-ChildItem -Path $Glob -ErrorAction SilentlyContinue)
  foreach ($i in $items) {
    $List.Add($i.FullName) | Out-Null
  }
}

if ($All) {
  $BackupsTest = $true
  $Tmp = $true
}

if (-not $BackupsTest -and -not $Tmp) {
  Write-Host "Nothing selected. Use -All, or one of: -BackupsTest, -Tmp" -ForegroundColor Yellow
  Write-Host "Dry-run by default. Use -Force to actually delete." -ForegroundColor DarkGray
  exit 0
}

$targets = New-Object "System.Collections.Generic.List[string]"

if ($BackupsTest) {
  # Only delete generated dumps under backups-test; keep README.md.
  Add-GlobTargets $targets "backups-test\\*.sql"
}

if ($Tmp) {
  # Intentionally conservative: only clean known repo-root temp artifacts.
  Add-GlobTargets $targets ".\\_tmp_*"
  # Common generated secret-bearing file (gitignored) for email alerting:
  Add-Targets $targets "services\\observability\\alertmanager\\alertmanager.generated.yml"
}

if ($targets.Count -eq 0) {
  Write-Host "No matching files found. Nothing to clean."
  exit 0
}

Write-Host "Clean targets:"
foreach ($t in $targets) { Write-Host " - $t" }

if (-not $Force) {
  Write-Host "Dry-run only. Re-run with -Force to delete the files above." -ForegroundColor Yellow
  exit 0
}

Write-Host "Deleting..." -ForegroundColor Yellow
foreach ($t in $targets) {
  try {
    Remove-Item -LiteralPath $t -Force -ErrorAction Stop
  } catch {
    Write-Host "WARN: failed to delete $t : $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

Write-Host "OK: cleanup done."


