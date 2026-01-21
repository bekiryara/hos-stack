# update_code_index.ps1
# Otomatik CODE_INDEX.md güncelleme scripti
# Önemli dosyaları tespit eder ve CODE_INDEX.md'yi günceller

param(
    [switch]$AutoCommit = $false,
    [switch]$AutoPush = $false,
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot | Split-Path -Parent
$codeIndexPath = Join-Path $repoRoot "docs\CODE_INDEX.md"

Write-Host "=== CODE_INDEX.md Otomatik Güncelleme ===" -ForegroundColor Cyan
Write-Host ""

# Önemli dosya pattern'leri
$importantPatterns = @(
    # Routes
    "**/routes/**/*.php",
    "**/routes/**/*.js",
    # Migrations
    "**/migrations/**/*.php",
    "**/migrations/**/*.sql",
    # Config
    "**/config/**/*.php",
    "**/config/**/*.js",
    "**/config/**/*.yaml",
    "**/config/**/*.yml",
    # Middleware
    "**/Middleware/**/*.php",
    "**/middleware/**/*.js",
    # Controllers
    "**/Controllers/**/*.php",
    "**/controllers/**/*.js",
    # Models
    "**/Models/**/*.php",
    # Components
    "**/components/**/*.vue",
    "**/components/**/*.js",
    # Pages
    "**/pages/**/*.vue",
    # Ops scripts
    "ops/**/*.ps1",
    # Bootstrap
    "**/bootstrap/**/*.php",
    "**/bootstrap/**/*.js"
)

# Git'te tracked olan dosyaları al
Write-Host "Git tracked dosyaları tespit ediliyor..." -ForegroundColor Yellow
$trackedFiles = git ls-files | Where-Object { $_ -notmatch '^docs/CODE_INDEX.md$' }

# Önemli dosyaları filtrele
$importantFiles = @()
foreach ($pattern in $importantPatterns) {
    $matches = $trackedFiles | Where-Object { $_ -like $pattern }
    $importantFiles += $matches
}
$importantFiles = $importantFiles | Sort-Object -Unique

Write-Host "Bulunan önemli dosya sayısı: $($importantFiles.Count)" -ForegroundColor Green

# CODE_INDEX.md'yi oku
$codeIndexContent = Get-Content $codeIndexPath -Raw -Encoding UTF8

# Mevcut dosyaları tespit et (raw URL'lerden)
$existingFiles = [regex]::Matches($codeIndexContent, 'https://raw\.githubusercontent\.com/bekiryara/hos-stack/main/([^\s\)]+)') | 
    ForEach-Object { $_.Groups[1].Value }

# Yeni dosyaları bul
$newFiles = $importantFiles | Where-Object { 
    $file = $_
    $found = $false
    foreach ($existing in $existingFiles) {
        if ($file -replace '\\', '/' -eq $existing) {
            $found = $true
            break
        }
    }
    -not $found
}

if ($newFiles.Count -eq 0) {
    Write-Host "Yeni dosya bulunamadı. CODE_INDEX.md güncel." -ForegroundColor Green
    exit 0
}

Write-Host "Yeni dosyalar bulundu: $($newFiles.Count)" -ForegroundColor Yellow
foreach ($file in $newFiles) {
    Write-Host "  - $file" -ForegroundColor White
}

if ($DryRun) {
    Write-Host "`n[DRY RUN] Dosyalar bulundu ama güncelleme yapılmadı." -ForegroundColor Cyan
    exit 0
}

# CODE_INDEX.md'yi güncelle
Write-Host "`nCODE_INDEX.md güncelleniyor..." -ForegroundColor Yellow

# Dosyaları kategorize et ve uygun bölümlere ekle
function Add-FileToSection {
    param($file, $sectionPattern, $insertAfter)
    
    $normalized = $file -replace '\\', '/'
    $fileName = Split-Path $file -Leaf
    $githubUrl = "https://github.com/bekiryara/hos-stack/blob/main/$normalized"
    $rawUrl = "https://raw.githubusercontent.com/bekiryara/hos-stack/main/$normalized"
    $entry = "- **$fileName**: [`$normalized`]($githubUrl) | [Raw]($rawUrl)"
    
    # Section'ı bul
    if ($codeIndexContent -match $sectionPattern) {
        $sectionEnd = $codeIndexContent.IndexOf("---", $matches[0].Index + $matches[0].Length)
        if ($sectionEnd -eq -1) { $sectionEnd = $codeIndexContent.Length }
        
        # Insert after pattern
        $insertPos = $codeIndexContent.IndexOf($insertAfter, $matches[0].Index)
        if ($insertPos -ne -1) {
            $insertPos = $codeIndexContent.IndexOf("`n", $insertPos) + 1
            $codeIndexContent = $codeIndexContent.Insert($insertPos, "$entry`n")
            return $true
        }
    }
    return $false
}

# Her dosyayı uygun bölüme ekle
$addedCount = 0
foreach ($file in $newFiles) {
    $normalized = $file -replace '\\', '/'
    $fileName = Split-Path $file -Leaf
    $githubUrl = "https://github.com/bekiryara/hos-stack/blob/main/$normalized"
    $rawUrl = "https://raw.githubusercontent.com/bekiryara/hos-stack/main/$normalized"
    $entry = "- **$fileName**: [`$normalized`]($githubUrl) | [Raw]($rawUrl)"
    
    $added = $false
    
    # Pazar Routes - Routes bölümüne ekle
    if ($normalized -like "work/pazar/routes/api/*.php" -and $codeIndexContent -match "## Pazar Service") {
        $routesSection = $codeIndexContent.IndexOf("### Routes", $matches[0].Index)
        if ($routesSection -ne -1) {
            # "Main Routes:" satırından sonra ekle
            $mainRoutesLine = $codeIndexContent.IndexOf("- **Main Routes:**", $routesSection)
            if ($mainRoutesLine -ne -1) {
                $insertPos = $codeIndexContent.IndexOf("`n", $mainRoutesLine) + 1
                $codeIndexContent = $codeIndexContent.Insert($insertPos, "$entry`n")
                $added = $true
            }
        }
    }
    # Pazar Migrations - Migrations bölümüne ekle
    elseif ($normalized -like "work/pazar/database/migrations/*.php" -and $codeIndexContent -match "### Database Migrations") {
        $migrationsSection = $codeIndexContent.IndexOf("### Database Migrations", $matches[0].Index)
        if ($migrationsSection -ne -1) {
            # Son migration'dan sonra ekle
            $lastMigration = $codeIndexContent.LastIndexOf("- **", $codeIndexContent.IndexOf("`n### Configuration", $migrationsSection))
            if ($lastMigration -ne -1) {
                $insertPos = $codeIndexContent.IndexOf("`n", $lastMigration) + 1
                $codeIndexContent = $codeIndexContent.Insert($insertPos, "$entry`n")
                $added = $true
            }
        }
    }
    # Ops Library - Ops bölümüne ekle
    elseif ($normalized -like "ops/_lib/*.ps1" -and $codeIndexContent -match "## Operations Scripts") {
        $opsSection = $codeIndexContent.IndexOf("## Operations Scripts", $matches[0].Index)
        # "Release & Bundle" bölümünden önce "Ops Library" bölümü oluştur veya ekle
        $releaseBundle = $codeIndexContent.IndexOf("### Release & Bundle", $opsSection)
        if ($releaseBundle -ne -1) {
            $insertPos = $releaseBundle
            # Ops Library bölümü var mı kontrol et
            $opsLibSection = $codeIndexContent.IndexOf("### Ops Library", $opsSection)
            if ($opsLibSection -eq -1 -or $opsLibSection -gt $releaseBundle) {
                # Yeni bölüm oluştur
                $codeIndexContent = $codeIndexContent.Insert($insertPos, "### Ops Library (`ops/_lib/`)`n`n")
                $insertPos = $codeIndexContent.IndexOf("`n### Release & Bundle", $insertPos)
            } else {
                $insertPos = $codeIndexContent.IndexOf("`n- **", $opsLibSection)
                while ($insertPos -ne -1) {
                    $nextLine = $codeIndexContent.IndexOf("`n", $insertPos + 1)
                    if ($nextLine -eq -1 -or $codeIndexContent.Substring($nextLine, 10) -match "`n### ") { break }
                    $insertPos = $nextLine
                }
            }
            $codeIndexContent = $codeIndexContent.Insert($insertPos + 1, "$entry`n")
            $added = $true
        }
    }
    # Diğer Ops scriptleri - Release & Bundle'dan önce ekle
    elseif ($normalized -like "ops/*.ps1" -and $codeIndexContent -match "## Operations Scripts") {
        $opsSection = $codeIndexContent.IndexOf("## Operations Scripts", $matches[0].Index)
        $releaseBundle = $codeIndexContent.IndexOf("### Release & Bundle", $opsSection)
        if ($releaseBundle -ne -1) {
            $insertPos = $codeIndexContent.LastIndexOf("`n- **", $releaseBundle)
            if ($insertPos -ne -1) {
                $insertPos = $codeIndexContent.IndexOf("`n", $insertPos) + 1
                $codeIndexContent = $codeIndexContent.Insert($insertPos, "$entry`n")
                $added = $true
            }
        }
    }
    
    if ($added) { $addedCount++ }
}

# "Last Updated" tarihini güncelle
$codeIndexContent = $codeIndexContent -replace '(\*\*Last Updated:\*\* )\d{4}-\d{2}-\d{2}', "`$1$(Get-Date -Format 'yyyy-MM-dd')"

# Dosyayı kaydet
Set-Content -Path $codeIndexPath -Value $codeIndexContent -Encoding UTF8 -NoNewline

Write-Host "CODE_INDEX.md güncellendi! ($addedCount dosya eklendi)" -ForegroundColor Green

Write-Host "CODE_INDEX.md güncellendi!" -ForegroundColor Green

if ($AutoCommit) {
    Write-Host "`nOtomatik commit yapılıyor..." -ForegroundColor Yellow
    git add $codeIndexPath
    git commit -m "Auto-update CODE_INDEX.md: Add $($newFiles.Count) new files"
    Write-Host "Commit yapıldı!" -ForegroundColor Green
    
    if ($AutoPush) {
        Write-Host "`nOtomatik push yapılıyor..." -ForegroundColor Yellow
        git push origin main
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Push başarılı! GitHub'a yayınlandı." -ForegroundColor Green
        } else {
            Write-Host "Push başarısız! Manuel kontrol gerekli." -ForegroundColor Red
        }
    } else {
        Write-Host "Push için: .\ops\update_code_index.ps1 -AutoCommit -AutoPush" -ForegroundColor Cyan
    }
}

Write-Host "`n=== TAMAMLANDI ===" -ForegroundColor Green

