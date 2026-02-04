<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * One-time data fix:
 * Backfill `attributes_json.interaction_mode` (and `offer_variant` when missing)
 * for legacy published listings so frontend CTA resolution becomes deterministic.
 *
 * Motivation:
 * - Frontend CTA resolver uses listing.attributes.interaction_mode ('flow'|'contact_only').
 * - Legacy rows can miss this field; UI falls back to flow which can show wrong CTAs.
 *
 * Safety:
 * - Only touches listings where interaction_mode is missing/null/empty.
 * - Does NOT overwrite existing interaction_mode values.
 * - Best-effort; skips rows with invalid JSON.
 */
return new class extends Migration
{
    private function defaultIntentSchema(): array
    {
        return [
            'allowed_transaction_modes' => ['sale', 'rental', 'reservation'],
            'default_offer_variant' => 'sale',
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'rental', 'label' => 'Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only'],
                ['key' => 'reservation', 'label' => 'Rezervasyon', 'transaction_mode' => 'reservation', 'interaction_mode' => 'flow'],
            ],
        ];
    }

    private function safeJsonDecode(?string $json): array
    {
        if ($json === null || trim($json) === '') return [];
        $data = json_decode($json, true);
        return is_array($data) ? $data : [];
    }

    private function safeJsonEncode(array $data): ?string
    {
        if (empty($data)) return null;
        return json_encode($data);
    }

    private function pickCanonicalMode(array $modes): string
    {
        $modes = array_values(array_filter(array_map('strval', $modes)));
        $set = [];
        foreach ($modes as $m) { $set[$m] = true; }
        if (isset($set['reservation'])) return 'reservation';
        if (isset($set['rental'])) return 'rental';
        if (isset($set['sale'])) return 'sale';
        return $modes[0] ?? 'sale';
    }

    /**
     * Resolve intent schema by walking up ancestors and matching by slug,
     * using config('category_flow_policy.rules').
     */
    private function resolveIntentSchemaForCategory(int $categoryId): array
    {
        $default = $this->defaultIntentSchema();
        $policy = config('category_flow_policy');
        $rules = is_array($policy) && isset($policy['rules']) && is_array($policy['rules']) ? $policy['rules'] : [];

        $visited = [];
        $currentId = $categoryId;
        $guard = 0;
        while ($currentId && $guard < 50) {
            $guard++;
            if (isset($visited[$currentId])) break;
            $visited[$currentId] = true;

            $row = DB::table('categories')
                ->where('id', $currentId)
                ->where('status', 'active')
                ->first();
            if (!$row) break;

            $slug = isset($row->slug) ? (string) $row->slug : '';
            if ($slug !== '' && isset($rules[$slug]) && is_array($rules[$slug])) {
                $merged = array_merge($default, $rules[$slug]);
                return $this->normalizeIntentSchema($merged, $default);
            }

            $currentId = $row->parent_id ? (int) $row->parent_id : 0;
        }

        return $default;
    }

    private function normalizeIntentSchema(array $schema, array $default): array
    {
        $allowedModes = isset($schema['allowed_transaction_modes']) && is_array($schema['allowed_transaction_modes'])
            ? array_values(array_filter(array_map('strval', $schema['allowed_transaction_modes'])))
            : $default['allowed_transaction_modes'];
        if (empty($allowedModes)) $allowedModes = $default['allowed_transaction_modes'];

        $defaultOfferVariant = isset($schema['default_offer_variant']) ? (string) $schema['default_offer_variant'] : $default['default_offer_variant'];
        if ($defaultOfferVariant === '') $defaultOfferVariant = $default['default_offer_variant'];

        $variants = [];
        $seen = [];
        $rawVariants = isset($schema['offer_variants']) && is_array($schema['offer_variants']) ? $schema['offer_variants'] : [];
        foreach ($rawVariants as $v) {
            if (!is_array($v)) continue;
            $key = isset($v['key']) ? (string) $v['key'] : '';
            if ($key === '' || isset($seen[$key])) continue;
            $seen[$key] = true;
            $variants[] = [
                'key' => $key,
                'label' => isset($v['label']) ? (string) $v['label'] : $key,
                'transaction_mode' => isset($v['transaction_mode']) ? (string) $v['transaction_mode'] : 'sale',
                'interaction_mode' => (isset($v['interaction_mode']) && (string) $v['interaction_mode'] === 'flow') ? 'flow' : 'contact_only',
            ];
        }
        if (empty($variants)) $variants = $default['offer_variants'];

        return [
            'allowed_transaction_modes' => $allowedModes,
            'default_offer_variant' => $defaultOfferVariant,
            'offer_variants' => $variants,
        ];
    }

    private function findVariantByKey(array $intentSchema, string $key): ?array
    {
        $variants = isset($intentSchema['offer_variants']) && is_array($intentSchema['offer_variants']) ? $intentSchema['offer_variants'] : [];
        foreach ($variants as $v) {
            if (is_array($v) && isset($v['key']) && (string) $v['key'] === $key) return $v;
        }
        return null;
    }

    private function findVariantForMode(array $intentSchema, string $mode): ?array
    {
        $variants = isset($intentSchema['offer_variants']) && is_array($intentSchema['offer_variants']) ? $intentSchema['offer_variants'] : [];
        foreach ($variants as $v) {
            if (!is_array($v)) continue;
            if (isset($v['transaction_mode']) && (string) $v['transaction_mode'] === $mode) return $v;
        }
        return null;
    }

    public function up(): void
    {
        if (!Schema::hasTable('listings') || !Schema::hasTable('categories')) {
            return;
        }

        // Only backfill published listings missing interaction_mode (or blank).
        DB::table('listings')
            ->select(['id', 'category_id', 'transaction_modes_json', 'attributes_json'])
            ->where('status', 'published')
            ->whereRaw("COALESCE(NULLIF(attributes_json::jsonb->>'interaction_mode',''), '') = ''")
            ->orderBy('id')
            ->chunk(200, function ($rows) {
                foreach ($rows as $row) {
                    $listingId = isset($row->id) ? (string) $row->id : '';
                    $categoryId = isset($row->category_id) ? (int) $row->category_id : 0;
                    if ($listingId === '' || $categoryId <= 0) continue;

                    $attrs = $this->safeJsonDecode(isset($row->attributes_json) ? (string) $row->attributes_json : null);
                    // Do not overwrite if another process filled it between select + update.
                    $existingMode = isset($attrs['interaction_mode']) ? (string) $attrs['interaction_mode'] : '';
                    if ($existingMode !== '') continue;

                    $modes = $this->safeJsonDecode(isset($row->transaction_modes_json) ? (string) $row->transaction_modes_json : null);
                    $canonicalMode = $this->pickCanonicalMode(is_array($modes) ? $modes : []);

                    $intent = $this->resolveIntentSchemaForCategory($categoryId);

                    $offerVariantKey = isset($attrs['offer_variant']) ? (string) $attrs['offer_variant'] : '';
                    $variant = null;
                    if ($offerVariantKey !== '') {
                        $variant = $this->findVariantByKey($intent, $offerVariantKey);
                    }
                    if (!$variant) {
                        $variant = $this->findVariantForMode($intent, $canonicalMode);
                    }

                    // Fill offer_variant if missing (best-effort)
                    if ($offerVariantKey === '') {
                        if ($variant && isset($variant['key'])) {
                            $offerVariantKey = (string) $variant['key'];
                        } else {
                            $offerVariantKey = $canonicalMode; // fallback
                        }
                        $attrs['offer_variant'] = $offerVariantKey;
                    }

                    // Fill interaction_mode (policy-derived if possible; otherwise conservative fallback).
                    if ($variant && isset($variant['interaction_mode'])) {
                        $attrs['interaction_mode'] = ((string) $variant['interaction_mode'] === 'flow') ? 'flow' : 'contact_only';
                    } else {
                        $attrs['interaction_mode'] = ($canonicalMode === 'reservation') ? 'flow' : 'contact_only';
                    }

                    DB::table('listings')
                        ->where('id', $listingId)
                        ->update([
                            'attributes_json' => $this->safeJsonEncode($attrs),
                            'updated_at' => now(),
                        ]);
                }
            });
    }

    public function down(): void
    {
        // Conservative rollback: do not delete or unset populated attributes.
        return;
    }
};

