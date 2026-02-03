<?php

use Illuminate\Foundation\Application;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    // Artisan commands: app/Console/Commands removed (was empty). Schedule: no pazar commands.
    ->withSchedule(function (Schedule $schedule): void {
        // Reserved for future: reservations:expire-holds, etc.
    })
    ->withMiddleware(function (Middleware $middleware): void {
        // CORS and security headers (early) - global middleware
        $middleware->prepend(\App\Http\Middleware\Cors::class);
        $middleware->prepend(\App\Http\Middleware\SecurityHeaders::class);
        
        // Force JSON for API/auth routes (early) - global middleware
        $middleware->prepend(\App\Http\Middleware\ForceJsonForApi::class);

        // Request ID and error envelope - global middleware (web and API)
        $middleware->web(append: [
            \App\Http\Middleware\RequestId::class,
        ]);
        $middleware->api(append: [
            \App\Http\Middleware\RequestId::class,
        ]);
        
        // Enforce error envelope (late, after response generation) - global middleware
        $middleware->append(\App\Http\Middleware\ErrorEnvelope::class);

        // This project is a JSON API (no browser forms). Exempt API endpoints from CSRF protection
        // so token-authenticated requests (and webhooks) work in real HTTP clients.
        $middleware->validateCsrfTokens(except: [
            'api/*',
            'orders*',
            'reservations*',
            'payments*',
        ]);

        $middleware->alias([
            'tenant.scope' => \App\Http\Middleware\TenantScope::class, // WP-26: Store-scope X-Active-Tenant-Id + membership enforcement
            'tenant.membership_strict' => \App\Http\Middleware\TenantMembershipStrict::class, // WP-NEXT: Tx decisions strict HOS membership
            'persona.scope' => \App\Http\Middleware\PersonaScope::class, // WP-8: Persona-based header enforcement
            'auth.any' => \App\Http\Middleware\AuthAny::class,
            'auth.ctx' => \App\Http\Middleware\AuthContext::class, // WP-13: JWT auth context
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $isApiRequest = function (Request $request): bool {
            return $request->expectsJson()
                || $request->is('api/*')
                || $request->is('orders*')
                || $request->is('reservations*')
                || $request->is('payments*');
        };

        // Helper: Get or generate request_id (guaranteed non-null)
        $getRequestId = function (Request $request): string {
            // Try header first
            $requestId = $request->header('X-Request-Id');
            
            // Else try request attributes
            if (empty($requestId)) {
                $requestId = $request->attributes->get('request_id');
            }
            
            // If empty/null/"-" => generate UUID
            if (empty($requestId) || $requestId === '-' || $requestId === null) {
                $requestId = (string) Str::uuid();
            }
            
            // Ensure resolved id is stored in request attributes
            $request->attributes->set('request_id', $requestId);
            
            return (string) $requestId;
        };

        // Helper: Map exception to error code
        $getErrorCode = function (Throwable $e): string {
            if ($e instanceof ValidationException) {
                return 'VALIDATION_ERROR';
            }
            if ($e instanceof AuthenticationException) {
                return 'UNAUTHORIZED';
            }
            if ($e instanceof AuthorizationException) {
                return 'FORBIDDEN';
            }
            if ($e instanceof HttpExceptionInterface) {
                $status = $e->getStatusCode();
                return match ($status) {
                    404 => 'NOT_FOUND',
                    401 => 'UNAUTHORIZED',
                    403 => 'FORBIDDEN',
                    422 => 'VALIDATION_ERROR',
                    default => 'HTTP_ERROR',
                };
            }
            return 'INTERNAL_ERROR';
        };

        // Helper: Structured error logging
        $logError = function (Throwable $e, Request $request, string $errorCode) use ($getRequestId): void {
            // Get guaranteed non-null request_id
            $requestId = $getRequestId($request);
            
            Log::error('error', [
                'event' => 'error',
                'error_code' => $errorCode,
                'request_id' => $requestId,
                'route' => $request->route()?->getName() ?? $request->path(),
                'method' => $request->method(),
                // Pazar is always the marketplace world (world_key); do not log X-World as a world_key.
                'world_key' => 'marketplace',
                // If some caller still sends X-World/world params (legacy), keep it as a hint only.
                'world_hint' => $request->header('X-World') ?? $request->input('world'),
                'user_id' => $request->user()?->id,
                'exception_class' => get_class($e),
                'message' => $e->getMessage(),
            ]);
        };

        // Helper: Standard error envelope
        $errorResponse = function (Request $request, string $errorCode, string $message, int $status, ?array $details = null) use ($getRequestId): \Illuminate\Http\JsonResponse {
            // Get guaranteed non-null request_id
            $requestId = $getRequestId($request);
            
            $body = [
                'ok' => false,
                'error_code' => $errorCode,
                'message' => $message,
                'request_id' => $requestId,
            ];
            if ($details !== null) {
                $body['details'] = $details;
            }
            
            // Return JSON response with X-Request-Id header
            return response()->json($body, $status)->header('X-Request-Id', $requestId);
        };

        $exceptions->shouldRenderJsonWhen(function (Request $request, Throwable $e) use ($isApiRequest) {
            return $isApiRequest($request);
        });

        $exceptions->render(function (ValidationException $e, Request $request) use ($isApiRequest, $getRequestId, $getErrorCode, $logError, $errorResponse) {
            if (! $isApiRequest($request)) {
                return null; // default web behavior (redirect back with errors)
            }

            $errorCode = $getErrorCode($e);
            $logError($e, $request, $errorCode);

            return $errorResponse(
                $request,
                $errorCode,
                'Validation failed.',
                $e->status,
                ['fields' => $e->errors()]
            );
        });

        $exceptions->render(function (AuthenticationException $e, Request $request) use ($isApiRequest, $getRequestId, $getErrorCode, $logError, $errorResponse) {
            if (! $isApiRequest($request)) {
                return null; // default web behavior (redirect to login)
            }

            $errorCode = $getErrorCode($e);
            $logError($e, $request, $errorCode);

            return $errorResponse(
                $request,
                $errorCode,
                'Unauthenticated.',
                401
            );
        });

        $exceptions->render(function (AuthorizationException $e, Request $request) use ($isApiRequest, $getRequestId, $getErrorCode, $logError, $errorResponse) {
            if (! $isApiRequest($request)) {
                return null; // default web behavior (403 HTML)
            }

            $errorCode = $getErrorCode($e);
            $logError($e, $request, $errorCode);

            return $errorResponse(
                $request,
                $errorCode,
                'Forbidden.',
                403
            );
        });

        $exceptions->render(function (HttpExceptionInterface $e, Request $request) use ($isApiRequest, $getRequestId, $getErrorCode, $logError, $errorResponse) {
            if (! $isApiRequest($request)) {
                return null; // default web behavior (HTML error pages)
            }

            $status = $e->getStatusCode();
            $errorCode = $getErrorCode($e);

            $message = $e->getMessage();
            if ($message === '') {
                $message = match ($status) {
                    401 => 'Unauthenticated.',
                    403 => 'Forbidden.',
                    404 => 'Not found.',
                    422 => 'Validation failed.',
                    default => 'Request failed.',
                };
            }

            $logError($e, $request, $errorCode);

            return $errorResponse(
                $request,
                $errorCode,
                $message,
                $status
            );
        });

        $exceptions->render(function (Throwable $e, Request $request) use ($isApiRequest, $getRequestId, $getErrorCode, $logError, $errorResponse) {
            if (! $isApiRequest($request)) {
                return null; // default web behavior (HTML 500)
            }

            $errorCode = $getErrorCode($e);
            $logError($e, $request, $errorCode);

            return $errorResponse(
                $request,
                $errorCode,
                'Server error.',
                500
            );
        });
    })->create();
