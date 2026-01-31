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
        'category_id' => 'required|integer|exists:categories,id',
        'title' => 'required|string|max:120',
        'description' => 'nullable|string',
        'transaction_modes' => 'required|array|min:1',
        'transaction_modes.*' => 'string|in:sale,rental,reservation',
        'attributes' => 'nullable|array',
        'location' => 'nullable|array'
    ]);
    
    $categoryId = (int) $validated['category_id'];
    $attributes = $validated['attributes'] ?? [];
    
    // P0 CORE: Leaf-only category rule (server-side hard lock)
    $hasChildren = DB::table('categories')->where('parent_id', $categoryId)->exists();
    if ($hasChildren) {
        return response()->json([
            'error' => 'leaf_category_required',
            'message' => 'Listing can only be created under leaf categories (categories without children)',
            'code' => 'leaf_category_required',
            'details' => ['category_id' => $categoryId],
        ], 422);
    }
    
    // P0 CORE: Build schemaMap from category_filter_schema (+ attributes.value_type)
    $hasSchemaTable = Schema::hasTable('category_filter_schema') && Schema::hasColumn('category_filter_schema', 'required');
    $allowedKeys = [];
    $requiredKeys = [];
    $optionsMap = [];
    $typeMap = [];
    
    if ($hasSchemaTable) {
        $schemaRows = DB::table('category_filter_schema')
            ->leftJoin('attributes', 'category_filter_schema.attribute_key', '=', 'attributes.key')
            ->where('category_filter_schema.category_id', $categoryId)
            ->where('category_filter_schema.status', 'active')
            ->select(
                'category_filter_schema.attribute_key',
                'category_filter_schema.required',
                'category_filter_schema.rules_json',
                'attributes.value_type'
            )
            ->get();
        
        foreach ($schemaRows as $row) {
            $key = $row->attribute_key;
            $allowedKeys[] = $key;
            if ($row->required) {
                $requiredKeys[] = $key;
            }
            $typeMap[$key] = $row->value_type ?? 'string';
            if ($row->rules_json) {
                $rules = json_decode($row->rules_json, true);
                if (isset($rules['options']) && is_array($rules['options'])) {
                    $optionsMap[$key] = array_map('strval', array_values(array_filter($rules['options'], function ($o) {
                        return $o !== null && $o !== '';
                    })));
                }
            }
        }
    }
    
    $allowedSet = array_flip($allowedKeys);
    
    // Reject unknown attribute keys
    $unknownKeys = [];
    foreach (array_keys($attributes) as $k) {
        if (!isset($allowedSet[$k])) {
            $unknownKeys[] = $k;
        }
    }
    if (!empty($unknownKeys)) {
        return response()->json([
            'error' => 'unknown_attribute_keys',
            'message' => 'Unknown attribute keys for this category',
            'code' => 'unknown_attribute_keys',
            'details' => ['unknown_keys' => $unknownKeys],
        ], 422);
    }
    
    // Reject missing required (boolean false counts as present)
    $missing = [];
    foreach ($requiredKeys as $k) {
        if (!array_key_exists($k, $attributes)) {
            $missing[] = $k;
        } else {
            $v = $attributes[$k];
            if ($v === null || $v === '' || (is_string($v) && trim($v) === '')) {
                $missing[] = $k;
            }
        }
    }
    if (!empty($missing)) {
        return response()->json([
            'error' => 'missing_required_attribute',
            'message' => 'Required attributes are missing',
            'code' => 'missing_required_attribute',
            'details' => ['missing' => $missing],
        ], 422);
    }
    
    // Enforce enum/select options and type checks
    $invalidValues = [];
    foreach ($attributes as $key => $value) {
        // Skip empty optional (already validated required above)
        if ($value === null || $value === '' || (is_string($value) && trim($value) === '')) {
            continue;
        }
        // Boolean false counts as present and valid
        if ($value === false || $value === 'false' || $value === '0' || $value === 0) {
            if (isset($typeMap[$key]) && $typeMap[$key] === 'boolean') {
                continue;
            }
            if (isset($optionsMap[$key])) {
                if (in_array('false', $optionsMap[$key], true) || in_array('0', $optionsMap[$key], true)) {
                    continue;
                }
            }
        }
        if (isset($optionsMap[$key]) && !empty($optionsMap[$key])) {
            $strVal = is_string($value) ? $value : (string) $value;
            if (!in_array($strVal, $optionsMap[$key], true)) {
                $invalidValues[$key] = $value;
            }
        } elseif (isset($typeMap[$key])) {
            $valueType = $typeMap[$key];
            $isValid = false;
            switch ($valueType) {
                case 'number':
                    $isValid = is_numeric($value);
                    break;
                case 'string':
                    $isValid = is_string($value) || is_numeric($value);
                    break;
                case 'boolean':
                    $isValid = is_bool($value) || in_array(strtolower((string) $value), ['true', 'false', '1', '0', 'yes', 'no']);
                    break;
                case 'enum':
                    $isValid = isset($optionsMap[$key]) ? in_array((string) $value, $optionsMap[$key], true) : true;
                    break;
                default:
                    $isValid = true;
            }
            if (!$isValid) {
                $invalidValues[$key] = $value;
            }
        }
    }
    if (!empty($invalidValues)) {
        return response()->json([
            'error' => 'invalid_attribute_value',
            'message' => 'Invalid attribute value(s)',
            'code' => 'invalid_attribute_value',
            'details' => ['invalid_values' => $invalidValues],
        ], 422);
    }
    
    // Get category to determine world/vertical
    $category = DB::table('categories')->where('id', $categoryId)->first();
    $world = $category->vertical ?? 'commerce'; // Default to 'commerce' if vertical not set
    
    // Create listing as DRAFT
    $listingId = \Illuminate\Support\Str::uuid()->toString();
    
    DB::table('listings')->insert([
        'id' => $listingId,
        'tenant_id' => $tenantId,
        'world' => $world,
        'category_id' => $categoryId,
        'title' => $validated['title'],
        'description' => $validated['description'] ?? null,
        'transaction_modes_json' => json_encode($validated['transaction_modes']),
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


