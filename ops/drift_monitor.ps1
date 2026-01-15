# drift_monitor.ps1 - Drift Detection Monitor
# Detects drift between audit runs
# PowerShell 5.1 compatible

param(
    [string]$CurrentPath = "",
    [string]$BaselinePath = ""
)

$ErrorActionPreference = "Continue"

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

# Ensure we're in repo root
$repoRoot = Split-Path -Parent $scriptDir
Push-Location $repoRoot

if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== DRIFT MONITOR ==="
} else {
    Write-Host "=== DRIFT MONITOR ===" -ForegroundColor Cyan
}
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Resolve current path (latest audit if not specified)
if ($CurrentPath -eq "") {
    $auditsDir = "_archive\audits"
    if (Test-Path $auditsDir) {
        $latestAudit = Get-ChildItem -Path $auditsDir -Directory -Filter "audit-*" | Sort-Object Name -Descending | Select-Object -First 1
        if ($latestAudit) {
            $CurrentPath = $latestAudit.FullName
        } else {
            if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
                Write-Fail "No audit folders found in $auditsDir"
            } else {
                Write-Host "[FAIL] No audit folders found in $auditsDir" -ForegroundColor Red
            }
            Pop-Location
            Invoke-OpsExit 1
            return 1
        }
    } else {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "Audits directory not found: $auditsDir"
        } else {
            Write-Host "[FAIL] Audits directory not found: $auditsDir" -ForegroundColor Red
        }
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
}

if (-not (Test-Path $CurrentPath)) {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "Current path not found: $CurrentPath"
    } else {
        Write-Host "[FAIL] Current path not found: $CurrentPath" -ForegroundColor Red
    }
    Pop-Location
    Invoke-OpsExit 1
    return 1
}

Write-Host "Current audit: $CurrentPath" -ForegroundColor Green

# Resolve baseline path (previous audit if not specified)
if ($BaselinePath -eq "") {
    $auditsDir = "_archive\audits"
    if (Test-Path $auditsDir) {
        $allAudits = Get-ChildItem -Path $auditsDir -Directory -Filter "audit-*" | Sort-Object Name -Descending
        $currentIndex = -1
        for ($i = 0; $i -lt $allAudits.Count; $i++) {
            if ($allAudits[$i].FullName -eq $CurrentPath) {
                $currentIndex = $i
                break
            }
        }
        if ($currentIndex -gt 0) {
            $BaselinePath = $allAudits[$currentIndex - 1].FullName
        } else {
            $BaselinePath = $null
        }
    } else {
        $BaselinePath = $null
    }
}

if ($null -eq $BaselinePath -or $BaselinePath -eq "" -or -not (Test-Path $BaselinePath)) {
    Write-Host "Baseline audit: (none - will generate report without comparison)" -ForegroundColor Yellow
    $hasBaseline = $false
} else {
    Write-Host "Baseline audit: $BaselinePath" -ForegroundColor Green
    $hasBaseline = $true
}

# Helper: Get file hash (SHA256)
function Get-FileHashSafe {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction Stop
        return @{
            hash = $hash.Hash
            size = (Get-Item $FilePath).Length
        }
    } catch {
        return $null
    }
}

# Helper: Get file hash list for directory
function Get-FileHashList {
    param(
        [string]$Directory,
        [string]$Pattern = "*.ps1"
    )
    
    if (-not (Test-Path $Directory)) {
        return @()
    }
    
    $files = Get-ChildItem -Path $Directory -Filter $Pattern -File -ErrorAction SilentlyContinue
    $hashList = @()
    
    foreach ($file in $files) {
        $hashInfo = Get-FileHashSafe -FilePath $file.FullName
        if ($hashInfo) {
            $hashList += [PSCustomObject]@{
                name = $file.Name
                hash = $hashInfo.hash
                size = $hashInfo.size
            }
        }
    }
    
    return $hashList
}

