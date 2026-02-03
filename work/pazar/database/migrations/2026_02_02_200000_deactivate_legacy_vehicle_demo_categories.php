<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Legacy/demo cleanup:
        // - These nodes represented "rental" as a category branch (car-rental/boat-rental),
        //   which conflicts with the canonical policy-driven model (offer_variant=rental).
        // - We keep records in DB but remove them from active categories tree.
        $slugs = ['car', 'car-rental', 'boat', 'boat-rental'];

        DB::table('categories')
            ->whereIn('slug', $slugs)
            ->update([
                'status' => 'inactive',
                'updated_at' => now(),
            ]);

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
        // Safe rollback: re-activate demo nodes (only if they exist).
        $slugs = ['car', 'car-rental', 'boat', 'boat-rental'];

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

