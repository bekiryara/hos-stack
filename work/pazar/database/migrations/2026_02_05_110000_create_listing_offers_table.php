<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * WP-9 Offers/Pricing Spine (Marketplace)
 *
 * Creates `listing_offers` table for sellable packages/offers per listing.
 *
 * Notes:
 * - listing_offers may be introduced after reservations.offer_id (guarded migration).
 * - This migration also attempts to add the reservations.offer_id FK once the table exists.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('listing_offers')) {
            Schema::create('listing_offers', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('listing_id');
                $table->uuid('provider_tenant_id');

                // Code unique within a listing (e.g. "basic-package")
                $table->string('code', 100);
                $table->string('name', 255);

                // Pricing
                $table->bigInteger('price_amount'); // >= 0 enforced at API layer (GENESIS)
                $table->string('price_currency', 3)->default('TRY');
                $table->string('billing_model', 20)->default('one_time'); // one_time|per_hour|per_day|per_person

                // Optional extra fields (offer-specific)
                $table->json('attributes_json')->nullable();

                $table->string('status', 20)->default('active'); // active|inactive
                $table->timestamps();

                // Indexes
                $table->index(['listing_id', 'status']);
                $table->index(['provider_tenant_id', 'status']);
                $table->unique(['listing_id', 'code']);

                // Foreign key to listings
                $table->foreign('listing_id')->references('id')->on('listings')->onDelete('cascade');
            });
        }

        // Best-effort: add reservations.offer_id FK now that listing_offers exists.
        if (Schema::hasTable('reservations') && Schema::hasColumn('reservations', 'offer_id')) {
            Schema::table('reservations', function (Blueprint $table) {
                try {
                    $table->foreign('offer_id')->references('id')->on('listing_offers')->nullOnDelete();
                } catch (\Throwable $e) {
                    // Ignore if FK already exists or cannot be created (must not block clean installs).
                }
            });
        }
    }

    public function down(): void
    {
        // Drop reservations FK if present (best-effort), then table.
        if (Schema::hasTable('reservations') && Schema::hasColumn('reservations', 'offer_id')) {
            Schema::table('reservations', function (Blueprint $table) {
                try {
                    $table->dropForeign(['offer_id']);
                } catch (\Throwable $e) {
                    // Ignore if FK doesn't exist.
                }
            });
        }

        Schema::dropIfExists('listing_offers');
    }
};

