<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Safe data fix (no behavior change in code paths):
 * - Add a catch-all leaf under the `vehicle` root: `vehicle-ilan`
 * - Reassign any listings incorrectly attached to the `vehicle` root to this leaf.
 *
 * Motivation:
 * - UI create flow requires leaf selection, but DB may contain legacy/root-attached listings.
 * - This keeps root=3 contract intact while allowing a safe temporary bucket.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('categories') || !Schema::hasTable('listings')) {
            return;
        }

        $vehicleId = DB::table('categories')->where('slug', 'vehicle')->value('id');
        if (!$vehicleId) {
            return;
        }

        // Upsert catch-all leaf under vehicle root.
        DB::table('categories')->updateOrInsert(
            ['slug' => 'vehicle-ilan'],
            [
                'parent_id' => $vehicleId,
                'name' => 'Vasıta İlanı (Genel)',
                'vertical' => 'vehicle',
                'status' => 'active',
                'sort_order' => 999,
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        $catchAllId = DB::table('categories')->where('slug', 'vehicle-ilan')->value('id');
        if (!$catchAllId) {
            return;
        }

        // Move any listings attached to vehicle root to the leaf bucket.
        DB::table('listings')
            ->where('category_id', $vehicleId)
            ->update([
                'category_id' => $catchAllId,
                'updated_at' => now(),
            ]);
    }

    public function down(): void
    {
        // Intentionally conservative:
        // - Do NOT move listings back (could revert legitimate manual reclassification).
        // - Only delete the catch-all leaf if it is unused.
        if (!Schema::hasTable('categories') || !Schema::hasTable('listings')) {
            return;
        }

        $catchAllId = DB::table('categories')->where('slug', 'vehicle-ilan')->value('id');
        if (!$catchAllId) {
            return;
        }

        $inUse = DB::table('listings')->where('category_id', $catchAllId)->exists();
        if ($inUse) {
            return;
        }

        DB::table('categories')->where('id', $catchAllId)->delete();
    }
};

