<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// Supply Spine Endpoints (WP-3)
// POST /v1/listings - Create DRAFT listing
// WP-8: STORE persona requires X-Active-Tenant-Id header (persona.scope:store)
// WP-26: Tenant scope enforced via tenant.scope middleware
// WP-29: Auth required via auth.any middleware (when GENESIS_ALLOW_UNAUTH_STORE=0)
// WP-50: AuthAny middleware now validates JWT tokens (allows user-like auth flow)
// WP-61B: In GENESIS mode (GENESIS_ALLOW_UNAUTH_STORE=1), Authorization is optional per SPEC §5.2
// WP-48: Use full class name to avoid Laravel terminate phase alias resolution issue
// WP-61B: Build middleware array conditionally based on GENESIS_ALLOW_UNAUTH_STORE
$createListingMiddleware = [\App\Http\Middleware\PersonaScope::class . ':store'];
if (env('GENESIS_ALLOW_UNAUTH_STORE', '1') !== '1') {
    $createListingMiddleware[] = 'auth.any';
}
$createListingMiddleware[] = 'tenant.scope';
Route::middleware($createListingMiddleware)->post('/v1/listings', function (\Illuminate\Http\Request $request) {
    // WP-26: tenant_id is set by TenantScope middleware
    // WP-28: Guard against null tenant_id (fail-fast if middleware didn't run)
    $tenantId = $request->attributes->get('tenant_id');
    if (!$tenantId) {
        return response()->json([
            'error' => 'missing_header',
            'message' => 'X-Active-Tenant-Id header is required'
        ], 400);
    }
    
    // Validate required fields
    $validated = $request->validate([
        // Phase-1 enforcement: category must be active (aligns with read path semantics).
        'category_id' => 'required|integer|exists:categories,id,status,active',
        'title' => 'required|string|max:120',
        'description' => 'nullable|string',
        'transaction_modes' => 'required|array|min:1',
        'transaction_modes.*' => 'string|in:sale,rental,reservation',
        'attributes' => 'nullable|array',
        'location' => 'nullable|array'
    ]);
    
    // Get category filter schema to validate required attributes
    $categoryId = $validated['category_id'];
    // Phase-1 enforcement: leaf-only category selection for create (prevents root/branch drift).
    $hasActiveChild = DB::table('categories')
        ->where('parent_id', $categoryId)
        ->where('status', 'active')
        ->exists();
    if ($hasActiveChild) {
        return response()->json([
            'error' => 'non_leaf_category_not_allowed',
            'message' => 'Create listing requires a leaf category (category must not have active children)',
            'category_id' => (int) $categoryId,
        ], 422);
    }
    // WP-28: Guard schema/table checks (hasTable before hasColumn)
    $hasNewFields = Schema::hasTable('category_filter_schema') && Schema::hasColumn('category_filter_schema', 'required');
    
    $requiredAttributes = [];
    if ($hasNewFields) {
        $requiredAttributes = DB::table('category_filter_schema')
            ->where('category_id', $categoryId)
            ->where('status', 'active')
            ->where('required', true)
            ->pluck('attribute_key')
            ->toArray();
    }
    
    // Validate required attributes exist in attributes_json
    $attributes = $validated['attributes'] ?? [];

    // Phase-1 enforcement: attributes must be schema-driven (whitelist by category_filter_schema).
    // Always allow policy meta keys (offer_variant, interaction_mode).
    $policyKeys = ['offer_variant' => true, 'interaction_mode' => true];
    $allowedKeys = [];
    if (Schema::hasTable('category_filter_schema')) {
        $allowedKeys = DB::table('category_filter_schema')
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
            'unknown_keys' => $unknownAttrKeys,
        ], 422);
    }

    foreach ($requiredAttributes as $attrKey) {
        if (!isset($attributes[$attrKey])) {
            return response()->json([
                'error' => 'missing_required_attribute',
                'message' => "Required attribute '{$attrKey}' is missing",
                'required_attributes' => $requiredAttributes
            ], 422);
        }
    }

    // Resolve category intent schema (CONTACT_ONLY vs FLOW) and validate transaction_modes + offer_variant
    $intentSchema = pazar_category_intent_schema((int) $categoryId);
    $allowedModes = isset($intentSchema['allowed_transaction_modes']) && is_array($intentSchema['allowed_transaction_modes'])
        ? $intentSchema['allowed_transaction_modes']
        : ['sale', 'rental', 'reservation'];

    $requestedModes = $validated['transaction_modes'] ?? [];
    $requestedModes = is_array($requestedModes) ? array_values(array_filter(array_map('strval', $requestedModes))) : [];
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
    
    // Type check attributes against attribute definitions
    if (!empty($attributes)) {
        $attributeDefs = DB::table('attributes')
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
                        $isValid = is_bool($value) || in_array(strtolower($value), ['true', 'false', '1', '0', 'yes', 'no']);
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
    
    // listings.world is the H-OS world key for Pazar listings.
    // Pazar is the Marketplace world, so listings in this service are always marketplace-scoped.
    $world = 'marketplace';
    
    // Create listing as DRAFT
    $listingId = \Illuminate\Support\Str::uuid()->toString();
    
    DB::table('listings')->insert([
        'id' => $listingId,
        'tenant_id' => $tenantId,
        'world' => $world,
        'category_id' => $categoryId,
        'title' => $validated['title'],
        'description' => $validated['description'] ?? null,
        'transaction_modes_json' => json_encode($requestedModes),
        'attributes_json' => !empty($attributes) ? json_encode($attributes) : null,
        'location_json' => isset($validated['location']) ? json_encode($validated['location']) : null,
        'status' => 'draft',
        'created_at' => now(),
        'updated_at' => now()
    ]);
    
    return response()->json([
        'id' => $listingId,
        'tenant_id' => $tenantId,
        'category_id' => $categoryId,
        'title' => $validated['title'],
        'status' => 'draft',
        'created_at' => now()->toISOString()
    ], 201);
});

