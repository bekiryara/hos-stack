<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * WP-7 Rental Thin Slice: Transactions Spine.
     * Creates rentals table for marketplace rental transactions.
     */
    public function up(): void
    {
        Schema::create('rentals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('listing_id');

            // Who is renting + who provides the listing
            $table->uuid('renter_user_id');
            $table->uuid('provider_tenant_id');

            // Rental window
            $table->timestamp('start_at');
            $table->timestamp('end_at');

            // requested|accepted|rejected|cancelled|active|completed
            $table->string('status', 20)->default('requested');
            $table->timestamps();

            // Indexes
            $table->index('listing_id');
            $table->index('renter_user_id');
            $table->index('provider_tenant_id');
            $table->index(['listing_id', 'status']);
            $table->index(['listing_id', 'start_at', 'end_at']); // overlap checks
            $table->index(['provider_tenant_id', 'status']);

            // Foreign key to listings
            $table->foreign('listing_id')->references('id')->on('listings')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rentals');
    }
};

