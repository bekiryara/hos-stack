<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Catalog Spine Seeder (SPEC §6.2, WP-2)
 * 
 * Seeds categories tree, attributes catalog, and filter schema.
 * Roots: vehicle, real_estate, service
 * Branches: service > events > wedding-hall, service > food > restaurant, vehicle > car > car-rental
 */
final class CatalogSpineSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $now = now();

        // 1. Insert Attributes
        $attributes = [
            [
                'key' => 'capacity_max',
                'value_type' => 'number',
                'unit' => 'person',
                'description' => 'Maximum capacity (number of people)',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'party_size',
                'value_type' => 'number',
                'unit' => 'person',
                'description' => 'Party size (used on reservation input)',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'price_min',
                'value_type' => 'number',
                'unit' => 'TRY',
                'description' => 'Minimum price in Turkish Lira',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'seats',
                'value_type' => 'number',
                'unit' => 'seat',
                'description' => 'Number of seats',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'cuisine',
                'value_type' => 'enum',
                'unit' => null,
                'description' => 'Cuisine type',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'city',
                'value_type' => 'string',
                'unit' => null,
                'description' => 'City location',
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ];

        foreach ($attributes as $attr) {
            DB::table('attributes')->insertOrIgnore($attr);
        }

        $this->command->info('Inserted attributes: capacity_max, party_size, price_min, seats, cuisine, city');

        // 2. Insert Root Categories (idempotent: upsert by slug)
        $vehicleId = DB::table('categories')->updateOrInsert(
            ['slug' => 'vehicle'],
            [
                'parent_id' => null,
                'name' => 'Vehicle',
                'vertical' => 'vehicle',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        ) ? DB::table('categories')->where('slug', 'vehicle')->value('id') : null;
        $vehicleId = $vehicleId ?? DB::table('categories')->where('slug', 'vehicle')->value('id');

        $realEstateId = DB::table('categories')->updateOrInsert(
            ['slug' => 'real-estate'],
            [
                'parent_id' => null,
                'name' => 'Real Estate',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 20,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        ) ? DB::table('categories')->where('slug', 'real-estate')->value('id') : null;
        $realEstateId = $realEstateId ?? DB::table('categories')->where('slug', 'real-estate')->value('id');

        $serviceId = DB::table('categories')->updateOrInsert(
            ['slug' => 'service'],
            [
                'parent_id' => null,
                'name' => 'Services',
                'vertical' => 'service',
                'status' => 'active',
                'sort_order' => 30,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        ) ? DB::table('categories')->where('slug', 'service')->value('id') : null;
        $serviceId = $serviceId ?? DB::table('categories')->where('slug', 'service')->value('id');

        $this->command->info('Upserted root categories: vehicle, real-estate, service');

        // 3. Insert Branch Categories (idempotent: upsert by slug)
        
        // service > events > wedding-hall
        DB::table('categories')->updateOrInsert(
            ['slug' => 'events'],
            [
                'parent_id' => $serviceId,
                'name' => 'Events',
                'vertical' => 'service',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $eventsId = DB::table('categories')->where('slug', 'events')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'wedding-hall'],
            [
                'parent_id' => $eventsId,
                'name' => 'Wedding Hall',
                'vertical' => 'service',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $weddingHallId = DB::table('categories')->where('slug', 'wedding-hall')->value('id');

        // service > food > restaurant
        DB::table('categories')->updateOrInsert(
            ['slug' => 'food'],
            [
                'parent_id' => $serviceId,
                'name' => 'Food',
                'vertical' => 'service',
                'status' => 'active',
                'sort_order' => 20,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $foodId = DB::table('categories')->where('slug', 'food')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'restaurant'],
            [
                'parent_id' => $foodId,
                'name' => 'Restaurant',
                'vertical' => 'service',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $restaurantId = DB::table('categories')->where('slug', 'restaurant')->value('id');

        // vehicle > car > car-rental
        DB::table('categories')->updateOrInsert(
            ['slug' => 'car'],
            [
                'parent_id' => $vehicleId,
                'name' => 'Car',
                'vertical' => 'vehicle',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $carId = DB::table('categories')->where('slug', 'car')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'car-rental'],
            [
                'parent_id' => $carId,
                'name' => 'Car Rental',
                'vertical' => 'vehicle',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $carRentalId = DB::table('categories')->where('slug', 'car-rental')->value('id');

        $this->command->info('Upserted branch categories: service > events > wedding-hall, service > food > restaurant, vehicle > car > car-rental');

        // 4. Insert Category Filter Schema (idempotent: upsert by category_id + attribute_key)
        
        // wedding-hall: capacity_max (required, range filter) - MUST EXIST for catalog check to PASS
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $weddingHallId,
                'attribute_key' => 'capacity_max',
            ],
            [
                'ui_component' => 'number',
                'required' => true,
                'filter_mode' => 'range',
                'rules_json' => json_encode(['min' => 1, 'max' => 1000]),
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );

        // restaurant: cuisine (optional, select/enum)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $restaurantId,
                'attribute_key' => 'cuisine',
            ],
            [
                'ui_component' => 'select',
                'required' => false,
                'filter_mode' => 'exact',
                'rules_json' => json_encode(['options' => ['Turkish', 'Italian', 'Chinese', 'Japanese']]),
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );

        // car-rental: seats (optional, number)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $carRentalId,
                'attribute_key' => 'seats',
            ],
            [
                'ui_component' => 'number',
                'required' => false,
                'filter_mode' => 'range',
                'rules_json' => json_encode(['min' => 2, 'max' => 9]),
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );

        $this->command->info('Inserted filter schemas:');
        $this->command->info('  - wedding-hall: capacity_max (required, range)');
        $this->command->info('  - restaurant: cuisine (optional, select)');
        $this->command->info('  - car-rental: seats (optional, range)');
        $this->command->info('Catalog spine seeding completed.');
    }
}


