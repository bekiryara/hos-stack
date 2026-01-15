# conformance.ps1 - Architecture Conformance Gate
# Windows-compatible PowerShell script for CI/CD

$ErrorActionPreference = "Stop"

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
if (Test-Path "${scriptDir}\_lib\worlds_config.ps1") {
    . "${scriptDir}\_lib\worlds_config.ps1"
}

$failed = $false
$failures = @()

# Helper: Write-Fail with check prefix (ASCII-only)
function Write-FailCheck {
    param([string]$Check, [string]$Message, [string[]]$Files = @())
    $script:failed = $true
    $script:failures += @{
        Check = $Check
        Message = $Message
        Files = $Files
    }
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "[$Check] $Message"
    } else {
        Write-Host "[FAIL] [$Check] $Message" -ForegroundColor Red
    }
    if ($Files.Count -gt 0) {
        foreach ($file in $Files) {
            Write-Host "  -> $file" -ForegroundColor Yellow
        }
    }
}

# Helper: Write-Pass with check prefix (ASCII-only)
function Write-PassCheck {
    param([string]$Check, [string]$Message = "")
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        $msg = "[$Check] $Check"
        if ($Message) {
            $msg += " - $Message"
        }
        Write-Pass $msg
    } else {
        Write-Host "[PASS] [$Check] $Check" -ForegroundColor Green
        if ($Message) {
            Write-Host "  $Message" -ForegroundColor Gray
        }
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
        Write-FailCheck "A" "WORLD_REGISTRY.md not found" @($registryPath)
        Write-Host "  Remediation: Create work/pazar/WORLD_REGISTRY.md with enabled/disabled world lists" -ForegroundColor Yellow
    } elseif (-not (Test-Path $configPath)) {
        Write-FailCheck "A" "config/worlds.php not found" @($configPath)
        Write-Host "  Remediation: Create work/pazar/config/worlds.php with enabled/disabled arrays" -ForegroundColor Yellow
    } else {
        # Parse WORLD_REGISTRY.md for enabled/disabled worlds
        # Only parse lines between "### Enabled Worlds" and "### Disabled Worlds" (or EOF)
        $registryContent = Get-Content $registryPath -Raw -ErrorAction Stop
        if ($null -eq $registryContent -or $registryContent.Length -eq 0) {
            Write-FailCheck "A" "WORLD_REGISTRY.md is empty or unreadable" @($registryPath)
        } else {
            $registryEnabled = @()
            $registryDisabled = @()
            
            # Split by "### Enabled Worlds" marker
            $parts = $registryContent -split "### Enabled Worlds"
            if ($parts.Count -gt 1) {
                $enabledSection = $parts[1]
                # Extract only until "### Disabled Worlds" marker
                if ($enabledSection -match '^(.*?)(?:### Disabled Worlds|$)') {
                    $enabledContent = $matches[1]
                    # Extract bullet lines: "- <world_key>"
                    $enabledLines = $enabledContent -split "`n" | Where-Object { $_ -match '^\s*-\s+([a-z0-9_]+)\s*$' }
                    if ($null -ne $enabledLines) {
                        foreach ($line in $enabledLines) {
                            if ($line -match '^\s*-\s+([a-z0-9_]+)\s*$') {
                                $worldId = $matches[1].Trim()
                                if ($worldId) {
                                    $registryEnabled += $worldId
                                }
                            }
                        }
                    }
                }
            }
            $registryEnabled = if ($null -ne $registryEnabled) { $registryEnabled | Sort-Object } else { @() }
            
            # Split by "### Disabled Worlds" marker
            $parts = $registryContent -split "### Disabled Worlds"
            if ($parts.Count -gt 1) {
                $disabledSection = $parts[1]
                # Extract until EOF (no more sections after this)
                # Extract bullet lines: "- <world_key>"
                $disabledLines = $disabledSection -split "`n" | Where-Object { $_ -match '^\s*-\s+([a-z0-9_]+)\s*$' }
                if ($null -ne $disabledLines) {
                    foreach ($line in $disabledLines) {
                        if ($line -match '^\s*-\s+([a-z0-9_]+)\s*$') {
                            $worldId = $matches[1].Trim()
                            if ($worldId) {
                                $registryDisabled += $worldId
                            }
                        }
                    }
                }
            }
            $registryDisabled = if ($null -ne $registryDisabled) { $registryDisabled | Sort-Object } else { @() }
            
            # Parse config/worlds.php using canonical parser
            $worldsConfig = Get-WorldsConfig -WorldsConfigPath $configPath
            if ($null -eq $worldsConfig) {
                Write-FailCheck "A" "Failed to parse config/worlds.php (Get-WorldsConfig returned null)" @($configPath)
            } else {
                $configEnabled = if ($worldsConfig.Enabled) { $worldsConfig.Enabled } else { @() }
                $configDisabled = if ($worldsConfig.Disabled) { $worldsConfig.Disabled } else { @() }
        
                # Ensure arrays are not null (PS5.1-safe)
                if ($null -eq $registryEnabled) { $registryEnabled = @() }
                if ($null -eq $registryDisabled) { $registryDisabled = @() }
                if ($null -eq $configEnabled) { $configEnabled = @() }
                if ($null -eq $configDisabled) { $configDisabled = @() }
                
                # Compare enabled lists (PS5.1-safe Compare-Object, no HashSet)
                # Compare-Object requires non-null arrays, even if empty
                $enabledDiff = $null
                if ($registryEnabled.Count -gt 0 -or $configEnabled.Count -gt 0) {
                    $enabledDiff = Compare-Object -ReferenceObject $registryEnabled -DifferenceObject $configEnabled -SyncWindow 0
                }
                
                # Compare disabled lists (PS5.1-safe Compare-Object, no HashSet)
                $disabledDiff = $null
                if ($registryDisabled.Count -gt 0 -or $configDisabled.Count -gt 0) {
                    $disabledDiff = Compare-Object -ReferenceObject $registryDisabled -DifferenceObject $configDisabled -SyncWindow 0
                }
                
                # Check for differences (PS5.1-safe Compare-Object)
                $enabledOnlyInRegistry = @()
                $enabledOnlyInConfig = @()
                if ($null -ne $enabledDiff) {
                    foreach ($diff in $enabledDiff) {
                        if ($diff.SideIndicator -eq "<=") {
                            $enabledOnlyInRegistry += $diff.InputObject
                        } elseif ($diff.SideIndicator -eq "=>") {
                            $enabledOnlyInConfig += $diff.InputObject
                        }
                    }
                }
                
                $disabledOnlyInRegistry = @()
                $disabledOnlyInConfig = @()
                if ($null -ne $disabledDiff) {
                    foreach ($diff in $disabledDiff) {
                        if ($diff.SideIndicator -eq "<=") {
                            $disabledOnlyInRegistry += $diff.InputObject
                        } elseif ($diff.SideIndicator -eq "=>") {
                            $disabledOnlyInConfig += $diff.InputObject
                        }
                    }
                }
                
                if ($enabledOnlyInRegistry.Count -gt 0 -or $enabledOnlyInConfig.Count -gt 0 -or $disabledOnlyInRegistry.Count -gt 0 -or $disabledOnlyInConfig.Count -gt 0) {
                    $diffList = @()
                    if ($enabledOnlyInRegistry.Count -gt 0) {
                        $diffList += "Enabled in registry but not in config: $($enabledOnlyInRegistry -join ', ')"
                    }
                    if ($enabledOnlyInConfig.Count -gt 0) {
                        $diffList += "Enabled in config but not in registry: $($enabledOnlyInConfig -join ', ')"
                    }
                    if ($disabledOnlyInRegistry.Count -gt 0) {
                        $diffList += "Disabled in registry but not in config: $($disabledOnlyInRegistry -join ', ')"
                    }
                    if ($disabledOnlyInConfig.Count -gt 0) {
                        $diffList += "Disabled in config but not in registry: $($disabledOnlyInConfig -join ', ')"
                    }
                    Write-FailCheck "A" "World registry drift detected: $($diffList -join '; ')" @($registryPath, $configPath)
                } else {
                    Write-PassCheck "A" "World registry matches config (enabled: $($registryEnabled.Count), disabled: $($registryDisabled.Count))"
                }
            }
        }
    }
} catch {
    Write-FailCheck "A" "Error checking world registry: $($_.Exception.Message)" @($registryPath, $configPath)
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
        Write-FailCheck "B" "Forbidden artifacts found in root or tracked paths" $found
    } else {
        Write-PassCheck "B" "No forbidden artifacts (*.bak, *.tmp, *.orig, *.swp, *~)"
    }
} catch {
    Write-FailCheck "B" "Error checking forbidden artifacts: $($_.Exception.Message)"
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
                if ($null -ne $controllerFiles -and $controllerFiles.Count -gt 0) {
                    $violations += "$controllerPath (disabled world has controller files)"
                }
            }
            
            # Check for route files
            if (Test-Path $routePath) {
                $violations += "$routePath (disabled world has route file)"
            }
        }
        
        if ($violations.Count -gt 0) {
            Write-FailCheck "C" "Disabled worlds have code (controllers/routes)" $violations
        } else {
            Write-PassCheck "C" "No code in disabled worlds ($($disabledWorlds.Count) disabled)"
        }
    } else {
        Write-FailCheck "C" "config/worlds.php not found" @($configPath)
    }
} catch {
    Write-FailCheck "C" "Error checking disabled-world policy: $($_.Exception.Message)"
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
    
    # Group by normalized path to detect actual duplicates (count > 1 per group)
    $allFiles = @()
    if ($null -ne $currentFiles) {
        $allFiles += $currentFiles | ForEach-Object { $_.FullName }
    }
    if ($null -ne $foundingFiles) {
        $allFiles += $foundingFiles | ForEach-Object { $_.FullName }
    }
    
    # Group by normalized filename (case-insensitive) to find duplicates
    $duplicateGroups = @{}
    foreach ($file in $allFiles) {
        $fileName = Split-Path -Leaf $file
        $normalized = $fileName.ToLower()
        if (-not $duplicateGroups.ContainsKey($normalized)) {
            $duplicateGroups[$normalized] = @()
        }
        $duplicateGroups[$normalized] += $file
    }
    
    # Only fail if any group has more than 1 unique path (actual duplicates)
    $actualDuplicates = @()
    foreach ($group in $duplicateGroups.GetEnumerator()) {
        $uniquePaths = $group.Value | Select-Object -Unique
        if ($uniquePaths.Count -gt 1) {
            $actualDuplicates += $group.Value
        }
    }
    
    if ($actualDuplicates.Count -gt 0) {
        Write-FailCheck "D" "Duplicate canonical docs found (groups with >1 unique path: $($actualDuplicates.Count) files)" $actualDuplicates
    } else {
        $uniqueCount = ($allFiles | Select-Object -Unique).Count
        Write-PassCheck "D" "No duplicate CURRENT*.md or FOUNDING_SPEC*.md files (checked $uniqueCount unique files)"
    }
} catch {
    Write-FailCheck "D" "Error checking canonical docs: $($_.Exception.Message)"
}

