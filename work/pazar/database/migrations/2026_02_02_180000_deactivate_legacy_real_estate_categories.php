<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Legacy model cleanup:
        // These nodes represented "2nd column" (Satılık/Kiralık) as categories.
        // New canonical model: 2nd column is policy-driven (/intent-schema), not a category branch.
        $slugs = ['for-sale', 'apartment-sale'];

        DB::table('categories')
            ->whereIn('slug', $slugs)
            ->update([
                'status' => 'inactive',
                'updated_at' => now(),
            ]);

        // Also deactivate any filter-schema rows tied to these categories to avoid confusion.
        $ids = DB::table('categories')->whereIn('slug', $slugs)->pluck('id')->all();
        if (!empty($ids)) {
            DB::table('category_filter_schema')
                ->whereIn('category_id', $ids)
                ->update([
                    'status' => 'inactive',
                    'updated_at' => now(),
                ]);
        }
    }

    public function down(): void
    {
        // Safe rollback: re-activate the categories (only if they exist).
        $slugs = ['for-sale', 'apartment-sale'];
        DB::table('categories')
            ->whereIn('slug', $slugs)
            ->update([
                'status' => 'active',
                'updated_at' => now(),
            ]);

        $ids = DB::table('categories')->whereIn('slug', $slugs)->pluck('id')->all();
        if (!empty($ids)) {
            DB::table('category_filter_schema')
                ->whereIn('category_id', $ids)
                ->update([
                    'status' => 'active',
                    'updated_at' => now(),
                ]);
        }
    }
};

