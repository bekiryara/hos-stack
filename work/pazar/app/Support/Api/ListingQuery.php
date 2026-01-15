<?php

namespace App\Support\Api;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

/**
 * Listing Query Builder
 * 
 * Applies filters and ordering to an Eloquent query builder.
 * Supports: q (search), status, from/to (date range), limit, cursor pagination.
 */
final class ListingQuery
{
    /**
     * Apply filters and ordering to a query builder
     * 
     * @param \Illuminate\Database\Eloquent\Builder $query Base query builder (already scoped to tenant/world)
     * @param \Illuminate\Http\Request $request HTTP request
     * @return array [$query, $limit, $nextCursor] Updated query, limit, and next cursor (null if no more pages)
     */
    public static function apply(Builder $query, Request $request): array
    {
        // Parse cursor (if provided)
        $cursorStr = $request->input('cursor');
        $cursorData = null;
        if (!empty($cursorStr)) {
            $cursorData = Cursor::decode($cursorStr);
            if ($cursorData === null) {
                // Invalid cursor - will be handled by controller (return 400 INVALID_CURSOR)
                // For now, treat as empty cursor (first page)
            }
        }

        // Apply search filter (q)
        $searchQuery = $request->input('q');
        if (!empty($searchQuery)) {
            $searchQuery = trim($searchQuery);
            // Safe length limit (max 80 characters)
            if (strlen($searchQuery) > 80) {
                $searchQuery = substr($searchQuery, 0, 80);
            }
            if (!empty($searchQuery)) {
                // Basic search on title/name fields (LIKE)
                $query->where(function ($q) use ($searchQuery) {
                    $q->where('title', 'LIKE', '%' . $searchQuery . '%')
                        ->orWhere('name', 'LIKE', '%' . $searchQuery . '%');
                });
            }
        }

        // Apply status filter
        $status = $request->input('status');
        if (!empty($status)) {
            $query->where('status', $status);
        }

        // Apply date range filters (from/to on created_at if exists)
        $from = $request->input('from');
        if (!empty($from)) {
            try {
                $fromDate = is_numeric($from) ? date('Y-m-d H:i:s', $from) : $from;
                $query->where('created_at', '>=', $fromDate);
            } catch (\Exception $e) {
                // Invalid date format - ignore
            }
        }

        $to = $request->input('to');
        if (!empty($to)) {
            try {
                $toDate = is_numeric($to) ? date('Y-m-d H:i:s', $to) : $to;
                $query->where('created_at', '<=', $toDate);
            } catch (\Exception $e) {
                // Invalid date format - ignore
            }
        }

        // Apply default ordering (created_at desc, then id desc for stability)
        $query->orderByDesc('created_at')
            ->orderByDesc('id');

        // Apply cursor pagination (if valid cursor provided)
        if ($cursorData !== null && $cursorData['sort'] === 'created_at' && $cursorData['dir'] === 'desc') {
            $afterValue = $cursorData['after'];
            // Parse after value (format: "timestamp:id")
            $parts = explode(':', $afterValue, 2);
            if (count($parts) === 2) {
                [$cursorCreatedAt, $cursorId] = $parts;
                $query->where(function ($q) use ($cursorCreatedAt, $cursorId) {
                    $q->where('created_at', '<', $cursorCreatedAt)
                        ->orWhere(function ($q2) use ($cursorCreatedAt, $cursorId) {
                            $q2->where('created_at', '=', $cursorCreatedAt)
                                ->where('id', '<', $cursorId);
                        });
                });
            }
        }

        // Apply limit (default 20, min 1, max 50)
        $limit = (int) $request->input('limit', 20);
        $limit = min(max($limit, 1), 50); // Clamp between 1 and 50

        return [$query, $limit, null]; // nextCursor will be computed by controller after fetching
    }
}



