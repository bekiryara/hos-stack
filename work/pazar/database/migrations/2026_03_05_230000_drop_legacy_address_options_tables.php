<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('address_manifest_versions');
        Schema::dropIfExists('address_neighborhoods');
        Schema::dropIfExists('address_districts');
        Schema::dropIfExists('address_cities');
    }

    public function down(): void
    {
        // Intentionally empty: legacy pazar address dictionary is retired.
    }
};

