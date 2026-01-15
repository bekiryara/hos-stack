<?php

namespace App\Support\ApiSpine;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

/**
 * Not Implemented Helper
 * 
 * Centralized helper for returning 501 NOT_IMPLEMENTED responses
 * in stub-only API spine endpoints (contract-first approach).
 */
final class NotImplemented
{
    /**
     * Return 501 NOT_IMPLEMENTED response with standard error envelope
     * 
     * @param Request $request
     * @param string $message Optional custom message (default: generic stub message)
     * @return JsonResponse
     */
    public static function response(Request $request, string $message = ''): JsonResponse
    {
        // Get request_id from request attributes (already set by middleware)
        $requestId = $request->attributes->get('request_id', '');
        
        // If request_id is not set, generate one (should not happen if middleware is active)
        if (empty($requestId)) {
            $requestId = (string) \Illuminate\Support\Str::uuid();
        }

        // Use custom message or default
        if (empty($message)) {
            $message = 'API endpoint is not implemented yet.';
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'NOT_IMPLEMENTED',
            'message' => $message,
            'request_id' => $requestId,
        ], 501)->header('Content-Type', 'application/json');

        return $response->header('X-Request-Id', $requestId);
    }
}





