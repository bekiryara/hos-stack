<?php

namespace App\Http\Middleware;

use App\Worlds\WorldRegistry;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * World Resolver Middleware
 * 
 * Determines world_id from route/URL and validates enabled/disabled status.
 * - Enabled worlds: attach world context, add X-World header
 * - Disabled worlds: return HTTP 410 WORLD_CLOSED
 * - Missing world: return HTTP 400
 */
final class WorldResolver
{
    public function __construct(
        private readonly WorldRegistry $worlds
    ) {
    }

    /**
     * Handle an incoming request
     * 
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Extract world_id from route parameter or URL segment
        $worldId = $request->route('world') ?? $request->segment(2);

        // If no world_id found, return 400 (missing world context)
        if (empty($worldId)) {
            if ($request->expectsJson() || $request->is('*/api/*')) {
                $requestId = $request->attributes->get('request_id', '');
                $response = response()->json([
                    'ok' => false,
                    'error_code' => 'MISSING_WORLD',
                ], 400);
                if ($requestId !== '') {
                    $response->header('X-Request-Id', $requestId);
                }
                return $response;
            }

            return response('Bad Request: World context is required.', 400);
        }

        $worldId = (string) $worldId;

        // Check if world exists (enabled or disabled)
        if (!$this->worlds->exists($worldId)) {
            if ($request->expectsJson() || $request->is('*/api/*')) {
                $requestId = $request->attributes->get('request_id', '');
                $response = response()->json([
                    'ok' => false,
                    'error_code' => 'WORLD_NOT_FOUND',
                    'world' => $worldId,
                ], 404);
                if ($requestId !== '') {
                    $response->header('X-Request-Id', $requestId);
                }
                return $response;
            }

            return response("Not Found: World '{$worldId}' does not exist.", 404);
        }

        // Check if world is disabled (closed-world law)
        if ($this->worlds->isDisabled($worldId)) {
            if ($request->expectsJson() || $request->is('*/api/*')) {
                $requestId = $request->attributes->get('request_id', '');
                $response = response()->json([
                    'ok' => false,
                    'error_code' => 'WORLD_CLOSED',
                    'world' => $worldId,
                ], 410)->header('X-World', $worldId);
                if ($requestId !== '') {
                    $response->header('X-Request-Id', $requestId);
                }
                return $response;
            }

            // HTML response for disabled world
            return response()->view('worlds.closed', [
                'world' => $worldId,
            ], 410)->header('X-World', $worldId);
        }

        // World is enabled: attach context and add X-World header
        $request->attributes->set('ctx.world', $worldId);
        $request->attributes->set('world_id', $worldId);

        $response = $next($request);

        // Add X-World header to response
        return $response->header('X-World', $worldId);
    }
}

