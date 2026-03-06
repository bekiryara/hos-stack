<?php

if (!function_exists('pazar_resolve_transaction_pricing')) {
    function pazar_pricing_parse_datetime($value): ?\DateTimeImmutable {
        if ($value instanceof \DateTimeInterface) {
            return \DateTimeImmutable::createFromInterface($value);
        }
        if (!is_string($value) || trim($value) === '') return null;
        try {
            return new \DateTimeImmutable(trim($value));
        } catch (\Throwable $e) {
            return null;
        }
    }

    function pazar_pricing_duration_seconds(array $context): ?int {
        $start = pazar_pricing_parse_datetime($context['start_at'] ?? null);
        $end = pazar_pricing_parse_datetime($context['end_at'] ?? null);
        if (!$start || !$end) return null;
        $seconds = $end->getTimestamp() - $start->getTimestamp();
        if ($seconds <= 0) return null;
        return $seconds;
    }

    function pazar_pricing_multiplier(string $billingModel, array $context): int {
        $quantity = isset($context['quantity']) && is_numeric($context['quantity'])
            ? max(1, (int) $context['quantity'])
            : 1;
        $partySize = isset($context['party_size']) && is_numeric($context['party_size'])
            ? max(1, (int) $context['party_size'])
            : 1;
        $seconds = pazar_pricing_duration_seconds($context);

        switch ($billingModel) {
            case 'per_person':
                return $partySize;
            case 'per_hour':
                if (!$seconds) return 1;
                return max(1, (int) ceil($seconds / 3600));
            case 'per_day':
            case 'per_night':
                if (!$seconds) return 1;
                return max(1, (int) ceil($seconds / 86400));
            case 'per_month':
                if (!$seconds) return 1;
                return max(1, (int) ceil($seconds / (30 * 86400)));
            case 'per_session':
            case 'per_visit':
                return $quantity;
            case 'one_time':
            default:
                return $quantity;
        }
    }

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
    function pazar_resolve_transaction_pricing(object $listing, ?object $offer = null, ?array $effectivePolicy = null, array $context = []): array {
        $policy = is_array($effectivePolicy) ? $effectivePolicy : [];
        $defaultBilling = isset($policy['billing_model']) && is_string($policy['billing_model']) && trim($policy['billing_model']) !== ''
            ? trim((string) $policy['billing_model'])
            : 'one_time';

        $unitPriceAmount = null;
        $priceCurrency = 'TRY';
        $billingModel = $defaultBilling;
        $offerId = null;
        $pricingSource = 'listing';

        if ($offer) {
            if (!is_numeric($offer->price_amount)) {
                throw new \InvalidArgumentException('Selected offer is missing canonical price_amount');
            }

            $pricingSource = 'offer';
            $unitPriceAmount = (int) $offer->price_amount;
            $priceCurrency = is_string($offer->price_currency) && trim($offer->price_currency) !== ''
                ? strtoupper(trim((string) $offer->price_currency))
                : 'TRY';
            $billingModel = is_string($offer->billing_model) && trim($offer->billing_model) !== ''
                ? trim((string) $offer->billing_model)
                : $defaultBilling;
            $offerId = $offer->id ?? null;
        } else {
            if (!is_numeric($listing->price_amount)) {
                throw new \InvalidArgumentException('Listing is missing canonical price_amount');
            }
            $unitPriceAmount = (int) $listing->price_amount;
            $priceCurrency = is_string($listing->currency) && trim($listing->currency) !== ''
                ? strtoupper(trim((string) $listing->currency))
                : 'TRY';
        }

        $multiplier = pazar_pricing_multiplier($billingModel, $context);
        $totalAmount = (int) round($unitPriceAmount * $multiplier);

        return [
            'pricing_source' => $pricingSource,
            // Legacy alias kept for compatibility with existing call-sites.
            'price_amount' => $unitPriceAmount,
            'unit_price_amount' => $unitPriceAmount,
            'multiplier' => $multiplier,
            'total_amount' => $totalAmount,
            'price_currency' => $priceCurrency,
            'billing_model' => $billingModel,
            'offer_id' => $offerId,
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
