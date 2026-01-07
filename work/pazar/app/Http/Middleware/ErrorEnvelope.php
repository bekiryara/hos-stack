<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * Enforce standard error envelope for error responses (>= 400).
 * Normalizes legacy error format to standard envelope if needed.
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

        // Check if has legacy "error" key and no "ok" key
        if (isset($decoded['error']) && !isset($decoded['ok'])) {
            $errorData = $decoded['error'];
            $errorCode = 'HTTP_ERROR';
            $message = 'Request failed.';
            $details = null;

            // Map error type to error_code
            if (isset($errorData['type'])) {
                $type = $errorData['type'];
                $errorCode = match ($type) {
                    'validation' => 'VALIDATION_ERROR',
                    'authentication' => 'UNAUTHORIZED',
                    'authorization' => 'FORBIDDEN',
                    'not_found' => 'NOT_FOUND',
                    default => 'HTTP_ERROR',
                };
            }

            if (isset($errorData['message'])) {
                $message = $errorData['message'];
            }

            // Extract details (fields for validation, status for HTTP errors)
            if (isset($errorData['fields'])) {
                $details = ['fields' => $errorData['fields']];
            } elseif (isset($errorData['status'])) {
                $details = ['status' => $errorData['status']];
            }

            // Get request_id (never null, generate if missing)
            $requestId = $getRequestId();

            // Build standard envelope
            $envelope = [
                'ok' => false,
                'error_code' => $errorCode,
                'message' => $message,
                'request_id' => $requestId,
            ];

            if ($details !== null) {
                $envelope['details'] = $details;
            }

            $response->setContent(json_encode($envelope, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
            $response->headers->set('Content-Type', 'application/json');
        }

        return $response;
    }
}

