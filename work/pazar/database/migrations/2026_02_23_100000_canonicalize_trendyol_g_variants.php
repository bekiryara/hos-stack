<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Canonicalize Trendyol g-variant categories.
 *
 * Problem: For 475 Trendyol WCs, multiple active DB rows exist
 * (service-product-ty-c<wc> + service-product-g1-ty-c<wc> + g2/g3).
 * This causes duplicate menu nodes and non-deterministic category_id
 * binding during listing creation.
 *
 * Solution:
 * 1. Migrate any listing.category_id references from g-variant to g0 canonical
 * 2. Migrate any category_filter_schema rows from g-variant to g0
 * 3. Deactivate g-variant category rows
 * 4. Re-parent orphaned children of g-variants under g0
 *
 * Safety: ON DELETE RESTRICT on listings prevents data loss.
 * Rollback: down() re-activates all deactivated slugs.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('categories') || !Schema::hasTable('listings')) {
            return;
        }

        // Build mapping: g-variant slug => g0 canonical slug
        // Match both active and inactive g-variants (catalog:sync may have already deactivated them)
        $gVariants = DB::table('categories')
            ->whereRaw("slug ~ ?", ['^service-product-g[0-9]+-ty-c[0-9]+$'])
            ->whereIn('status', ['active', 'inactive'])
            ->get(['id', 'slug', 'parent_id']);

        if ($gVariants->isEmpty()) {
            return;
        }

        // Extract wc from slug and find g0 canonical
        $slugToId = DB::table('categories')
            ->where('status', 'active')
            ->pluck('id', 'slug');

        $migratedListings = 0;
        $migratedSchema = 0;
        $reparented = 0;
        $deactivated = 0;

        foreach ($gVariants as $gv) {
            preg_match('/^service-product-g\d+-ty-c(\d+)$/', $gv->slug, $m);
            if (!$m) continue;
            $wc = $m[1];
            $canonicalSlug = "service-product-ty-c{$wc}";
            $canonicalId = $slugToId[$canonicalSlug] ?? null;

            if (!$canonicalId) continue;
            $gvId = (int) $gv->id;
            if ($gvId === (int) $canonicalId) continue;

            // 1. Migrate listings
            $affected = DB::table('listings')
                ->where('category_id', $gvId)
                ->update([
                    'category_id' => $canonicalId,
                    'updated_at' => now(),
                ]);
            $migratedListings += $affected;

            // 2. Migrate filter schema (merge: skip if canonical already has the key)
            $existingKeys = DB::table('category_filter_schema')
                ->where('category_id', $canonicalId)
                ->pluck('attribute_key')
                ->all();

            $gvSchemaRows = DB::table('category_filter_schema')
                ->where('category_id', $gvId)
                ->get();

            foreach ($gvSchemaRows as $row) {
                if (in_array($row->attribute_key, $existingKeys, true)) {
                    DB::table('category_filter_schema')
                        ->where('id', $row->id)
                        ->delete();
                } else {
                    DB::table('category_filter_schema')
                        ->where('id', $row->id)
                        ->update([
                            'category_id' => $canonicalId,
                            'updated_at' => now(),
                        ]);
                    $migratedSchema++;
                }
            }

            // 3. Re-parent any active children under g0 canonical
            $children = DB::table('categories')
                ->where('parent_id', $gvId)
                ->where('status', 'active')
                ->pluck('id');

            if ($children->isNotEmpty()) {
                DB::table('categories')
                    ->whereIn('id', $children)
                    ->update([
                        'parent_id' => $canonicalId,
                        'updated_at' => now(),
                    ]);
                $reparented += $children->count();
            }

            // 4. Deactivate g-variant
            DB::table('categories')
                ->where('id', $gvId)
                ->update([
                    'status' => 'inactive',
                    'updated_at' => now(),
                ]);
            $deactivated++;
        }

        // Log summary (visible in migration output)
        if ($deactivated > 0) {
            DB::table('categories')->where('id', 0)->get(); // no-op, keeps transaction alive
        }

        \Illuminate\Support\Facades\Log::info("canonicalize_trendyol_g_variants: deactivated={$deactivated}, listings_migrated={$migratedListings}, schema_migrated={$migratedSchema}, reparented={$reparented}");
    }

    public function down(): void
    {
        // Re-activate all g-variant slugs
        DB::table('categories')
            ->whereRaw("slug ~ ?", ['^service-product-g[0-9]+-ty-c[0-9]+$'])
            ->where('status', 'inactive')
            ->update([
                'status' => 'active',
                'updated_at' => now(),
            ]);

        \Illuminate\Support\Facades\Log::info('canonicalize_trendyol_g_variants: rolled back (g-variants re-activated). NOTE: listing category_id references were NOT reverted.');
    }
};
