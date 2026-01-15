<?php

namespace App\Services\Commerce;

use App\Models\Listing;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Pagination\LengthAwarePaginator as Paginator;

/**
 * Commerce Listing Service
 * 
 * Business logic for commerce listings (CRUD + publish/unpublish).
 * Enforces tenant boundary and visibility rules.
 */
final class ListingService
{
    /**
     * Search public listings
     * 
     * @param array $filters
     * @param int $page
     * @param int $perPage
     * @return LengthAwarePaginator
     */
    public function searchPublic(array $filters, int $page = 1, int $perPage = 20): LengthAwarePaginator
    {
        $query = Listing::query()
            ->forWorld('commerce')
            ->publicVisible()
            ->orderByDesc('created_at');

        // Search by title/description
        if (isset($filters['q']) && !empty($filters['q'])) {
            $q = (string) $filters['q'];
            $query->where(function ($qry) use ($q) {
                $qry->where('title', 'LIKE', "%{$q}%")
                    ->orWhere('description', 'LIKE', "%{$q}%");
            });
        }

        // Filter by min_price
        if (isset($filters['min_price']) && is_numeric($filters['min_price'])) {
            $query->where('price_amount', '>=', (int) $filters['min_price']);
        }

        // Filter by max_price
        if (isset($filters['max_price']) && is_numeric($filters['max_price'])) {
            $query->where('price_amount', '<=', (int) $filters['max_price']);
        }

        // Filter by currency
        if (isset($filters['currency']) && !empty($filters['currency'])) {
            $query->where('currency', $filters['currency']);
        }

        return $query->paginate($perPage, ['*'], 'page', $page);
    }

    /**
     * Get public listing by ID
     * 
     * @param int|string $id
     * @return Listing|null
     */
    public function getPublic(int|string $id): ?Listing
    {
        return Listing::query()
            ->forWorld('commerce')
            ->publicVisible()
            ->find($id);
    }

    /**
     * Create listing for tenant
     * 
     * @param string $tenantId
     * @param string|null $userId
     * @param array $data
     * @return Listing
     */
    public function createForTenant(string $tenantId, ?string $userId, array $data): Listing
    {
        return Listing::create([
            'tenant_id' => $tenantId,
            'world' => 'commerce',
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'price_amount' => isset($data['price_amount']) ? (int) $data['price_amount'] : null,
            'currency' => $data['currency'] ?? 'TRY',
            'status' => Listing::STATUS_DRAFT,
        ]);
    }

    /**
     * Update listing for tenant (enforces tenant ownership)
     * 
     * @param string $tenantId
     * @param string $listingId
     * @param array $data
     * @return Listing
     * @throws \Illuminate\Database\Eloquent\ModelNotFoundException
     */
    public function updateForTenant(string $tenantId, string $listingId, array $data): Listing
    {
        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld('commerce')
            ->findOrFail($listingId);

        $updateData = [];
        if (isset($data['title'])) {
            $updateData['title'] = $data['title'];
        }
        if (isset($data['description'])) {
            $updateData['description'] = $data['description'];
        }
        if (isset($data['price_amount'])) {
            $updateData['price_amount'] = (int) $data['price_amount'];
        }
        if (isset($data['currency'])) {
            $updateData['currency'] = $data['currency'];
        }

        $listing->update($updateData);
        $listing->refresh();

        return $listing;
    }

    /**
     * Publish listing for tenant
     * 
     * @param string $tenantId
     * @param string $listingId
     * @return Listing
     * @throws \Illuminate\Database\Eloquent\ModelNotFoundException
     */
    public function publishForTenant(string $tenantId, string $listingId): Listing
    {
        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld('commerce')
            ->findOrFail($listingId);

        $listing->status = Listing::STATUS_PUBLISHED;
        $listing->save();
        $listing->refresh();

        return $listing;
    }

    /**
     * Unpublish listing for tenant
     * 
     * @param string $tenantId
     * @param string $listingId
     * @return Listing
     * @throws \Illuminate\Database\Eloquent\ModelNotFoundException
     */
    public function unpublishForTenant(string $tenantId, string $listingId): Listing
    {
        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld('commerce')
            ->findOrFail($listingId);

        $listing->status = Listing::STATUS_DRAFT;
        $listing->save();
        $listing->refresh();

        return $listing;
    }
}





