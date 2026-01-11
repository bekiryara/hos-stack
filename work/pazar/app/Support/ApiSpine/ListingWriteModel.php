<?php

namespace App\Support\ApiSpine;

use App\Models\Listing;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Validator;

/**
 * Listing Write Model
 * 
 * Centralized write operations for listings across all enabled worlds.
 * Enforces tenant and world boundaries, validation, and error handling.
 */
final class ListingWriteModel
{
    /**
     * Create a listing
     * 
     * @param string $world World identifier (commerce, food, rentals)
     * @param string $tenantId Tenant ID (from resolved context, NOT from request)
     * @param array $input Input data from request
     * @return Listing Created listing model
     * @throws ValidationException If validation fails
     */
    public static function create(string $world, string $tenantId, array $input): Listing
    {
        // Validate input
        $validator = Validator::make($input, [
            'title' => 'required|string|max:120',
            'description' => 'nullable|string|max:5000',
            'price_amount' => 'nullable|integer|min:0|max:999999999',
            'currency' => 'nullable|string|size:3',
            'status' => 'nullable|in:draft,published',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $validated = $validator->validated();

        // Create listing
        $listing = new Listing();
        $listing->tenant_id = $tenantId;
        $listing->world = $world;
        $listing->title = $validated['title'];
        if (isset($input['description'])) {
            $listing->description = $input['description'];
        }
        
        // Set optional fields only if provided
        if (array_key_exists('price_amount', $validated) && $validated['price_amount'] !== null) {
            $listing->price_amount = $validated['price_amount'];
        }
        if (array_key_exists('currency', $validated) && $validated['currency'] !== null) {
            $listing->currency = $validated['currency'];
        }
        if (isset($validated['status'])) {
            $listing->status = $validated['status'];
        } else {
            // Default to draft if status not provided
            $listing->status = 'draft';
        }
        
        $listing->save();

        return $listing;
    }

    /**
     * Update a listing (partial update)
     * 
     * @param string $world World identifier (commerce, food, rentals)
     * @param string $tenantId Tenant ID (from resolved context)
     * @param string $id Listing ID
     * @param array $input Input data from request
     * @return Listing Updated listing model
     * @throws ValidationException If validation fails
     * @return null If listing not found (wrong tenant/world)
     */
    public static function update(string $world, string $tenantId, string $id, array $input): ?Listing
    {
        // Find listing in tenant+world scope (prevents cross-tenant leakage)
        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld($world)
            ->where('id', $id)
            ->first();

        if (!$listing) {
            // Return null to signal not found (controller maps to 404 NOT_FOUND)
            return null;
        }

        // Validate partial update fields
        $validator = Validator::make($input, [
            'title' => 'sometimes|string|max:120',
            'description' => 'sometimes|string|nullable|max:5000',
            'price_amount' => 'sometimes|nullable|integer|min:0|max:999999999',
            'currency' => 'sometimes|nullable|string|size:3',
            'status' => 'sometimes|in:draft,published',
        ]);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $validated = $validator->validated();

        // Update only provided fields
        if (isset($validated['title'])) {
            $listing->title = $validated['title'];
        }
        if (array_key_exists('description', $validated)) {
            $listing->description = $validated['description'];
        }
        if (array_key_exists('price_amount', $validated)) {
            $listing->price_amount = $validated['price_amount'];
        }
        if (array_key_exists('currency', $validated)) {
            $listing->currency = $validated['currency'];
        }
        if (isset($validated['status'])) {
            $listing->status = $validated['status'];
        }
        
        $listing->save();

        return $listing;
    }

    /**
     * Delete a listing (hard delete)
     * 
     * @param string $world World identifier (commerce, food, rentals)
     * @param string $tenantId Tenant ID (from resolved context)
     * @param string $id Listing ID
     * @return bool True if deleted, false if not found (wrong tenant/world)
     */
    public static function delete(string $world, string $tenantId, string $id): bool
    {
        // Find listing in tenant+world scope (prevents cross-tenant leakage)
        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld($world)
            ->where('id', $id)
            ->first();

        if (!$listing) {
            // Return false to signal not found (controller maps to 404 NOT_FOUND)
            return false;
        }

        // Hard delete
        $listing->delete();

        return true;
    }
}

