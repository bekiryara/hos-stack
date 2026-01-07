# conformance.ps1 - Architecture Conformance Gate
# Windows-compatible PowerShell script for CI/CD

$ErrorActionPreference = "Stop"
$failed = $false
$failures = @()

function Write-Fail {
    param([string]$Check, [string]$Message, [string[]]$Files = @())
    $script:failed = $true
    $script:failures += @{
        Check = $Check
        Message = $Message
        Files = $Files
    }
    Write-Host "❌ FAIL: $Check - $Message" -ForegroundColor Red
    if ($Files.Count -gt 0) {
        foreach ($file in $Files) {
            Write-Host "  → $file" -ForegroundColor Yellow
        }
    }
}

function Write-Pass {
    param([string]$Check, [string]$Message = "")
    Write-Host "✅ PASS: $Check" -ForegroundColor Green
    if ($Message) {
        Write-Host "  $Message" -ForegroundColor Gray
    }
}

Write-Host "=== Architecture Conformance Gate ===" -ForegroundColor Cyan
Write-Host ""

# A) World registry drift
Write-Host "[A] World registry drift check..." -ForegroundColor Yellow
try {
    $registryPath = "work\pazar\WORLD_REGISTRY.md"
    $configPath = "work\pazar\config\worlds.php"
    
    if (-not (Test-Path $registryPath)) {
        Write-Fail "A" "WORLD_REGISTRY.md not found" @($registryPath)
    } elseif (-not (Test-Path $configPath)) {
        Write-Fail "A" "config/worlds.php not found" @($configPath)
    } else {
        # Parse WORLD_REGISTRY.md for world_id values
        $registryContent = Get-Content $registryPath -Raw
        $registryMatches = [regex]::Matches($registryContent, '\*\*world_id\*\*:\s*`([a-z0-9_]+)`')
        $registryIds = $registryMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object
        
        # Parse config/worlds.php for world keys
        $configContent = Get-Content $configPath -Raw
        $configMatches = [regex]::Matches($configContent, "'([a-z0-9_]+)'\s*=>\s*\[")
        $configIds = $configMatches | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne 'default' -and $_ -ne 'worlds' } | Sort-Object
        
        # Compare
        $registrySet = [System.Collections.Generic.HashSet[string]]::new($registryIds)
        $configSet = [System.Collections.Generic.HashSet[string]]::new($configIds)
        
        $missingInConfig = $registrySet | Where-Object { -not $configSet.Contains($_) }
        $extraInConfig = $configSet | Where-Object { -not $registrySet.Contains($_) }
        
        if ($missingInConfig.Count -gt 0 -or $extraInConfig.Count -gt 0) {
            $msg = "World registry mismatch"
            $details = @()
            if ($missingInConfig.Count -gt 0) {
                $details += "Missing in config: $($missingInConfig -join ', ')"
            }
            if ($extraInConfig.Count -gt 0) {
                $details += "Extra in config: $($extraInConfig -join ', ')"
            }
            Write-Fail "A" "$msg - $($details -join '; ')" @($registryPath, $configPath)
        } else {
            Write-Pass "A" "World registry matches config ($($registryIds.Count) worlds)"
        }
    }
} catch {
    Write-Fail "A" "Error checking world registry: $($_.Exception.Message)" @($registryPath, $configPath)
}

# B) Forbidden artifacts
Write-Host "`n[B] Forbidden artifacts check..." -ForegroundColor Yellow
try {
    $patterns = @("*.bak", "*.tmp", "*.orig", "*.swp", "*~")
    $found = @()
    
    foreach ($pattern in $patterns) {
        $files = Get-ChildItem -Path . -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue | 
            Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\_archive\*" -and $_.FullName -notlike "*\_backup\*" } |
            Select-Object -First 10
        if ($files) {
            $found += $files | ForEach-Object { $_.FullName }
        }
    }
    
    if ($found.Count -gt 0) {
        Write-Fail "B" "Forbidden artifacts found in root or tracked paths" $found
    } else {
        Write-Pass "B" "No forbidden artifacts (*.bak, *.tmp, *.orig, *.swp, *~)"
    }
} catch {
    Write-Fail "B" "Error checking forbidden artifacts: $($_.Exception.Message)"
}

