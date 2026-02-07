# Secret Scan Script (WP-33, WP-41)
# Scans tracked files for common secret patterns
# ASCII-only output, exit 0 (PASS) or 1 (FAIL)

$ErrorActionPreference = "Stop"

Write-Host "=== SECRET SCAN ===" -ForegroundColor Cyan

$hits = @()
$binaryExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.svg', '.zip', '.tar', '.gz', '.pdf', '.exe', '.dll', '.so', '.dylib', '.woff', '.woff2', '.ttf', '.eot', '.otf', '.mp4', '.mp3', '.avi', '.mov', '.wmv', '.flv', '.webm')

# Get tracked files
$trackedFiles = git ls-files

foreach ($file in $trackedFiles) {
    # Skip binary files
    $ext = [System.IO.Path]::GetExtension($file).ToLower()
    if ($binaryExtensions -contains $ext) {
        continue
    }
    
    if (-not (Test-Path $file)) {
        continue
    }
    
    try {
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if ($null -eq $content) {
            continue
        }
        
        $lines = $content -split "`r?`n"
        $lineNum = 0
        
        foreach ($line in $lines) {
            $lineNum++
            
            # Skip allowlisted placeholders
            if ($line -match "(?i)(<token>|REDACTED|EXAMPLE|changeme|AKIAIOSFODNN7EXAMPLE|wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY)") {
                continue
            }
            
            # Pattern 1: Private keys (RSA, EC, etc.)
            if ($line -match "-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----") {
                $hits += "  $file`:$lineNum - Private key detected"
                continue
            }
            
            # Pattern 2: GitHub tokens (ghp_, gho_, ghu_, ghs_, ghr_)
            if ($line -match "(?i)(ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|ghu_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}|ghr_[a-zA-Z0-9]{36})") {
                $hits += "  $file`:$lineNum - GitHub token detected"
                continue
            }
            
            # Pattern 3: AWS keys (AKIA + 16 chars, then secret key)
            if ($line -match "(?i)AKIA[0-9A-Z]{16}") {
                if ($line -notmatch "AKIAIOSFODNN7EXAMPLE") {
                    $hits += "  $file`:$lineNum - AWS access key detected"
                    continue
                }
            }
            
            # Pattern 4: Slack tokens (xoxb-, xoxa-, xoxp-, xoxo-)
            if ($line -match "(?i)(xoxb-[0-9]{11}-[0-9]{11}-[a-zA-Z0-9]{24}|xoxa-[0-9]{11}-[0-9]{11}-[a-zA-Z0-9]{24}|xoxp-[0-9]{11}-[0-9]{11}-[a-zA-Z0-9]{24}|xoxo-[0-9]{11}-[0-9]{11}-[a-zA-Z0-9]{24})") {
                $hits += "  $file`:$lineNum - Slack token detected"
                continue
            }
            
            # Pattern 5: Google API keys (AIza...)
            if ($line -match "(?i)AIza[0-9A-Za-z_-]{35}") {
                $hits += "  $file`:$lineNum - Google API key detected"
                continue
            }
            
            # Pattern 6: Stripe live keys (sk_live_)
            if ($line -match "(?i)sk_live_[0-9a-zA-Z]{24,}") {
                $hits += "  $file`:$lineNum - Stripe live key detected"
                continue
            }
            
            # Pattern 7: Bearer tokens (long tokens, >40 chars)
            if ($line -match "(?i)Bearer\s+[a-zA-Z0-9_-]{40,}") {
                $token = $matches[0] -replace "Bearer\s+", ""
                # Skip if looks like placeholder
                if ($token -notmatch "(?i)(token|example|changeme|redacted)") {
                    $hits += "  $file`:$lineNum - Bearer token detected (long token)"
                    continue
                }
            }
            
            # Pattern 8: Database connection strings with passwords
            if ($line -match "(?i)(mysql://|postgres://|mongodb://|redis://).*[:@][^/]+@") {
                if ($line -notmatch "(?i)(password|pass)=[^,;\s]+") {
                    # Check if has actual password (not placeholder)
                    if ($line -notmatch "(?i)(changeme|example|password|pass)") {
                        $hits += "  $file`:$lineNum - Database connection string with potential password"
                        continue
                    }
                }
            }
        }
    } catch {
        # Skip files that can't be read (binary, etc.)
        continue
    }
}

if ($hits.Count -gt 0) {
    Write-Host "FAIL: Found $($hits.Count) potential secret(s):" -ForegroundColor Red
    foreach ($hit in $hits) {
        Write-Host $hit -ForegroundColor Yellow
    }
    exit 1
} else {
    Write-Host "PASS: 0 hits" -ForegroundColor Green
    exit 0
}

