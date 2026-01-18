<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Attributes table for marketplace catalog spine (SPEC §6.2, WP-2).
     * Global attribute catalog (key-value type definitions).
     */
    public function up(): void
    {
        Schema::create('attributes', function (Blueprint $table) {
            $table->string('key', 100)->primary(); // PK: attribute key (e.g., 'capacity_max')
            $table->string('value_type', 20); // number|string|boolean|date|etc
            $table->string('unit', 20)->nullable(); // optional unit (e.g., 'person', 'm2', 'TRY')
            $table->text('description')->nullable();
            $table->timestamps();

            // Indexes
            $table->index('value_type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('attributes');
    }
};








