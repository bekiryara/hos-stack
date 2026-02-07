# product_contract.ps1 - Marketplace Product Contract Gate (Doc Reality Lock)
# This gate ensures the canonical spine doc matches CURRENT repo reality.
#
# Reality lock:
# - No retired multiworld/world-prefixed listings routing described
# - Canonical endpoints include /api/v1/listings
#
# Exit codes: 0 PASS, 1 FAIL, 2 WARN

param(
    [string]$SpinePath = "docs\\PRODUCT\\PRODUCT_API_SPINE.md"
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") { . "${scriptDir}\_lib\ops_output.ps1"; Initialize-OpsOutput }
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") { . "${scriptDir}\_lib\ops_exit.ps1"; Initialize-OpsExit }

Write-Host "=== PRODUCT CONTRACT GATE (MARKETPLACE) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Spine doc: $SpinePath" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $SpinePath)) {
    Write-Fail "Spine doc not found: $SpinePath"
    Invoke-OpsExit 1
    return
}

try {
    $content = Get-Content $SpinePath -Raw -Encoding UTF8
} catch {
    Write-Fail "Could not read spine doc: $($_.Exception.Message)"
    Invoke-OpsExit 1
    return
}

$hasCanonical = ($content -match "/api/v1/listings")
$mentionsForbidden = ($content -match "/api/v1/(?!listings(?:/|$))[a-z0-9_-]+/listings")

if (-not $hasCanonical) {
    Write-Fail "Spine doc missing canonical endpoint: /api/v1/listings"
    Invoke-OpsExit 1
    return
}

if ($mentionsForbidden) {
    Write-Fail "Spine doc describes retired multiworld/world-prefixed listings routing."
    Invoke-OpsExit 1
    return
}

Write-Pass "Spine doc matches marketplace API shape (no multiworld paths)."
Invoke-OpsExit 0

