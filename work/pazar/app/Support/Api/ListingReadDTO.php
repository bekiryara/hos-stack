<?php

namespace App\Support\Api;

/**
 * Listing Read DTO
 * 
 * Provides a stable, minimal, world-agnostic payload for listing responses.
 * Safe field access with fallbacks to avoid crashes on missing fields.
 */
final class ListingReadDTO
{
    /**
     * Convert a Listing model to a stable array representation
     * 
     * @param \App\Models\Listing|object $listing Listing model or object
     * @return array Stable array representation
     */
    public static function fromModel($listing): array
    {
        $result = [];

        // id (required)
        if (isset($listing->id)) {
            $result['id'] = (string) $listing->id;
        } elseif (property_exists($listing, 'id')) {
            $result['id'] = (string) $listing->id;
        }

        // tenant_id (if exists)
        if (isset($listing->tenant_id)) {
            $result['tenant_id'] = (string) $listing->tenant_id;
        } elseif (property_exists($listing, 'tenant_id') && $listing->tenant_id !== null) {
            $result['tenant_id'] = (string) $listing->tenant_id;
        }

        // world (if exists)
        if (isset($listing->world)) {
            $result['world'] = (string) $listing->world;
        } elseif (property_exists($listing, 'world') && $listing->world !== null) {
            $result['world'] = (string) $listing->world;
        }

        // title/name (fallback chain, avoid null)
        $title = null;
        if (isset($listing->title)) {
            $title = $listing->title;
        } elseif (property_exists($listing, 'title') && $listing->title !== null) {
            $title = $listing->title;
        } elseif (isset($listing->name)) {
            $title = $listing->name;
        } elseif (property_exists($listing, 'name') && $listing->name !== null) {
            $title = $listing->name;
        }
        if ($title !== null) {
            $result['title'] = (string) $title;
        }

        // description (if exists, nullable)
        if (isset($listing->description) && $listing->description !== null) {
            $result['description'] = (string) $listing->description;
        } elseif (property_exists($listing, 'description') && $listing->description !== null) {
            $result['description'] = (string) $listing->description;
        }

        // status (if exists)
        if (isset($listing->status)) {
            $result['status'] = (string) $listing->status;
        } elseif (property_exists($listing, 'status') && $listing->status !== null) {
            $result['status'] = (string) $listing->status;
        }

        // created_at (if exists)
        if (isset($listing->created_at)) {
            if (is_object($listing->created_at) && method_exists($listing->created_at, 'toIso8601String')) {
                $result['created_at'] = $listing->created_at->toIso8601String();
            } elseif (is_string($listing->created_at)) {
                $result['created_at'] = $listing->created_at;
            }
        } elseif (property_exists($listing, 'created_at') && $listing->created_at !== null) {
            if (is_object($listing->created_at) && method_exists($listing->created_at, 'toIso8601String')) {
                $result['created_at'] = $listing->created_at->toIso8601String();
            } elseif (is_string($listing->created_at)) {
                $result['created_at'] = $listing->created_at;
            }
        }

        // updated_at (if exists)
        if (isset($listing->updated_at)) {
            if (is_object($listing->updated_at) && method_exists($listing->updated_at, 'toIso8601String')) {
                $result['updated_at'] = $listing->updated_at->toIso8601String();
            } elseif (is_string($listing->updated_at)) {
                $result['updated_at'] = $listing->updated_at;
            }
        } elseif (property_exists($listing, 'updated_at') && $listing->updated_at !== null) {
            if (is_object($listing->updated_at) && method_exists($listing->updated_at, 'toIso8601String')) {
                $result['updated_at'] = $listing->updated_at->toIso8601String();
            } elseif (is_string($listing->updated_at)) {
                $result['updated_at'] = $listing->updated_at;
            }
        }

        // price/currency (if exists) else omit
        $hasPrice = false;
        if (isset($listing->price_amount) && $listing->price_amount !== null) {
            $result['price_amount'] = (int) $listing->price_amount;
            $hasPrice = true;
        } elseif (property_exists($listing, 'price_amount') && $listing->price_amount !== null) {
            $result['price_amount'] = (int) $listing->price_amount;
            $hasPrice = true;
        } elseif (isset($listing->price) && $listing->price !== null) {
            $result['price_amount'] = (int) $listing->price;
            $hasPrice = true;
        } elseif (property_exists($listing, 'price') && $listing->price !== null) {
            $result['price_amount'] = (int) $listing->price;
            $hasPrice = true;
        }

        if ($hasPrice) {
            if (isset($listing->currency) && $listing->currency !== null) {
                $result['currency'] = (string) $listing->currency;
            } elseif (property_exists($listing, 'currency') && $listing->currency !== null) {
                $result['currency'] = (string) $listing->currency;
            }
        }

        return $result;
    }
}