# Governance surfaces to hash
$governanceFiles = @(
    "ops\snapshots\routes.pazar.json",
    "ops\snapshots\schema.pazar.sql",
    "work\pazar\WORLD_REGISTRY.md",
    "work\pazar\config\worlds.php",
    "docs\RULES.md",
    "docs\ARCHITECTURE.md",
    "docs\REPO_LAYOUT.md",
    "CHANGELOG.md",
    "docs\product\PRODUCT_API_SPINE.md"
)

# Ops scripts to hash
$opsScripts = @(
    "ops\ops_status.ps1",
    "ops\self_audit.ps1",
    "ops\drift_monitor.ps1"
)

# Collect current hashes
Write-Host ""
Write-Host "=== Collecting Current Hashes ===" -ForegroundColor Cyan
$currentHashes = @{}

foreach ($file in $governanceFiles) {
    $fullPath = Join-Path $repoRoot $file
    $hashInfo = Get-FileHashSafe -FilePath $fullPath
    if ($hashInfo) {
        $currentHashes[$file] = $hashInfo
        Write-Host "  [OK] $file" -ForegroundColor Gray
    } else {
        Write-Host "  [SKIP] $file (not found)" -ForegroundColor Gray
    }
}

foreach ($script in $opsScripts) {
    $fullPath = Join-Path $repoRoot $script
    $hashInfo = Get-FileHashSafe -FilePath $fullPath
    if ($hashInfo) {
        $currentHashes[$script] = $hashInfo
        Write-Host "  [OK] $script" -ForegroundColor Gray
    } else {
        Write-Host "  [SKIP] $script (not found)" -ForegroundColor Gray
    }
}

