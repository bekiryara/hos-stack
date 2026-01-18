<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Add missing fields to category_filter_schema table (SPEC §6.2, WP-2).
     * Adds: ui_component, required, filter_mode, rules_json
     */
    public function up(): void
    {
        Schema::table('category_filter_schema', function (Blueprint $table) {
            // Add new fields if they don't exist (idempotent)
            if (!Schema::hasColumn('category_filter_schema', 'ui_component')) {
                $table->string('ui_component', 50)->nullable()->after('attribute_key');
            }
            if (!Schema::hasColumn('category_filter_schema', 'required')) {
                $table->boolean('required')->default(false)->after('ui_component');
            }
            if (!Schema::hasColumn('category_filter_schema', 'filter_mode')) {
                $table->string('filter_mode', 50)->nullable()->after('required');
            }
            if (!Schema::hasColumn('category_filter_schema', 'rules_json')) {
                $table->json('rules_json')->nullable()->after('filter_mode');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('category_filter_schema', function (Blueprint $table) {
            $table->dropColumn(['ui_component', 'required', 'filter_mode', 'rules_json']);
        });
    }
};







