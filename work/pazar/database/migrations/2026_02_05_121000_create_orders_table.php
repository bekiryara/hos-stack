<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * WP-6 Order Thin Slice: Transactions Spine.
     * Creates orders table for marketplace purchase transactions.
     */
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('listing_id');
            $table->uuid('seller_tenant_id');
            $table->uuid('buyer_user_id')->nullable(); // GENESIS/back-compat
            $table->integer('quantity')->default(1);
            // placed|accepted|approved|rejected|cancelled|completed
            $table->string('status', 20)->default('placed');
            $table->json('totals_json')->nullable();
            $table->timestamps();

            // Indexes
            $table->index('listing_id');
            $table->index('seller_tenant_id');
            $table->index('buyer_user_id');
            $table->index(['seller_tenant_id', 'status']);
            $table->index(['buyer_user_id', 'status']);

            // Foreign key to listings
            $table->foreign('listing_id')->references('id')->on('listings')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};

