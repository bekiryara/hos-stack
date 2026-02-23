<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Permanently delete inactive Trendyol g-variant category rows.
 *
 * Prerequisites (enforced by checks below):
 * - All g-variants must already be inactive (migration 2026_02_23_100000)
 * - No listings may reference any g-variant category_id (ON DELETE RESTRICT would block anyway)
 * - No active children may exist under g-variant rows
 *
 * This is the final cleanup step. After this, each Trendyol WC has exactly
 * one row in the categories table (the g0 canonical: service-product-ty-c<wc>).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('categories')) {
            return;
        }

        $gVariants = DB::table('categories')
            ->whereRaw("slug ~ ?", ['^service-product-g[0-9]+-ty-c[0-9]+$'])
            ->get(['id', 'slug', 'status']);

        if ($gVariants->isEmpty()) {
            return;
        }

        // Safety gate: all must be inactive
        $activeOnes = $gVariants->where('status', 'active');
        if ($activeOnes->isNotEmpty()) {
            $sample = $activeOnes->take(5)->pluck('slug')->implode(', ');
            throw new \RuntimeException(
                "Cannot delete: {$activeOnes->count()} g-variants are still active ({$sample}). Run canonicalization migration first."
            );
        }

        $ids = $gVariants->pluck('id')->all();

        // Safety gate: no listings reference these
        $listingCount = DB::table('listings')
            ->whereIn('category_id', $ids)
            ->count();
        if ($listingCount > 0) {
            throw new \RuntimeException(
                "Cannot delete: {$listingCount} listings still reference g-variant category IDs. Migrate them first."
            );
        }

        // Safety gate: no active children
        $childCount = DB::table('categories')
            ->whereIn('parent_id', $ids)
            ->where('status', 'active')
            ->count();
        if ($childCount > 0) {
            throw new \RuntimeException(
                "Cannot delete: {$childCount} active child categories still have g-variant parents. Re-parent them first."
            );
        }

        // CASCADE handles category_filter_schema automatically.
        // Delete inactive children first (g-variant children of g-variants).
        DB::table('categories')
            ->whereIn('parent_id', $ids)
            ->where('status', 'inactive')
            ->delete();

        // Delete the g-variant rows
        $deleted = DB::table('categories')
            ->whereIn('id', $ids)
            ->delete();

        \Illuminate\Support\Facades\Log::info("delete_inactive_trendyol_g_variants: {$deleted} rows permanently deleted.");
    }

    public function down(): void
    {
        // Physical deletes cannot be automatically rolled back.
        // Restore from SSOT: run catalog:sync after reverting categories.csv to the backup.
        \Illuminate\Support\Facades\Log::warning('delete_inactive_trendyol_g_variants: down() is a no-op. Restore from SSOT backup + catalog:sync if needed.');
    }
};
