<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * WP-7 Rentals Thin Slice: Transactions Spine.
     * Creates rentals table for marketplace rental transactions.
     */
    public function up(): void
    {
        Schema::create('rentals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('listing_id');
            $table->uuid('renter_user_id'); // User renting the listing
            $table->uuid('provider_tenant_id'); // Listing owner tenant
            $table->timestamp('start_at');
            $table->timestamp('end_at');
            $table->string('status', 20)->default('requested'); // requested|accepted|active|completed|cancelled
            $table->timestamps();

            // Indexes
            $table->index('listing_id');
            $table->index(['renter_user_id', 'status']);
            $table->index(['provider_tenant_id', 'status']);
            $table->index(['listing_id', 'start_at', 'end_at']); // For overlap checks
            
            // Foreign key to listings
            $table->foreign('listing_id')->references('id')->on('listings')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('rentals');
    }
};



