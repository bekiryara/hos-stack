<?php

namespace App\Hos\Remote;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Symfony\Component\HttpKernel\Exception\ServiceUnavailableHttpException;

/**
 * Remote H-OS HTTP client (skeleton).
 *
 * Important:
 * - Not wired into runtime yet (default HOS_MODE=embedded).
 * - When wired, critical mutation operations MUST be fail-closed (503) on remote failure.
 */
final class RemoteHosHttpClient
{
    /**
     * @param  array<string,mixed>  $payload
     * @return array<string,mixed>
     */
    public function post(string $path, array $payload): array
    {
        $baseUrl = rtrim((string) config('hos.remote.base_url', ''), '/');
        if ($baseUrl === '') {
            throw new ServiceUnavailableHttpException(null, 'H-OS remote base_url is not configured.');
        }

        $apiKey = (string) config('hos.remote.api_key', '');
        $timeoutMs = (int) config('hos.remote.timeout_ms', 1500);
        $retries = (int) config('hos.remote.retries', 1);

        // Propagate request ID to H-OS
        $headers = $apiKey !== '' ? ['X-HOS-API-KEY' => $apiKey] : [];
        $request = request();
        if ($request instanceof Request && $request->hasHeader('X-Request-Id')) {
            $headers['X-Request-Id'] = $request->header('X-Request-Id');
        } elseif ($request instanceof Request && $request->attributes->has('request_id')) {
            $headers['X-Request-Id'] = $request->attributes->get('request_id');
        }

        try {
            $resp = Http::baseUrl($baseUrl)
                ->acceptJson()
                ->asJson()
                ->timeout(max(1, (int) ceil($timeoutMs / 1000)))
                ->retry($retries, 200)
                ->withHeaders($headers)
                ->post($path, $payload);

            if (! $resp->successful()) {
                $body = (string) $resp->body();
                $snippet = mb_substr($body, 0, 500);
                throw new ServiceUnavailableHttpException(
                    null,
                    'H-OS remote call failed: '.$resp->status().' '.$resp->reason().($snippet !== '' ? ' body='.$snippet : '')
                );
            }

            $json = $resp->json();
            if (! is_array($json)) {
                throw new ServiceUnavailableHttpException(null, 'H-OS remote response is not JSON.');
            }

            /** @var array<string,mixed> $json */
            return $json;
        } catch (ServiceUnavailableHttpException $e) {
            // Preserve the most useful error message (status/body) for logs & outbox last_error.
            throw $e;
        } catch (\Throwable $e) {
            throw new ServiceUnavailableHttpException(null, 'H-OS remote unavailable.', $e);
        }
    }

    /**
     * @return array<string,mixed>
     */
    public function get(string $path): array
    {
        $baseUrl = rtrim((string) config('hos.remote.base_url', ''), '/');
        if ($baseUrl === '') {
            throw new ServiceUnavailableHttpException(null, 'H-OS remote base_url is not configured.');
        }

        $apiKey = (string) config('hos.remote.api_key', '');
        $timeoutMs = (int) config('hos.remote.timeout_ms', 1500);
        $retries = (int) config('hos.remote.retries', 1);

        // Propagate request ID to H-OS
        $headers = $apiKey !== '' ? ['X-HOS-API-KEY' => $apiKey] : [];
        $request = request();
        if ($request instanceof Request && $request->hasHeader('X-Request-Id')) {
            $headers['X-Request-Id'] = $request->header('X-Request-Id');
        } elseif ($request instanceof Request && $request->attributes->has('request_id')) {
            $headers['X-Request-Id'] = $request->attributes->get('request_id');
        }

        try {
            $resp = Http::baseUrl($baseUrl)
                ->acceptJson()
                ->asJson()
                ->timeout(max(1, (int) ceil($timeoutMs / 1000)))
                ->retry($retries, 200)
                ->withHeaders($headers)
                ->get($path);

            if (! $resp->successful()) {
                $body = (string) $resp->body();
                $snippet = mb_substr($body, 0, 500);
                throw new ServiceUnavailableHttpException(
                    null,
                    'H-OS remote call failed: '.$resp->status().' '.$resp->reason().($snippet !== '' ? ' body='.$snippet : '')
                );
            }

            $json = $resp->json();
            if (! is_array($json)) {
                throw new ServiceUnavailableHttpException(null, 'H-OS remote response is not JSON.');
            }

            /** @var array<string,mixed> $json */
            return $json;
        } catch (ServiceUnavailableHttpException $e) {
            throw $e;
        } catch (\Throwable $e) {
            throw new ServiceUnavailableHttpException(null, 'H-OS remote unavailable.', $e);
        }
    }
}



