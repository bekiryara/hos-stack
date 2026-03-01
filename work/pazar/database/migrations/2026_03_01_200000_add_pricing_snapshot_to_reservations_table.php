<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            if (!Schema::hasColumn('reservations', 'pricing_source')) {
                $table->string('pricing_source', 20)->nullable()->after('offer_id');
            }
            if (!Schema::hasColumn('reservations', 'price_amount')) {
                $table->integer('price_amount')->nullable()->after('pricing_source');
            }
            if (!Schema::hasColumn('reservations', 'price_currency')) {
                $table->string('price_currency', 3)->nullable()->after('price_amount');
            }
            if (!Schema::hasColumn('reservations', 'billing_model')) {
                $table->string('billing_model', 30)->nullable()->after('price_currency');
            }
        });
    }

    public function down(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            foreach (['billing_model', 'price_currency', 'price_amount', 'pricing_source'] as $column) {
                if (Schema::hasColumn('reservations', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
