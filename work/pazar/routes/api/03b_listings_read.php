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
    
    // Filter by attributes (simple key-value matching)
    if ($request->has('attrs')) {
        $attrs = $request->input('attrs');
        if (is_array($attrs)) {
            foreach ($attrs as $key => $value) {
                $query->whereRaw("attributes_json->>? = ?", [$key, $value]);
            }
        }
    }
    
    // WP-12: Pagination (per_page default 20, max 50)
    $page = max(1, (int)$request->input('page', 1));
    $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
    $offset = ($page - 1) * $perPage;
    
    // A) Removed unused $total count (response is array, not paginated envelope)
    // Contract: GET /v1/listings returns JSON array (WP-3.1)
    
    $listings = $query->orderBy('created_at', 'desc')
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

// WP-8: Search & Discovery Thin Slice (Read Spine)
// GET /api/v1/search - Search listings with filters and availability
Route::get('/v1/search', function (\Illuminate\Http\Request $request) {
    
    // Validate required parameters
    $validated = $request->validate([
        'category_id' => 'required|integer|exists:categories,id',
        'city' => 'nullable|string|max:255',
        'date_from' => 'nullable|date',
        'date_to' => 'nullable|date|after_or_equal:date_from',
        'capacity_min' => 'nullable|integer|min:1',
        'transaction_mode' => 'nullable|string|in:sale,rental,reservation',
        'page' => 'nullable|integer|min:1',
        'per_page' => 'nullable|integer|min:1|max:50'
    ], [
        'category_id.required' => 'category_id parameter is required',
        'category_id.exists' => 'category_id not found',
        'date_to.after_or_equal' => 'date_to must be after or equal to date_from',
        'per_page.max' => 'per_page cannot exceed 50'
    ]);
    
    // Get all category IDs including descendants (recursive)
    $categoryId = (int) $validated['category_id'];
    
    // WP-73: Use CTE subquery in SQL instead of building ID array in PHP
    // Avoids generating large descendant ID arrays in memory
    $cteData = pazar_category_descendant_cte_in_clause_sql($categoryId);
    
    // Build query - only published listings
    $query = DB::table('listings')
        ->where('status', 'published')
        ->whereRaw("category_id IN " . $cteData['sql'], $cteData['bindings']);
    
    // Filter by city (from location_json)
    if ($request->has('city')) {
        $city = $request->input('city');
        $query->whereRaw("location_json->>'city' = ?", [$city]);
    }
    
    // Filter by capacity_min (from attributes_json)
    if ($request->has('capacity_min')) {
        $capacityMin = (int) $request->input('capacity_min');
        // Check if capacity_max exists and is >= capacity_min
        $query->whereRaw("CAST(attributes_json->>'capacity_max' AS INTEGER) >= ?", [$capacityMin]);
    }
    
    // Filter by transaction_mode (from transaction_modes_json)
    if ($request->has('transaction_mode')) {
        $transactionMode = $request->input('transaction_mode');
        // Check if transaction_modes_json array contains the mode
        $query->whereRaw("transaction_modes_json::text LIKE ?", ['%' . $transactionMode . '%']);
    }
    
    // Availability logic: exclude listings with overlapping reservations/rentals
    if ($request->has('date_from') && $request->has('date_to')) {
        $dateFrom = $request->input('date_from');
        $dateTo = $request->input('date_to');
        
        // Get transaction_mode to determine which availability check to use
        $transactionMode = $request->input('transaction_mode');
        $excludedListingIds = [];
        
        // For reservation listings: exclude overlapping accepted/requested reservations
        if (!$transactionMode || $transactionMode === 'reservation') {
            $excludedReservationListingIds = DB::table('reservations')
                ->whereIn('status', ['requested', 'accepted'])
                ->where(function ($q) use ($dateFrom, $dateTo) {
                    // Overlap: reservation starts before date_to AND ends after date_from
                    $q->where('slot_start', '<', $dateTo)
                      ->where('slot_end', '>', $dateFrom);
                })
                ->pluck('listing_id')
                ->unique()
                ->toArray();
            
            $excludedListingIds = array_merge($excludedListingIds, $excludedReservationListingIds);
        }
        
        // For rental listings: exclude overlapping active/accepted/requested rentals
        if (!$transactionMode || $transactionMode === 'rental') {
            $excludedRentalListingIds = DB::table('rentals')
                ->whereIn('status', ['requested', 'accepted', 'active'])
                ->where(function ($q) use ($dateFrom, $dateTo) {
                    // Overlap: rental starts before date_to AND ends after date_from
                    $q->where('start_at', '<', $dateTo)
                      ->where('end_at', '>', $dateFrom);
                })
                ->pluck('listing_id')
                ->unique()
                ->toArray();
            
            $excludedListingIds = array_merge($excludedListingIds, $excludedRentalListingIds);
        }
        
        // Remove duplicates and exclude listings
        if (!empty($excludedListingIds)) {
            $excludedListingIds = array_unique($excludedListingIds);
            $query->whereNotIn('id', $excludedListingIds);
        }
    }
    
    // Deterministic ordering (created_at DESC)
    $query->orderBy('created_at', 'desc');
    
    // Pagination
    $page = (int) ($request->input('page', 1));
    $perPage = min(50, max(1, (int) ($request->input('per_page', 20))));
    $offset = ($page - 1) * $perPage;
    
    // Get total count before pagination
    $total = $query->count();
    
    // Apply pagination
    $listings = $query->offset($offset)
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
        });
    
    // Empty result is VALID - return empty array with pagination info
    return response()->json([
        'data' => $listings,
        'meta' => [
            'total' => $total,
            'page' => $page,
            'per_page' => $perPage,
            'total_pages' => (int) ceil($total / $perPage)
        ]
    ]);
});

