<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * World Lock Middleware
 * 
 * Validates and locks world context for API routes.
 * Sets ctx.world attribute and X-World response header.
 */
class WorldLock
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @param  string  $world  World identifier (e.g., 'commerce', 'food', 'rentals')
     * @return \Symfony\Component\HttpFoundation\Response
     */
    public function handle(Request $request, Closure $next, string $world): Response
    {
        // Get enabled worlds from config
        $enabledWorlds = config('worlds.enabled', []);
        $disabledWorlds = config('worlds.disabled', []);

        // Validate world is enabled
        if (!in_array($world, $enabledWorlds)) {
            // Check if world is explicitly disabled
            if (in_array($world, $disabledWorlds)) {
                $requestId = $request->attributes->get('request_id', '');
                if (empty($requestId)) {
                    $requestId = (string) Str::uuid();
                }

                return response()->json([
                    'ok' => false,
                    'error_code' => 'WORLD_DISABLED',
                    'message' => "World '$world' is disabled.",
                    'request_id' => $requestId,
                ], 404)->header('X-Request-Id', $requestId);
            }

            // Unknown world
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            return response()->json([
                'ok' => false,
                'error_code' => 'WORLD_INVALID',
                'message' => "World '$world' is not valid.",
                'request_id' => $requestId,
            ], 404)->header('X-Request-Id', $requestId);
        }

        // Set world context in request attributes
        $request->attributes->set('ctx.world', $world);
        $request->attributes->set('world', $world); // Compatibility/back-compat

        // Process request
        $response = $next($request);

        // Add X-World header to response (if response exists)
        if ($response instanceof Response) {
            $response->headers->set('X-World', $world);
        }

        return $response;
    }
}



