<?php

/**
 * Category Flow Policy (CONTACT_ONLY vs FLOW)
 *
 * Purpose:
 * - Keep "2nd column" (Satılık/Kiralık/Devren/...) out of the category tree.
 * - Drive UI choices and backend validation from a single source of truth.
 *
 * Notes:
 * - `transaction_mode` is canonical: sale|rental|reservation
 * - `interaction_mode` is UX/workflow: contact_only|flow
 * - Rules are resolved by walking up category ancestors and matching by `slug`.
 */
return [
    'version' => 2,

    // Canonical transaction modes (single source of truth for the entire system).
    // Every file that needs to validate or list modes MUST read from here.
    'canonical_transaction_modes' => ['sale', 'rental', 'reservation'],

    // Slug prefixes whose categories are selectable for listing creation even if
    // they have active children (e.g. Trendyol product taxonomy allows binding to
    // non-leaf categories). All other categories require leaf selection.
    'non_leaf_selectable_prefixes' => ['service-product-ty-c'],

    // Card display config: which attribute is the price and what to highlight.
    // Frontend reads this to render listing cards per vertical — one component, all verticals.
    'card_display' => [
        'vehicle' => [
            'price_field' => 'vehicle_price',
            'currency' => 'TRY',
            'highlights' => ['vehicle_model', 'vehicle_year', 'city', 'vehicle_km_bucket'],
        ],
        'konut' => [
            'price_field' => 'rent_price',
            'currency' => 'TRY',
            'highlights' => ['city', 'room_count', 'area_m2'],
        ],
        'is-yeri' => [
            'price_field' => 'rent_price',
            'currency' => 'TRY',
            'highlights' => ['city', 'area_m2'],
        ],
        'service-product' => [
            'price_field' => 'product_price',
            'currency' => 'TRY',
            'highlights' => ['product_brand', 'product_condition'],
        ],
        'events' => [
            'price_field' => 'event_price',
            'currency' => 'TRY',
            'highlights' => ['city', 'capacity_max'],
        ],
        'food' => [
            'price_field' => 'product_price',
            'currency' => 'TRY',
            'highlights' => ['city'],
        ],
    ],

    'rules' => [
        // Vasıta (Vehicle) — Sahibinden-like:
        'vehicle' => [
            'allowed_transaction_modes' => ['sale', 'rental'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'rental', 'label' => 'Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'flow'],
            ],
        ],

        // Sahibinden-like Emlak (Real Estate)
        'konut' => [
            'allowed_transaction_modes' => ['sale', 'rental', 'reservation'],
            'default_offer_variant' => 'sale',
            'supports_packages' => true,
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'rental', 'label' => 'Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only'],
                ['key' => 'turistik_gunluk_kiralik', 'label' => 'Turistik Günlük Kiralık', 'transaction_mode' => 'reservation', 'interaction_mode' => 'flow'],
                ['key' => 'devren_satilik_konut', 'label' => 'Devren Satılık Konut', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
            ],
        ],
        'is-yeri' => [
            'allowed_transaction_modes' => ['sale', 'rental'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'rental', 'label' => 'Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only'],
                ['key' => 'devren_satilik', 'label' => 'Devren Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'devren_kiralik', 'label' => 'Devren Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only'],
            ],
        ],

        // Ürün (Trendyol e-commerce): order flow only.
        'service-product' => [
            'allowed_transaction_modes' => ['sale'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'flow'],
            ],
        ],

        // Etkinlik (Events): reservation flow only.
        'events' => [
            'allowed_transaction_modes' => ['reservation'],
            'default_offer_variant' => 'reservation',
            'supports_packages' => true,
            'offer_variants' => [
                ['key' => 'reservation', 'label' => 'Rezervasyon', 'transaction_mode' => 'reservation', 'interaction_mode' => 'flow'],
            ],
        ],

        // Yemek (Food): order flow only.
        'food' => [
            'allowed_transaction_modes' => ['sale'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Sipariş Ver', 'transaction_mode' => 'sale', 'interaction_mode' => 'flow'],
            ],
        ],
    ],
];

