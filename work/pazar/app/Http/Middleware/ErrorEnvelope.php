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

        // If standard envelope (ok:false), ensure request_id and code/error_code duality
        if (isset($decoded['ok']) && $decoded['ok'] === false) {
            $modified = false;
            if (empty($decoded['request_id']) || $decoded['request_id'] === null || $decoded['request_id'] === '' || $decoded['request_id'] === '-') {
                $decoded['request_id'] = $getRequestId();
                $modified = true;
            }
            // WP-66: Ensure both code and error_code for stable contract
            $ec = $decoded['error_code'] ?? $decoded['code'] ?? null;
            if ($ec !== null && (string)$ec !== '') {
                if (!isset($decoded['code']) || $decoded['code'] === null || $decoded['code'] === '') {
                    $decoded['code'] = $ec;
                    $modified = true;
                }
                if (!isset($decoded['error_code']) || $decoded['error_code'] === null || $decoded['error_code'] === '') {
                    $decoded['error_code'] = $ec;
                    $modified = true;
                }
            }
            if ($modified) {
                $status = $response->getStatusCode();
                $headers = $response->headers->all();
                return response()->json($decoded, $status, $headers);
            }
            return $response; // Already in standard format
        }

        // Check if has legacy "error" key and no "ok" key
        if (isset($decoded['error']) && !isset($decoded['ok'])) {
            $errorData = $decoded['error'];
            $errorCode = 'HTTP_ERROR';
            $message = 'Request failed.';
            $details = null;

            // WP-65: Preserve P0 CORE 422 codes (unknown_attribute_keys, invalid_attribute_value, leaf_category_required)
            if (isset($decoded['code']) && is_string($decoded['code']) && $decoded['code'] !== '') {
                $errorCode = $decoded['code'];
                if (isset($decoded['message']) && is_string($decoded['message'])) {
                    $message = $decoded['message'];
                }
                if (isset($decoded['details']) && is_array($decoded['details'])) {
                    $details = $decoded['details'];
                }
            }
            // Map error type to error_code (when error is object)
            elseif (is_array($errorData) && isset($errorData['type'])) {
                $type = $errorData['type'];
                $errorCode = match ($type) {
                    'validation' => 'VALIDATION_ERROR',
                    'authentication' => 'UNAUTHORIZED',
                    'authorization' => 'FORBIDDEN',
                    'not_found' => 'NOT_FOUND',
                    default => 'HTTP_ERROR',
                };
            }

            if (is_array($errorData) && isset($errorData['message'])) {
                $message = $errorData['message'];
            }

            // Extract details (fields for validation, status for HTTP errors)
            if ($details === null && is_array($errorData)) {
                if (isset($errorData['fields'])) {
                    $details = ['fields' => $errorData['fields']];
                } elseif (isset($errorData['status'])) {
                    $details = ['status' => $errorData['status']];
                }
            }

            // Get request_id (never null, generate if missing)
            $requestId = $getRequestId();

            // WP-66: Include BOTH code and error_code for stable machine-readable contract
            $envelope = [
                'ok' => false,
                'code' => $errorCode,
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

        // Debug headers: Prove ErrorEnvelope middleware ran (only in debug/local)
        if (config('app.debug') || config('app.env') === 'local') {
            $response->headers->set('X-ErrorEnvelope', '1');
            $response->headers->set('X-ErrorEnvelope-Status', (string)$response->getStatusCode());
        }

        // Final check: Ensure request_id and code/error_code duality for standard envelope (ok:false)
        $finalBody = $response->getContent();
        if (!empty($finalBody) && str_starts_with(trim($finalBody), '{')) {
            $finalDecoded = json_decode($finalBody, true);
            if (is_array($finalDecoded) && isset($finalDecoded['ok']) && $finalDecoded['ok'] === false) {
                $modified = false;
                if (empty($finalDecoded['request_id']) || $finalDecoded['request_id'] === null || $finalDecoded['request_id'] === '' || $finalDecoded['request_id'] === '-') {
                    $finalDecoded['request_id'] = $getRequestId();
                    $modified = true;
                }
                $ec = $finalDecoded['error_code'] ?? $finalDecoded['code'] ?? null;
                if ($ec !== null && (string)$ec !== '') {
                    if (!isset($finalDecoded['code']) || $finalDecoded['code'] === null || $finalDecoded['code'] === '') {
                        $finalDecoded['code'] = $ec;
                        $modified = true;
                    }
                    if (!isset($finalDecoded['error_code']) || $finalDecoded['error_code'] === null || $finalDecoded['error_code'] === '') {
                        $finalDecoded['error_code'] = $ec;
                        $modified = true;
                    }
                }
                if ($modified) {
                    $status = $response->getStatusCode();
                    $headers = $response->headers->all();
                    return response()->json($finalDecoded, $status, $headers);
                }
            }
        }

        return $response;
    }
}

