<?php

/**
 * Catalog / Category / Listing helpers (SSOT)
 *
 * Rules:
 * - Do NOT add "maybe-needed later" placeholders.
 * - Only keep helpers that are used by multiple route modules.
 *
 * Loaded by: `work/pazar/routes/api.php`
 */

// Helper function to build category tree (WP-17: extract from closure, WP-72: optimized to O(n))
// WP-72: Changed from O(n²) to O(n) by building index first, but output remains identical
if (!function_exists('pazar_build_tree')) {
    function pazar_build_tree(array $categories, $parentId = null) {
        // WP-72: Build index by parent_id for O(n) lookup instead of O(n²) nested loops
        $indexedByParent = [];
        foreach ($categories as $category) {
            $pid = $category['parent_id'] ?? null;
            if (!isset($indexedByParent[$pid])) {
                $indexedByParent[$pid] = [];
            }
            $indexedByParent[$pid][] = $category;
        }
        
        // Recursive function using index (O(n) total)
        $buildBranch = function($pid) use (&$buildBranch, $indexedByParent) {
            $branch = [];
            if (!isset($indexedByParent[$pid])) {
                return $branch;
            }
            
            foreach ($indexedByParent[$pid] as $category) {
                $children = $buildBranch($category['id']);
                if (!empty($children)) {
                    $category['children'] = $children;
                }
                $branch[] = $category;
            }
            return $branch;
        };
        
        return $buildBranch($parentId);
    }
}

// Helper function to get all descendant category IDs recursively (WP-48, WP-72: optimized with CTE)
// Returns array of category IDs including the root category and all its descendants
if (!function_exists('pazar_category_descendant_ids')) {
    function pazar_category_descendant_ids(int $rootId): array {
        // WP-72: Use PostgreSQL recursive CTE to avoid N+1 queries
        // Single query instead of recursive PHP function calls
        $results = DB::select("
            WITH RECURSIVE category_tree AS (
                -- Base case: start with root category
                SELECT id, parent_id
                FROM categories
                WHERE id = ? AND status = 'active'
                
                UNION ALL
                
                -- Recursive case: get children of current level
                SELECT c.id, c.parent_id
                FROM categories c
                INNER JOIN category_tree ct ON c.parent_id = ct.id
                WHERE c.status = 'active'
            )
            SELECT id FROM category_tree
        ", [$rootId]);
        
        return array_map(function($row) {
            return (int) $row->id;
        }, $results);
    }
}

// Helper function to get SQL snippet and bindings for category descendant CTE (WP-73)
// Returns array with 'sql' (subquery snippet) and 'bindings' (array with root category id)
// Use in whereRaw("category_id IN (<sql>)", bindings)
if (!function_exists('pazar_category_descendant_cte_in_clause_sql')) {
    function pazar_category_descendant_cte_in_clause_sql(int $rootId): array {
        // WP-73: Return CTE subquery as SQL snippet to avoid building large ID arrays in PHP
        // Must include root category id in results
        return [
            'sql' => "(WITH RECURSIVE category_tree AS (
                SELECT id FROM categories WHERE id = ? AND status = 'active'
                UNION ALL
                SELECT c.id FROM categories c
                INNER JOIN category_tree ct ON c.parent_id = ct.id
                WHERE c.status = 'active'
            ) SELECT id FROM category_tree)",
            'bindings' => [$rootId]
        ];
    }
}

