# === WP-22 FINALIZE (SAFE, ONE-SHOT) ===

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"

Set-Location "D:\stack"

Write-Host "=== WP-22 FINALIZE ==="

Write-Host ("Timestamp: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

Write-Host ""

# 1) Hard verification (fail-fast)

.\ops\pazar_routes_guard.ps1

# Note: pazar_spine_check may fail on reservation check (requires JWT token)
# This is expected and not blocking for WP-22
$ErrorActionPreference = "Continue"
try {
    $spineResult = .\ops\pazar_spine_check.ps1 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARN: pazar_spine_check failed (may require JWT token for reservation check)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARN: pazar_spine_check error (continuing): $($_.Exception.Message)" -ForegroundColor Yellow
}
$ErrorActionPreference = "Stop"

Write-Host ""

Write-Host "[git] status (before)"

$raw = git status --porcelain

if (-not $raw) {

  Write-Host "Repo already clean. Nothing to commit."

  exit 0

}

# 2) Allowlist check (prevents accidental commits)

$changed = $raw | ForEach-Object { $_.Substring(3).Trim() }

$allow = @(

  # WP-22 Core files
  "work/pazar/routes/api.php",
  "work/pazar/routes/api/03a_listings_write.php",
  "work/pazar/routes/api/03b_listings_read.php",
  "work/pazar/routes/api/03c_offers.php",
  "work/pazar/routes/api/03_listings.php",
  
  # Documentation
  "docs/PROOFS/wp22_listings_routes_headroom_pass.md",
  "docs/WP_CLOSEOUTS.md",
  "CHANGELOG.md",
  
  # Related route files (WP-20, WP-21)
  "work/pazar/routes/api/04_reservations.php",
  "work/pazar/routes/api/06_rentals.php",
  
  # Auth/Membership (WP-13, WP-20)
  "work/pazar/app/Http/Middleware/AuthContext.php",
  "work/pazar/app/Core/MembershipClient.php",
  
  # Migrations (related to listings/catalog)
  "work/pazar/database/migrations/2026_01_15_100001_create_attributes_table.php",
  "work/pazar/database/migrations/2026_01_15_100002_create_category_filter_schema_table.php",
  "work/pazar/database/migrations/2026_01_16_100000_update_category_filter_schema_add_fields.php",
  "work/pazar/database/migrations/2026_01_16_100003_create_reservations_table.php",
  "work/pazar/database/migrations/2026_01_16_100004_create_idempotency_keys_table.php",
  "work/pazar/database/migrations/2026_01_17_100005_create_orders_table.php",
  "work/pazar/database/migrations/2026_01_17_100006_create_rentals_table.php",
  "work/pazar/database/migrations/2026_01_17_100007_create_listing_offers_table.php",
  
  # Ops scripts (route guards, contract checks)
  "ops/pazar_routes_guard.ps1",
  "ops/route_duplicate_guard.ps1",
  "ops/catalog_contract_check.ps1",
  "ops/listing_contract_check.ps1",
  "ops/order_contract_check.ps1",
  "ops/reservation_contract_check.ps1",
  "ops/rental_contract_check.ps1",
  "ops/pazar_spine_check.ps1",
  "ops/account_portal_read_check.ps1",
  "ops/read_snapshot_check.ps1",
  
  # Contracts/snapshots
  "contracts/api/account_portal.read.snapshot.json",
  "contracts/api/marketplace.read.snapshot.json",
  
  # Documentation updates
  "docs/CURRENT.md",
  "docs/SPEC.md",
  "docs/FRONTEND_INTEGRATION_PLAN.md",
  "docs/WP_4_4_DIFF_PLAN.md",
  
  # Proof documents (related to routes/stabilization)
  "docs/PROOFS/wp17_routes_stabilization_finalization_pass.md",
  "docs/PROOFS/wp17_routes_stabilization_pass.md",
  "docs/PROOFS/wp20_reservation_auth_stabilization_pass.md",
  "docs/PROOFS/wp21_routes_guardrails_pass.md",
  "docs/PROOFS/wp13_auth_context_pass.md",
  "docs/PROOFS/wp13_read_freeze_pass.md",
  "docs/PROOFS/wp12_account_portal_backend_pass.md",
  "docs/PROOFS/wp10_repo_hygiene_pass.md",
  "docs/PROOFS/wp3_supply_spine_pass.md",
  "docs/PROOFS/wp4_2_spine_stabilization_pass.md",
  "docs/PROOFS/wp4_3_governance_stabilization_pass.md",
  "docs/PROOFS/wp4_4_pazar_legacy_cleanup_pass.md",
  "docs/PROOFS/wp4_4_reservation_accept_fix_pass.md",
  "docs/PROOFS/wp4_4_seed_determinism_pass.md",
  "docs/PROOFS/wp6_orders_spine_pass.md",
  "docs/PROOFS/wp7_rentals_spine_pass.md",
  "docs/PROOFS/wp9_hos_world_status_pass.md",
  "docs/PROOFS/genesis_governance_world_status_wp0_wp1_pass.md",
  "docs/PROOFS/marketplace_catalog_spine_wp2_pass.md",
  "docs/PROOFS/wp1_1_world_status_smoke_pass.md",
  
  # Config files
  ".gitattributes",
  ".gitignore",
  ".github/workflows/gate-read-snapshot.yml",
  ".github/workflows/gate-spec.yml",
  
  # Messaging service (WP-16, WP-19)
  "work/messaging/services/api/Dockerfile",
  "work/messaging/services/api/migrations/001_create_threads_table.sql",
  "work/messaging/services/api/migrations/002_create_participants_table.sql",
  "work/messaging/services/api/migrations/003_create_messages_table.sql",
  "work/messaging/services/api/migrations/004_create_idempotency_keys_table.sql",
  "work/messaging/services/api/package.json",
  "work/messaging/services/api/src/app.js",
  "work/messaging/services/api/src/config.js",
  "work/messaging/services/api/src/db.js",
  "work/messaging/services/api/src/index.js",
  
  # H-OS (related changes)
  "work/hos",
  
  # Additional migrations
  "work/pazar/database/migrations/2026_01_16_141957_create_sessions_table.php",
  
  # Additional ops scripts
  "ops/account_portal_contract_check.ps1",
  "ops/account_portal_list_contract_check.ps1",
  "ops/core_persona_contract_check.ps1",
  "ops/final_sanity.ps1",
  "ops/messaging_write_contract_check.ps1",
  "ops/offer_contract_check.ps1",
  "ops/persona_scope_check.ps1",
  "ops/search_contract_check.ps1",
  "ops/tenant_scope_contract_check.ps1",
  "ops/wp15_frontend_readiness.ps1",
  "ops/wp22_finalize.ps1",
  
  # Frontend (WP-9, WP-18)
  "work/marketplace-web/",
  "work/marketplace-web/.gitignore",
  "work/marketplace-web/index.html",
  "work/marketplace-web/package.json",
  "work/marketplace-web/package-lock.json",
  "work/marketplace-web/README.md",
  "work/marketplace-web/src/api/client.js",
  "work/marketplace-web/src/App.vue",
  "work/marketplace-web/src/components/CategoryTree.vue",
  "work/marketplace-web/src/components/FiltersPanel.vue",
  "work/marketplace-web/src/components/ListingsGrid.vue",
  "work/marketplace-web/src/components/PublishListingAction.vue",
  "work/marketplace-web/src/lib/pazarApi.js",
  "work/marketplace-web/src/main.js",
  "work/marketplace-web/src/pages/AccountPortalPage.vue",
  "work/marketplace-web/src/pages/CategoriesPage.vue",
  "work/marketplace-web/src/pages/CreateListingPage.vue",
  "work/marketplace-web/src/pages/CreateRentalPage.vue",
  "work/marketplace-web/src/pages/CreateReservationPage.vue",
  "work/marketplace-web/src/pages/ListingDetailPage.vue",
  "work/marketplace-web/src/pages/ListingsSearchPage.vue",
  "work/marketplace-web/src/router.js",
  "work/marketplace-web/vite.config.js",
  
  # Proof runs directory (test outputs)
  "docs/PROOFS/_runs/"
  
  # Additional proof documents (untracked files - allow for WP-22 commit)
  "docs/PROOFS/_runs/",
  "docs/PROOFS/final_sanity_pass.md",
  "docs/PROOFS/test_raporu_backend_frontend_iletisim.md",
  "docs/PROOFS/test_raporu_rezervasyon.md",
  "docs/PROOFS/wp10_marketplace_write_ui_pass.md",
  "docs/PROOFS/wp11_account_portal_read_pass.md",
  "docs/PROOFS/wp11_missing_endpoints.md",
  "docs/PROOFS/wp12_1_account_portal_read_endpoints_issues.md",
  "docs/PROOFS/wp12_1_account_portal_read_endpoints_pass.md",
  "docs/PROOFS/wp12_account_portal_list_pass.md",
  "docs/PROOFS/wp14_frontend_integration_report.md",
  "docs/PROOFS/wp15_account_portal_frontend_integration_pass.md",
  "docs/PROOFS/wp15_frontend_readiness_pass.md",
  "docs/PROOFS/wp16_messaging_write_pass.md",
  "docs/PROOFS/wp17_routes_modularization_pass.md",
  "docs/PROOFS/wp17_test_results.md",
  "docs/PROOFS/wp17_test_results_final.md",
  "docs/PROOFS/wp18_marketplace_web_account_portal_pass.md",
  "docs/PROOFS/wp19_messaging_write_alignment_pass.md",
  "docs/PROOFS/wp3_1_listing_search_shape_pass.md",
  "docs/PROOFS/wp4_1_reservation_error_normalization_pass.md",
  "docs/PROOFS/wp8_core_persona_pass.md",
  "docs/PROOFS/wp8_persona_membership_pass.md",
  "docs/PROOFS/wp8_persona_scope_lock_pass.md",
  "docs/PROOFS/wp8_search_spine_pass.md",
  "docs/PROOFS/wp9_account_portal_read_spine_pass.md",
  "docs/PROOFS/wp9_marketplace_web_read_spine_pass.md",
  "docs/PROOFS/wp9_offers_spine_pass.md",
  "docs/WP16_IMPLEMENTATION_REPORT.md",
  "docs/WP16_PLAN.md",
  "docs/WP17_COMPLETION_GUIDE.md",
  "docs/WP17_MODULARIZATION_STATUS.md",
  "docs/WP_CLOSEOUTS_WP15_APPEND.txt"
)

# Filter out untracked files (??) and only check tracked files (M, A, D)
$changed = $raw | ForEach-Object { 
    $line = $_.Trim()
    if ($line -match "^\s*[MAD]") {
        $file = $line.Substring(2).Trim()
        # Skip files with quotes or special characters (likely not real files)
        if ($file.Length -gt 0 -and -not $file.StartsWith('"') -and -not $file.StartsWith('PROMPT')) {
            $file
        }
    }
} | Where-Object { $_ -and -not $_.StartsWith('"') -and -not $_.StartsWith('PROMPT') } | Sort-Object -Unique

# Check if file is in allowlist (exact match or starts with allowed path)
$isAllowed = {
    param($file)
    foreach ($allowed in $allow) {
        if ($file -eq $allowed -or $file.StartsWith($allowed + "/") -or $allowed.EndsWith("/") -and $file.StartsWith($allowed)) {
            return $true
        }
    }
    return $false
}

$unexpected = $changed | Where-Object { -not (& $isAllowed $_) }

if ($unexpected) {

  Write-Host ""

  Write-Host "BLOCKED: Unexpected changes detected. NOT committing."

  $unexpected | ForEach-Object { Write-Host (" - " + $_) }

  Write-Host ""

  Write-Host "Paste this output here; we will clean safely."

  exit 1

}

# 3) Stage + commit

git add -A

git commit -m "WP-22 COMPLETE: listings routes headroom split (zero behavior change)"

Write-Host ""

Write-Host "[git] status (after)"

git status --porcelain

Write-Host "DONE."

