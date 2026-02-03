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
            $table->uuid('offer_id')->nullable()->index();

            // offer_id belongs to listing_offers; if an offer is removed, keep reservation but drop the reference.
            $table->foreign('offer_id')->references('id')->on('listing_offers')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            // Drop FK first, then column.
            $table->dropForeign(['offer_id']);
            $table->dropColumn('offer_id');
        });
    }
};