// POST /v1/listings/{id}/publish - Publish listing
// WP-8: STORE persona requires X-Active-Tenant-Id header (persona.scope:store)
// WP-26: Tenant scope enforced via tenant.scope middleware
// WP-29: Auth required via auth.any middleware (when GENESIS_ALLOW_UNAUTH_STORE=0)
// WP-50: AuthAny middleware now validates JWT tokens (allows user-like auth flow)
// WP-61B: In GENESIS mode (GENESIS_ALLOW_UNAUTH_STORE=1), Authorization is optional per SPEC §5.2
// WP-48: Use full class name to avoid Laravel terminate phase alias resolution issue
// WP-61B: Build middleware array conditionally based on GENESIS_ALLOW_UNAUTH_STORE
$publishListingMiddleware = [\App\Http\Middleware\PersonaScope::class . ':store'];
if (env('GENESIS_ALLOW_UNAUTH_STORE', '1') !== '1') {
    $publishListingMiddleware[] = 'auth.any';
}
$publishListingMiddleware[] = 'tenant.scope';
Route::middleware($publishListingMiddleware)->post('/v1/listings/{id}/publish', function ($id, \Illuminate\Http\Request $request) {
    // WP-26: tenant_id is set by TenantScope middleware
    // WP-28: Guard against null tenant_id (fail-fast if middleware didn't run)
    $tenantId = $request->attributes->get('tenant_id');
    if (!$tenantId) {
        return response()->json([
            'error' => 'missing_header',
            'message' => 'X-Active-Tenant-Id header is required'
        ], 400);
    }
    
    // Find listing
    $listing = DB::table('listings')->where('id', $id)->first();
    if (!$listing) {
        return response()->json([
            'error' => 'listing_not_found',
            'message' => "Listing with id {$id} not found"
        ], 404);
    }
    
    // Check tenant ownership
    if ($listing->tenant_id !== $tenantId) {
        return response()->json([
            'error' => 'forbidden',
            'message' => 'Only the listing owner can publish this listing'
        ], 403);
    }
    
    // Check status is draft
    if ($listing->status !== 'draft') {
        return response()->json([
            'error' => 'invalid_status',
            'message' => "Listing must be in 'draft' status to publish. Current status: {$listing->status}"
        ], 422);
    }
    
    // Update status to published
    DB::table('listings')
        ->where('id', $id)
        ->update([
            'status' => 'published',
            'updated_at' => now()
        ]);
    
    $updated = DB::table('listings')->where('id', $id)->first();
    
    return response()->json([
        'id' => $updated->id,
        'tenant_id' => $updated->tenant_id,
        'category_id' => $updated->category_id,
        'title' => $updated->title,
        'status' => $updated->status,
        'updated_at' => $updated->updated_at
    ]);
});


