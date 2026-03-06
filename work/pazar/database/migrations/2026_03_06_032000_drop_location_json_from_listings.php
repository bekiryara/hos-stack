<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('listings', 'location_json')) return;
        Schema::table('listings', function (Blueprint $table) {
            $table->dropColumn('location_json');
        });
    }

    public function down(): void
    {
        if (Schema::hasColumn('listings', 'location_json')) return;
        Schema::table('listings', function (Blueprint $table) {
            $table->json('location_json')->nullable()->after('attributes_json');
        });
    }
};

