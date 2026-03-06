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
    function pazar_resolve_transaction_pricing(object $listing, ?object $offer = null, ?array $effectivePolicy = null): array {
        $policy = is_array($effectivePolicy) ? $effectivePolicy : [];
        $defaultBilling = isset($policy['billing_model']) && is_string($policy['billing_model']) && trim($policy['billing_model']) !== ''
            ? trim((string) $policy['billing_model'])
            : 'one_time';
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
                    : $defaultBilling,
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
            'billing_model' => $defaultBilling,
            'offer_id' => null,
        ];
    }
}

if (!function_exists('pazar_listing_effective_policy')) {
    function pazar_listing_effective_policy(object $listing): array {
        $intent = pazar_category_intent_schema((int) $listing->category_id);
        $attrs = [];
        if (isset($listing->attributes_json) && $listing->attributes_json) {
            $decoded = json_decode((string) $listing->attributes_json, true);
            if (is_array($decoded)) $attrs = $decoded;
        }
        $offerVariant = isset($attrs['offer_variant']) && is_string($attrs['offer_variant'])
            ? trim((string) $attrs['offer_variant'])
            : '';
        return pazar_effective_intent_policy($intent, $offerVariant);
    }
}

if (!function_exists('pazar_validate_transaction_offer_policy')) {
    function pazar_validate_transaction_offer_policy(array $effectivePolicy, ?string $offerId, bool $supportsOfferSelection, string $flowLabel = 'Transaction') {
        $pricingStrategy = isset($effectivePolicy['pricing_strategy']) ? (string) $effectivePolicy['pricing_strategy'] : 'base_only';
        $offerRequirement = isset($effectivePolicy['offer_requirement']) ? (string) $effectivePolicy['offer_requirement'] : 'no_offer';
        $hasOffer = is_string($offerId) && trim($offerId) !== '';

        if (!$supportsOfferSelection && $hasOffer) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => strtolower($flowLabel) . ' create does not support offer selection in v1'
            ], 422);
        }

        if ($pricingStrategy === 'offer_only' && !$hasOffer) {
            if ($supportsOfferSelection) {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'offer_id is required for pricing_strategy=offer_only'
                ], 422);
            }
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => strtolower($flowLabel) . ' create requires offer selection, but offer-based flow is not supported in v1'
            ], 422);
        }

        if ($offerRequirement === 'required_offer' && !$hasOffer) {
            if ($supportsOfferSelection) {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'offer_id is required for this service model'
                ], 422);
            }
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => strtolower($flowLabel) . ' create requires offer selection, but offer-based flow is not supported in v1'
            ], 422);
        }

        if ($offerRequirement === 'no_offer' && $hasOffer) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => 'offer_id is not allowed for this service model'
            ], 422);
        }

        return null;
    }
}
