<?php

namespace App\Support\ApiSpine;

use App\Models\Listing;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Listing Query Model v1.1
 * 
 * Centralized query builder for listings with filters, cursor pagination, and stable ordering.
 * Single source of truth for listing queries across all enabled worlds.
 */
final class ListingQueryModel
{
    /**
     * Build and execute query for listings
     * 
     * @param string $tenantId Tenant ID
     * @param string $world World identifier
     * @param Request $request HTTP request
     * @return array [items, page] Items array and page metadata
     */
    public static function query(string $tenantId, string $world, Request $request): array
    {
        // Build base query (tenant-scoped, world-scoped)
        $baseQuery = Listing::query()
            ->forTenant($tenantId)
            ->forWorld($world);

        // Apply filters
        $query = self::applyFilters($baseQuery, $request);

        // Apply stable ordering (id desc for stability)
        $query->orderByDesc('id');

        // Parse cursor and apply pagination
        $limit = self::parseLimit($request);
        [$query, $cursorData] = self::applyCursor($query, $request, $tenantId, $world);

        // Fetch items (limit + 1 to check if there's more)
        $items = $query->limit($limit + 1)->get();
        $hasMore = $items->count() > $limit;

        if ($hasMore) {
            $items = $items->take($limit);
        }

        // Build next cursor (if there are more items)
        $nextCursor = null;
        if ($hasMore && $items->count() > 0) {
            $lastItem = $items->last();
            $nextCursor = self::encodeCursor($lastItem->id, $tenantId, $world);
        }

        // Format items using ListingReadDTO
        $formattedItems = $items->map(function ($item) {
            return \App\Support\Api\ListingReadDTO::fromModel($item);
        })->toArray();

        return [
            'items' => $formattedItems,
            'page' => [
                'limit' => $limit,
                'next_cursor' => $nextCursor,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * Apply filters to query
     */
    private static function applyFilters(Builder $query, Request $request): Builder
    {
        // Search filter (q) - LIKE on title and description
        $searchQuery = $request->input('q');
        if (!empty($searchQuery)) {
            $searchQuery = trim($searchQuery);
            if (strlen($searchQuery) > 80) {
                $searchQuery = substr($searchQuery, 0, 80);
            }
            if (!empty($searchQuery)) {
                $query->where(function ($q) use ($searchQuery) {
                    $q->where('title', 'LIKE', '%' . $searchQuery . '%')
                        ->orWhere('description', 'LIKE', '%' . $searchQuery . '%');
                });
            }
        }

        // Status filter
        $status = $request->input('status');
        if (!empty($status) && in_array($status, ['draft', 'published'], true)) {
            $query->where('status', $status);
        }

        // Price filters (min_price, max_price)
        $minPrice = $request->input('min_price');
        if (!empty($minPrice) && is_numeric($minPrice)) {
            $query->where('price_amount', '>=', (int) $minPrice);
        }

        $maxPrice = $request->input('max_price');
        if (!empty($maxPrice) && is_numeric($maxPrice)) {
            $query->where('price_amount', '<=', (int) $maxPrice);
        }

        // Updated after filter
        $updatedAfter = $request->input('updated_after');
        if (!empty($updatedAfter)) {
            try {
                $date = Carbon::parse($updatedAfter);
                $query->where('updated_at', '>=', $date);
            } catch (\Exception $e) {
                // Invalid date format - ignore
            }
        }

        return $query;
    }

    /**
     * Parse limit from request
     */
    private static function parseLimit(Request $request): int
    {
        $limit = (int) $request->input('limit', 20);
        $limit = min(max($limit, 1), 100); // Clamp between 1 and 100
        return $limit;
    }

    /**
     * Apply cursor pagination
     */
    private static function applyCursor(Builder $query, Request $request, string $tenantId, string $world): array
    {
        $cursorStr = $request->input('cursor');
        if (empty($cursorStr)) {
            return [$query, null];
        }

        // Decode and validate cursor
        $cursorData = self::decodeCursor($cursorStr, $tenantId, $world);
        if ($cursorData === null) {
            // Invalid cursor - return query without cursor applied (will be handled by controller as 400)
            return [$query, null];
        }

        // Apply cursor (id < last_id for desc ordering)
        $lastId = $cursorData['last_id'] ?? null;
        if ($lastId !== null) {
            $query->where('id', '<', $lastId);
        }

        return [$query, $cursorData];
    }

    /**
     * Encode cursor with HMAC signature
     */
    private static function encodeCursor(string $lastId, string $tenantId, string $world): string
    {
        $payload = [
            'last_id' => $lastId,
            'tenant_id' => $tenantId,
            'world' => $world,
            'ts' => time(), // Timestamp for additional tamper protection
        ];

        $json = json_encode($payload, JSON_UNESCAPED_SLASHES);
        $payloadBase64 = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($json));

        // Generate HMAC signature using APP_KEY
        $key = config('app.key', '');
        if (empty($key)) {
            // Fallback: use payload as-is (no signature) - not recommended for production
            return $payloadBase64;
        }

        $signature = hash_hmac('sha256', $payloadBase64, $key, true);
        $signatureBase64 = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

        // Return payload.signature format
        return $payloadBase64 . '.' . $signatureBase64;
    }

    /**
     * Decode and validate cursor with HMAC signature
     */
    private static function decodeCursor(string $cursor, string $tenantId, string $world): ?array
    {
        if (empty($cursor)) {
            return null;
        }

        // Split payload and signature
        $parts = explode('.', $cursor, 2);
        if (count($parts) !== 2) {
            return null; // Invalid format
        }

        [$payloadBase64, $signatureBase64] = $parts;

        // Verify HMAC signature
        $key = config('app.key', '');
        if (!empty($key)) {
            $expectedSignature = hash_hmac('sha256', $payloadBase64, $key, true);
            $expectedSignatureBase64 = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($expectedSignature));

            if (!hash_equals($expectedSignatureBase64, $signatureBase64)) {
                return null; // Invalid signature
            }
        }

        // Decode payload
        $payloadJson = base64_decode(str_replace(['-', '_'], ['+', '/'], $payloadBase64), true);
        if ($payloadJson === false) {
            return null;
        }

        $payload = json_decode($payloadJson, true);
        if (!is_array($payload) || !isset($payload['last_id'])) {
            return null;
        }

        // Validate tenant_id and world (prevent cross-tenant/world cursor usage)
        if (isset($payload['tenant_id']) && $payload['tenant_id'] !== $tenantId) {
            return null; // Tenant mismatch
        }

        if (isset($payload['world']) && $payload['world'] !== $world) {
            return null; // World mismatch
        }

        return $payload;
    }

    /**
     * Validate cursor (used by controller before calling query)
     */
    public static function validateCursor(string $cursor, string $tenantId, string $world): bool
    {
        if (empty($cursor)) {
            return true; // Empty cursor is valid (first page)
        }

        return self::decodeCursor($cursor, $tenantId, $world) !== null;
    }

    /**
     * Create invalid cursor response
     */
    public static function invalidCursorResponse(Request $request): \Illuminate\Http\JsonResponse
    {
        $requestId = $request->attributes->get('request_id', (string) \Illuminate\Support\Str::uuid());

        return response()->json([
            'ok' => false,
            'error_code' => 'INVALID_CURSOR',
            'message' => 'Invalid cursor provided.',
            'request_id' => $requestId,
        ], 400)->header('X-Request-Id', $requestId);
    }
}

