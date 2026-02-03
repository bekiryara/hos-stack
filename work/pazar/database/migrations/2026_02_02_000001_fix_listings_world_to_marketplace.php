<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Safety migration: ensure listings.world is marketplace everywhere.
     *
     * This exists because some environments may have already applied older drift cleanups
     * that normalized listings.world to other values. We hard-normalize to the canonical
     * world key for Pazar listings.
     */
    public function up(): void
    {
        if (!Schema::hasTable('listings') || !Schema::hasColumn('listings', 'world')) {
            return;
        }

        DB::statement("
            UPDATE listings
            SET world = 'marketplace'
            WHERE world IS NULL OR world <> 'marketplace'
        ");
    }

    public function down(): void
    {
        // no-op (data migration)
    }
};

