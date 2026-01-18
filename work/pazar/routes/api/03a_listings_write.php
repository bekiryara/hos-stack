<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// Supply Spine Endpoints (WP-3)
// POST /v1/listings - Create DRAFT listing
// WP-26: Tenant scope enforced via tenant.scope middleware
Route::middleware('tenant.scope')->post('/v1/listings', function (\Illuminate\Http\Request $request) {
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
    
    // Get category filter schema to validate required attributes
    $categoryId = $validated['category_id'];
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
    foreach ($requiredAttributes as $attrKey) {
        if (!isset($attributes[$attrKey])) {
            return response()->json([
                'error' => 'missing_required_attribute',
                'message' => "Required attribute '{$attrKey}' is missing",
                'required_attributes' => $requiredAttributes
            ], 422);
        }
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
// WP-26: Tenant scope enforced via tenant.scope middleware
Route::middleware('tenant.scope')->post('/v1/listings/{id}/publish', function ($id, \Illuminate\Http\Request $request) {
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

