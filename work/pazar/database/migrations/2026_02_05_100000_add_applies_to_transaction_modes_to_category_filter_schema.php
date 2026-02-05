<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phase-2 schema-driven applicability:
 * Add `applies_to_transaction_modes` to category_filter_schema.
 *
 * Semantics:
 * - NULL: applies to all modes (sale|rental|reservation)
 * - JSON array of strings: allowed modes for this attribute_key in this category.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('category_filter_schema', function (Blueprint $table) {
            if (!Schema::hasColumn('category_filter_schema', 'applies_to_transaction_modes')) {
                $table->json('applies_to_transaction_modes')->nullable()->after('rules_json');
            }
        });
    }

    public function down(): void
    {
        Schema::table('category_filter_schema', function (Blueprint $table) {
            if (Schema::hasColumn('category_filter_schema', 'applies_to_transaction_modes')) {
                $table->dropColumn('applies_to_transaction_modes');
            }
        });
    }
};

