<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('rentals', function (Blueprint $table) {
            if (!Schema::hasColumn('rentals', 'totals_json')) {
                $table->json('totals_json')->nullable()->after('billing_model');
            }
        });

        Schema::table('reservations', function (Blueprint $table) {
            if (!Schema::hasColumn('reservations', 'totals_json')) {
                $table->json('totals_json')->nullable()->after('billing_model');
            }
        });
    }

    public function down(): void
    {
        Schema::table('rentals', function (Blueprint $table) {
            if (Schema::hasColumn('rentals', 'totals_json')) {
                $table->dropColumn('totals_json');
            }
        });

        Schema::table('reservations', function (Blueprint $table) {
            if (Schema::hasColumn('reservations', 'totals_json')) {
                $table->dropColumn('totals_json');
            }
        });
    }
};
