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
        Schema::create('listings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->string('world', 20); // commerce|food|rentals
            $table->string('title', 120);
            $table->text('description')->nullable();
            $table->bigInteger('price_amount')->nullable();
            $table->string('currency', 3)->default('TRY');
            $table->string('status', 20)->default('draft'); // draft|published
            $table->timestamps();

            // Indexes
            $table->index(['tenant_id', 'world', 'status']);
            $table->index(['tenant_id', 'status']);
            $table->index(['world', 'status']);
            $table->index('title');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('listings');
    }
};

