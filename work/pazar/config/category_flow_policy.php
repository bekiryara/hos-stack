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

    'rules' => [
        // Vasıta (Vehicle) — Sahibinden-like:
        // - "Satılık / Kiralık" is NOT a category branch; it's an offer_variant.
        // - User decision: Kiralık Araç = FLOW (rental workflow).
        'vehicle' => [
            'allowed_transaction_modes' => ['sale', 'rental'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'rental', 'label' => 'Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'flow'],
            ],
        ],

        // Sahibinden-like Emlak (Real Estate) intent sets
        // The category tree holds "what it is" (Konut / İş Yeri / Arsa ... + type leaves).
        // The second column is modeled here as "offer_variants".
        'konut' => [
            'allowed_transaction_modes' => ['sale', 'rental', 'reservation'],
            'default_offer_variant' => 'sale',
            'supports_packages' => true,
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'rental', 'label' => 'Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only'],
                // User decision: Airbnb-like reservation flow for daily rentals
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
        // No rental/reservation — physical goods are sold and shipped.
        'service-product' => [
            'allowed_transaction_modes' => ['sale'],
            'default_offer_variant' => 'sale',
            'supports_packages' => false,
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'flow'],
            ],
        ],

        // Etkinlik (Events): reservation flow only.
        // Tickets are booked and paid for upfront.
        'events' => [
            'allowed_transaction_modes' => ['reservation'],
            'default_offer_variant' => 'reservation',
            'supports_packages' => true,
            'offer_variants' => [
                ['key' => 'reservation', 'label' => 'Rezervasyon', 'transaction_mode' => 'reservation', 'interaction_mode' => 'flow'],
            ],
        ],

        // Yemek (Food): order flow only.
        // Food is ordered and delivered/picked up.
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

