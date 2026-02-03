<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Normalize legacy listings.world values to the allowlist
     * (marketplace).
     *
     * WHY:
     * - Historically, code wrote category "vertical" values (vehicle/service/...) into listings.world.
     * - listings.world must be the H-OS world key for Pazar listings: marketplace.
     *
     * This is a data migration (best-effort, non-destructive) to remove drift in existing databases.
     */
    public function up(): void
    {
        if (!Schema::hasTable('listings') || !Schema::hasColumn('listings', 'world')) {
            return;
        }

        // Pazar = Marketplace world. Force allowlist normalization.
        DB::statement("
            UPDATE listings
            SET world = 'marketplace'
            WHERE world IS NULL OR world <> 'marketplace'
        ");
    }

    /**
     * Non-reversible data migration.
     */
    public function down(): void
    {
        // no-op
    }
};

