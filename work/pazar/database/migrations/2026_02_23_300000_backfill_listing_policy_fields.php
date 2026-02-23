<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Backfill interaction_mode and offer_variant for all existing listings
 * using the current category_flow_policy.
 *
 * This ensures DB values match the policy (important for reports/exports).
 * The read-time normalization layer in 03b_listings_read.php handles API
 * responses independently, so this migration is a "DB hygiene" step.
 */
return new class extends Migration
{
    public function up(): void
    {
        $listings = DB::table('listings')
            ->whereNotNull('category_id')
            ->select(['id', 'category_id', 'attributes_json', 'transaction_modes_json'])
            ->get();

        $updated = 0;
        $skipped = 0;

        foreach ($listings as $listing) {
            $categoryId = (int) $listing->category_id;
            if ($categoryId <= 0) {
                $skipped++;
                continue;
            }

            $attrs = $listing->attributes_json ? json_decode($listing->attributes_json, true) : [];
            if (!is_array($attrs)) $attrs = [];

            $offerVariant = isset($attrs['offer_variant']) ? (string) $attrs['offer_variant'] : '';

            try {
                $intent = pazar_category_intent_schema($categoryId);
            } catch (\Throwable $e) {
                $skipped++;
                continue;
            }

            $variants = isset($intent['offer_variants']) && is_array($intent['offer_variants'])
                ? $intent['offer_variants'] : [];

            $matched = null;
            foreach ($variants as $v) {
                if (is_array($v) && isset($v['key']) && (string) $v['key'] === $offerVariant) {
                    $matched = $v;
                    break;
                }
            }
            if (!$matched && !empty($variants)) {
                $matched = $variants[0];
            }
            if (!$matched) {
                $skipped++;
                continue;
            }

            $newInteractionMode = isset($matched['interaction_mode']) && $matched['interaction_mode'] === 'flow'
                ? 'flow' : 'contact_only';
            $newOfferVariant = (string) $matched['key'];
            $newTxMode = isset($matched['transaction_mode']) ? (string) $matched['transaction_mode'] : '';

            $oldInteractionMode = isset($attrs['interaction_mode']) ? (string) $attrs['interaction_mode'] : '';
            $oldOfferVariant = $offerVariant;
            $oldTxModes = $listing->transaction_modes_json ? json_decode($listing->transaction_modes_json, true) : [];

            $needsUpdate = false;

            if ($oldInteractionMode !== $newInteractionMode) {
                $attrs['interaction_mode'] = $newInteractionMode;
                $needsUpdate = true;
            }
            if ($oldOfferVariant !== $newOfferVariant) {
                $attrs['offer_variant'] = $newOfferVariant;
                $needsUpdate = true;
            }

            $newTxModes = $oldTxModes;
            if ($newTxMode !== '' && in_array($newTxMode, ['sale', 'rental', 'reservation'], true)) {
                if ($oldTxModes !== [$newTxMode]) {
                    $newTxModes = [$newTxMode];
                    $needsUpdate = true;
                }
            }

            if ($needsUpdate) {
                DB::table('listings')
                    ->where('id', $listing->id)
                    ->update([
                        'attributes_json' => json_encode($attrs),
                        'transaction_modes_json' => json_encode($newTxModes),
                        'updated_at' => now(),
                    ]);
                $updated++;
            } else {
                $skipped++;
            }
        }

        echo "Backfill complete: {$updated} updated, {$skipped} already correct.\n";
    }

    public function down(): void
    {
        // Policy-derived fields are not reversible to a specific old state.
        // The read-time normalization layer ensures correct values regardless.
    }
};