# Collect baseline hashes (if available)
$baselineHashes = @{}
if ($hasBaseline) {
    Write-Host ""
    Write-Host "=== Loading Baseline Hashes ===" -ForegroundColor Cyan
    $baselineHashFile = Join-Path $BaselinePath "drift_hashes.json"
    if (Test-Path $baselineHashFile) {
        try {
            $baselineContent = Get-Content $baselineHashFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($key in $baselineContent.PSObject.Properties.Name) {
                $baselineHashes[$key] = $baselineContent.$key
            }
            Write-Host "  [OK] Loaded baseline hashes" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Failed to load baseline hashes: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [WARN] Baseline hash file not found: $baselineHashFile" -ForegroundColor Yellow
    }
}

# Generate drift_hashes.json
Write-Host ""
Write-Host "=== Writing Drift Hashes ===" -ForegroundColor Cyan
try {
    $hashObject = @{}
    foreach ($key in $currentHashes.Keys) {
        $hashObject[$key] = @{
            hash = $currentHashes[$key].hash
            size = $currentHashes[$key].size
        }
    }
    $hashJson = $hashObject | ConvertTo-Json -Depth 10
    $hashJson | Out-File -FilePath "${CurrentPath}\drift_hashes.json" -Encoding UTF8
    Write-Host "  [OK] drift_hashes.json" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Failed to write drift_hashes.json: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Generate drift_report.md
Write-Host ""
Write-Host "=== Generating Drift Report ===" -ForegroundColor Cyan
$reportLines = @()
$reportLines += "# Drift Report"
$reportLines += ""
$reportLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$reportLines += "**Current Audit:** $CurrentPath"
if ($hasBaseline) {
    $reportLines += "**Baseline Audit:** $BaselinePath"
} else {
    $reportLines += "**Baseline Audit:** (none - first run)"
}
$reportLines += ""

# Git diff summary
$reportLines += "## Git Status"
try {
    $gitStatus = & git status --porcelain 2>&1 | Out-String
    $gitStatusCount = ($gitStatus -split "`n" | Where-Object { $_.Trim() -ne "" }).Count
    if ($gitStatusCount -gt 0) {
        $reportLines += ""
        $reportLines += "**Repository is dirty:** $gitStatusCount uncommitted changes"
        $reportLines += ""
        $reportLines += '```'
        $reportLines += $gitStatus.Trim()
        $reportLines += '```'
    } else {
        $reportLines += ""
        $reportLines += "**Repository is clean** (no uncommitted changes)"
    }
} catch {
    $reportLines += ""
    $reportLines += "**Error checking git status:** $($_.Exception.Message)"
}
$reportLines += ""

# Governance surfaces comparison
$reportLines += "## Governance Surfaces"
$reportLines += ""

$hasDrift = $false

foreach ($file in $governanceFiles) {
    $reportLines += "### $file"
    $reportLines += ""
    
    if ($currentHashes.ContainsKey($file)) {
        $current = $currentHashes[$file]
        $reportLines += "- **Current:** hash=`$($current.hash.Substring(0, 16))...`, size=$($current.size) bytes"
        
        if ($baselineHashes.ContainsKey($file)) {
            $baseline = $baselineHashes[$file]
            $reportLines += "- **Baseline:** hash=`$($baseline.hash.Substring(0, 16))...`, size=$($baseline.size) bytes"
            
            if ($current.hash -ne $baseline.hash) {
                $reportLines += "- **Status:** ⚠️ **DRIFT DETECTED** (hash changed)"
                $hasDrift = $true
            } elseif ($current.size -ne $baseline.size) {
                $reportLines += "- **Status:** ⚠️ **DRIFT DETECTED** (size changed)"
                $hasDrift = $true
            } else {
                $reportLines += "- **Status:** ✅ No change"
            }
        } else {
            $reportLines += "- **Baseline:** (not found in baseline)"
            $reportLines += "- **Status:** ⚠️ **NEW FILE** (drift: file added)"
            $hasDrift = $true
        }
    } else {
        $reportLines += "- **Current:** (file not found)"
        if ($baselineHashes.ContainsKey($file)) {
            $reportLines += "- **Baseline:** hash=`$($baselineHashes[$file].hash.Substring(0, 16))...`, size=$($baselineHashes[$file].size) bytes"
            $reportLines += "- **Status:** ⚠️ **DRIFT DETECTED** (file removed)"
            $hasDrift = $true
        } else {
            $reportLines += "- **Baseline:** (not found)"
            $reportLines += "- **Status:** (file absent in both)"
        }
    }
    $reportLines += ""
}

# Ops scripts summary
$reportLines += "## Ops Scripts"
$reportLines += ""

$opsScriptCount = 0
foreach ($script in $opsScripts) {
    if ($currentHashes.ContainsKey($script)) {
        $opsScriptCount++
    }
}

$reportLines += "- **Ops scripts checked:** $opsScriptCount / $($opsScripts.Count)"
$reportLines += ""
$reportLines += "Individual script hashes are stored in `drift_hashes.json`."
$reportLines += ""

# Summary
$reportLines += "## Summary"
$reportLines += ""

if (-not $hasBaseline) {
    $reportLines += "⚠️ **No baseline available** - this is the first run. Use this audit as baseline for future comparisons."
    $reportLines += ""
} elseif ($hasDrift) {
    $reportLines += "⚠️ **DRIFT DETECTED** - Governance surfaces have changed since baseline."
    $reportLines += ""
    $reportLines += "Review the changes above and ensure they are intentional and documented."
    $reportLines += ""
} else {
    $reportLines += "✅ **No drift detected** - Governance surfaces match baseline."
    $reportLines += ""
}

try {
    $reportContent = $reportLines -join "`n"
    $reportContent | Out-File -FilePath "${CurrentPath}\drift_report.md" -Encoding UTF8
    Write-Host "  [OK] drift_report.md" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Failed to write drift_report.md: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Print summary
Write-Host ""
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== DRIFT MONITOR COMPLETE ==="
} else {
    Write-Host "=== DRIFT MONITOR COMPLETE ===" -ForegroundColor Cyan
}
Write-Host ""

if ($hasBaseline) {
    if ($hasDrift) {
        Write-Host "DRIFT_STATUS=DRIFT_DETECTED" -ForegroundColor Yellow
    } else {
        Write-Host "DRIFT_STATUS=NO_DRIFT" -ForegroundColor Green
    }
} else {
    Write-Host "DRIFT_STATUS=NO_BASELINE" -ForegroundColor Gray
}

Write-Host "DRIFT_REPORT=${CurrentPath}\drift_report.md" -ForegroundColor Yellow

Pop-Location
Invoke-OpsExit 0
return 0

