<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            // MVP: reservation selects a single "package" (offer) for the listing.
            // Nullable for backward compatibility (existing reservations without a package).
            if (!Schema::hasColumn('reservations', 'offer_id')) {
                $table->uuid('offer_id')->nullable()->index();
            }

            // offer_id belongs to listing_offers; if an offer is removed, keep reservation but drop the reference.
            // Guard: listing_offers table may not exist in some environments; do not block migrations.
            if (Schema::hasTable('listing_offers')) {
                $table->foreign('offer_id')->references('id')->on('listing_offers')->nullOnDelete();
            }
        });
    }

    public function down(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            // Drop FK first, then column.
            try {
                $table->dropForeign(['offer_id']);
            } catch (\Throwable $e) {
                // Ignore if FK was never created (e.g. listing_offers missing).
            }
            if (Schema::hasColumn('reservations', 'offer_id')) {
                $table->dropColumn('offer_id');
            }
        });
    }
};

