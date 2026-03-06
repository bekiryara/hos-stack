<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * Enforce request_id presence for standard error envelopes (ok:false).
 */
class ErrorEnvelope
{
    public function handle(Request $request, Closure $next): Response
    {
        /** @var \Symfony\Component\HttpFoundation\Response $response */
        $response = $next($request);

        // Only process error responses (status >= 400)
        if ($response->getStatusCode() < 400) {
            return $response;
        }

        // Only process JSON responses
        $contentType = $response->headers->get('Content-Type', '');
        if (!str_contains($contentType, 'application/json') && !str_contains($contentType, 'json')) {
            return $response;
        }

        $body = $response->getContent();
        if (empty($body) || !str_starts_with(trim($body), '{')) {
            return $response;
        }

        // Try to decode JSON
        $decoded = json_decode($body, true);
        if (!is_array($decoded)) {
            return $response;
        }

        // Helper: Get or generate request_id (never null)
        $getRequestId = function () use ($response, $request): string {
            // Try multiple sources
            $requestId = $response->headers->get('X-Request-Id')
                ?? $request->headers->get('X-Request-Id')
                ?? $request->attributes->get('request_id')
                ?? null;
            
            // If still null or empty, generate UUID
            if ($requestId === null || $requestId === '') {
                $requestId = (string) Str::uuid();
            }
            
            return (string) $requestId;
        };

        // If standard envelope (ok:false), ensure request_id is always filled
        if (isset($decoded['ok']) && $decoded['ok'] === false) {
            // Standard envelope format - ensure request_id is present and not null/empty/'-'
            if (empty($decoded['request_id']) || $decoded['request_id'] === null || $decoded['request_id'] === '' || $decoded['request_id'] === '-') {
                $decoded['request_id'] = $getRequestId();
                $status = $response->getStatusCode();
                // Preserve all headers and status code
                $headers = $response->headers->all();
                return response()->json($decoded, $status, $headers);
            }
            return $response; // Already in standard format with valid request_id
        }

        // Debug headers: Prove ErrorEnvelope middleware ran (only in debug/local)
        if (config('app.debug') || config('app.env') === 'local') {
            $response->headers->set('X-ErrorEnvelope', '1');
            $response->headers->set('X-ErrorEnvelope-Status', (string)$response->getStatusCode());
        }

        // Final check: Ensure request_id is filled for standard envelope (ok:false)
        // Re-read body in case it was modified by legacy conversion
        $finalBody = $response->getContent();
        if (!empty($finalBody) && str_starts_with(trim($finalBody), '{')) {
            $finalDecoded = json_decode($finalBody, true);
            if (is_array($finalDecoded) && isset($finalDecoded['ok']) && $finalDecoded['ok'] === false) {
                if (empty($finalDecoded['request_id']) || $finalDecoded['request_id'] === null || $finalDecoded['request_id'] === '' || $finalDecoded['request_id'] === '-') {
                    $finalDecoded['request_id'] = $getRequestId();
                    $status = $response->getStatusCode();
                    $headers = $response->headers->all();
                    return response()->json($finalDecoded, $status, $headers);
                }
            }
        }

        return $response;
    }
}
