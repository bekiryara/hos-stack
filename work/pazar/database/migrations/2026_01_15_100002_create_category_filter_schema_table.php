<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Category Filter Schema table for marketplace catalog spine (SPEC §6.2, WP-2).
     * Maps attributes to categories (which filters are available for which category).
     * UNIQUE constraint: (category_id, attribute_key).
     */
    public function up(): void
    {
        Schema::create('category_filter_schema', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('category_id');
            $table->string('attribute_key', 100);
            $table->string('status', 20)->default('active'); // active|deprecated
            $table->integer('sort_order')->default(0);
            $table->timestamps();

            // Indexes
            $table->index(['category_id', 'status']);
            $table->index('sort_order');
            
            // Foreign keys
            $table->foreign('category_id')->references('id')->on('categories')->onDelete('cascade');
            $table->foreign('attribute_key')->references('key')->on('attributes')->onDelete('cascade');
            
            // UNIQUE constraint: one attribute per category (SPEC requirement)
            $table->unique(['category_id', 'attribute_key']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('category_filter_schema');
    }
};




