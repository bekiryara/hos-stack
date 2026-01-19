# Pazar Legacy Inventory

**Created:** 2026-01-19  
**Purpose:** Identify potentially legacy/unused files in `work/pazar/` for future cleanup decisions  
**Status:** INVENTORY ONLY (no deletions in this WP)

---

## Methodology

**Search Criteria:**
1. Files/folders with naming patterns: `*legacy*`, `*old*`, `*backup*`, `*tmp*`
2. Files not referenced by grep in codebase
3. Unused controllers, routes, or scripts

**Action Categories:**
- **KEEP:** File is actively used and should remain
- **QUARANTINE:** File is suspected legacy but needs verification before deletion
- **DELETE-LATER:** File is confirmed legacy and can be safely deleted in a future cleanup WP

---

## Inventory Results

### No Legacy Files Found

**Search Results:**
- No files matching `*legacy*` pattern
- No files matching `*old*` pattern
- No files matching `*backup*` pattern
- No files matching `*tmp*` pattern

### Route Files Analysis

**All route files are referenced and active:**

1. `routes/api/00_ping.php` - ✅ Referenced in `api.php` line 10
2. `routes/api/01_world_status.php` - ✅ Referenced in `api.php` line 11
3. `routes/api/02_catalog.php` - ✅ Referenced in `api.php` line 12
4. `routes/api/03a_listings_write.php` - ✅ Referenced in `api.php` line 13
5. `routes/api/03c_offers.php` - ✅ Referenced in `api.php` line 14
6. `routes/api/03b_listings_read.php` - ✅ Referenced in `api.php` line 15
7. `routes/api/04_reservations.php` - ✅ Referenced in `api.php` line 16
8. `routes/api/05_orders.php` - ✅ Referenced in `api.php` line 17
9. `routes/api/06_rentals.php` - ✅ Referenced in `api.php` line 18
10. `routes/api/messaging.php` - ✅ Referenced in `api.php` line 19 (placeholder, intentionally kept)
11. `routes/api/account_portal.php` - ✅ Referenced in `api.php` line 20

**Status:** All route files are actively referenced. No orphaned route files detected.

### Placeholder Files

**File:** `routes/api/messaging.php`

**Status:** KEEP (intentional placeholder)

**Reason:**
- File contains only comments explaining that messaging functionality is handled via MessagingClient integration
- File is kept for future messaging route additions if needed
- Referenced in `api.php` line 19
- Not legacy - intentionally minimal for future expansion

**Recommendation:** KEEP

---

## Directory Structure Analysis

### Active Directories

**All directories contain active code:**

- `app/Core/` - Active (MembershipClient.php)
- `app/Hos/` - Active (Contract, Remote clients)
- `app/Http/Middleware/` - Active (12 middleware files including TenantScope)
- `app/Messaging/` - Active (MessagingClient.php)
- `app/Models/` - Active (Listing.php, Product.php)
- `app/Worlds/` - Active (WorldRegistry.php)
- `routes/api/` - Active (all 11 route files referenced)
- `database/migrations/` - Active (all migrations are recent, 2026-01-*)
- `database/seeders/` - Active (CatalogSpineSeeder, ListingApiSpineSeeder)
- `tests/Feature/` - Active (test files present)

### No Suspicious Directories

- No `_old/` or `_legacy/` directories
- No `backup/` or `tmp/` directories
- No unreferenced controller directories

---

## Recommendations

### Immediate Actions

**None required.** All files in `work/pazar/` are actively used or intentionally kept placeholders.

### Future Monitoring

1. **Route Files:** Continue using `ops/pazar_routes_guard.ps1` to detect unreferenced route modules
2. **Migration Files:** Monitor for old migrations that may no longer be needed (currently all migrations are recent)
3. **Test Files:** Ensure test files remain referenced and active

### Cleanup Candidates

**None identified at this time.**

---

## Conclusion

**Status:** ✅ CLEAN

**Summary:**
- No legacy files found matching common naming patterns
- All route files are referenced and active
- No backup or temporary files detected
- All directories contain active code
- Placeholder files are intentional and documented

**Next Steps:**
- Continue monitoring via route guardrails script
- Re-run inventory if significant refactoring occurs
- Consider automated detection of unreferenced files in future WPs

---

**Inventory Date:** 2026-01-19  
**Inventory Method:** File system scan + route reference verification  
**Files Scanned:** All files in `work/pazar/` directory tree  
**Legacy Files Found:** 0

