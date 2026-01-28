<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Catalog Spine Seeder (SPEC §6.2, WP-2)
 * 
 * Seeds categories tree, attributes catalog, filter schema, and minimal demo listings.
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
            [
                'key' => 'brand',
                'value_type' => 'string',
                'unit' => null,
                'description' => 'Brand / make (vehicle)',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'spicy_level',
                'value_type' => 'number',
                'unit' => null,
                'description' => 'Spicy level (0-10)',
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ];

        foreach ($attributes as $attr) {
            DB::table('attributes')->insertOrIgnore($attr);
        }

        $this->command->info('Inserted attributes: capacity_max, guests_max, party_size, price_min, seats, cuisine, city, brand, spicy_level');

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

        // service > events > bando
        DB::table('categories')->updateOrInsert(
            ['slug' => 'bando'],
            [
                'parent_id' => $eventsId,
                'name' => 'Bando',
                'vertical' => 'service',
                'status' => 'active',
                'sort_order' => 20,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $bandoId = DB::table('categories')->where('slug', 'bando')->value('id');

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

        // service > food > kebab
        DB::table('categories')->updateOrInsert(
            ['slug' => 'kebab'],
            [
                'parent_id' => $foodId,
                'name' => 'Kebab',
                'vertical' => 'service',
                'status' => 'active',
                'sort_order' => 20,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $kebabId = DB::table('categories')->where('slug', 'kebab')->value('id');

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

        // bando: capacity_max (optional, range) + city (optional, exact)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $bandoId,
                'attribute_key' => 'capacity_max',
            ],
            [
                'ui_component' => 'number',
                'required' => false,
                'filter_mode' => 'range',
                'rules_json' => json_encode(['min' => 1, 'max' => 1000]),
                'status' => 'active',
                'sort_order' => 10,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $bandoId,
                'attribute_key' => 'city',
            ],
            [
                'ui_component' => 'text',
                'required' => false,
                'filter_mode' => 'exact',
                'rules_json' => null,
                'status' => 'active',
                'sort_order' => 20,
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

        // car-rental: brand (optional, exact)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $carRentalId,
                'attribute_key' => 'brand',
            ],
            [
                'ui_component' => 'text',
                'required' => false,
                'filter_mode' => 'exact',
                'rules_json' => null,
                'status' => 'active',
                'sort_order' => 20,
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

        // kebab: cuisine (optional, select) + spicy_level (optional, range)
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $kebabId,
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
        DB::table('category_filter_schema')->updateOrInsert(
            [
                'category_id' => $kebabId,
                'attribute_key' => 'spicy_level',
            ],
            [
                'ui_component' => 'number',
                'required' => false,
                'filter_mode' => 'range',
                'rules_json' => json_encode(['min' => 0, 'max' => 10]),
                'status' => 'active',
                'sort_order' => 20,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );

        $this->command->info('Inserted filter schemas:');
        $this->command->info('  - wedding-hall: capacity_max (required, range)');
        $this->command->info('  - restaurant: cuisine (optional, select)');
        $this->command->info('  - bando: capacity_max (optional, range), city (optional, exact)');
        $this->command->info('  - car-rental: seats (optional, range)');
        $this->command->info('  - car-rental: brand (optional, exact)');
        $this->command->info('  - headphones: price_min (required, range)');
        $this->command->info('  - hotel-room: guests_max (required, range)');
        $this->command->info('  - apartment-sale: price_min (required, range)');
        $this->command->info('  - boat-rental: seats (optional, range)');
        $this->command->info('  - kebab: cuisine (optional, select), spicy_level (optional, range)');

        // 5. Insert minimal demo listings (idempotent by UUID)
        // Note: tenant_id is a stable placeholder UUID; no FK constraint exists in Pazar for listings.tenant_id
        $demoTenantId = '00000000-0000-0000-0000-000000000001';

        $demoListings = [
            // service / bando
            [
                'id' => '510e1bc9-4e08-40cd-a4d0-fc430142a96b',
                'category_id' => $bandoId,
                'title' => 'Bando Presto 4 kişi',
                'description' => 'Demo listing (service/bando)',
                'status' => 'published',
                'transaction_modes_json' => json_encode(['reservation']),
                'attributes_json' => json_encode(['capacity_max' => 4, 'city' => 'Izmir']),
            ],
            // rental / boat
            [
                'id' => '68003790-cf34-4329-91a3-150aff9ced1d',
                'category_id' => $boatRentalId,
                'title' => 'Rüyam Tekne Kiralama',
                'description' => 'Demo listing (rental/boat)',
                'status' => 'published',
                'transaction_modes_json' => json_encode(['rental']),
                'attributes_json' => json_encode(['seats' => 8, 'city' => 'Istanbul']),
            ],
            // rental / car
            [
                'id' => '9f425e36-2dd2-4787-88a0-a459406f35a9',
                'category_id' => $carRentalId,
                'title' => 'Mercedes Kiralık',
                'description' => 'Demo listing (rental/car)',
                'status' => 'published',
                'transaction_modes_json' => json_encode(['rental']),
                'attributes_json' => json_encode(['seats' => 5, 'brand' => 'Mercedes', 'city' => 'Ankara']),
            ],
            // food / kebab (sale)
            [
                'id' => '40988e47-a29c-4e7f-9453-d0690478b1fa',
                'category_id' => $kebabId,
                'title' => 'Adana Kebap',
                'description' => 'Demo listing (food/kebab)',
                'status' => 'published',
                'transaction_modes_json' => json_encode(['sale']),
                'attributes_json' => json_encode(['cuisine' => 'Turkish', 'spicy_level' => 7, 'city' => 'Adana']),
            ],
        ];

        foreach ($demoListings as $l) {
            $world = DB::table('categories')->where('id', $l['category_id'])->value('vertical') ?? 'commerce';
            DB::table('listings')->updateOrInsert(
                ['id' => $l['id']],
                [
                    'tenant_id' => $demoTenantId,
                    'world' => $world,
                    'category_id' => $l['category_id'],
                    'title' => $l['title'],
                    'description' => $l['description'],
                    'status' => $l['status'],
                    'transaction_modes_json' => $l['transaction_modes_json'],
                    'attributes_json' => $l['attributes_json'],
                    'location_json' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]
            );
        }

        $this->command->info('Inserted demo listings: bando, boat rental, car rental, kebab');
        $this->command->info('Catalog spine seeding completed.');
    }
}


