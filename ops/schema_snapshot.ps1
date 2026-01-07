# schema_snapshot.ps1 - DB Contract Gate (Schema Snapshot)
# Validates that database schema hasn't changed unexpectedly

$ErrorActionPreference = "Stop"
$failed = $false

Write-Host "=== DB Contract Gate (Schema Snapshot) ===" -ForegroundColor Cyan
Write-Host ""

# Paths
$snapshotPath = "ops\snapshots\schema.pazar.sql"
$diffPath = "ops\diffs\schema.diff"
$tempPath = "ops\diffs\schema.current.sql"

# Ensure directories exist
if (-not (Test-Path "ops\snapshots")) {
    Write-Host "❌ FAIL: ops\snapshots directory not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "ops\diffs")) {
    New-Item -ItemType Directory -Path "ops\diffs" -Force | Out-Null
}

# Check if snapshot exists
if (-not (Test-Path $snapshotPath)) {
    Write-Host "❌ FAIL: Schema snapshot not found: $snapshotPath" -ForegroundColor Red
    Write-Host "Run this locally to create initial snapshot:" -ForegroundColor Yellow
    Write-Host "  docker compose exec -T pazar-db pg_dump --schema-only --no-owner --no-privileges -U pazar pazar | Out-File -FilePath $snapshotPath -Encoding UTF8" -ForegroundColor Gray
    exit 1
}

Write-Host "[1] Checking Docker Compose status..." -ForegroundColor Yellow
$psOutput = docker compose ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ FAIL: docker compose ps failed" -ForegroundColor Red
    Write-Host $psOutput
    exit 1
}

# Check if pazar-db is running
$pazarDbRunning = $psOutput | Select-String "pazar-db.*Up"
if (-not $pazarDbRunning) {
    Write-Host "  Pazar-db not running, starting services..." -ForegroundColor Yellow
    docker compose up -d 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ FAIL: docker compose up failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Waiting for database to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Write-Host "  ✓ Services started" -ForegroundColor Green
} else {
    Write-Host "  ✓ Pazar-db is running" -ForegroundColor Green
}

