<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('rentals', function (Blueprint $table) {
            if (!Schema::hasColumn('rentals', 'pricing_source')) {
                $table->string('pricing_source', 20)->nullable()->after('provider_tenant_id');
            }
            if (!Schema::hasColumn('rentals', 'price_amount')) {
                $table->integer('price_amount')->nullable()->after('pricing_source');
            }
            if (!Schema::hasColumn('rentals', 'price_currency')) {
                $table->string('price_currency', 3)->nullable()->after('price_amount');
            }
            if (!Schema::hasColumn('rentals', 'billing_model')) {
                $table->string('billing_model', 30)->nullable()->after('price_currency');
            }
        });
    }

    public function down(): void
    {
        Schema::table('rentals', function (Blueprint $table) {
            foreach (['billing_model', 'price_currency', 'price_amount', 'pricing_source'] as $column) {
                if (Schema::hasColumn('rentals', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
