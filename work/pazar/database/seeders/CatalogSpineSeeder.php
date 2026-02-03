<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Catalog Spine Seeder (SPEC §6.2, WP-2)
 * 
 * Seeds categories tree, attributes catalog, filter schema, and minimal demo listings.
 * Roots: vehicle, real_estate, service
 * Branches: service > events > wedding-hall, service > food > restaurant, vehicle > otomobil (MVP)
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
            // Car rental attributes
            [
                'key' => 'fuel_type',
                'value_type' => 'enum',
                'unit' => null,
                'description' => 'Yakıt türü (benzin, dizel, elektrik, hibrit)',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'transmission',
                'value_type' => 'enum',
                'unit' => null,
                'description' => 'Vites (manuel, otomatik)',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'year',
                'value_type' => 'number',
                'unit' => null,
                'description' => 'Model yılı',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'price_per_day',
                'value_type' => 'number',
                'unit' => 'TRY',
                'description' => 'Günlük kiralama fiyatı',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'min_rent_days',
                'value_type' => 'number',
                'unit' => 'day',
                'description' => 'Minimum kiralama günü',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'key' => 'has_aircon',
                'value_type' => 'boolean',
                'unit' => null,
                'description' => 'Klima var mı',
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ];

        foreach ($attributes as $attr) {
            DB::table('attributes')->insertOrIgnore($attr);
        }

        $this->command->info('Inserted attributes: capacity_max, guests_max, party_size, price_min, seats, cuisine, city, brand, spicy_level (+ vehicle_* MVP keys)');

        // 2. Insert Root Categories (idempotent: upsert by slug)
        $vehicleId = DB::table('categories')->updateOrInsert(
            ['slug' => 'vehicle'],
            [
                'parent_id' => null,
                'name' => 'Vasıta',
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
                'name' => 'Emlak',
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

        // Vasıta MVP (Sahibinden-like): 2nd column (Satılık/Kiralık) is policy-driven, not categories.
        // Create-mode requires leaf categories, so each main branch has a single leaf ("ilan") for now.
        $vehicleBranches = [
            ['slug' => 'otomobil', 'name' => 'Otomobil', 'sort_order' => 10, 'leaf_slug' => 'otomobil-ilan', 'leaf_name' => 'Otomobil İlanı'],
            ['slug' => 'arazi-suv-pickup', 'name' => 'Arazi, SUV & Pickup', 'sort_order' => 20, 'leaf_slug' => 'arazi-suv-pickup-ilan', 'leaf_name' => 'Arazi/SUV/Pickup İlanı'],
            ['slug' => 'elektrikli-araclar', 'name' => 'Elektrikli Araçlar', 'sort_order' => 30, 'leaf_slug' => 'elektrikli-arac-ilan', 'leaf_name' => 'Elektrikli Araç İlanı'],
            ['slug' => 'motosiklet', 'name' => 'Motosiklet', 'sort_order' => 40, 'leaf_slug' => 'motosiklet-ilan', 'leaf_name' => 'Motosiklet İlanı'],
            ['slug' => 'minivan-panelvan', 'name' => 'Minivan & Panelvan', 'sort_order' => 50, 'leaf_slug' => 'minivan-panelvan-ilan', 'leaf_name' => 'Minivan/Panelvan İlanı'],
            ['slug' => 'ticari-araclar', 'name' => 'Ticari Araçlar', 'sort_order' => 60, 'leaf_slug' => 'ticari-arac-ilan', 'leaf_name' => 'Ticari Araç İlanı'],
            ['slug' => 'karavan', 'name' => 'Karavan', 'sort_order' => 70, 'leaf_slug' => 'karavan-ilan', 'leaf_name' => 'Karavan İlanı'],
            ['slug' => 'atv', 'name' => 'ATV', 'sort_order' => 80, 'leaf_slug' => 'atv-ilan', 'leaf_name' => 'ATV İlanı'],
        ];

        $vehicleLeafIds = [];
        foreach ($vehicleBranches as $b) {
            DB::table('categories')->updateOrInsert(
                ['slug' => $b['slug']],
                [
                    'parent_id' => $vehicleId,
                    'name' => $b['name'],
                    'vertical' => 'vehicle',
                    'status' => 'active',
                    'sort_order' => $b['sort_order'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]
            );
            $branchId = DB::table('categories')->where('slug', $b['slug'])->value('id');

            DB::table('categories')->updateOrInsert(
                ['slug' => $b['leaf_slug']],
                [
                    'parent_id' => $branchId,
                    'name' => $b['leaf_name'],
                    'vertical' => 'vehicle',
                    'status' => 'active',
                    'sort_order' => 999,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]
            );
            $leafId = DB::table('categories')->where('slug', $b['leaf_slug'])->value('id');
            $vehicleLeafIds[$b['slug']] = $leafId;
        }

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

        // Sahibinden-like Emlak spine (2nd column is NOT categories; it's policy-driven)
        // real-estate > konut|isyeri|arsa|bina|devre-mulk|turistik-tesis
        DB::table('categories')->updateOrInsert(
            ['slug' => 'konut'],
            [
                'parent_id' => $realEstateId,
                'name' => 'Konut',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 20,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $konutId = DB::table('categories')->where('slug', 'konut')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'isyeri'],
            [
                'parent_id' => $realEstateId,
                'name' => 'İş Yeri',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 30,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $isyeriId = DB::table('categories')->where('slug', 'isyeri')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'arsa'],
            [
                'parent_id' => $realEstateId,
                'name' => 'Arsa',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 40,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $arsaId = DB::table('categories')->where('slug', 'arsa')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'bina'],
            [
                'parent_id' => $realEstateId,
                'name' => 'Bina',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 50,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $binaId = DB::table('categories')->where('slug', 'bina')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'devre-mulk'],
            [
                'parent_id' => $realEstateId,
                'name' => 'Devre Mülk',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 60,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $devreMulkId = DB::table('categories')->where('slug', 'devre-mulk')->value('id');

        DB::table('categories')->updateOrInsert(
            ['slug' => 'turistik-tesis'],
            [
                'parent_id' => $realEstateId,
                'name' => 'Turistik Tesis',
                'vertical' => 'real_estate',
                'status' => 'active',
                'sort_order' => 70,
                'created_at' => $now,
                'updated_at' => $now,
            ]
        );
        $turistikTesisId = DB::table('categories')->where('slug', 'turistik-tesis')->value('id');

        // Konut leaf types (3rd column examples)
        $konutLeaves = [
            ['slug' => 'daire', 'name' => 'Daire', 'sort_order' => 10],
            ['slug' => 'rezidans', 'name' => 'Rezidans', 'sort_order' => 20],
            ['slug' => 'mustakil-ev', 'name' => 'Müstakil Ev', 'sort_order' => 30],
            ['slug' => 'villa', 'name' => 'Villa', 'sort_order' => 40],
            ['slug' => 'apart-pansiyon', 'name' => 'Apart & Pansiyon', 'sort_order' => 50],
        ];
        foreach ($konutLeaves as $c) {
            DB::table('categories')->updateOrInsert(
                ['slug' => $c['slug']],
                [
                    'parent_id' => $konutId,
                    'name' => $c['name'],
                    'vertical' => 'real_estate',
                    'status' => 'active',
                    'sort_order' => $c['sort_order'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]
            );
        }

        // İş Yeri leaf types (3rd column examples)
        $isyeriLeaves = [
            ['slug' => 'akaryakit-istasyonu', 'name' => 'Akaryakıt İstasyonu', 'sort_order' => 10],
            ['slug' => 'apartman-dairesi', 'name' => 'Apartman Dairesi', 'sort_order' => 20],
            ['slug' => 'atolye', 'name' => 'Atölye', 'sort_order' => 30],
            ['slug' => 'avm', 'name' => 'AVM', 'sort_order' => 40],
            ['slug' => 'bufe', 'name' => 'Büfe', 'sort_order' => 50],
            ['slug' => 'buro-ofis', 'name' => 'Büro & Ofis', 'sort_order' => 60],
            ['slug' => 'ciftlik', 'name' => 'Çiftlik', 'sort_order' => 70],
            ['slug' => 'depo-antrepo', 'name' => 'Depo & Antrepo', 'sort_order' => 80],
            ['slug' => 'dugun-salonu', 'name' => 'Düğün Salonu', 'sort_order' => 90],
            ['slug' => 'dukkan-magaza', 'name' => 'Dükkan & Mağaza', 'sort_order' => 100],
            ['slug' => 'enerji-santrali', 'name' => 'Enerji Santrali', 'sort_order' => 110],
            ['slug' => 'fabrika-uretim-tesisi', 'name' => 'Fabrika & Üretim Tesisi', 'sort_order' => 120],
        ];
        foreach ($isyeriLeaves as $c) {
            DB::table('categories')->updateOrInsert(
                ['slug' => $c['slug']],
                [
                    'parent_id' => $isyeriId,
                    'name' => $c['name'],
                    'vertical' => 'real_estate',
                    'status' => 'active',
                    'sort_order' => $c['sort_order'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]
            );
        }

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

        // Vasıta attributes (MVP): namespaced keys to avoid cross-domain drift
        $vehicleAttributes = [
            ['key' => 'vehicle_brand', 'value_type' => 'string', 'unit' => null, 'description' => 'Marka'],
            ['key' => 'vehicle_model', 'value_type' => 'string', 'unit' => null, 'description' => 'Model'],
            ['key' => 'vehicle_year', 'value_type' => 'number', 'unit' => null, 'description' => 'Yıl'],
            ['key' => 'vehicle_fuel_type', 'value_type' => 'enum', 'unit' => null, 'description' => 'Yakıt'],
            ['key' => 'vehicle_transmission', 'value_type' => 'enum', 'unit' => null, 'description' => 'Vites'],
            ['key' => 'vehicle_km', 'value_type' => 'number', 'unit' => 'km', 'description' => 'Kilometre'],
            ['key' => 'vehicle_price', 'value_type' => 'number', 'unit' => 'TRY', 'description' => 'Fiyat'],
            // Rental-only fields (still part of schema; UI can show optional fields)
            ['key' => 'vehicle_price_per_day', 'value_type' => 'number', 'unit' => 'TRY', 'description' => 'Günlük Fiyat'],
            ['key' => 'vehicle_min_rent_days', 'value_type' => 'number', 'unit' => 'day', 'description' => 'Minimum Kiralama Günü'],
        ];
        foreach ($vehicleAttributes as $a) {
            DB::table('attributes')->insertOrIgnore([
                'key' => $a['key'],
                'value_type' => $a['value_type'],
                'unit' => $a['unit'],
                'description' => $a['description'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        // Attach vehicle filter schema to leaf nodes (MVP)
        $vehicleFuelOptions = ['Benzin', 'Dizel', 'Elektrik', 'Hibrit', 'LPG'];
        $vehicleTransmissionOptions = ['Manuel', 'Otomatik', 'Yarı Otomatik'];

        $vehicleCommonSchema = [
            ['key' => 'vehicle_brand', 'ui' => 'text', 'mode' => 'exact', 'rules' => null, 'order' => 10],
            ['key' => 'vehicle_model', 'ui' => 'text', 'mode' => 'exact', 'rules' => null, 'order' => 20],
            ['key' => 'vehicle_year', 'ui' => 'number', 'mode' => 'range', 'rules' => json_encode(['min' => 1950, 'max' => 2035]), 'order' => 30],
            ['key' => 'vehicle_fuel_type', 'ui' => 'select', 'mode' => 'exact', 'rules' => json_encode(['options' => $vehicleFuelOptions]), 'order' => 40],
            ['key' => 'vehicle_transmission', 'ui' => 'select', 'mode' => 'exact', 'rules' => json_encode(['options' => $vehicleTransmissionOptions]), 'order' => 50],
            ['key' => 'vehicle_km', 'ui' => 'number', 'mode' => 'range', 'rules' => json_encode(['min' => 0, 'max' => 2000000]), 'order' => 60],
            ['key' => 'vehicle_price', 'ui' => 'number', 'mode' => 'range', 'rules' => json_encode(['min' => 0, 'max' => 1000000000]), 'order' => 70],
            ['key' => 'vehicle_price_per_day', 'ui' => 'number', 'mode' => 'range', 'rules' => json_encode(['min' => 0, 'max' => 1000000]), 'order' => 80],
            ['key' => 'vehicle_min_rent_days', 'ui' => 'number', 'mode' => 'range', 'rules' => json_encode(['min' => 1, 'max' => 365]), 'order' => 90],
        ];

        $vehicleLeafSlugsForSchema = ['otomobil', 'arazi-suv-pickup', 'elektrikli-araclar', 'motosiklet', 'minivan-panelvan', 'ticari-araclar', 'karavan', 'atv'];
        foreach ($vehicleLeafSlugsForSchema as $slug) {
            $leafId = $vehicleLeafIds[$slug] ?? null;
            if (!$leafId) continue;
            foreach ($vehicleCommonSchema as $def) {
                DB::table('category_filter_schema')->updateOrInsert(
                    [
                        'category_id' => $leafId,
                        'attribute_key' => $def['key'],
                    ],
                    [
                        'ui_component' => $def['ui'],
                        'required' => false,
                        'filter_mode' => $def['mode'],
                        'rules_json' => $def['rules'],
                        'status' => 'active',
                        'sort_order' => $def['order'],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
            }
        }

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

        // Note: legacy demo vehicle filter schemas (car-rental/boat-rental) remain in DB, but the categories
        // are deactivated by migration to avoid UI confusion with the canonical policy-driven model.

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
        $this->command->info('  - vehicle (MVP): brand/model/year/fuel/transmission/km/price (+ rental fields)');
        $this->command->info('  - headphones: price_min (required, range)');
        $this->command->info('  - hotel-room: guests_max (required, range)');
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
            // vehicle / karavan (rental) — reuses old demo UUID to avoid drift
            [
                'id' => '68003790-cf34-4329-91a3-150aff9ced1d',
                'category_id' => $vehicleLeafIds['karavan'] ?? null,
                'title' => 'Karavan Kiralık (Demo)',
                'description' => 'Demo listing (vehicle/karavan, rental)',
                'status' => 'published',
                'transaction_modes_json' => json_encode(['rental']),
                'attributes_json' => json_encode([
                    'offer_variant' => 'rental',
                    'interaction_mode' => 'flow',
                    'vehicle_brand' => 'Fiat',
                    'vehicle_model' => 'Ducato',
                    'vehicle_year' => 2020,
                    'vehicle_fuel_type' => 'Dizel',
                    'vehicle_transmission' => 'Manuel',
                    'vehicle_km' => 85000,
                    'vehicle_price_per_day' => 1900,
                    'vehicle_min_rent_days' => 3,
                ]),
            ],
            // vehicle / otomobil (rental) — uses policy-driven offer_variant=rental
            [
                'id' => '9f425e36-2dd2-4787-88a0-a459406f35a9',
                'category_id' => $vehicleLeafIds['otomobil'] ?? null,
                'title' => 'Otomobil Kiralık (Demo)',
                'description' => 'Demo listing (vehicle/otomobil, rental)',
                'status' => 'published',
                'transaction_modes_json' => json_encode(['rental']),
                'attributes_json' => json_encode([
                    'offer_variant' => 'rental',
                    'interaction_mode' => 'flow',
                    'vehicle_brand' => 'Alpine',
                    'vehicle_model' => 'A290',
                    'vehicle_year' => 2025,
                    'vehicle_fuel_type' => 'Elektrik',
                    'vehicle_transmission' => 'Otomatik',
                    'vehicle_km' => 7000,
                    'vehicle_price_per_day' => 2500,
                    'vehicle_min_rent_days' => 2,
                ]),
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
            if (empty($l['category_id'])) {
                // Skip demo rows that depend on optional leaf ids
                continue;
            }
            // Pazar listings are always in the Marketplace world.
            $world = 'marketplace';
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

        $this->command->info('Inserted demo listings: bando, karavan kiralık, otomobil kiralık, kebab');
        $this->command->info('Catalog spine seeding completed.');
    }
}


