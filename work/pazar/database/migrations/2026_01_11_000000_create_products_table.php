<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('tenant_id')->index();
            $table->string('world', 32)->index(); // commerce/food/rentals
            $table->string('type', 64)->index(); // listing/product/service etc (future-proof)
            $table->string('title', 255);
            $table->string('status', 32)->index()->default('draft'); // draft/published/archived
            $table->string('currency', 8)->nullable();
            $table->bigInteger('price_amount')->nullable(); // store minor units
            $table->json('payload_json')->nullable(); // world-specific data (no schema drift)
            $table->timestamps();
            
            // Composite index for tenant + world + status queries
            $table->index(['tenant_id', 'world', 'status']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};





