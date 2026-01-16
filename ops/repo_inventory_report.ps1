# repo_inventory_report.ps1 - Repository inventory report

param(
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"

if (-not $Quiet) {
    Write-Host "=== Repository Inventory Report ===" -ForegroundColor Cyan
    Write-Host ""
}

# 1) Largest 30 files (MB)
if (-not $Quiet) {
    Write-Host "[1] Largest 30 Files (MB)" -ForegroundColor Yellow
    Write-Host ""
}
try {
    $largeFiles = Get-ChildItem -Path . -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.FullName -notmatch "\\.git\\" -and 
            $_.FullName -notmatch "\\vendor\\" -and
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\_archive\\daily\\"
        } |
        Select-Object FullName, @{Name="SizeMB";Expression={[math]::Round($_.Length / 1MB, 2)}} |
        Sort-Object SizeMB -Descending |
        Select-Object -First 30
    
    if ($largeFiles) {
        $largeFiles | Format-Table -AutoSize FullName, SizeMB
    } else {
        Write-Host "  No large files found" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 2) Files that shouldn't be in root
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[2] Files That Shouldn't Be in Root" -ForegroundColor Yellow
    Write-Host ""
}
$rootFiles = Get-ChildItem -Path . -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -notmatch "^(README|LICENSE|SECURITY|CHANGELOG|VERSION|\.gitignore|\.github|docker-compose)" -and
        $_.Extension -notmatch "^(\.md|\.yml|\.yaml|\.txt|\.ps1)$" -and
        $_.Name -notmatch "^\."
    }

$suspiciousRootFiles = @()
foreach ($file in $rootFiles) {
    $ext = $file.Extension.ToLower()
    if ($ext -match "\.(log|dump|sql|bak|tmp|zip|rar|tar|gz)$" -or 
        $file.Name -match "(dump|export|backup|log|temp|tmp)") {
        $suspiciousRootFiles += $file
    }
}

if ($suspiciousRootFiles.Count -gt 0) {
    Write-Host "  Found suspicious files in root:" -ForegroundColor Yellow
    $suspiciousRootFiles | ForEach-Object { 
        Write-Host "    $($_.Name) ($([math]::Round($_.Length / 1KB, 2)) KB)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  RECOMMENDATION: Move to _archive/ or _graveyard/" -ForegroundColor Cyan
} else {
    Write-Host "  No suspicious root files found" -ForegroundColor Green
}

# 3) Node modules / vendor in wrong places
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[3] Node Modules / Vendor in Wrong Places" -ForegroundColor Yellow
    Write-Host ""
}
$wrongVendors = @()
$vendorDirs = Get-ChildItem -Path . -Directory -Recurse -Filter "node_modules" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\vendor\\" -and $_.FullName -notmatch "\\.git\\" }
$vendorDirs += Get-ChildItem -Path . -Directory -Recurse -Filter "vendor" -ErrorAction SilentlyContinue |
    Where-Object { 
        $_.FullName -notmatch "\\work\\pazar\\vendor\\" -and 
        $_.FullName -notmatch "\\work\\hos\\vendor\\" -and
        $_.FullName -notmatch "\\.git\\"
    }

if ($vendorDirs.Count -gt 0) {
    Write-Host "  Found vendor/node_modules in unexpected locations:" -ForegroundColor Yellow
    $vendorDirs | ForEach-Object { 
        Write-Host "    $($_.FullName)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  RECOMMENDATION: Ensure .gitignore excludes these" -ForegroundColor Cyan
} else {
    Write-Host "  No unexpected vendor/node_modules found" -ForegroundColor Green
}

# 4) Summary
if (-not $Quiet) {
    Write-Host ""
    Write-Host "=== Report Complete ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NOTE: This is a REPORT ONLY. No files are moved automatically." -ForegroundColor Gray
    Write-Host "To move files, use:" -ForegroundColor Gray
    Write-Host "  - _archive/ for temporary dumps/exports" -ForegroundColor Gray
    Write-Host "  - _graveyard/ for deprecated/unused code" -ForegroundColor Gray
}
exit 0





