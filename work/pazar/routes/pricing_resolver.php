<?php

if (!function_exists('pazar_resolve_transaction_pricing')) {
    /**
     * Resolve canonical transaction pricing snapshot.
     *
     * Rules:
     * - If an active offer is selected, offer pricing wins.
     * - Otherwise listing canonical price_amount / currency is used.
     * - billing_model is only known for offers today; listing-based pricing returns null.
     *
     * @throws \InvalidArgumentException when no canonical pricing source exists
     */
    function pazar_resolve_transaction_pricing(object $listing, ?object $offer = null): array {
        if ($offer) {
            if (!is_numeric($offer->price_amount)) {
                throw new \InvalidArgumentException('Selected offer is missing canonical price_amount');
            }

            return [
                'pricing_source' => 'offer',
                'price_amount' => (int) $offer->price_amount,
                'price_currency' => is_string($offer->price_currency) && trim($offer->price_currency) !== ''
                    ? strtoupper(trim((string) $offer->price_currency))
                    : 'TRY',
                'billing_model' => is_string($offer->billing_model) && trim($offer->billing_model) !== ''
                    ? trim((string) $offer->billing_model)
                    : null,
                'offer_id' => $offer->id ?? null,
            ];
        }

        if (!is_numeric($listing->price_amount)) {
            throw new \InvalidArgumentException('Listing is missing canonical price_amount');
        }

        return [
            'pricing_source' => 'listing',
            'price_amount' => (int) $listing->price_amount,
            'price_currency' => is_string($listing->currency) && trim($listing->currency) !== ''
                ? strtoupper(trim((string) $listing->currency))
                : 'TRY',
            'billing_model' => null,
            'offer_id' => null,
        ];
    }
}
