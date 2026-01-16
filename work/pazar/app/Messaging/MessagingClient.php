<?php

namespace App\Messaging;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Messaging Client
 * 
 * Client adapter for Messaging service integration.
 * Handles thread creation and message posting for context-based messaging.
 * 
 * Network failures are non-fatal (logged, but do not crash reservation creation).
 */
final class MessagingClient
{
    private string $baseUrl;
    private string $apiKey;
    private int $timeout;

    public function __construct()
    {
        $this->baseUrl = env('MESSAGING_BASE_URL', 'http://messaging-api:3000');
        $this->apiKey = env('MESSAGING_API_KEY', 'dev-messaging-key');
        $this->timeout = 1000; // 1 second timeout
    }

    /**
     * Upsert thread by context
     * 
     * @param string $contextType Context type (e.g., "reservation")
     * @param string $contextId Context ID (e.g., reservation ID)
     * @param array $participants Array of participants [{type: "user"|"tenant", id: "..."}]
     * @return string|null Thread ID on success, null on failure (logged)
     */
    public function upsertThread(string $contextType, string $contextId, array $participants): ?string
    {
        try {
            $response = Http::timeout($this->timeout / 1000)
                ->withHeaders([
                    'messaging-api-key' => $this->apiKey,
                    'Content-Type' => 'application/json'
                ])
                ->post("{$this->baseUrl}/api/v1/threads/upsert", [
                    'context_type' => $contextType,
                    'context_id' => $contextId,
                    'participants' => $participants
                ]);

            if ($response->successful()) {
                $data = $response->json();
                return $data['thread_id'] ?? null;
            }

            Log::warning('messaging.upsert_thread.failed', [
                'context_type' => $contextType,
                'context_id' => $contextId,
                'status' => $response->status(),
                'body' => $response->body()
            ]);

            return null;
        } catch (\Exception $e) {
            Log::warning('messaging.upsert_thread.exception', [
                'context_type' => $contextType,
                'context_id' => $contextId,
                'error' => $e->getMessage()
            ]);

            return null;
        }
    }

    /**
     * Post message to thread
     * 
     * @param string $threadId Thread ID
     * @param string $senderType Sender type ("user" or "tenant")
     * @param string $senderId Sender ID
     * @param string $body Message body
     * @return string|null Message ID on success, null on failure (logged)
     */
    public function postMessage(string $threadId, string $senderType, string $senderId, string $body): ?string
    {
        try {
            $response = Http::timeout($this->timeout / 1000)
                ->withHeaders([
                    'messaging-api-key' => $this->apiKey,
                    'Content-Type' => 'application/json'
                ])
                ->post("{$this->baseUrl}/api/v1/threads/{$threadId}/messages", [
                    'sender_type' => $senderType,
                    'sender_id' => $senderId,
                    'body' => $body
                ]);

            if ($response->successful()) {
                $data = $response->json();
                return $data['message_id'] ?? null;
            }

            Log::warning('messaging.post_message.failed', [
                'thread_id' => $threadId,
                'status' => $response->status(),
                'body' => $response->body()
            ]);

            return null;
        } catch (\Exception $e) {
            Log::warning('messaging.post_message.exception', [
                'thread_id' => $threadId,
                'error' => $e->getMessage()
            ]);

            return null;
        }
    }
}

