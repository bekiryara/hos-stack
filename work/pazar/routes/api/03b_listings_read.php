<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// GET /v1/listings - Search listings
// WP-8: GUEST+ persona (no headers required for basic search, store scope requires X-Active-Tenant-Id)
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/listings', function (\Illuminate\Http\Request $request) {
    $query = DB::table('listings');
    
    // Filter by category_id if provided (WP-48: recursive - include all descendant categories)
    // WP-73: Use CTE subquery in SQL instead of building ID array in PHP
    if ($request->has('category_id')) {
        $categoryId = (int) $request->input('category_id');
        $cteData = pazar_category_descendant_cte_in_clause_sql($categoryId);
        $query->whereRaw("category_id IN " . $cteData['sql'], $cteData['bindings']);
    }
    
    // Filter by status (default: published)
    $status = $request->input('status', 'published');
    $query->where('status', $status);
    
    // WP-12.1: Filter by tenant_id if provided (Account Portal Store view)
    // Store scope requires X-Active-Tenant-Id header
    if ($request->has('tenant_id')) {
        $tenantId = $request->input('tenant_id');
        $tenantIdHeader = $request->header('X-Active-Tenant-Id');
        
        // WP-12.1: Store scope requires X-Active-Tenant-Id header
        if (!$tenantIdHeader) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => 'X-Active-Tenant-Id header is required for store scope'
            ], 400);
        }
        
        // WP-12.1: Validate tenant_id format (UUID format check)
        $membershipClient = new \App\Core\MembershipClient();
        if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
            return response()->json([
                'error' => 'FORBIDDEN_SCOPE',
                'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
            ], 403);
        }
        
        // Verify X-Active-Tenant-Id matches tenant_id parameter for security
        if ($tenantIdHeader !== $tenantId) {
            return response()->json([
                'error' => 'FORBIDDEN_SCOPE',
                'message' => 'X-Active-Tenant-Id header must match tenant_id parameter'
            ], 403);
        }
        
        $query->where('tenant_id', $tenantId);
    }
    
    // Filter by attributes (supports exact match + _min/_max numeric ranges)
    if ($request->has('attrs')) {
        $attrs = $request->input('attrs');
        if (is_array($attrs)) {
            foreach ($attrs as $key => $value) {
                // Range helpers (schema-driven UI uses *_min/*_max keys)
                if (is_string($key) && preg_match('/^(.*)_(min|max)$/', $key, $m)) {
                    $baseKey = $m[1];
                    $rangeType = $m[2]; // min|max
                    if ($rangeType === 'min') {
                        $query->whereRaw("CAST(attributes_json->>? AS INTEGER) >= ?", [$baseKey, (int) $value]);
                    } else {
                        $query->whereRaw("CAST(attributes_json->>? AS INTEGER) <= ?", [$baseKey, (int) $value]);
                    }
                } else {
                    $query->whereRaw("attributes_json->>? = ?", [$key, $value]);
                }
            }
        }
    }
    
    // WP-12: Pagination (per_page default 20, max 50)
    $page = max(1, (int)$request->input('page', 1));
    $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
    $offset = ($page - 1) * $perPage;
    
    // A) Removed unused $total count (response is array, not paginated envelope)
    // Contract: GET /v1/listings returns JSON array (WP-3.1)
    
    // Deterministic ordering
    $listings = $query->orderBy('created_at', 'desc')->orderBy('id', 'desc')
        ->offset($offset)
        ->limit($perPage)
        ->get()
        ->map(function ($listing) {
            return [
                'id' => $listing->id,
                'tenant_id' => $listing->tenant_id,
                'category_id' => $listing->category_id,
                'title' => $listing->title,
                'description' => $listing->description,
                'status' => $listing->status,
                'transaction_modes' => $listing->transaction_modes_json ? json_decode($listing->transaction_modes_json, true) : [],
                'attributes' => $listing->attributes_json ? json_decode($listing->attributes_json, true) : [],
                'location' => $listing->location_json ? json_decode($listing->location_json, true) : null,
                'created_at' => $listing->created_at,
                'updated_at' => $listing->updated_at
            ];
        })
        ->values()
        ->all();
    
    // WP-3.1: Response MUST always be a JSON array (contract requirement)
    // Empty results return [] (empty array)
    return response()->json($listings);
});

// GET /v1/listings/{id} - Get single listing
// WP-8: GUEST+ persona (no headers required)
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/listings/{id}', function ($id) {
    $listing = DB::table('listings')->where('id', $id)->first();
    
    if (!$listing) {
        return response()->json([
            'error' => 'listing_not_found',
            'message' => "Listing with id {$id} not found"
        ], 404);
    }
    
    return response()->json([
        'id' => $listing->id,
        'tenant_id' => $listing->tenant_id,
        'category_id' => $listing->category_id,
        'title' => $listing->title,
        'description' => $listing->description,
        'status' => $listing->status,
        'transaction_modes' => $listing->transaction_modes_json ? json_decode($listing->transaction_modes_json, true) : [],
        'attributes' => $listing->attributes_json ? json_decode($listing->attributes_json, true) : [],
        'location' => $listing->location_json ? json_decode($listing->location_json, true) : null,
        'created_at' => $listing->created_at,
        'updated_at' => $listing->updated_at
    ]);
});
