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
                'key' => 'guests_max',
                'value_type' => 'number',
                'unit' => 'person',
                'description' => 'Maximum guests (for accommodation-style listings)',
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

        $this->command->info('Inserted attributes: capacity_max, guests_max, party_size, price_min, seats, cuisine, city');

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

        // Additional upper classes (KANONIK_MODEL): keep them under "service" to preserve 3-root contract lock (WP-2)
        $productsId = DB::table('categories')->updateOrInsert(
            ['slug' => 'products'],
            [
                'parent_id' => $serviceId,
                'name' => 'Products',
                'vertical' => 'product',
                'status' => 'active',
                'sort_order' => 50,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        ) ? DB::table('categories')->where('slug', 'products')->value('id') : null;
        $productsId = $productsId ?? DB::table('categories')->where('slug', 'products')->value('id');

        $accommodationId = DB::table('categories')->updateOrInsert(
            ['slug' => 'accommodation'],
            [
                'parent_id' => $serviceId,
                'name' => 'Accommodation',
                'vertical' => 'accommodation',
                'status' => 'active',
                'sort_order' => 60,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        ) ? DB::table('categories')->where('slug', 'accommodation')->value('id') : null;
        $accommodationId = $accommodationId ?? DB::table('categories')->where('slug', 'accommodation')->value('id');

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

        // service > food > restaurant (keep original structure: Food under Services)
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

        // vehicle > boat > boat-rental
        DB::table('categories')->updateOrInsert(
            ['slug' => 'boat'],
            [
                'parent_id' => $vehicleId,
                'name' => 'Boat',
                'vertical' => 'vehicle',
                'status' => 'active',
                'sort_order' => 20,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $boatId = DB::table('categories')->where('slug', 'boat')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'boat-rental'],
            [
                'parent_id' => $boatId,
                'name' => 'Boat Rental',
                'vertical' => 'vehicle',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $boatRentalId = DB::table('categories')->where('slug', 'boat-rental')->value('id');

        // products > electronics > headphones
        DB::table('categories')->updateOrInsert(
            ['slug' => 'electronics'],
            [
                'parent_id' => $productsId,
                'name' => 'Electronics',
                'vertical' => 'product',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $electronicsId = DB::table('categories')->where('slug', 'electronics')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'headphones'],
            [
                'parent_id' => $electronicsId,
                'name' => 'Headphones',
                'vertical' => 'product',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $headphonesId = DB::table('categories')->where('slug', 'headphones')->value('id');

        // accommodation > hotel > hotel-room
        DB::table('categories')->updateOrInsert(
            ['slug' => 'hotel'],
            [
                'parent_id' => $accommodationId,
                'name' => 'Hotel',
                'vertical' => 'accommodation',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $hotelId = DB::table('categories')->where('slug', 'hotel')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'hotel-room'],
            [
                'parent_id' => $hotelId,
                'name' => 'Hotel Room',
                'vertical' => 'accommodation',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $hotelRoomId = DB::table('categories')->where('slug', 'hotel-room')->value('id');

        // real-estate > for-sale > apartment-sale
        DB::table('categories')->updateOrInsert(
            ['slug' => 'for-sale'],
            [
                'parent_id' => $realEstateId,
                'name' => 'For Sale',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $forSaleId = DB::table('categories')->where('slug', 'for-sale')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'apartment-sale'],
            [
                'parent_id' => $forSaleId,
                'name' => 'Apartment (Sale)',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $apartmentSaleId = DB::table('categories')->where('slug', 'apartment-sale')->value('id');

        $this->command->info('Upserted branch categories (expanded roots + example leaves).');

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

        // products/headphones: price_min (required, range)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $headphonesId,
                'attribute_key' => 'price_min',
            ],
            [
                'ui_component' => 'number',
                'required' => true,
                'filter_mode' => 'range',
                'rules_json' => json_encode(['min' => 0, 'max' => 500000]),
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );

        // accommodation/hotel-room: guests_max (required, range)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $hotelRoomId,
                'attribute_key' => 'guests_max',
            ],
            [
                'ui_component' => 'number',
                'required' => true,
                'filter_mode' => 'range',
                'rules_json' => json_encode(['min' => 1, 'max' => 20]),
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );

        // real-estate/apartment-sale: price_min (required, range)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $apartmentSaleId,
                'attribute_key' => 'price_min',
            ],
            [
                'ui_component' => 'number',
                'required' => true,
                'filter_mode' => 'range',
                'rules_json' => json_encode(['min' => 0, 'max' => 1000000000]),
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );

        // vehicle/boat-rental: seats (optional, range)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $boatRentalId,
                'attribute_key' => 'seats',
            ],
            [
                'ui_component' => 'number',
                'required' => false,
                'filter_mode' => 'range',
                'rules_json' => json_encode(['min' => 1, 'max' => 100]),
                'status' => 'active',
                'sort_order' => 20,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );

        $this->command->info('Inserted filter schemas:');
        $this->command->info('  - wedding-hall: capacity_max (required, range)');
        $this->command->info('  - restaurant: cuisine (optional, select)');
        $this->command->info('  - car-rental: seats (optional, range)');
        $this->command->info('  - headphones: price_min (required, range)');
        $this->command->info('  - hotel-room: guests_max (required, range)');
        $this->command->info('  - apartment-sale: price_min (required, range)');
        $this->command->info('  - boat-rental: seats (optional, range)');
        $this->command->info('Catalog spine seeding completed.');
    }
}


