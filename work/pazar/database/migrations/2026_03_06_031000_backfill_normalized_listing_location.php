<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('listings', 'location_scope') || !Schema::hasColumn('listings', 'location_json')) {
            return;
        }

        DB::statement("
            UPDATE listings
            SET
                location_scope = COALESCE(
                    NULLIF(attributes_json->>'location_scope', ''),
                    CASE
                        WHEN location_json IS NULL THEN NULL
                        WHEN jsonb_typeof(location_json::jsonb -> 'service_area') = 'array' THEN 'service_area'
                        WHEN COALESCE(location_json::jsonb ->> 'city', '') <> '' AND COALESCE(location_json::jsonb ->> 'district', '') <> '' AND COALESCE(location_json::jsonb ->> 'neighborhood', '') <> '' THEN 'point'
                        WHEN COALESCE(location_json::jsonb ->> 'city', '') <> '' THEN 'city'
                        ELSE NULL
                    END
                ),
                location_city = NULLIF(location_json::jsonb ->> 'city', ''),
                location_district = NULLIF(location_json::jsonb ->> 'district', ''),
                location_neighborhood = NULLIF(location_json::jsonb ->> 'neighborhood', ''),
                location_street = NULLIF(location_json::jsonb ->> 'street', ''),
                location_building_no = NULLIF(location_json::jsonb ->> 'building_no', ''),
                location_door_no = NULLIF(location_json::jsonb ->> 'door_no', ''),
                location_address_line = NULLIF(location_json::jsonb ->> 'address_line', ''),
                location_lat = CASE
                    WHEN COALESCE(location_json::jsonb ->> 'lat', '') ~ '^-?[0-9]+(\\.[0-9]+)?$' THEN (location_json::jsonb ->> 'lat')::numeric
                    ELSE NULL
                END,
                location_lng = CASE
                    WHEN COALESCE(location_json::jsonb ->> 'lng', '') ~ '^-?[0-9]+(\\.[0-9]+)?$' THEN (location_json::jsonb ->> 'lng')::numeric
                    ELSE NULL
                END
            WHERE location_json IS NOT NULL
        ");

        if (Schema::hasTable('listing_service_areas')) {
            DB::statement("
                INSERT INTO listing_service_areas (listing_id, city, all_districts, districts_json, created_at, updated_at)
                SELECT
                    l.id AS listing_id,
                    e.city,
                    e.all_districts,
                    e.districts_json,
                    NOW(),
                    NOW()
                FROM listings l
                CROSS JOIN LATERAL (
                    SELECT
                        NULLIF(j->>'city', '') AS city,
                        COALESCE((j->>'all_districts')::boolean, false) AS all_districts,
                        CASE
                            WHEN COALESCE((j->>'all_districts')::boolean, false) = true THEN '[]'::json
                            WHEN jsonb_typeof(j->'districts') = 'array' THEN (j->'districts')::json
                            ELSE '[]'::json
                        END AS districts_json
                    FROM jsonb_array_elements(
                        CASE
                            WHEN jsonb_typeof(l.location_json::jsonb -> 'service_area') = 'array'
                                THEN l.location_json::jsonb -> 'service_area'
                            ELSE '[]'::jsonb
                        END
                    ) AS j
                ) e
                LEFT JOIN listing_service_areas x
                  ON x.listing_id = l.id
                 AND x.city = e.city
                WHERE e.city IS NOT NULL
                  AND x.id IS NULL
            ");
        }
    }

    public function down(): void
    {
        // no-op
    }
};

