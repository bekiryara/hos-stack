# release_note.ps1 - Generate release note from CHANGELOG

param(
    [Parameter(Mandatory=$true)]
    [string]$Tag,
    
    [string]$OutputFile = "RELEASE_NOTE.md"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Release Note Generator ===" -ForegroundColor Cyan
Write-Host "Tag: $Tag" -ForegroundColor Gray
Write-Host ""

# Get tag date
$tagDate = Get-Date -Format "yyyy-MM-dd"

# Read CHANGELOG.md
if (-not (Test-Path "CHANGELOG.md")) {
    Write-Host "FAIL: CHANGELOG.md not found" -ForegroundColor Red
    exit 1
}

# Read CHANGELOG with encoding tolerance (UTF-8 preferred; fallback to UTF-16 if needed)
$changelog = $null
try {
    $changelog = Get-Content "CHANGELOG.md" -Raw -Encoding UTF8
} catch {
    $changelog = $null
}
if (-not $changelog) {
    try {
        $changelog = Get-Content "CHANGELOG.md" -Raw -Encoding Unicode
    } catch {
        $changelog = ""
    }
}

# Extract [Unreleased] section
$unreleasedPattern = '(?ms)^##\s*\[Unreleased\]\s*(.*?)(?=^##\s*\[|\z)'
if ($changelog -match $unreleasedPattern) {
    $unreleasedContent = $matches[1].Trim()
} else {
    Write-Host "WARN: [Unreleased] section not found in CHANGELOG.md" -ForegroundColor Yellow
    $unreleasedContent = ""
}

# Get git shortlog for contributors
$shortlog = ""
try {
    # Get commits since last tag or last 30 commits if no tags
    $lastTag = git describe --tags --abbrev=0 2>$null
    if ($lastTag) {
        $shortlog = git shortlog "$lastTag..HEAD" 2>&1
    } else {
        $shortlog = git shortlog -n 30 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        $shortlog = ""
    }
} catch {
    $shortlog = ""
}

# Generate release note
$contributorsText = if ($shortlog) { $shortlog } else { "See git log for contributors." }

# NOTE: Use a single-quoted here-string + -f to avoid PowerShell backtick escaping
$releaseNoteTemplate = @'
# Release Note: {0}

**Date:** {1}

## Changes

{2}

## Verification

Before deploying this release, verify:

```powershell
# Checkout tag
git checkout {0}

# Verify baseline
.\ops\baseline_status.ps1
.\ops\verify.ps1
.\ops\conformance.ps1
```

## Contributors

{3}

## Related

- **Baseline definition**: See `docs/CURRENT.md`
- **Release plan**: See `docs/RELEASES/PLAN.md`
- **Proof docs**: See `docs/PROOFS/`

'@

$releaseNote = $releaseNoteTemplate -f $Tag, $tagDate, $unreleasedContent, $contributorsText

# Write release note
Set-Content -Path $OutputFile -Value $releaseNote -Encoding UTF8

Write-Host "Release note generated: $OutputFile" -ForegroundColor Green
Write-Host ""
Write-Host "Preview:" -ForegroundColor Yellow
Write-Host "-------" -ForegroundColor Gray
Write-Host $releaseNote






