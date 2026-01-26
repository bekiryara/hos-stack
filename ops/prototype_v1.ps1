# WP-68C: Prototype / Demo Verification Entrypoint
# Purpose: Quick verification that prototype/demo environment is ready
# PowerShell 5.1 compatible, ASCII-only
# WP-69: Added optional demo seed check

param(
    [switch]$CheckDemoSeed
)

$ErrorActionPreference = "Stop"

Write-Host "=== PROTOTYPE / DEMO VERIFICATION (WP-68C) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Check 1: Frontend Smoke Test
Write-Host "[1] Running frontend smoke test..." -ForegroundColor Yellow
try {
    & .\ops\frontend_smoke.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: Frontend smoke test failed" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: Frontend smoke test" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Frontend smoke test error: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Check 2: World Status
Write-Host "[2] Checking world status..." -ForegroundColor Yellow
try {
    & .\ops\world_status_check.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: World status check failed" -ForegroundColor Red
        $hasFailures = $true
    } else {
        Write-Host "PASS: World status check" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: World status check error: $($_.Exception.Message)" -ForegroundColor Red
    $hasFailures = $true
}

Write-Host ""

# Check 3: Demo Seed (optional, non-destructive)
if ($CheckDemoSeed) {
    Write-Host "[3] Checking demo seed (non-destructive)..." -ForegroundColor Yellow
    try {
        $pazarBaseUrl = "http://localhost:8080"
        $categoriesResponse = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/categories" -TimeoutSec 5 -ErrorAction Stop
        
        # Find categories for demo listings
        function Find-CategoryBySlug {
            param([object]$Tree, [string]$Slug)
            foreach ($item in $Tree) {
                if ($item.slug -eq $Slug) { return $item }
                if ($item.children) {
                    $found = Find-CategoryBySlug -Tree $item.children -Slug $Slug
                    if ($found) { return $found }
                }
            }
            return $null
        }
        
        $weddingHall = Find-CategoryBySlug -Tree $categoriesResponse -Slug "wedding-hall"
        $carRental = Find-CategoryBySlug -Tree $categoriesResponse -Slug "car-rental"
        $restaurant = Find-CategoryBySlug -Tree $categoriesResponse -Slug "restaurant"
        
        $demoTitles = @("Bando Takimi", "Kiralik Tekne", "Adana Kebap")
        $foundCount = 0
        
        foreach ($cat in @($weddingHall, $carRental, $restaurant)) {
            if ($cat) {
                try {
                    $listings = Invoke-RestMethod -Uri "$pazarBaseUrl/api/v1/listings?category_id=$($cat.id)&status=published&limit=50" -TimeoutSec 5 -ErrorAction Stop
                    $listingsArray = if ($listings -is [Array]) { $listings } elseif ($listings.data) { $listings.data } elseif ($listings.items) { $listings.items } else { @($listings) }
                    foreach ($listing in $listingsArray) {
                        if ($demoTitles -contains $listing.title) {
                            $foundCount++
                            break
                        }
                    }
                } catch {
                    # Ignore individual category check failures
                }
            }
        }
        
        if ($foundCount -eq 0) {
            Write-Host "  INFO: Demo listings not found. Run: .\ops\demo_seed_v1.ps1" -ForegroundColor Yellow
        } else {
            Write-Host "PASS: Demo seed check ($foundCount demo listings found)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  WARN: Demo seed check failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($hasFailures) {
    Write-Host "=== PROTOTYPE VERIFICATION FAILED ===" -ForegroundColor Red
    Write-Host "Some checks failed. Review output above." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "=== PROTOTYPE VERIFICATION PASSED ===" -ForegroundColor Green
    Write-Host "Prototype/demo environment is ready." -ForegroundColor White
    if (-not $CheckDemoSeed) {
        Write-Host "  Tip: Use -CheckDemoSeed to verify demo listings exist" -ForegroundColor Gray
    }
    exit 0
}

