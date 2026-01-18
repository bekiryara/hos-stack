<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * WP-4 Reservation Thin Slice: Idempotency support.
     * Stores idempotency keys for write operations.
     */
    public function up(): void
    {
        Schema::create('idempotency_keys', function (Blueprint $table) {
            $table->id();
            $table->string('scope_type', 20); // user|tenant
            $table->string('scope_id', 100); // UUID or identifier
            $table->string('key', 255); // Idempotency-Key header value
            $table->string('request_hash', 64); // SHA-256 hash of request body
            $table->json('response_json'); // Cached response
            $table->timestamp('created_at');
            $table->timestamp('expires_at'); // TTL for cleanup

            // Indexes
            $table->index(['scope_type', 'scope_id', 'key']);
            $table->index('expires_at'); // For cleanup queries
            
            // UNIQUE constraint: same scope+key should be unique
            $table->unique(['scope_type', 'scope_id', 'key'], 'idempotency_scope_key_unique');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('idempotency_keys');
    }
};