// Resolve category intent schema (CONTACT_ONLY vs FLOW) via config/category_flow_policy.php
// Walks up ancestors and matches by slug; returns a deterministic response shape.
if (!function_exists('pazar_category_intent_schema')) {
    function pazar_category_intent_schema(int $categoryId): array {
        // Default: allow all transaction modes, but treat reservation as FLOW.
        $default = [
            'allowed_transaction_modes' => ['sale', 'rental', 'reservation'],
            'default_offer_variant' => 'sale',
            'offer_variants' => [
                ['key' => 'sale', 'label' => 'Satılık', 'transaction_mode' => 'sale', 'interaction_mode' => 'contact_only'],
                ['key' => 'rental', 'label' => 'Kiralık', 'transaction_mode' => 'rental', 'interaction_mode' => 'contact_only'],
                ['key' => 'reservation', 'label' => 'Rezervasyon', 'transaction_mode' => 'reservation', 'interaction_mode' => 'flow'],
            ],
        ];

        $policy = config('category_flow_policy');
        $rules = is_array($policy) && isset($policy['rules']) && is_array($policy['rules']) ? $policy['rules'] : [];

        // Build ancestor chain from leaf to root
        $chain = [];
        $currentId = $categoryId;
        $guard = 0;
        while ($currentId && $guard < 50) {
            $guard++;
            $row = DB::table('categories')->where('id', $currentId)->first();
            if (!$row) break;
            $chain[] = $row;
            $currentId = $row->parent_id ? (int) $row->parent_id : 0;
        }

        $resolved = null;
        $resolvedFrom = null;
        foreach ($chain as $cat) {
            $slug = isset($cat->slug) ? (string) $cat->slug : '';
            if ($slug !== '' && isset($rules[$slug]) && is_array($rules[$slug])) {
                $resolved = $rules[$slug];
                $resolvedFrom = $cat;
                break;
            }
        }

        $schema = $resolved ? array_merge($default, $resolved) : $default;

        // Normalize offer_variants (array of objects with required keys)
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
                'interaction_mode' => isset($v['interaction_mode']) ? (string) $v['interaction_mode'] : 'contact_only',
            ];
        }
        if (empty($variants)) {
            $variants = $default['offer_variants'];
        }

        $allowedModes = isset($schema['allowed_transaction_modes']) && is_array($schema['allowed_transaction_modes'])
            ? array_values(array_filter(array_map('strval', $schema['allowed_transaction_modes'])))
            : $default['allowed_transaction_modes'];

        $defaultOfferVariant = isset($schema['default_offer_variant']) ? (string) $schema['default_offer_variant'] : $default['default_offer_variant'];
        if ($defaultOfferVariant === '') $defaultOfferVariant = $default['default_offer_variant'];        return [
            'category_id' => (int) $categoryId,
            'resolved_from' => $resolvedFrom ? [
                'category_id' => (int) $resolvedFrom->id,
                'category_slug' => (string) $resolvedFrom->slug,
            ] : null,
            'allowed_transaction_modes' => $allowedModes,
            'default_offer_variant' => $defaultOfferVariant,
            'offer_variants' => $variants,
        ];
    }
}

/**
 * Single-source-of-truth guard for listing write paths that can change:
 * - category_id
 * - attributes_json
 * - transaction_modes_json
 *
 * All entrypoints (Create / Update / Admin edits / Import) MUST call this guard to prevent drift.
 *
 * Returns:
 * - On success: array with normalized 'attributes' and 'transaction_modes'
 * - On failure: JSON response (422/4xx) with the same error shapes used by existing routes
 */
