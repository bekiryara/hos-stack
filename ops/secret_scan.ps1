#!/usr/bin/env pwsh
# SECRET SCAN (Local, Fast)
# Scans tracked git files for common secret patterns.
# Exits 1 if any finding exists; exits 0 otherwise.

$ErrorActionPreference = "Stop"

Write-Host "=== SECRET SCAN ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Get all tracked files
$trackedFiles = git ls-files 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get tracked files. Are you in a git repository?" -ForegroundColor Red
    exit 1
}

if (-not $trackedFiles) {
    Write-Host "WARN: No tracked files found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Scanning $($trackedFiles.Count) tracked files..." -ForegroundColor Gray
Write-Host ""

# Placeholder allowlist - lines containing these are NOT secrets
$placeholderPatterns = @(
    '<token>', '<JWT>', '<API_KEY>', '<JWT_SECRET>', '<APP_KEY>', '<MESSAGING_API_KEY>',
    'CHANGE-ME', 'example', 'dummy', 'test-token', 'placeholder', 'your_', '<your_',
    'Bearer <', 'Bearer\$', 'Bearer `\$'
)

# Environment variable reference patterns (ignore these - they're not secrets)
$envRefPatterns = @(
    "env\('", 'env\("', 'process\.env\.', '\$\{.*\}', '\$env:', 'getenv\('
)

# Secret patterns to search for (high-quality, real secrets only)
$patterns = @(
    # JWT-like token pattern (three parts separated by dots, each part at least 10 chars, total at least 50 chars)
    @{ Pattern = '\b[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b'; Name = 'JWT-like token' }
    # Laravel APP_KEY base64 format
    @{ Pattern = 'APP_KEY\s*=\s*base64:[A-Za-z0-9+/=]{20,}'; Name = 'Laravel APP_KEY (base64)' }
    # Hardcoded API key assignments (but not env refs, placeholders, or URLs)
    @{ Pattern = '(API_KEY|MESSAGING_API_KEY|HOS_API_KEY)\s*=\s*(?!<|CHANGE-ME|example|dummy|test-token|your_|process\.env|env\(|getenv|http://|https://)[^\s]{12,}'; Name = 'Hardcoded API key' }
    # Known token prefixes
    @{ Pattern = '\b(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}|AKIA[0-9A-Z]{16})\b'; Name = 'Known token prefix' }
    # AWS Access Key ID
    @{ Pattern = 'AKIA[0-9A-Z]{16}'; Name = 'AWS Access Key ID' }
    # Private keys (PEM format)
    @{ Pattern = '-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----'; Name = 'Private key (PEM)' }
    @{ Pattern = '-----BEGIN\s+EC\s+PRIVATE\s+KEY-----'; Name = 'EC Private key' }
    @{ Pattern = '-----BEGIN\s+DSA\s+PRIVATE\s+KEY-----'; Name = 'DSA Private key' }
    # Database URL with credentials (but not placeholders)
    @{ Pattern = 'DATABASE_URL\s*=\s*(postgresql|mysql)://[^<@\s]{3,}:[^<@\s]{3,}@'; Name = 'Database URL with credentials' }
    # Bearer token with actual JWT-like structure (not placeholders, each part at least 10 chars)
    @{ Pattern = 'Bearer\s+[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'; Name = 'Bearer token (JWT-like)' }
    # Authorization header with actual token (not placeholders, each part at least 10 chars)
    @{ Pattern = 'Authorization:\s*Bearer\s+[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'; Name = 'Authorization header (JWT-like)' }
)

$findings = @()
$fileCount = 0

foreach ($file in $trackedFiles) {
    $fileCount++
    if ($fileCount % 100 -eq 0) {
        Write-Host "  Scanned $fileCount files..." -ForegroundColor Gray
    }
    
    # Skip binary files and large files
    try {
        if (-not (Test-Path -LiteralPath $file -ErrorAction Stop)) {
            continue
        }
    } catch {
        # Skip files with invalid paths
        continue
    }
    
    $fileInfo = Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
    if (-not $fileInfo) {
        continue
    }
    
    # Skip files larger than 1MB
    if ($fileInfo.Length -gt 1MB) {
        continue
    }
    
    # Skip binary files (heuristic: check extension)
    $ext = [System.IO.Path]::GetExtension($file).ToLower()
    $binaryExts = @('.exe', '.dll', '.so', '.dylib', '.bin', '.jpg', '.jpeg', '.png', '.gif', '.pdf', '.zip', '.tar', '.gz')
    if ($binaryExts -contains $ext) {
        continue
    }
    
    try {
        $content = Get-Content -LiteralPath $file -Raw -ErrorAction Stop
        if (-not $content) {
            continue
        }
        
        $lineNumber = 0
        foreach ($line in ($content -split "`r?`n")) {
            $lineNumber++
            
            # Skip lines with placeholders (not real secrets)
            $isPlaceholder = $false
            foreach ($placeholder in $placeholderPatterns) {
                if ($line -match [regex]::Escape($placeholder)) {
                    $isPlaceholder = $true
                    break
                }
            }
            if ($isPlaceholder) {
                continue
            }
            
            # Skip lines with env variable references (not secrets)
            $isEnvRef = $false
            foreach ($envPattern in $envRefPatterns) {
                if ($line -match $envPattern) {
                    $isEnvRef = $true
                    break
                }
            }
            if ($isEnvRef) {
                continue
            }
            
            # Check for real secrets
            foreach ($patternInfo in $patterns) {
                $pattern = $patternInfo.Pattern
                $name = $patternInfo.Name
                
                if ($line -match $pattern) {
                    # Redact the secret (mask middle chars)
                    $matchedValue = $matches[0]
                    $redacted = if ($matchedValue.Length -gt 20) {
                        $matchedValue.Substring(0, 8) + "..." + $matchedValue.Substring($matchedValue.Length - 8)
                    } else {
                        $matchedValue.Substring(0, 4) + "..." + $matchedValue.Substring($matchedValue.Length - 4)
                    }
                    
                    $findings += @{
                        File = $file
                        Line = $lineNumber
                        Pattern = $name
                        Snippet = $redacted
                        FullLine = $line.Trim()
                    }
                }
            }
        }
    } catch {
        # Skip files that can't be read (permissions, binary, etc.)
        continue
    }
}

Write-Host "Scan complete. Scanned $fileCount files." -ForegroundColor Gray
Write-Host ""

if ($findings.Count -eq 0) {
    Write-Host "=== SECRET SCAN: PASS ===" -ForegroundColor Green
    Write-Host "No secrets detected in tracked files." -ForegroundColor Green
    exit 0
}

Write-Host "=== SECRET SCAN: FAIL ===" -ForegroundColor Red
Write-Host "Found $($findings.Count) potential secret(s):" -ForegroundColor Red
Write-Host ""

foreach ($finding in $findings) {
    Write-Host "File: $($finding.File)" -ForegroundColor Yellow
    Write-Host "  Line $($finding.Line): $($finding.Pattern)" -ForegroundColor Red
    Write-Host "  Snippet: $($finding.Snippet)" -ForegroundColor Gray
    Write-Host "  Full line: $($finding.FullLine)" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "REMEDIATION REQUIRED:" -ForegroundColor Red
Write-Host "1. Remove or rotate the secrets found above" -ForegroundColor Yellow
Write-Host "2. If secrets were committed to git history, consider:" -ForegroundColor Yellow
Write-Host "   - Using git filter-repo to remove from history" -ForegroundColor Yellow
Write-Host "   - Creating a fresh public mirror" -ForegroundColor Yellow
Write-Host "3. Ensure .env files are in .gitignore and not tracked" -ForegroundColor Yellow
Write-Host "4. Use environment variables or secret management for sensitive data" -ForegroundColor Yellow
Write-Host ""

exit 1

