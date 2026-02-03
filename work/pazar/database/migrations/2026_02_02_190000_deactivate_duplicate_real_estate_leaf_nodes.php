<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Cleanup: remove duplicate leaf that conflicts with canonical "Devre Mülk" root branch.
        // Canonical decision: Devre Mülk is a top-level Emlak branch, not a Konut leaf.
        $slugs = ['devre-mulk-konut'];

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
        // Safe rollback: re-activate if it exists.
        $slugs = ['devre-mulk-konut'];

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

