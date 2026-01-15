<?php

namespace App\Http\Controllers;

use App\Models\Listing;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

/**
 * Listing Controller
 * 
 * Handles public and panel endpoints for listings in enabled worlds.
 * Tenant-scoped, world-specific, status-based (draft|published).
 */
final class ListingController extends Controller
{
    /**
     * Public search (no auth required)
     * 
     * GET /api/{world}/listings/search?q=&status=published&page=1
     */
    public function search(Request $request, string $world)
    {
        $worldId = $request->attributes->get('ctx.world', $world);

        $validator = Validator::make($request->all(), [
            'q' => 'nullable|string|max:255',
            'status' => 'nullable|in:published',
            'page' => 'nullable|integer|min:1',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $query = Listing::query()->forWorld($worldId)->published();

        if ($request->has('q') && $request->input('q') !== '') {
            $q = (string) $request->input('q');
            $query->where(function ($qry) use ($q) {
                $qry->where('title', 'LIKE', "%{$q}%")
                    ->orWhere('description', 'LIKE', "%{$q}%");
            });
        }

        $page = (int) ($request->input('page', 1));
        $perPage = 20;
        $listings = $query->orderByDesc('created_at')->paginate($perPage, ['*'], 'page', $page);

        $requestId = $request->attributes->get('request_id', '');

        $response = response()->json([
            'ok' => true,
            'listings' => $listings->items(),
            'pagination' => [
                'current_page' => $listings->currentPage(),
                'last_page' => $listings->lastPage(),
                'per_page' => $listings->perPage(),
                'total' => $listings->total(),
            ],
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Public show (published only)
     * 
     * GET /api/{world}/listings/{id}
     */
    public function show(Request $request, string $world, string $id)
    {
        $worldId = $request->attributes->get('ctx.world', $world);

        $listing = Listing::query()
            ->forWorld($worldId)
            ->published()
            ->find($id);

        if (!$listing) {
            $requestId = $request->attributes->get('request_id', '');
            $response = response()->json([
                'ok' => false,
                'error_code' => 'NOT_FOUND',
            ], 404);
            if ($requestId !== '') {
                $response->header('X-Request-Id', $requestId);
            }
            return $response;
        }

        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => true,
            'listing' => $listing,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Panel: List tenant's listings (any status)
     * 
     * GET /api/{world}/panel/listings
     */
    public function index(Request $request, string $world)
    {
        $worldId = $request->attributes->get('ctx.world', $world);
        $tenantId = $this->getTenantId($request);

        if (!$tenantId) {
            return $this->unauthorized($request);
        }

        // Validate world match
        if ($worldId !== $world) {
            return $this->badRequest($request, 'WORLD_MISMATCH', 'World in path does not match context');
        }

        $listings = Listing::query()
            ->forTenant($tenantId)
            ->forWorld($worldId)
            ->orderByDesc('created_at')
            ->get();

        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => true,
            'listings' => $listings,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Panel: Create listing
     * 
     * POST /api/{world}/panel/listings
     */
    public function store(Request $request, string $world)
    {
        $worldId = $request->attributes->get('ctx.world', $world);
        $tenantId = $this->getTenantId($request);

        if (!$tenantId) {
            return $this->unauthorized($request);
        }

        // Validate world match
        if ($worldId !== $world) {
            return $this->badRequest($request, 'WORLD_MISMATCH', 'World in path does not match context');
        }

        $validator = Validator::make($request->all(), [
            'title' => 'required|string|min:3|max:120',
            'description' => 'nullable|string|max:5000',
            'price_amount' => 'nullable|integer|min:0',
            'currency' => 'nullable|string|size:3|in:TRY,USD,EUR',
            'status' => 'nullable|in:draft,published',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $listing = Listing::create([
            'tenant_id' => $tenantId,
            'world' => $worldId,
            'title' => $request->input('title'),
            'description' => $request->input('description'),
            'price_amount' => $request->input('price_amount'),
            'currency' => $request->input('currency', 'TRY'),
            'status' => $request->input('status', 'draft'),
        ]);

        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => true,
            'listing' => $listing,
        ], 201);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Panel: Update listing
     * 
     * PATCH /api/{world}/panel/listings/{id}
     */
    public function update(Request $request, string $world, string $id)
    {
        $worldId = $request->attributes->get('ctx.world', $world);
        $tenantId = $this->getTenantId($request);

        if (!$tenantId) {
            return $this->unauthorized($request);
        }

        // Validate world match
        if ($worldId !== $world) {
            return $this->badRequest($request, 'WORLD_MISMATCH', 'World in path does not match context');
        }

        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld($worldId)
            ->find($id);

        if (!$listing) {
            return $this->notFound($request);
        }

        $validator = Validator::make($request->all(), [
            'title' => 'sometimes|required|string|min:3|max:120',
            'description' => 'nullable|string|max:5000',
            'price_amount' => 'nullable|integer|min:0',
            'currency' => 'nullable|string|size:3|in:TRY,USD,EUR',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $listing->fill($request->only(['title', 'description', 'price_amount', 'currency']));
        $listing->save();

        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => true,
            'listing' => $listing,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Panel: Publish listing
     * 
     * POST /api/{world}/panel/listings/{id}/publish
     */
    public function publish(Request $request, string $world, string $id)
    {
        $worldId = $request->attributes->get('ctx.world', $world);
        $tenantId = $this->getTenantId($request);

        if (!$tenantId) {
            return $this->unauthorized($request);
        }

        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld($worldId)
            ->find($id);

        if (!$listing) {
            return $this->notFound($request);
        }

        $listing->status = Listing::STATUS_PUBLISHED;
        $listing->save();

        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => true,
            'listing' => $listing,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Panel: Unpublish listing
     * 
     * POST /api/{world}/panel/listings/{id}/unpublish
     */
    public function unpublish(Request $request, string $world, string $id)
    {
        $worldId = $request->attributes->get('ctx.world', $world);
        $tenantId = $this->getTenantId($request);

        if (!$tenantId) {
            return $this->unauthorized($request);
        }

        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld($worldId)
            ->find($id);

        if (!$listing) {
            return $this->notFound($request);
        }

        $listing->status = Listing::STATUS_DRAFT;
        $listing->save();

        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => true,
            'listing' => $listing,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Get tenant ID from request
     */
    private function getTenantId(Request $request): ?string
    {
        // Try request->tenant first (from resolve.tenant middleware)
        if ($request->has('tenant') && is_object($request->input('tenant'))) {
            $tenant = $request->input('tenant');
            if (isset($tenant->id)) {
                return (string) $tenant->id;
            }
        }

        // Try request->tenant property
        if (isset($request->tenant) && is_object($request->tenant) && isset($request->tenant->id)) {
            return (string) $request->tenant->id;
        }

        // Try request->user()->tenant_id
        $user = $request->user();
        if ($user && isset($user->tenant_id)) {
            return (string) $user->tenant_id;
        }

        // Try request attributes
        $tenantId = $request->attributes->get('tenant_id');
        if ($tenantId) {
            return (string) $tenantId;
        }

        return null;
    }

    /**
     * Unauthorized response
     */
    private function unauthorized(Request $request)
    {
        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => false,
            'error_code' => 'UNAUTHORIZED',
        ], 401);
        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }
        return $response;
    }

    /**
     * Not found response
     */
    private function notFound(Request $request)
    {
        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => false,
            'error_code' => 'NOT_FOUND',
        ], 404);
        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }
        return $response;
    }

    /**
     * Bad request response
     */
    private function badRequest(Request $request, string $errorCode, string $message)
    {
        $requestId = $request->attributes->get('request_id', '');
        $response = response()->json([
            'ok' => false,
            'error_code' => $errorCode,
            'message' => $message,
        ], 400);
        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }
        return $response;
    }
}

