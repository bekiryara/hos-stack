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
    // Register class-based Artisan commands (keep routes/console.php minimal).
    ->withCommands([
        __DIR__.'/../app/Console/Commands',
    ])
    ->withSchedule(function (Schedule $schedule): void {
        // Airbnb feel: short reservation hold that expires if checkout/payment never starts.
        $schedule->command('reservations:expire-holds')->everyMinute();

        // H-OS outbox dispatcher (hybrid/remote). In embedded mode this command is a no-op.
        $schedule->command('hos:outbox-dispatch --limit=50')
            ->everyMinute()
            ->withoutOverlapping();
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
            'auth/*',
            'admin/*',
            'panel/*',
            'products',
            'orders*',
            'reservations*',
            'payments*',
        ]);

        $middleware->alias([
            'resolve.tenant' => \App\Http\Middleware\ResolveTenant::class,
            'tenant.user' => \App\Http\Middleware\EnsureTenantUser::class,
            'tenant.role' => \App\Http\Middleware\EnsureTenantRole::class,
            'auth.any' => \App\Http\Middleware\AuthAny::class,
            'auth.ctx' => \App\Http\Middleware\AuthContext::class, // WP-13: JWT auth context
            'super.admin' => \App\Http\Middleware\EnsureSuperAdmin::class,
            // UI (session-based) helpers
            'ui.super_admin' => \App\Http\Middleware\EnsureUiSuperAdmin::class,
            'ui.tenant' => \App\Http\Middleware\ResolveUiTenant::class,
            // World resolver
            'world.resolve' => \App\Http\Middleware\WorldResolver::class,
            'world.lock' => \App\Http\Middleware\WorldLock::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $isApiRequest = function (Request $request): bool {
            return $request->expectsJson()
                || $request->is('admin/*')
                || $request->is('panel/*')
                || $request->is('api/*')
                || $request->is('auth/*')
                || $request->is('products')
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
                'world' => $request->header('X-World') ?? $request->input('world'),
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
