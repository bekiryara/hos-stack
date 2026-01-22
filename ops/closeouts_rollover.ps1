# Closeouts Rollover (WP-46)
# Moves older WP sections from docs/WP_CLOSEOUTS.md to archive safely

param(
    [int]$Keep = 8,
    [string]$ActivePath = "docs/WP_CLOSEOUTS.md",
    [string]$ArchivePath = "docs/closeouts/WP_CLOSEOUTS_ARCHIVE_2026.md"
)

$ErrorActionPreference = "Stop"

Write-Host "=== CLOSEOUTS ROLLOVER (WP-46) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Validate inputs
if (-not (Test-Path $ActivePath)) {
    Write-Host "FAIL: Active file not found: $ActivePath" -ForegroundColor Red
    exit 1
}

# Ensure archive directory exists
$archiveDir = Split-Path $ArchivePath -Parent
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    Write-Host "Created archive directory: $archiveDir" -ForegroundColor Gray
}

# Read active file
$activeContent = Get-Content $ActivePath -Raw
$activeLines = Get-Content $ActivePath

# Find header block (everything before first "## WP-")
$headerEndPattern = '(?m)^##\s+WP-\d+:'
$firstWpMatch = [regex]::Match($activeContent, $headerEndPattern)
if (-not $firstWpMatch.Success) {
    Write-Host "FAIL: No WP sections found in active file" -ForegroundColor Red
    exit 1
}

$headerEndIndex = $firstWpMatch.Index
$headerBlock = $activeContent.Substring(0, $headerEndIndex)

# Split into WP sections
$wpSections = @()
$wpPattern = '(?ms)(^##\s+WP-\d+:.*?)(?=^##\s+WP-\d+:|$)'
$wpMatches = [regex]::Matches($activeContent, $wpPattern)

foreach ($match in $wpMatches) {
    $wpSections += $match.Groups[1].Value.Trim()
}

if ($wpSections.Count -eq 0) {
    Write-Host "FAIL: No WP sections extracted" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($wpSections.Count) WP sections" -ForegroundColor Gray

# Determine which sections to keep vs archive
$totalSections = $wpSections.Count
$sectionsToKeep = [Math]::Min($Keep, $totalSections)
$sectionsToArchive = $totalSections - $sectionsToKeep

if ($sectionsToArchive -eq 0) {
    Write-Host "PASS: No rollover needed (only $totalSections sections, keeping $Keep)" -ForegroundColor Green
    exit 0
}

Write-Host "  Keeping: last $sectionsToKeep sections" -ForegroundColor Gray
Write-Host "  Archiving: oldest $sectionsToArchive sections" -ForegroundColor Gray

# Extract WP numbers for reporting
$keptWps = @()
$archivedWps = @()

for ($i = 0; $i -lt $wpSections.Count; $i++) {
    $section = $wpSections[$i]
    $wpNumMatch = [regex]::Match($section, '^##\s+WP-(\d+):')
    if ($wpNumMatch.Success) {
        $wpNum = $wpNumMatch.Groups[1].Value
        if ($i -lt $sectionsToArchive) {
            $archivedWps += "WP-$wpNum"
        } else {
            $keptWps += "WP-$wpNum"
        }
    }
}

# Build new active content (header + kept sections)
$newActiveContent = $headerBlock
for ($i = $sectionsToArchive; $i -lt $wpSections.Count; $i++) {
    $newActiveContent += "`n`n" + $wpSections[$i]
}

# Read or create archive file
$archiveContent = ""
if (Test-Path $ArchivePath) {
    $archiveContent = Get-Content $ArchivePath -Raw
} else {
    $archiveContent = "# WP Closeouts Archive 2026`n`n**Date:** $(Get-Date -Format 'yyyy-MM-dd')`n**Note:** Archived closeouts moved from `docs/WP_CLOSEOUTS.md` to keep index small.`n`n---`n`n"
}

# Append archived sections (avoid duplicates)
$existingWpNums = [regex]::Matches($archiveContent, '^##\s+WP-(\d+):', [System.Text.RegularExpressions.RegexOptions]::Multiline) | ForEach-Object { $_.Groups[1].Value }

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$archiveContent += "`n`n## Rollover: $timestamp`n`n"

for ($i = 0; $i -lt $sectionsToArchive; $i++) {
    $section = $wpSections[$i]
    $wpNumMatch = [regex]::Match($section, '^##\s+WP-(\d+):')
    if ($wpNumMatch.Success) {
        $wpNum = $wpNumMatch.Groups[1].Value
        if ($existingWpNums -notcontains $wpNum) {
            $archiveContent += $section + "`n`n---`n`n"
        } else {
            Write-Host "  SKIP: WP-$wpNum already in archive" -ForegroundColor Yellow
        }
    }
}

# Write files
try {
    [System.IO.File]::WriteAllText((Resolve-Path $ActivePath).Path, $newActiveContent, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText((Resolve-Path $ArchivePath).Path, $archiveContent, [System.Text.Encoding]::UTF8)
} catch {
    Write-Host "FAIL: Error writing files: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Report results
$newActiveLines = ($newActiveContent -split "`r?`n").Count
$newArchiveLines = ($archiveContent -split "`r?`n").Count

Write-Host ""
Write-Host "Rollover complete:" -ForegroundColor Green
Write-Host "  Moved: $($archivedWps -join ', ')" -ForegroundColor Gray
Write-Host "  Kept: $($keptWps -join ', ')" -ForegroundColor Gray
Write-Host "  Active file: $newActiveLines lines (was $($activeLines.Count))" -ForegroundColor Gray
Write-Host "  Archive file: $newArchiveLines lines" -ForegroundColor Gray
Write-Host ""
Write-Host "=== CLOSEOUTS ROLLOVER: PASS ===" -ForegroundColor Green
exit 0

