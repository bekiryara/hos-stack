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
    'version' => 1,
    'rules' => [
        // Vasıta (Vehicle) — Sahibinden-like:
        // - "Satılık / Kiralık" is NOT a category branch; it's an offer_variant.
        // - User decision: Kiralık Araç = FLOW (rental workflow).
        'vehicle' => [
            'allowed_transaction_modes' => ['sale', 'rental'],
            'default_offer_variant' => 'sale',
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
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'rental', 'label' => 'Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only'],
                ['key' => 'devren_satilik', 'label' => 'Devren Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'devren_kiralik', 'label' => 'Devren Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only'],
            ],
        ],
    ],
];

