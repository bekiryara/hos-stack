<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Categories table for marketplace catalog spine (SPEC §6.2, WP-2).
     * Supports hierarchical category tree with parent_id.
     */
    public function up(): void
    {
        // Check if table already exists (idempotent)
        if (Schema::hasTable('categories')) {
            return; // Table exists, skip creation
        }
        
        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('parent_id')->nullable();
            $table->string('slug', 100)->unique();
            $table->string('name', 200);
            $table->string('vertical', 50)->nullable(); // world/vertical identifier (e.g., 'services')
            $table->string('status', 20)->default('active'); // active|inactive|deprecated
            $table->integer('sort_order')->default(0);
            $table->timestamps();

            // Indexes
            $table->index('parent_id');
            $table->index(['vertical', 'status']);
            $table->index('sort_order');
            
            // Foreign key for self-referential parent relationship
            $table->foreign('parent_id')->references('id')->on('categories')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('categories');
    }
};


