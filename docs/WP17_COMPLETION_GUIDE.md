# WP-17 Modularization Completion Guide

## Current Status

✅ Created:
- `_helpers.php` - Helper functions
- `api/_meta.php` - Meta endpoints (ping, world/status)
- `api/catalog.php` - Catalog endpoints
- `api/search.php` - Search endpoint
- Refactored `api.php` - Main entry point with requires

⏳ Remaining modules to create (extract from original api.php backup):

1. **api/listings.php** - Extract lines 193-872 and 1032-1056 from original
2. **api/reservations.php** - Extract lines 1058-1351 and 1834-1857 from original
3. **api/account_portal.php** - Extract lines 1353-1705 from original
4. **api/orders.php** - Extract lines 1707-1832 from original
5. **api/rentals.php** - Extract lines 1859-2114 from original

## Extraction Instructions

Each module file should:
1. Start with `<?php`
2. Include necessary `use` statements for that module
3. Contain the exact route definitions from the original file
4. Preserve all comments and formatting

## Verification Steps

After all modules are created:
1. Run `php artisan route:list` to verify all routes are registered
2. Run `.\ops\pazar_spine_check.ps1` to verify contract compliance
3. Run `.\ops\route_duplicate_guard.ps1` to check for duplicates
4. Create proof document

## Rollback Command

If needed:
```powershell
git restore work/pazar/routes/api.php work/pazar/routes/_helpers.php work/pazar/routes/api/
```

