<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// Reservation Spine Endpoints (WP-4)
// POST /v1/reservations - Create reservation
Route::middleware('auth.ctx')->post('/v1/reservations', function (\Illuminate\Http\Request $request) {
    // WP-4.1: Error normalization - wrap entire handler in try-catch
    try {
    // WP-13: AuthContext middleware handles JWT verification and sets requester_user_id
    
    // Require Idempotency-Key header
    $idempotencyKey = $request->header('Idempotency-Key');
    if (!$idempotencyKey) {
        return response()->json([
            'error' => 'missing_header',
            'message' => 'Idempotency-Key header is required'
        ], 400);
    }
    
    // Validate required fields
    $validated = $request->validate([
        'listing_id' => 'required|uuid',
        'slot_start' => 'required|date',
        'slot_end' => 'required|date|after:slot_start',
        'party_size' => 'required|integer|min:1'
    ]);
    
    // Get listing
    $listing = DB::table('listings')->where('id', $validated['listing_id'])->first();
    if (!$listing) {
        return response()->json([
            'error' => 'listing_not_found',
            'message' => "Listing with id {$validated['listing_id']} not found"
        ], 404);
    }
    
    // Check listing is published
    if ($listing->status !== 'published') {
        return response()->json([
            'error' => 'listing_not_published',
            'message' => "Listing must be published to create reservations. Current status: {$listing->status}"
        ], 422);
    }
    
    // Idempotency check (MUST be before overlap check to avoid false conflicts)
    // WP-13: Get requester_user_id from request attributes (set by AuthContext middleware)
    $scopeType = 'user';
    $scopeId = $request->attributes->get('requester_user_id') ?? 'genesis-default';
    $requestHash = hash('sha256', json_encode($validated));
    
    $existingIdempotency = DB::table('idempotency_keys')
        ->where('scope_type', $scopeType)
        ->where('scope_id', $scopeId)
        ->where('key', $idempotencyKey)
        ->where('request_hash', $requestHash)
        ->where('expires_at', '>', now())
        ->first();
    
    if ($existingIdempotency) {
        // Return cached response (idempotency replay)
        $cachedResponse = json_decode($existingIdempotency->response_json, true);
        return response()->json($cachedResponse, 200);
    }
    
    // Check capacity_max constraint: party_size <= capacity_max
    $attributes = $listing->attributes_json ? json_decode($listing->attributes_json, true) : [];
    if (isset($attributes['capacity_max'])) {
        $capacityMax = (int) $attributes['capacity_max'];
        if ($validated['party_size'] > $capacityMax) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => "party_size ({$validated['party_size']}) exceeds capacity_max ({$capacityMax})",
                'party_size' => $validated['party_size'],
                'capacity_max' => $capacityMax
            ], 422);
        }
    } else {
        // If capacity_max not set, return VALIDATION_ERROR
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'listing.attributes_json.capacity_max is required but not found'
        ], 422);
    }
    
    // Check slot overlap: accepted/requested reservations that overlap same listing
    $slotStart = new \DateTime($validated['slot_start']);
    $slotEnd = new \DateTime($validated['slot_end']);
    
    $overlapping = DB::table('reservations')
        ->where('listing_id', $validated['listing_id'])
        ->whereIn('status', ['requested', 'accepted'])
        ->where(function ($query) use ($slotStart, $slotEnd) {
            $query->where(function ($q) use ($slotStart, $slotEnd) {
                // Reservation starts before our end and ends after our start
                $q->where('slot_start', '<', $slotEnd->format('Y-m-d H:i:s'))
                  ->where('slot_end', '>', $slotStart->format('Y-m-d H:i:s'));
            });
        })
        ->first();
    
    if ($overlapping) {
        return response()->json([
            'error' => 'CONFLICT',
            'message' => 'Slot overlaps with existing reservation',
            'conflicting_reservation_id' => $overlapping->id
        ], 409);
    }
    
    // Create reservation
    // WP-13: Get requester_user_id from request attributes (set by AuthContext middleware)
    $reservationId = \Illuminate\Support\Str::uuid()->toString();
    $providerTenantId = $listing->tenant_id;
    $requesterUserId = $request->attributes->get('requester_user_id');
    
    DB::table('reservations')->insert([
        'id' => $reservationId,
        'listing_id' => $validated['listing_id'],
        'provider_tenant_id' => $providerTenantId,
        'requester_user_id' => $requesterUserId,
        'slot_start' => $slotStart->format('Y-m-d H:i:s'),
        'slot_end' => $slotEnd->format('Y-m-d H:i:s'),
        'party_size' => $validated['party_size'],
        'status' => 'requested',
        'created_at' => now(),
        'updated_at' => now()
    ]);
    
    $response = [
        'id' => $reservationId,
        'listing_id' => $validated['listing_id'],
        'provider_tenant_id' => $providerTenantId,
        'requester_user_id' => $requesterUserId,
        'slot_start' => $slotStart->format('Y-m-d\TH:i:s\Z'),
        'slot_end' => $slotEnd->format('Y-m-d\TH:i:s\Z'),
        'party_size' => $validated['party_size'],
        'status' => 'requested',
        'created_at' => now()->toISOString()
    ];
    
    // Store idempotency key (expires in 24 hours)
    DB::table('idempotency_keys')->insert([
        'scope_type' => $scopeType,
        'scope_id' => $scopeId,
        'key' => $idempotencyKey,
        'request_hash' => $requestHash,
        'response_json' => json_encode($response),
        'created_at' => now(),
        'expires_at' => now()->addHours(24)
    ]);
    
    // Create messaging thread for reservation (context-only integration, WP-5)
    // Non-fatal: if messaging service is unavailable, reservation still succeeds
    try {
        $messagingClient = new \App\Messaging\MessagingClient();
        $participants = [];
        
        if ($requesterUserId) {
            $participants[] = ['type' => 'user', 'id' => $requesterUserId];
        }
        if ($providerTenantId) {
            $participants[] = ['type' => 'tenant', 'id' => $providerTenantId];
        }
        
        if (!empty($participants)) {
            $messagingClient->upsertThread('reservation', $reservationId, $participants);
        }
    } catch (\Exception $e) {
        // Non-fatal: log but do not fail reservation creation
        \Illuminate\Support\Facades\Log::warning('messaging.thread_creation.failed', [
            'reservation_id' => $reservationId,
            'error' => $e->getMessage()
        ]);
    }
    
    return response()->json($response, 201);
    } catch (\Exception $e) {
        // WP-4.1: Error normalization - catch all exceptions
        \Log::error('Reservation create error', ['error' => $e->getMessage(), 'trace' => $e->getTraceAsString()]);
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => $e->getMessage()
        ], 422);
    }
});

