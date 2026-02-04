<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Cleanup: remove temporary bucket leaf categories if unused.
 * - vehicle-ilan
 * - real-estate-ilan
 *
 * These were introduced for safe one-session reclassification and should not remain in the taxonomy.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('categories') || !Schema::hasTable('listings')) {
            return;
        }

        $slugs = ['vehicle-ilan', 'real-estate-ilan'];

        foreach ($slugs as $slug) {
            $id = DB::table('categories')->where('slug', $slug)->value('id');
            if (!$id) continue;

            $inUse = DB::table('listings')->where('category_id', $id)->exists();
            if ($inUse) continue;

            $hasChildren = DB::table('categories')->where('parent_id', $id)->where('status', 'active')->exists();
            if ($hasChildren) continue;

            if (Schema::hasTable('category_filter_schema')) {
                DB::table('category_filter_schema')->where('category_id', $id)->delete();
            }

            DB::table('categories')->where('id', $id)->delete();
        }
    }

    public function down(): void
    {
        // No rollback: categories are temporary and should not be reintroduced automatically.
        return;
    }
};

