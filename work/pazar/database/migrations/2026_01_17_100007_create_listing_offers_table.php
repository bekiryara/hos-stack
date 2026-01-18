<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * WP-9 Offers/Pricing Spine: Marketplace owner.
     * Creates listing_offers table for marketplace pricing/offers.
     */
    public function up(): void
    {
        Schema::create('listing_offers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('listing_id');
            $table->uuid('provider_tenant_id'); // Offer owner tenant
            $table->string('code', 100); // Unique within listing (slug/kebab-case)
            $table->string('name', 255); // Offer name
            $table->integer('price_amount'); // Price amount (int, >= 0)
            $table->string('price_currency', 3)->default('TRY'); // Currency code (TRY, USD, etc.)
            $table->string('billing_model', 20)->default('one_time'); // one_time|per_hour|per_day|per_person
            $table->json('attributes_json')->nullable(); // Additional attributes
            $table->string('status', 20)->default('active'); // active|inactive
            $table->timestamps();

            // Indexes
            $table->index(['listing_id', 'status']);
            $table->index(['provider_tenant_id', 'status']);
            
            // Unique constraint: code unique within listing
            $table->unique(['listing_id', 'code'], 'listing_offer_code_unique');
            
            // Foreign key to listings
            $table->foreign('listing_id')->references('id')->on('listings')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('listing_offers');
    }
};


