// Messaging domain: thread and message operations
// WP-NEXT: Extracted from client.js (NO BEHAVIOR CHANGE)
import { messagingApiRequest } from '../request.js';

export async function messagingUpsertThread({ contextType, contextId, participants }) {
  return messagingApiRequest(
    '/api/v1/threads/upsert',
    {
      method: 'POST',
      body: JSON.stringify({
        context_type: contextType,
        context_id: contextId,
        participants,
      }),
    },
    false
  );
}

export async function messagingGetThreadByContext({ contextType, contextId }) {
  const qs = new URLSearchParams({
    context_type: contextType,
    context_id: contextId,
  });
  return messagingApiRequest(`/api/v1/threads/by-context?${qs.toString()}`, {}, false);
}

export async function messagingSendMessage(threadId, { senderType, senderId, body }) {
  return messagingApiRequest(
    `/api/v1/threads/${encodeURIComponent(threadId)}/messages`,
    {
      method: 'POST',
      body: JSON.stringify({
        sender_type: senderType,
        sender_id: senderId,
        body,
      }),
    },
    false
  );
}
