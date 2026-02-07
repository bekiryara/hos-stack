# Repo Payload Audit (WP-53)
# Identifies large payload files in the last commit (HEAD)
# Exit code: 0 always (audit tool, non-blocking)

$ErrorActionPreference = "Stop"

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

# Helper: Print sanitized
function Write-Sanitized {
    param([string]$text, [string]$Color = "White")
    $sanitized = Sanitize-Ascii $text
    Write-Host $sanitized -ForegroundColor $Color
}

Write-Host "=== REPO PAYLOAD AUDIT (WP-53) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Get HEAD commit info
$headSha = git rev-parse HEAD
$headSubject = git log -1 --pretty=format:"%s" HEAD

Write-Sanitized "HEAD SHA: $headSha" "Cyan"
Write-Sanitized "Commit Subject: $headSubject" "Cyan"
Write-Host ""

# Show git show --stat
Write-Host "[1] Git Show --stat" -ForegroundColor Yellow
Write-Host ""
try {
    $statOutput = git show --stat HEAD 2>&1
    $statOutput | ForEach-Object { Write-Sanitized $_ "Gray" }
} catch {
    Write-Sanitized "ERROR: Failed to get git show --stat: $($_.Exception.Message)" "Red"
}
Write-Host ""

# Show git show --numstat (top 20 by added lines)
Write-Host "[2] Top 20 Files by Added Lines (git show --numstat)" -ForegroundColor Yellow
Write-Host ""
try {
    $numstatLines = git show --numstat HEAD 2>&1 | Where-Object { $_ -match '^\d+\s+\d+\s+' }
    $fileStats = @()
    
    foreach ($line in $numstatLines) {
        if ($line -match '^(\d+)\s+(\d+)\s+(.+)$') {
            $added = [int]$matches[1]
            $deleted = [int]$matches[2]
            $file = $matches[3].Trim()
            
            $fileStats += [PSCustomObject]@{
                Added = $added
                Deleted = $deleted
                File = $file
            }
        }
    }
    
    $topFiles = $fileStats | Sort-Object Added -Descending | Select-Object -First 20
    
    if ($topFiles.Count -gt 0) {
        Write-Host "  Lines Added | Lines Deleted | File" -ForegroundColor Gray
        Write-Host "  " + ("-" * 80) -ForegroundColor Gray
        foreach ($f in $topFiles) {
            Write-Sanitized "  $($f.Added.ToString().PadLeft(11)) | $($f.Deleted.ToString().PadLeft(13)) | $($f.File)" "White"
        }
    } else {
        Write-Host "  No file statistics available" -ForegroundColor Gray
    }
} catch {
    Write-Sanitized "ERROR: Failed to get git show --numstat: $($_.Exception.Message)" "Red"
}
Write-Host ""

# Identify suspicious files
Write-Host "[3] Suspicious Files (Heuristics)" -ForegroundColor Yellow
Write-Host ""

$suspiciousFiles = @()

# Heuristic 1: Files with >50,000 added lines OR size > 2MB tracked
try {
    $numstatLines = git show --numstat HEAD 2>&1 | Where-Object { $_ -match '^\d+\s+\d+\s+' }
    
    foreach ($line in $numstatLines) {
        if ($line -match '^(\d+)\s+(\d+)\s+(.+)$') {
            $added = [int]$matches[1]
            $file = $matches[3].Trim()
            
            # Check added lines
            if ($added -gt 50000) {
                $suspiciousFiles += [PSCustomObject]@{
                    File = $file
                    Reason = "Added lines: $added (>50,000)"
                    AddedLines = $added
                }
            }
        }
    }
    
    # Check file sizes in HEAD
    $trackedFiles = git ls-tree -r --name-only HEAD
    foreach ($file in $trackedFiles) {
        $blobSize = git cat-file -s "HEAD:$file" 2>$null
        if ($blobSize -and $blobSize -gt 2097152) {  # 2MB = 2097152 bytes
            $sizeMB = [math]::Round($blobSize / 1MB, 2)
            $suspiciousFiles += [PSCustomObject]@{
                File = $file
                Reason = "Size: $sizeMB MB (>2MB)"
                AddedLines = $null
            }
        }
    }
} catch {
    Write-Sanitized "ERROR: Failed to check file sizes: $($_.Exception.Message)" "Red"
}

# Heuristic 2: Forbidden path patterns
$forbiddenPatterns = @(
    'dist/',
    'build/',
    '\.next/',
    'vendor/',
    'node_modules/',
    'coverage/',
    'logs/',
    'tmp/',
    '_archive/'
)

try {
    $changedFiles = git diff-tree --no-commit-id --name-only -r HEAD
    foreach ($file in $changedFiles) {
        foreach ($pattern in $forbiddenPatterns) {
            if ($file -match $pattern) {
                $suspiciousFiles += [PSCustomObject]@{
                    File = $file
                    Reason = "Matches forbidden pattern: $pattern"
                    AddedLines = $null
                }
                break
            }
        }
    }
} catch {
    Write-Sanitized "ERROR: Failed to check forbidden patterns: $($_.Exception.Message)" "Red"
}

# Remove duplicates
$suspiciousFiles = $suspiciousFiles | Sort-Object File -Unique

if ($suspiciousFiles.Count -gt 0) {
    Write-Host "  Found $($suspiciousFiles.Count) suspicious file(s):" -ForegroundColor Yellow
    Write-Host ""
    foreach ($s in $suspiciousFiles) {
        Write-Sanitized "  File: $($s.File)" "Red"
        Write-Sanitized "    Reason: $($s.Reason)" "Yellow"
        if ($s.AddedLines) {
            Write-Sanitized "    Added Lines: $($s.AddedLines)" "Yellow"
        }
        Write-Host ""
    }
} else {
    Write-Host "  PASS: No suspicious files detected" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== REPO PAYLOAD AUDIT: COMPLETE ===" -ForegroundColor Cyan
exit 0