# E) Secrets safety
Write-Host "`n[E] Secrets safety check..." -ForegroundColor Yellow
try {
    $trackedFiles = git ls-files 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-FailCheck "E" "git ls-files failed: $trackedFiles"
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
            Write-FailCheck "E" "Secrets tracked in git" $secrets
        } else {
            Write-PassCheck "E" "No secrets tracked in git"
        }
    }
} catch {
    Write-FailCheck "E" "Error checking secrets: $($_.Exception.Message)"
}

# Summary
Write-Host ""
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== Summary ==="
} else {
    Write-Host "=== Summary ===" -ForegroundColor Cyan
}
if ($failed) {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "CONFORMANCE FAILED"
    } else {
        Write-Host "[FAIL] CONFORMANCE FAILED" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Failures:" -ForegroundColor Yellow
    foreach ($failure in $failures) {
        Write-Host "  [$($failure.Check)] $($failure.Message)" -ForegroundColor Red
        if ($failure.Files.Count -gt 0) {
            foreach ($file in $failure.Files) {
                Write-Host "    -> $file" -ForegroundColor Yellow
            }
        }
    }
    Invoke-OpsExit 1
    return
} else {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Pass "CONFORMANCE PASSED - All architecture rules validated"
    } else {
        Write-Host "[PASS] CONFORMANCE PASSED" -ForegroundColor Green
        Write-Host "All architecture rules validated" -ForegroundColor Gray
    }
    Invoke-OpsExit 0
    return
}

