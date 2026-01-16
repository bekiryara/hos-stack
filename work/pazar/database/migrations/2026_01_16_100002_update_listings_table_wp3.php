<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * WP-3 Supply Spine: Update listings table for schema-driven supply.
     * Adds: category_id, transaction_modes_json, attributes_json, location_json
     * Updates: status enum to include 'paused'
     * Adds indexes: (tenant_id,status), (category_id,status)
     */
    public function up(): void
    {
        Schema::table('listings', function (Blueprint $table) {
            // Add category_id if it doesn't exist
            if (!Schema::hasColumn('listings', 'category_id')) {
                $table->unsignedBigInteger('category_id')->nullable()->after('tenant_id');
                $table->foreign('category_id')->references('id')->on('categories')->onDelete('restrict');
            }
            
            // Add transaction_modes_json if it doesn't exist
            if (!Schema::hasColumn('listings', 'transaction_modes_json')) {
                $table->json('transaction_modes_json')->nullable()->after('description');
            }
            
            // Add attributes_json if it doesn't exist
            if (!Schema::hasColumn('listings', 'attributes_json')) {
                $table->json('attributes_json')->nullable()->after('transaction_modes_json');
            }
            
            // Add location_json if it doesn't exist
            if (!Schema::hasColumn('listings', 'location_json')) {
                $table->json('location_json')->nullable()->after('attributes_json');
            }
        });
        
        // Add indexes (tenant_id,status already exists, add category_id,status)
        Schema::table('listings', function (Blueprint $table) {
            // Add category_id,status index if category_id column exists
            if (Schema::hasColumn('listings', 'category_id')) {
                try {
                    $table->index(['category_id', 'status'], 'listings_category_id_status_index');
                } catch (\Exception $e) {
                    // Index might already exist, ignore
                }
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('listings', function (Blueprint $table) {
            // Drop indexes
            $sm = Schema::getConnection()->getDoctrineSchemaManager();
            $indexesFound = $sm->listTableIndexes('listings');
            
            if (isset($indexesFound['listings_category_id_status_index'])) {
                $table->dropIndex('listings_category_id_status_index');
            }
            
            // Drop columns
            if (Schema::hasColumn('listings', 'location_json')) {
                $table->dropColumn('location_json');
            }
            if (Schema::hasColumn('listings', 'attributes_json')) {
                $table->dropColumn('attributes_json');
            }
            if (Schema::hasColumn('listings', 'transaction_modes_json')) {
                $table->dropColumn('transaction_modes_json');
            }
            if (Schema::hasColumn('listings', 'category_id')) {
                $table->dropForeign(['category_id']);
                $table->dropColumn('category_id');
            }
        });
    }
};

