<?php

namespace Database\Seeders;

use App\Catalog\Import\CatalogImportService;
use Illuminate\Database\Seeder;

/**
 * Catalog Spine Seeder (manifest-backed):
 *
 * IMPORTANT: This seeder is NOT a data store.
 * Catalog data (categories/attributes/schema) MUST live in manifests:
 *   - default: work/pazar/catalog/manifests/
 *   - or external: env(CATALOG_MANIFESTS_PATH) mounted into container
 *
 * This seeder only delegates to the manifest importer.
 *
 * Canonical clean install flow (team single way):
 *   php artisan migrate:fresh --force
 *   php artisan catalog:import --dry-run
 *   php artisan catalog:import --apply
 *
 * Note: `catalog:import --apply` is "clean DB only" and transactional.
 */
final class CatalogSpineSeeder extends Seeder
{
    public function run(): void
    {
        $svc = CatalogImportService::fromDefaultPath();

        $m = $svc->loadManifests();
        $svc->validateOrFail($m);

        if (isset($this->command)) {
            $this->command->info('CatalogSpineSeeder: applying catalog manifests (clean DB only).');
        }

        $svc->apply($m);

        if (isset($this->command)) {
            $this->command->info('CatalogSpineSeeder: catalog import apply OK.');
        }

        // Demo listings (optional) MUST be seeded by a separate seeder.
        // Keep demo data clearly separated to avoid polluting manifests (SSOT).
        // Example (future):
        // if (env('SEED_DEMO_LISTINGS', '0') === '1') { $this->call(CatalogDemoSeeder::class); }
    }
}