if (!function_exists('pazar_guard_listing_catalog_write')) {
    function pazar_guard_listing_catalog_write(int $categoryId, array $attributes, array $transactionModes) {
        // Guard must be self-sufficient: category must exist + be active.
        if (!\Illuminate\Support\Facades\Schema::hasTable('categories')) {
            return response()->json([
                'error' => 'catalog_unavailable',
                'message' => 'Catalog tables are not available',
            ], 500);
        }
        $categoryRow = \Illuminate\Support\Facades\DB::table('categories')
            ->where('id', $categoryId)
            ->where('status', 'active')
            ->first();
        if (!$categoryRow) {
            return response()->json([
                'error' => 'invalid_category',
                'message' => 'Listing write requires an active category',
                'category_id' => (int) $categoryId,
            ], 422);
        }

        // Phase-1 enforcement: leaf-only category selection for write paths.
        $hasActiveChild = \Illuminate\Support\Facades\DB::table('categories')
            ->where('parent_id', $categoryId)
            ->where('status', 'active')
            ->exists();
        if ($hasActiveChild) {
            return response()->json([
                'error' => 'non_leaf_category_not_allowed',
                'message' => 'Listing write requires a leaf category (category must not have active children)',
                'category_id' => (int) $categoryId,
            ], 422);
        }

        // Required attributes (if schema table + new fields exist).
        $hasNewFields = \Illuminate\Support\Facades\Schema::hasTable('category_filter_schema')
            && \Illuminate\Support\Facades\Schema::hasColumn('category_filter_schema', 'required');
        $hasAppliesToModes = \Illuminate\Support\Facades\Schema::hasTable('category_filter_schema')
            && \Illuminate\Support\Facades\Schema::hasColumn('category_filter_schema', 'applies_to_transaction_modes');

        $requiredAttributes = [];

        // Phase-1 enforcement: attributes must be schema-driven (whitelist by category_filter_schema).
        // Always allow policy meta keys (offer_variant, interaction_mode).
        $policyKeys = ['offer_variant' => true, 'interaction_mode' => true];
        $allowedKeys = [];
        if (\Illuminate\Support\Facades\Schema::hasTable('category_filter_schema')) {
            $allowedKeys = \Illuminate\Support\Facades\DB::table('category_filter_schema')
                ->where('category_id', $categoryId)
                ->where('status', 'active')
                ->pluck('attribute_key')
                ->map(function ($k) { return (string) $k; })
                ->values()
                ->all();
        }
        $allowedSet = $policyKeys;
        foreach ($allowedKeys as $k) { $allowedSet[$k] = true; }

        $unknownAttrKeys = [];
        foreach ($attributes as $k => $v) {
            if (!is_string($k) || $k === '') { continue; }
            if (!isset($allowedSet[$k])) {
                $unknownAttrKeys[] = $k;
            }
        }
        $unknownAttrKeys = array_values(array_unique($unknownAttrKeys));
        if (!empty($unknownAttrKeys)) {
            return response()->json([
                'error' => 'unknown_attribute_keys',
                'message' => 'Unknown attribute keys for this category (allowed keys are defined by catalog schema)',
                'category_id' => (int) $categoryId,
                'unknown_keys' => $unknownAttrKeys,
            ], 422);
        }

        // Resolve category intent schema and validate transaction_modes + offer_variant
        $intentSchema = pazar_category_intent_schema((int) $categoryId);
        $allowedModes = isset($intentSchema['allowed_transaction_modes']) && is_array($intentSchema['allowed_transaction_modes'])
            ? $intentSchema['allowed_transaction_modes']
            : ['sale', 'rental', 'reservation'];

        $requestedModes = is_array($transactionModes)
            ? array_values(array_filter(array_map('strval', $transactionModes)))
            : [];
        if (empty($requestedModes)) {
            return response()->json([
                'error' => 'invalid_transaction_modes',
                'message' => 'transaction_modes must include at least one mode'
            ], 422);
        }

        // Offer variant lives in attributes (schema-driven UI "2nd column" selection)
        $offerVariant = isset($attributes['offer_variant']) ? (string) $attributes['offer_variant'] : '';
        $resolvedVariant = null;
        if ($offerVariant !== '') {
            $variants = isset($intentSchema['offer_variants']) && is_array($intentSchema['offer_variants']) ? $intentSchema['offer_variants'] : [];
            foreach ($variants as $v) {
                if (is_array($v) && isset($v['key']) && (string) $v['key'] === $offerVariant) {
                    $resolvedVariant = $v;
                    break;
                }
            }
            if (!$resolvedVariant) {
                return response()->json([
                    'error' => 'invalid_offer_variant',
                    'message' => "Offer variant '{$offerVariant}' is not allowed for this category",
                    'allowed_offer_variants' => array_map(function ($v) {
                        return is_array($v) && isset($v['key']) ? (string) $v['key'] : null;
                    }, $variants),
                ], 422);
            }

            $impliedMode = isset($resolvedVariant['transaction_mode']) ? (string) $resolvedVariant['transaction_mode'] : '';
            if ($impliedMode === '' || !in_array($impliedMode, ['sale', 'rental', 'reservation'], true)) {
                return response()->json([
                    'error' => 'invalid_offer_variant',
                    'message' => "Offer variant '{$offerVariant}' does not define a valid transaction_mode"
                ], 422);
            }
            if (!in_array($impliedMode, $allowedModes, true)) {
                return response()->json([
                    'error' => 'invalid_transaction_modes',
                    'message' => "Transaction mode '{$impliedMode}' is not allowed for this category"
                ], 422);
            }
            // Deterministic: for now, listings have exactly one transaction mode (avoid ambiguous UX)
            if (count($requestedModes) !== 1 || $requestedModes[0] !== $impliedMode) {
                return response()->json([
                    'error' => 'invalid_transaction_modes',
                    'message' => "transaction_modes must match offer_variant '{$offerVariant}'",
                    'expected' => [$impliedMode],
                    'received' => $requestedModes,
                ], 422);
            }

            // Normalize interaction_mode from policy
            $interactionMode = isset($resolvedVariant['interaction_mode']) ? (string) $resolvedVariant['interaction_mode'] : '';
            if ($interactionMode !== 'flow') $interactionMode = 'contact_only';
            $attributes['interaction_mode'] = $interactionMode;
        } else {
            // If no offer_variant provided, still validate requested modes are allowed.
            foreach ($requestedModes as $m) {
                if (!in_array($m, $allowedModes, true)) {
                    return response()->json([
                        'error' => 'invalid_transaction_modes',
                        'message' => "Transaction mode '{$m}' is not allowed for this category",
                        'allowed_transaction_modes' => $allowedModes,
                    ], 422);
                }
            }

            // Normalize to a single mode (first) to keep listing semantics deterministic.
            $requestedModes = [$requestedModes[0]];

            // Auto-fill offer_variant if it matches a default key (sale/rental/reservation)
            $attributes['offer_variant'] = $requestedModes[0];
            $attributes['interaction_mode'] = ($requestedModes[0] === 'reservation') ? 'flow' : 'contact_only';
        }

        // Determine effective transaction mode (after offer_variant normalization).
        $effectiveMode = '';
        if (isset($impliedMode) && is_string($impliedMode) && $impliedMode !== '') {
            $effectiveMode = $impliedMode;
        } elseif (!empty($requestedModes) && isset($requestedModes[0])) {
            $effectiveMode = (string) $requestedModes[0];
        }
        $effectiveMode = $effectiveMode !== '' ? $effectiveMode : 'sale';

        // Phase-2 hardening: schema-driven applicability by transaction_mode.
        // - If applies_to_transaction_modes is NULL/empty => applies to all modes.
        // - Otherwise, only the listed modes can store this key.
        $droppedKeys = [];
        if ($hasAppliesToModes && \Illuminate\Support\Facades\Schema::hasTable('category_filter_schema')) {
            $rows = \Illuminate\Support\Facades\DB::table('category_filter_schema')
                ->where('category_id', $categoryId)
                ->where('status', 'active')
                ->select(['attribute_key', 'required', 'applies_to_transaction_modes'])
                ->get();

            $appliesMap = [];
            $requiredForMode = [];
            foreach ($rows as $r) {
                $k = isset($r->attribute_key) ? (string) $r->attribute_key : '';
                if ($k === '') continue;
                $applies = null;
                if (isset($r->applies_to_transaction_modes) && $r->applies_to_transaction_modes) {
                    $decoded = json_decode((string) $r->applies_to_transaction_modes, true);
                    if (is_array($decoded)) {
                        $list = array_values(array_filter(array_map('strval', $decoded)));
                        if (!empty($list)) $applies = $list;
                    }
                }
                $appliesMap[$k] = $applies; // null => all modes

                $isReq = $hasNewFields && isset($r->required) ? (bool) $r->required : false;
                if ($isReq) {
                    if ($applies === null || in_array($effectiveMode, $applies, true)) {
                        $requiredForMode[] = $k;
                    }
                }
            }

            // Drop keys not applicable for this mode (but keep policy keys always).
            foreach (array_keys($attributes) as $k) {
                if ($k === 'offer_variant' || $k === 'interaction_mode') continue;
                if (!array_key_exists($k, $appliesMap)) continue; // unknown keys handled earlier
                $applies = $appliesMap[$k];
                if (is_array($applies) && !in_array($effectiveMode, $applies, true)) {
                    unset($attributes[$k]);
                    $droppedKeys[] = $k;
                }
            }

            $requiredAttributes = $requiredForMode;
        } else {
            // Back-compat: if applies column doesn't exist, required = all required keys.
            if ($hasNewFields) {
                $requiredAttributes = \Illuminate\Support\Facades\DB::table('category_filter_schema')
                    ->where('category_id', $categoryId)
                    ->where('status', 'active')
                    ->where('required', true)
                    ->pluck('attribute_key')
                    ->toArray();
            }
        }

        // Enforce required keys (mode-aware when applies_to_transaction_modes exists).
        foreach ($requiredAttributes as $attrKey) {
            if (!array_key_exists($attrKey, $attributes)) {
                return response()->json([
                    'error' => 'missing_required_attribute',
                    'message' => "Required attribute '{$attrKey}' is missing",
                    'required_attributes' => $requiredAttributes
                ], 422);
            }
            $v = $attributes[$attrKey];
            $isEmpty = $v === null
                || (is_string($v) && trim($v) === '')
                || (is_array($v) && count($v) === 0);
            if ($isEmpty) {
                return response()->json([
                    'error' => 'missing_required_attribute',
                    'message' => "Required attribute '{$attrKey}' is missing or empty",
                    'required_attributes' => $requiredAttributes
                ], 422);
            }
        }

        if (!empty($droppedKeys)) {
            try {
                if (app()->environment('local') || env('APP_DEBUG', 'false') === 'true') {
                    \Illuminate\Support\Facades\Log::debug('Dropped mode-incompatible listing attributes (schema applicability)', [
                        'category_id' => (int) $categoryId,
                        'effective_mode' => $effectiveMode,
                        'dropped_keys' => array_values($droppedKeys),
                    ]);
                }
            } catch (\Throwable $e) {
                // ignore logging failures (must not block listing writes)
            }
        }

        // Type check attributes against attribute definitions
        if (!empty($attributes)) {
            $attributeDefs = \Illuminate\Support\Facades\DB::table('attributes')
                ->whereIn('key', array_keys($attributes))
                ->pluck('value_type', 'key')
                ->toArray();

            foreach ($attributes as $key => $value) {
                if (isset($attributeDefs[$key])) {
                    $valueType = $attributeDefs[$key];
                    $isValid = false;

                    switch ($valueType) {
                        case 'number':
                            $isValid = is_numeric($value);
                            break;
                        case 'string':
                            $isValid = is_string($value);
                            break;
                        case 'boolean':
                            $lower = is_string($value) ? strtolower($value) : (is_scalar($value) ? strtolower((string) $value) : '');
                            $isValid = is_bool($value) || in_array($lower, ['true', 'false', '1', '0', 'yes', 'no'], true);
                            break;
                        default:
                            $isValid = true; // Unknown types pass
                    }

                    if (!$isValid) {
                        return response()->json([
                            'error' => 'invalid_attribute_type',
                            'message' => "Attribute '{$key}' must be of type '{$valueType}'",
                            'attribute' => $key,
                            'value' => $value,
                            'expected_type' => $valueType
                        ], 422);
                    }
                }
            }
        }

        return [
            'category_id' => (int) $categoryId,
            'attributes' => $attributes,
            'transaction_modes' => $requestedModes,
            'intent_schema' => $intentSchema,
        ];
    }
}
