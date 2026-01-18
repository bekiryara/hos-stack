<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * WP-4 Reservation Thin Slice: Transactions Spine.
     * Creates reservations table for marketplace transactions.
     */
    public function up(): void
    {
        Schema::create('reservations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('listing_id');
            $table->uuid('provider_tenant_id'); // Listing owner tenant
            $table->uuid('requester_user_id')->nullable(); // Optional for GENESIS phase
            $table->timestamp('slot_start');
            $table->timestamp('slot_end');
            $table->integer('party_size'); // Number of people
            $table->string('status', 20)->default('requested'); // requested|accepted|cancelled|completed
            $table->timestamps();

            // Indexes
            $table->index('listing_id');
            $table->index('provider_tenant_id');
            $table->index(['listing_id', 'status']);
            $table->index(['listing_id', 'slot_start', 'slot_end']); // For overlap checks
            
            // Foreign key to listings
            $table->foreign('listing_id')->references('id')->on('listings')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('reservations');
    }
};







