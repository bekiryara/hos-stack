# WP_CLOSEOUTS.md Verification Script
# Checks if deliverables mentioned in WP_CLOSEOUTS.md actually exist in the codebase

Write-Host "=== WP_CLOSEOUTS.md UYUM KONTROLU ===" -ForegroundColor Cyan
Write-Host ""

$errors = 0
$warnings = 0

# 1. Check proof files
Write-Host "[1] Proof dosyalari kontrol ediliyor..." -ForegroundColor Yellow
$proofFiles = Select-String -Path docs/WP_CLOSEOUTS.md -Pattern "docs/PROOFS/([^`\s`"]+)" | 
    ForEach-Object { 
        if ($_.Line -match "docs/PROOFS/([^`\s`"]+)") { 
            $matches[1] 
        } 
    } | Sort-Object -Unique

$missingProofs = @()
foreach ($proof in $proofFiles) {
    if (-not (Test-Path "docs/PROOFS/$proof")) {
        $missingProofs += $proof
        $warnings++
    }
}

if ($missingProofs.Count -eq 0) {
    Write-Host "  PASS: Tum proof dosyalari mevcut ($($proofFiles.Count) dosya)" -ForegroundColor Green
} else {
    Write-Host "  WARN: $($missingProofs.Count) proof dosyasi eksik:" -ForegroundColor Yellow
    $missingProofs | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
}

Write-Host ""

# 2. Check ops scripts
Write-Host "[2] Ops scriptleri kontrol ediliyor..." -ForegroundColor Yellow
$scripts = Select-String -Path docs/WP_CLOSEOUTS.md -Pattern "ops/([a-z_]+\.ps1)" | 
    ForEach-Object { 
        if ($_.Line -match "ops/([a-z_]+\.ps1)") { 
            $matches[1] 
        } 
    } | Sort-Object -Unique

$missingScripts = @()
foreach ($script in $scripts) {
    if (-not (Test-Path "ops/$script")) {
        $missingScripts += $script
        $errors++
    }
}

if ($missingScripts.Count -eq 0) {
    Write-Host "  PASS: Tum ops scriptleri mevcut ($($scripts.Count) script)" -ForegroundColor Green
} else {
    Write-Host "  FAIL: $($missingScripts.Count) ops scripti eksik:" -ForegroundColor Red
    $missingScripts | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}

Write-Host ""

# 3. Check route files (WP-17)
Write-Host "[3] Route dosyalari kontrol ediliyor (WP-17)..." -ForegroundColor Yellow
$routeFiles = @("00_ping.php", "00_metrics.php", "01_world_status.php", "02_catalog.php", "03a_listings_write.php", "03b_listings_read.php", "03c_offers.php", "04_reservations.php", "05_orders.php", "06_rentals.php", "account_portal.php", "messaging.php")
$missingRoutes = @()
foreach ($route in $routeFiles) {
    $found = Get-ChildItem -Path work/pazar/routes/api -Filter $route -ErrorAction SilentlyContinue
    if (-not $found) {
        $missingRoutes += $route
        $warnings++
    }
}

if ($missingRoutes.Count -eq 0) {
    Write-Host "  PASS: Tum route dosyalari mevcut" -ForegroundColor Green
} else {
    Write-Host "  WARN: $($missingRoutes.Count) route dosyasi eksik:" -ForegroundColor Yellow
    $missingRoutes | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
}

Write-Host ""

# 4. Check frontend files (WP-9, WP-32)
Write-Host "[4] Frontend dosyalari kontrol ediliyor..." -ForegroundColor Yellow
$frontendFiles = @(
    "work/marketplace-web/src/api/client.js",
    "work/marketplace-web/src/pages/AccountPortalPage.vue",
    "work/marketplace-web/vite.config.js"
)
$missingFrontend = @()
foreach ($file in $frontendFiles) {
    if (-not (Test-Path $file)) {
        $missingFrontend += $file
        $errors++
    }
}

if ($missingFrontend.Count -eq 0) {
    Write-Host "  PASS: Tum frontend dosyalari mevcut" -ForegroundColor Green
} else {
    Write-Host "  FAIL: $($missingFrontend.Count) frontend dosyasi eksik:" -ForegroundColor Red
    $missingFrontend | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}

Write-Host ""

# 5. Summary
Write-Host "=== OZET ===" -ForegroundColor Cyan
Write-Host "Proof dosyalari: $($proofFiles.Count - $missingProofs.Count)/$($proofFiles.Count) mevcut"
Write-Host "Ops scriptleri: $($scripts.Count - $missingScripts.Count)/$($scripts.Count) mevcut"
Write-Host "Route dosyalari: $($routeFiles.Count - $missingRoutes.Count)/$($routeFiles.Count) mevcut"
Write-Host "Frontend dosyalari: $($frontendFiles.Count - $missingFrontend.Count)/$($frontendFiles.Count) mevcut"
Write-Host ""

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "SONUC: TUM KONTROLLER PASS" -ForegroundColor Green
    exit 0
} elseif ($errors -eq 0) {
    Write-Host "SONUC: PASS (bazi uyarilar var)" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "SONUC: FAIL ($errors hata, $warnings uyari)" -ForegroundColor Red
    exit 1
}

