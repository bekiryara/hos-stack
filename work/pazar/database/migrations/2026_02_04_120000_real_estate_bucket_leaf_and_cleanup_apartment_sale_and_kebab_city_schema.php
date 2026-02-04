<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 1 DATA CLEANUP (safe, data-only):
 * - Add a temporary "bucket" leaf under `real-estate`: `real-estate-ilan`
 * - Move any listings attached to inactive legacy category `apartment-sale` into that bucket
 * - Remove `price_min` attribute key from those moved listings (do NOT add to schema)
 * - Add `city` filter-schema row to `kebab` category (align existing data with schema)
 *
 * Goal: make audits reach 0/0/0 before enabling stricter backend enforcement.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('categories') || !Schema::hasTable('listings')) {
            return;
        }

        // 1) Ensure bucket leaf exists under real-estate root.
        $realEstateId = DB::table('categories')->where('slug', 'real-estate')->value('id');
        if ($realEstateId) {
            DB::table('categories')->updateOrInsert(
                ['slug' => 'real-estate-ilan'],
                [
                    'parent_id' => $realEstateId,
                    'name' => 'Emlak İlanı (Genel)',
                    'vertical' => 'real_estate',
                    'status' => 'active',
                    'sort_order' => 999,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }

        $bucketId = DB::table('categories')->where('slug', 'real-estate-ilan')->value('id');

        // 2) Move listings from legacy inactive category `apartment-sale` into the bucket leaf.
        $apartmentSaleId = DB::table('categories')->where('slug', 'apartment-sale')->value('id');
        if ($bucketId && $apartmentSaleId) {
            // Move category_id
            DB::table('listings')
                ->where('category_id', $apartmentSaleId)
                ->update([
                    'category_id' => $bucketId,
                    'updated_at' => now(),
                ]);

            // Remove price_min from attributes_json for moved rows (best-effort).
            // Keep null if becomes empty object.
            DB::statement("
                UPDATE listings
                SET attributes_json =
                    CASE
                        WHEN attributes_json IS NULL THEN NULL
                        ELSE
                            CASE
                                WHEN (attributes_json::jsonb - 'price_min') = '{}'::jsonb THEN NULL
                                ELSE (attributes_json::jsonb - 'price_min')::json
                            END
                    END,
                    updated_at = NOW()
                WHERE category_id = ?
            ", [$bucketId]);
        }

        // 3) Add kebab -> city schema row (keeps existing kebab demo listing aligned with schema-driven UI/search).
        if (Schema::hasTable('category_filter_schema')) {
            $kebabId = DB::table('categories')->where('slug', 'kebab')->value('id');
            $cityExists = DB::table('attributes')->where('key', 'city')->exists();
            if ($kebabId && $cityExists) {
                DB::table('category_filter_schema')->updateOrInsert(
                    [
                        'category_id' => $kebabId,
                        'attribute_key' => 'city',
                    ],
                    [
                        'ui_component' => 'text',
                        'required' => false,
                        'filter_mode' => 'exact',
                        'rules_json' => null,
                        'status' => 'active',
                        'sort_order' => 30,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]
                );
            }
        }
    }

    public function down(): void
    {
        // Conservative rollback:
        // - Do not move listings back to legacy inactive categories.
        // - Do not re-add removed attributes keys.
        // - Only remove the bucket leaf if unused; deactivate the kebab->city schema row if present.
        if (!Schema::hasTable('categories')) {
            return;
        }

        if (Schema::hasTable('category_filter_schema')) {
            $kebabId = DB::table('categories')->where('slug', 'kebab')->value('id');
            if ($kebabId) {
                DB::table('category_filter_schema')
                    ->where('category_id', $kebabId)
                    ->where('attribute_key', 'city')
                    ->update(['status' => 'inactive', 'updated_at' => now()]);
            }
        }

        if (!Schema::hasTable('listings')) {
            return;
        }

        $bucketId = DB::table('categories')->where('slug', 'real-estate-ilan')->value('id');
        if (!$bucketId) {
            return;
        }

        $inUse = DB::table('listings')->where('category_id', $bucketId)->exists();
        if ($inUse) {
            return;
        }

        DB::table('categories')->where('id', $bucketId)->delete();
    }
};

