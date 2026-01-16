<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Fix existing categories table to match WP-2 schema (SPEC §6.2).
     * Adds missing columns: vertical, status (if is_active exists, migrate it)
     */
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            // Add vertical column if it doesn't exist
            if (!Schema::hasColumn('categories', 'vertical')) {
                $table->string('vertical', 50)->nullable()->after('name');
            }
            
            // Add status column if it doesn't exist
            if (!Schema::hasColumn('categories', 'status')) {
                $table->string('status', 20)->nullable()->after('vertical');
            }
        });
        
        // Migrate is_active to status if is_active exists (after column is added)
        if (Schema::hasColumn('categories', 'is_active') && Schema::hasColumn('categories', 'status')) {
            DB::statement("UPDATE categories SET status = CASE WHEN is_active = true THEN 'active' ELSE 'inactive' END WHERE status IS NULL");
            // Set default for any remaining NULLs
            DB::statement("UPDATE categories SET status = 'active' WHERE status IS NULL");
            // Alter column to have default and NOT NULL
            DB::statement("ALTER TABLE categories ALTER COLUMN status SET DEFAULT 'active'");
            DB::statement("ALTER TABLE categories ALTER COLUMN status SET NOT NULL");
        } elseif (Schema::hasColumn('categories', 'status')) {
            // If status exists but no is_active, just set defaults
            DB::statement("UPDATE categories SET status = 'active' WHERE status IS NULL");
            DB::statement("ALTER TABLE categories ALTER COLUMN status SET DEFAULT 'active'");
            DB::statement("ALTER TABLE categories ALTER COLUMN status SET NOT NULL");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            if (Schema::hasColumn('categories', 'vertical')) {
                $table->dropColumn('vertical');
            }
            if (Schema::hasColumn('categories', 'status')) {
                $table->dropColumn('status');
            }
        });
    }
};