# C) Disabled-world code policy
Write-Host "`n[C] Disabled-world code policy check..." -ForegroundColor Yellow
try {
    $configPath = "work\pazar\config\worlds.php"
    if (Test-Path $configPath) {
        $configContent = Get-Content $configPath -Raw
        
        # Find disabled worlds
        $disabledMatches = [regex]::Matches($configContent, "'([a-z0-9_]+)'\s*=>\s*\[[\s\S]*?'enabled'\s*=>\s*false")
        $disabledWorlds = $disabledMatches | ForEach-Object { $_.Groups[1].Value }
        
        $violations = @()
        foreach ($world in $disabledWorlds) {
            # Convert world_id to controller directory name (real_estate -> RealEstate, services -> Services, vehicles -> Vehicles)
            $worldDir = $world -replace '_', ''
            $worldDir = $worldDir.Substring(0,1).ToUpper() + $worldDir.Substring(1)
            
            $controllerPath = "work\pazar\app\Http\Controllers\World\$worldDir"
            $routePath = "work\pazar\routes\world_$world.php"
            
            # Check for controller files (excluding archived)
            if (Test-Path $controllerPath) {
                $controllerFiles = Get-ChildItem $controllerPath -Recurse -File -ErrorAction SilentlyContinue | 
                    Where-Object { $_.FullName -notlike "*\_archive\*" }
                if ($controllerFiles.Count -gt 0) {
                    $violations += "$controllerPath (disabled world has controller files)"
                }
            }
            
            # Check for route files
            if (Test-Path $routePath) {
                $violations += "$routePath (disabled world has route file)"
            }
        }
        
        if ($violations.Count -gt 0) {
            Write-Fail "C" "Disabled worlds have code (controllers/routes)" $violations
        } else {
            Write-Pass "C" "No code in disabled worlds ($($disabledWorlds.Count) disabled)"
        }
    } else {
        Write-Fail "C" "config/worlds.php not found" @($configPath)
    }
} catch {
    Write-Fail "C" "Error checking disabled-world policy: $($_.Exception.Message)"
}

# D) Canonical docs single-source
Write-Host "`n[D] Canonical docs single-source check..." -ForegroundColor Yellow
try {
    # Check for CURRENT*.md duplicates (excluding docs/CURRENT.md and _archive/_backup)
    $currentFiles = Get-ChildItem -Path . -Filter "CURRENT*.md" -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.FullName -notlike "*\.git\*" -and 
            $_.FullName -notlike "*\_archive\*" -and 
            $_.FullName -notlike "*\_backup\*" -and
            $_.FullName -ne (Resolve-Path "work\pazar\docs\CURRENT.md" -ErrorAction SilentlyContinue).Path -and
            $_.FullName -ne (Resolve-Path "work\pazar\docs\runbooks\CURRENT.md" -ErrorAction SilentlyContinue).Path
        }
    
    # Check for FOUNDING_SPEC*.md duplicates (excluding canonical ones)
    $foundingFiles = Get-ChildItem -Path . -Filter "FOUNDING_SPEC*.md" -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.FullName -notlike "*\.git\*" -and 
            $_.FullName -notlike "*\_archive\*" -and 
            $_.FullName -notlike "*\_backup\*" -and
            $_.FullName -notlike "*\work\pazar\docs\FOUNDING_SPEC.md" -and
            $_.FullName -notlike "*\work\hos\docs\pazar\FOUNDING_SPEC.md"
        }
    
    $duplicates = @()
    if ($currentFiles) {
        $duplicates += $currentFiles | ForEach-Object { $_.FullName }
    }
    if ($foundingFiles) {
        $duplicates += $foundingFiles | ForEach-Object { $_.FullName }
    }
    
    if ($duplicates.Count -gt 0) {
        Write-Fail "D" "Duplicate canonical docs found" $duplicates
    } else {
        Write-Pass "D" "No duplicate CURRENT*.md or FOUNDING_SPEC*.md files"
    }
} catch {
    Write-Fail "D" "Error checking canonical docs: $($_.Exception.Message)"
}

# E) Secrets safety
Write-Host "`n[E] Secrets safety check..." -ForegroundColor Yellow
try {
    $trackedFiles = git ls-files 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "E" "git ls-files failed: $trackedFiles"
    } else {
        $secrets = @()
        
        # Check for *.env files
        $envFiles = $trackedFiles | Where-Object { $_ -match '\.env$' -and $_ -notmatch '\.env\.example$' }
        if ($envFiles) {
            $secrets += $envFiles
        }
        
        # Check for secrets/*.txt
        $secretsFiles = $trackedFiles | Where-Object { $_ -match 'secrets[/\\].*\.txt$' }
        if ($secretsFiles) {
            $secrets += $secretsFiles
        }
        
        if ($secrets.Count -gt 0) {
            Write-Fail "E" "Secrets tracked in git" $secrets
        } else {
            Write-Pass "E" "No secrets tracked in git"
        }
    }
} catch {
    Write-Fail "E" "Error checking secrets: $($_.Exception.Message)"
}

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($failed) {
    Write-Host "❌ CONFORMANCE FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Failures:" -ForegroundColor Yellow
    foreach ($failure in $failures) {
        Write-Host "  [$($failure.Check)] $($failure.Message)" -ForegroundColor Red
        if ($failure.Files.Count -gt 0) {
            foreach ($file in $failure.Files) {
                Write-Host "    → $file" -ForegroundColor Yellow
            }
        }
    }
    exit 1
} else {
    Write-Host "✅ CONFORMANCE PASSED" -ForegroundColor Green
    Write-Host "All architecture rules validated" -ForegroundColor Gray
    exit 0
}

