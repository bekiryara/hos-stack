<?php

/**
 * Category Flow Policy (CONTACT_ONLY vs FLOW)
 *
 * Purpose:
 * - Keep "2nd column" (Satiilik/Kiralik/Devren/...) out of the category tree.
 * - Drive UI choices and backend validation from a single source of truth.
 */
return [
    'version' => 2,

    'canonical_transaction_modes' => ['sale', 'rental', 'reservation'],

    'non_leaf_selectable_prefixes' => ['service-product-ty-c'],

    'card_display' => [
        'vehicle' => [
            'currency' => 'TRY',
            'highlights' => ['vehicle_model', 'vehicle_year', 'city', 'vehicle_km_bucket'],
        ],
        'konut' => [
            'currency' => 'TRY',
            'highlights' => ['city', 'room_count', 'area_m2'],
        ],
        'is-yeri' => [
            'currency' => 'TRY',
            'highlights' => ['city', 'area_m2'],
        ],
        'service-product' => [
            'currency' => 'TRY',
            'highlights' => ['product_brand', 'product_condition'],
        ],
        'events' => [
            'currency' => 'TRY',
            'highlights' => ['city', 'capacity_max'],
        ],
        'food' => [
            'currency' => 'TRY',
            'highlights' => ['city'],
        ],
    ],

    'rules' => [
        'vehicle' => [
            'allowed_transaction_modes' => ['sale', 'rental'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'fulfillment_mode' => 'provider_location',
            'location_scope' => 'point',
            'service_time_model' => 'none',
            'offer_requirement' => 'no_offer',
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satilik', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'none', 'offer_requirement' => 'no_offer'],
                ['key' => 'rental', 'label' => 'Kiralik', 'transaction_mode' => 'rental', 'interaction_mode' => 'flow', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'date_range', 'offer_requirement' => 'no_offer'],
            ],
        ],

        'konut' => [
            'allowed_transaction_modes' => ['sale', 'rental', 'reservation'],
            'default_offer_variant' => 'sale',
            'supports_packages' => true,
            'fulfillment_mode' => 'provider_location',
            'location_scope' => 'point',
            'service_time_model' => 'none',
            'offer_requirement' => 'optional_offer',
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satilik', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'none', 'offer_requirement' => 'no_offer'],
                ['key' => 'rental', 'label' => 'Kiralik', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'date_range', 'offer_requirement' => 'no_offer'],
                ['key' => 'turistik_gunluk_kiralik', 'label' => 'Turistik Gunluk Kiralik', 'transaction_mode' => 'reservation', 'interaction_mode' => 'flow', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'slot', 'offer_requirement' => 'optional_offer'],
                ['key' => 'devren_satilik_konut', 'label' => 'Devren Satilik Konut', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'none', 'offer_requirement' => 'no_offer'],
            ],
        ],

        'is-yeri' => [
            'allowed_transaction_modes' => ['sale', 'rental'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'fulfillment_mode' => 'provider_location',
            'location_scope' => 'point',
            'service_time_model' => 'none',
            'offer_requirement' => 'no_offer',
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satilik', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'none', 'offer_requirement' => 'no_offer'],
                ['key' => 'rental', 'label' => 'Kiralik', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'date_range', 'offer_requirement' => 'no_offer'],
                ['key' => 'devren_satilik', 'label' => 'Devren Satilik', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'none', 'offer_requirement' => 'no_offer'],
                ['key' => 'devren_kiralik', 'label' => 'Devren Kiralik', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'date_range', 'offer_requirement' => 'no_offer'],
            ],
        ],

        'service-product' => [
            'allowed_transaction_modes' => ['sale'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'fulfillment_mode' => 'provider_location',
            'location_scope' => 'point',
            'service_time_model' => 'none',
            'offer_requirement' => 'no_offer',
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satilik', 'transaction_mode' => 'sale', 'interaction_mode' => 'flow', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'none', 'offer_requirement' => 'no_offer'],
            ],
        ],

        'events' => [
            'allowed_transaction_modes' => ['reservation'],
            'default_offer_variant' => 'reservation',
            'supports_packages' => true,
            'fulfillment_mode' => 'provider_location',
            'location_scope' => 'point',
            'service_time_model' => 'slot',
            'offer_requirement' => 'optional_offer',
            'offer_variants' => [
                ['key' => 'reservation', 'label' => 'Rezervasyon', 'transaction_mode' => 'reservation', 'interaction_mode' => 'flow', 'fulfillment_mode' => 'provider_location', 'location_scope' => 'point', 'service_time_model' => 'slot', 'offer_requirement' => 'optional_offer'],
            ],
        ],

        'food' => [
            'allowed_transaction_modes' => ['sale'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'fulfillment_mode' => 'customer_location',
            'location_scope' => 'service_area',
            'service_time_model' => 'none',
            'offer_requirement' => 'no_offer',
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Siparis Ver', 'transaction_mode' => 'sale', 'interaction_mode' => 'flow', 'fulfillment_mode' => 'customer_location', 'location_scope' => 'service_area', 'service_time_model' => 'none', 'offer_requirement' => 'no_offer'],
            ],
        ],
    ],
];
