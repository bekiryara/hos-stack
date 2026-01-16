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

$changelog = Get-Content "CHANGELOG.md" -Raw

# Extract [Unreleased] section
$unreleasedPattern = '##\s*\[Unreleased\](.*?)(?=##\s*\[|$)'
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
$releaseNote = @"
# Release Note: $Tag

**Date:** $tagDate

## Changes

$unreleasedContent

## Verification

Before deploying this release, verify:

\`\`\`powershell
# Checkout tag
git checkout $Tag

# Verify baseline
.\ops\baseline_status.ps1
.\ops\verify.ps1
.\ops\conformance.ps1
\`\`\`

## Contributors

$(if ($shortlog) { $shortlog } else { "See git log for contributors." })

## Related

- **Baseline definition**: See \`docs/CURRENT.md\`
- **Release plan**: See \`docs/RELEASES/PLAN.md\`
- **Proof docs**: See \`docs/PROOFS/\`

"@

# Write release note
Set-Content -Path $OutputFile -Value $releaseNote -Encoding UTF8

Write-Host "Release note generated: $OutputFile" -ForegroundColor Green
Write-Host ""
Write-Host "Preview:" -ForegroundColor Yellow
Write-Host "-------" -ForegroundColor Gray
Write-Host $releaseNote