// POST /v1/reservations/{id}/accept - Accept reservation
// WP-26: Tenant scope enforced via tenant.scope middleware
Route::middleware(['auth.ctx', 'tenant.scope'])->post('/v1/reservations/{id}/accept', function ($id, \Illuminate\Http\Request $request) {
    // WP-4.1: Error normalization - wrap entire handler in try-catch
    try {
    // WP-26: tenant_id is set by TenantScope middleware
    $tenantId = $request->attributes->get('tenant_id');
    
    // Find reservation
    $reservation = DB::table('reservations')->where('id', $id)->first();
    if (!$reservation) {
        return response()->json([
            'error' => 'reservation_not_found',
            'message' => "Reservation with id {$id} not found"
        ], 404);
    }
    
    // Check tenant ownership (FORBIDDEN_SCOPE)
    if ($reservation->provider_tenant_id !== $tenantId) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'Only the listing owner can accept this reservation'
        ], 403);
    }
    
    // Check status is requested (state transition validation)
    if ($reservation->status !== 'requested') {
        return response()->json([
            'error' => 'INVALID_STATE',
            'message' => "Reservation must be in 'requested' status to accept. Current status: {$reservation->status}"
        ], 422);
    }
    
    // Update status to accepted (atomic operation)
    // NOTE: Accept does NOT perform overlap checks - only create does
    // Accept only validates: tenant ownership, state transition (requested -> accepted)
    $updated = DB::table('reservations')
        ->where('id', $id)
        ->where('status', 'requested') // Atomic: only update if still requested
        ->update([
            'status' => 'accepted',
            'updated_at' => now()
        ]);
    
    // Verify update succeeded (race condition check)
    if ($updated === 0) {
        // Status changed between check and update (race condition or idempotency)
        $current = DB::table('reservations')->where('id', $id)->first();
        if ($current && $current->status === 'accepted') {
            // Already accepted (idempotent accept)
            $reservation = $current;
        } else {
            // WP-4.1: Race condition -> 422 VALIDATION_ERROR (not 500)
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => 'Reservation status changed during update (race condition)'
            ], 422);
        }
    } else {
        // Reload updated reservation
        $reservation = DB::table('reservations')->where('id', $id)->first();
    }
    
    return response()->json([
        'id' => $reservation->id,
        'listing_id' => $reservation->listing_id,
        'provider_tenant_id' => $reservation->provider_tenant_id,
        'requester_user_id' => $reservation->requester_user_id,
        'slot_start' => $reservation->slot_start,
        'slot_end' => $reservation->slot_end,
        'party_size' => $reservation->party_size,
        'status' => $reservation->status,
        'updated_at' => $reservation->updated_at
    ]);
    } catch (\Illuminate\Database\QueryException $e) {
        // WP-4.1: Database errors in accept -> 422 VALIDATION_ERROR
        $errorMessage = $e->getMessage();
        \Log::error('Reservation accept database error', ['error' => $errorMessage, 'reservation_id' => $id]);
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'Database error during reservation accept'
        ], 422);
    } catch (\Exception $e) {
        // WP-4.1: Catch all other exceptions -> 422 VALIDATION_ERROR
        \Log::error('Reservation accept error', ['error' => $e->getMessage(), 'reservation_id' => $id, 'trace' => $e->getTraceAsString()]);
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => $e->getMessage()
        ], 422);
    }
});

// GET /v1/reservations/{id} - Get reservation
Route::get('/v1/reservations/{id}', function ($id) {
    $reservation = DB::table('reservations')->where('id', $id)->first();
    
    if (!$reservation) {
        return response()->json([
            'error' => 'reservation_not_found',
            'message' => "Reservation with id {$id} not found"
        ], 404);
    }
    
    return response()->json([
        'id' => $reservation->id,
        'listing_id' => $reservation->listing_id,
        'provider_tenant_id' => $reservation->provider_tenant_id,
        'requester_user_id' => $reservation->requester_user_id,
        'slot_start' => $reservation->slot_start,
        'slot_end' => $reservation->slot_end,
        'party_size' => $reservation->party_size,
        'status' => $reservation->status,
        'created_at' => $reservation->created_at,
        'updated_at' => $reservation->updated_at
    ]);
});

