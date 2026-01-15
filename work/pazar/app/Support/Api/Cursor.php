<?php

namespace App\Support\Api;

/**
 * Cursor Pagination Helper
 * 
 * Encodes and decodes cursor values using base64 JSON.
 * Format: { "sort": "created_at", "dir": "desc", "after": "<timestamp|id>" }
 */
final class Cursor
{
    /**
     * Encode cursor value
     * 
     * @param string $sort Sort field (e.g., "created_at")
     * @param string $dir Sort direction ("asc" or "desc")
     * @param string $after After value (timestamp or ID)
     * @return string Base64-encoded cursor string
     */
    public static function encode(string $sort, string $dir, string $after): string
    {
        $data = [
            'sort' => $sort,
            'dir' => $dir,
            'after' => $after,
        ];

        $json = json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        return base64_encode($json);
    }

    /**
     * Decode cursor value
     * 
     * @param string $cursor Base64-encoded cursor string
     * @return array|null Decoded cursor data or null if invalid
     */
    public static function decode(string $cursor): ?array
    {
        if (empty($cursor)) {
            return null;
        }

        $decoded = base64_decode($cursor, true);
        if ($decoded === false) {
            return null;
        }

        $data = json_decode($decoded, true);
        if (!is_array($data)) {
            return null;
        }

        // Validate required fields
        if (!isset($data['sort']) || !isset($data['dir']) || !isset($data['after'])) {
            return null;
        }

        // Validate dir
        if (!in_array($data['dir'], ['asc', 'desc'], true)) {
            return null;
        }

        return $data;
    }

    /**
     * Validate cursor input
     * 
     * @param string|null $cursor Cursor string or null
     * @return bool True if valid, false otherwise
     */
    public static function isValid(?string $cursor): bool
    {
        if ($cursor === null || $cursor === '') {
            return true; // Empty cursor is valid (means first page)
        }

        return self::decode($cursor) !== null;
    }
}