Write-Host "`n[2] Exporting current schema..." -ForegroundColor Yellow
try {
    # Export schema using pg_dump (schema-only, no owner, no privileges)
    # PGPASSWORD environment variable for non-interactive password
    $env:PGPASSWORD = "pazar_password"
    $schemaExport = docker compose exec -T pazar-db pg_dump --schema-only --no-owner --no-privileges -U pazar pazar 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ FAIL: pg_dump failed" -ForegroundColor Red
        Write-Host $schemaExport
        exit 1
    }
    
    # Save raw export
    $schemaExport | Out-File -FilePath $tempPath -Encoding UTF8
    Write-Host "  ✓ Schema exported" -ForegroundColor Green
} catch {
    Write-Host "❌ FAIL: Error exporting schema: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Remove-Item env:PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Host "`n[3] Normalizing schema..." -ForegroundColor Yellow
try {
    # Normalize both snapshot and current schema
    # Remove timestamp comments, auto-generated comments, and blank lines
    function Normalize-Schema {
        param([string]$content)
        
        $lines = $content -split "`r?`n"
        $normalized = @()
        
        foreach ($line in $lines) {
            # Skip timestamp/comment lines
            if ($line -match "^--.*(Dumped|PostgreSQL|pg_dump|dump|on|at)\s+.*$") { continue }
            if ($line -match "^--.*\(PostgreSQL\)\s+\d+\.\d+$") { continue }
            if ($line -match "^--.*name:\s+\w+.*oid:") { continue }
            if ($line -match "^--.*Tablespace:") { continue }
            
            # Keep other lines (including -- comments that are not auto-generated)
            $normalized += $line
        }
        
        # Remove trailing blank lines
        while ($normalized.Count -gt 0 -and $normalized[-1] -match "^\s*$") {
            $normalized = $normalized[0..($normalized.Count - 2)]
        }
        
        return $normalized -join "`n"
    }
    
    $snapshotContent = Get-Content $snapshotPath -Raw -Encoding UTF8
    $currentContent = Get-Content $tempPath -Raw -Encoding UTF8
    
    $normalizedSnapshot = Normalize-Schema $snapshotContent
    $normalizedCurrent = Normalize-Schema $currentContent
    
    Write-Host "  ✓ Schema normalized" -ForegroundColor Green
    
    # Compare normalized schemas
    Write-Host "`n[4] Comparing schemas..." -ForegroundColor Yellow
    
    if ($normalizedSnapshot -eq $normalizedCurrent) {
        Write-Host "  ✓ No schema changes detected" -ForegroundColor Green
        
        # Clean up temp file
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force
        }
        if (Test-Path $diffPath) {
            Remove-Item $diffPath -Force
        }
        
        Write-Host "`n✅ DB CONTRACT PASSED" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "  ❌ Schema changes detected" -ForegroundColor Red
        
        # Generate diff report using line-by-line comparison
        $snapshotLines = ($normalizedSnapshot -split "`n") | Where-Object { $_ -notmatch "^\s*$" }
        $currentLines = ($normalizedCurrent -split "`n") | Where-Object { $_ -notmatch "^\s*$" }
        
        $diff = @()
        $diff += "# Database Schema Contract Diff"
        $diff += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $diff += ""
        $diff += "## Summary"
        $diff += "- Snapshot lines: $($snapshotLines.Count)"
        $diff += "- Current lines: $($currentLines.Count)"
        $diff += ""
        $diff += "## Diff Details"
        $diff += ""
        
        # Simple line-based diff (added/removed)
        $snapshotSet = [System.Collections.Generic.HashSet[string]]::new($snapshotLines)
        $currentSet = [System.Collections.Generic.HashSet[string]]::new($currentLines)
        
        $added = @()
        $removed = @()
        
        foreach ($line in $currentLines) {
            if (-not $snapshotSet.Contains($line)) {
                $added += $line
            }
        }
        
        foreach ($line in $snapshotLines) {
            if (-not $currentSet.Contains($line)) {
                $removed += $line
            }
        }
        
        if ($added.Count -gt 0) {
            $diff += "## Added Lines ($($added.Count))"
            $diff += ""
            foreach ($line in $added | Select-Object -First 50) {
                $diff += "+ $line"
            }
            if ($added.Count -gt 50) {
                $diff += "... and $($added.Count - 50) more lines"
            }
            $diff += ""
        }
        
        if ($removed.Count -gt 0) {
            $diff += "## Removed Lines ($($removed.Count))"
            $diff += ""
            foreach ($line in $removed | Select-Object -First 50) {
                $diff += "- $line"
            }
            if ($removed.Count -gt 50) {
                $diff += "... and $($removed.Count - 50) more lines"
            }
            $diff += ""
        }
        
        # Save diff
        $diff | Out-File -FilePath $diffPath -Encoding UTF8
        
        Write-Host "`n❌ DB CONTRACT FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "Schema changes detected:" -ForegroundColor Yellow
        if ($added.Count -gt 0) {
            Write-Host "  ➕ Added: $($added.Count) lines" -ForegroundColor Green
        }
        if ($removed.Count -gt 0) {
            Write-Host "  ➖ Removed: $($removed.Count) lines" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Diff saved to: $diffPath" -ForegroundColor Yellow
        Write-Host "Current schema saved to: $tempPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If these changes are intentional:" -ForegroundColor Cyan
        Write-Host "  1. Review the diff: cat $diffPath" -ForegroundColor Gray
        Write-Host "  2. Update snapshot: docker compose exec -T pazar-db pg_dump --schema-only --no-owner --no-privileges -U pazar pazar | Out-File -FilePath $snapshotPath -Encoding UTF8" -ForegroundColor Gray
        Write-Host "  3. Commit the updated snapshot" -ForegroundColor Gray
        
        exit 1
    }
} catch {
    Write-Host "❌ FAIL: Error comparing schemas: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

