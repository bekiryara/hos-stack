<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Deactivate categories urun, yemek, hizmetler (were added by JSON seed; not in original PHP seeder).
 * Restores Services tree to original: Events, Food, Products, Accommodation only.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::table('categories')
            ->whereIn('slug', ['urun', 'yemek', 'hizmetler'])
            ->update(['status' => 'inactive', 'updated_at' => now()]);
    }

    public function down(): void
    {
        DB::table('categories')
            ->whereIn('slug', ['urun', 'yemek', 'hizmetler'])
            ->update(['status' => 'active', 'updated_at' => now()]);
    }
};
