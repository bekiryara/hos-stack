<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class RequestId
{
    public function handle(Request $request, Closure $next): Response
    {
        $requestId = (string) $request->headers->get('X-Request-Id', '');

        if ($requestId === '' || strlen($requestId) > 128) {
            $requestId = (string) Str::uuid();
        }

        $request->attributes->set('request_id', $requestId);

        // Structured log context: ts, level, service, request_id, route, method, status, user_id, world_key
        Log::withContext([
            'service' => 'pazar',
            'request_id' => $requestId,
            'route' => $request->route()?->getName() ?? $request->path(),
            'method' => $request->method(),
            'tenant_id' => $request->tenant?->id,
            'user_id' => $request->user()?->id,
            // Pazar is always the marketplace world (world_key); do not log X-World as a world_key.
            'world_key' => 'marketplace',
            // If some caller still sends X-World/world params (legacy), keep it as a hint only.
            'world_hint' => $request->header('X-World') ?? $request->input('world'),
        ]);

        /** @var \Symfony\Component\HttpFoundation\Response $response */
        $response = $next($request);
        $response->headers->set('X-Request-Id', $requestId);

        return $response;
    }
}








