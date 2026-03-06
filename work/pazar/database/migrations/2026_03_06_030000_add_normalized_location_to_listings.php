<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('listings', function (Blueprint $table) {
            if (!Schema::hasColumn('listings', 'location_scope')) {
                $table->string('location_scope', 20)->nullable()->after('location_json');
            }
            if (!Schema::hasColumn('listings', 'location_city')) {
                $table->string('location_city', 120)->nullable()->after('location_scope');
            }
            if (!Schema::hasColumn('listings', 'location_district')) {
                $table->string('location_district', 120)->nullable()->after('location_city');
            }
            if (!Schema::hasColumn('listings', 'location_neighborhood')) {
                $table->string('location_neighborhood', 120)->nullable()->after('location_district');
            }
            if (!Schema::hasColumn('listings', 'location_street')) {
                $table->string('location_street', 160)->nullable()->after('location_neighborhood');
            }
            if (!Schema::hasColumn('listings', 'location_building_no')) {
                $table->string('location_building_no', 50)->nullable()->after('location_street');
            }
            if (!Schema::hasColumn('listings', 'location_door_no')) {
                $table->string('location_door_no', 50)->nullable()->after('location_building_no');
            }
            if (!Schema::hasColumn('listings', 'location_address_line')) {
                $table->text('location_address_line')->nullable()->after('location_door_no');
            }
            if (!Schema::hasColumn('listings', 'location_lat')) {
                $table->decimal('location_lat', 10, 7)->nullable()->after('location_address_line');
            }
            if (!Schema::hasColumn('listings', 'location_lng')) {
                $table->decimal('location_lng', 10, 7)->nullable()->after('location_lat');
            }
        });

        Schema::table('listings', function (Blueprint $table) {
            try {
                $table->index(['location_scope', 'status'], 'listings_location_scope_status_index');
            } catch (\Throwable $e) {}
            try {
                $table->index(['location_city', 'status'], 'listings_location_city_status_index');
            } catch (\Throwable $e) {}
            try {
                $table->index(['location_city', 'location_district', 'location_neighborhood'], 'listings_location_city_district_neighborhood_index');
            } catch (\Throwable $e) {}
            try {
                $table->index(['location_lat', 'location_lng'], 'listings_location_lat_lng_index');
            } catch (\Throwable $e) {}
        });

        if (!Schema::hasTable('listing_service_areas')) {
            Schema::create('listing_service_areas', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->uuid('listing_id');
                $table->string('city', 120);
                $table->boolean('all_districts')->default(false);
                $table->json('districts_json')->nullable();
                $table->timestamps();

                $table->foreign('listing_id')->references('id')->on('listings')->onDelete('cascade');
                $table->index(['listing_id', 'city'], 'lsa_listing_city_index');
                $table->index(['city', 'all_districts'], 'lsa_city_all_districts_index');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('listing_service_areas');

        Schema::table('listings', function (Blueprint $table) {
            try { $table->dropIndex('listings_location_scope_status_index'); } catch (\Throwable $e) {}
            try { $table->dropIndex('listings_location_city_status_index'); } catch (\Throwable $e) {}
            try { $table->dropIndex('listings_location_city_district_neighborhood_index'); } catch (\Throwable $e) {}
            try { $table->dropIndex('listings_location_lat_lng_index'); } catch (\Throwable $e) {}

            foreach ([
                'location_lng',
                'location_lat',
                'location_address_line',
                'location_door_no',
                'location_building_no',
                'location_street',
                'location_neighborhood',
                'location_district',
                'location_city',
                'location_scope',
            ] as $col) {
                if (Schema::hasColumn('listings', $col)) {
                    $table->dropColumn($col);
                }
            }
        });
    }
};

