<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// Supply Spine Endpoints (WP-3)
// POST /v1/listings - Create DRAFT listing
// WP-8: STORE persona requires X-Active-Tenant-Id header (persona.scope:store)
// WP-26: Tenant scope enforced via tenant.scope middleware
// WP-29: Auth required via auth.any middleware
// WP-50: AuthAny middleware validates JWT tokens
// WP-48: Use full class name to avoid Laravel terminate phase alias resolution issue
$createListingMiddleware = [\App\Http\Middleware\PersonaScope::class . ':store'];
$createListingMiddleware[] = 'auth.any';
$createListingMiddleware[] = 'auth.ctx';
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
    
    // Single-source-of-truth: validate + normalize category/attributes/transaction modes via guard.
    $categoryId = (int) $validated['category_id'];
    $attributes = $validated['attributes'] ?? [];
    $transactionModes = $validated['transaction_modes'] ?? [];
    $guard = pazar_guard_listing_catalog_write($categoryId, is_array($attributes) ? $attributes : [], is_array($transactionModes) ? $transactionModes : []);
    if ($guard instanceof \Illuminate\Http\JsonResponse) {
        return $guard;
    }
    $attributes = $guard['attributes'] ?? [];
    $requestedModes = $guard['transaction_modes'];
    
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
// WP-29: Auth required via auth.any middleware
// WP-50: AuthAny middleware validates JWT tokens
// WP-48: Use full class name to avoid Laravel terminate phase alias resolution issue
$publishListingMiddleware = [\App\Http\Middleware\PersonaScope::class . ':store'];
$publishListingMiddleware[] = 'auth.any';
$publishListingMiddleware[] = 'auth.ctx';
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


