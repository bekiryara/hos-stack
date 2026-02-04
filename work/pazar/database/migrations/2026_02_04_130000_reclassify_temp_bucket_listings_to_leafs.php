<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * One-session bucket reclassify (data-only):
 * - Move 1 listing from `vehicle-ilan` bucket to `otomobil-ilan` (default/general vehicle leaf)
 * - Move 2 listings from `real-estate-ilan` bucket to `daire` (konut leaf)
 *
 * Deterministic rule:
 * - If listing content is not category-informative, pick the closest general leaf and move forward.
 * - Do not leave listings in buckets (buckets are temporary only).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('categories') || !Schema::hasTable('listings')) {
            return;
        }

        // Resolve target leaf IDs by slug (stable across environments).
        $otomobilIlanId = DB::table('categories')->where('slug', 'otomobil-ilan')->value('id');
        $daireId = DB::table('categories')->where('slug', 'daire')->value('id');
        if (!$otomobilIlanId || !$daireId) {
            return;
        }

        // Vehicle bucket listing (content not informative; default to otomobil-ilan).
        $vehicleListingId = 'ceb08872-886c-4d34-8cb3-b51345c9465b';
        DB::table('listings')
            ->where('id', $vehicleListingId)
            ->update([
                'category_id' => $otomobilIlanId,
                'updated_at' => now(),
            ]);

        // Real-estate bucket listings (title indicates apartment; map to daire).
        $realEstateListingIds = [
            'f61d6d07-9530-44f9-acbd-7bfbb38313f1',
            'f9c3e410-5514-431e-8e10-aa661865206b',
        ];
        DB::table('listings')
            ->whereIn('id', $realEstateListingIds)
            ->update([
                'category_id' => $daireId,
                'updated_at' => now(),
            ]);
    }

    public function down(): void
    {
        // Conservative rollback: do not move listings back into temporary buckets.
        return;
    }
};

