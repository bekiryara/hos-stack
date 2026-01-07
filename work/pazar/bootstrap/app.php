<?php

use Illuminate\Foundation\Application;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
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
        // Force JSON for API/auth routes (early)
        $middleware->web(prepend: [
            \App\Http\Middleware\ForceJsonForApi::class,
        ]);

        $middleware->web(append: [
            \App\Http\Middleware\RequestId::class,
            // Enforce error envelope (late, after response generation)
            \App\Http\Middleware\ErrorEnvelope::class,
        ]);

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
            'super.admin' => \App\Http\Middleware\EnsureSuperAdmin::class,
            // UI (session-based) helpers
            'ui.super_admin' => \App\Http\Middleware\EnsureUiSuperAdmin::class,
            'ui.tenant' => \App\Http\Middleware\ResolveUiTenant::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $isApiRequest = function (Request $request): bool {
            return $request->expectsJson()
                || $request->is('admin/*')
                || $request->is('panel/*')
                || $request->is('auth/*')
                || $request->is('products')
                || $request->is('orders*')
                || $request->is('reservations*')
                || $request->is('payments*');
        };

        // Helper: Get request_id from request attributes
        $getRequestId = function (Request $request): ?string {
            return $request->attributes->get('request_id');
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
        $logError = function (Throwable $e, Request $request, string $errorCode): void {
            Log::error('error', [
                'event' => 'error',
                'error_code' => $errorCode,
                'request_id' => $request->attributes->get('request_id'),
                'route' => $request->route()?->getName() ?? $request->path(),
                'method' => $request->method(),
                'world' => $request->header('X-World') ?? $request->input('world'),
                'user_id' => $request->user()?->id,
                'exception_class' => get_class($e),
                'message' => $e->getMessage(),
            ]);
        };

        // Helper: Standard error envelope
        $errorResponse = function (Request $request, string $errorCode, string $message, int $status, ?array $details = null): \Illuminate\Http\JsonResponse {
            $body = [
                'ok' => false,
                'error_code' => $errorCode,
                'message' => $message,
                'request_id' => $request->attributes->get('request_id'),
            ];
            if ($details !== null) {
                $body['details'] = $details;
            }
            return response()->json($body, $status);
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
