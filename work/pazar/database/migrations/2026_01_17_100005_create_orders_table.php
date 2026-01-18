<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * WP-6 Orders Thin Slice: Transactions Spine.
     * Creates orders table for marketplace sales.
     */
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('buyer_user_id')->nullable(); // Optional for GENESIS phase
            $table->uuid('seller_tenant_id'); // Listing owner tenant
            $table->uuid('listing_id');
            $table->integer('quantity')->default(1);
            $table->string('status', 20)->default('placed'); // placed|paid|fulfilled|cancelled
            $table->json('totals_json')->nullable(); // Price/currency breakdown
            $table->timestamps();

            // Indexes
            $table->index(['buyer_user_id', 'status']);
            $table->index(['seller_tenant_id', 'status']);
            $table->index('listing_id');
            
            // Foreign key to listings
            $table->foreign('listing_id')->references('id')->on('listings')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};





