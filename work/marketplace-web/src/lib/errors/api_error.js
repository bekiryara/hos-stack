/**
 * Normalize API errors for display (status + message from response body).
 * WP-NEXT: Toast WP-2 — single source for API error messages.
 */

const MAX_MESSAGE_LEN = 140;

/**
 * Extract a short, single-line message from an API error.
 * Tries response body (message, detail, errors[0]) then err.message; fallback "Request failed".
 * @param {unknown} err - Thrown error (fetch API: err.status, err.data, err.message)
 * @returns {{ status: number|null, code: string|null, message: string }}
 */
export function normalizeApiError(err) {
  const status = err?.response?.status ?? err?.status ?? null;
  const data = err?.response?.data ?? err?.data ?? null;

  let message = '';
  if (data && typeof data === 'object') {
    message =
      (typeof data.message === 'string' && data.message.trim()) ||
      (typeof data.detail === 'string' && data.detail.trim()) ||
      (Array.isArray(data.errors) && data.errors[0] && typeof data.errors[0].message === 'string' && data.errors[0].message.trim()) ||
      (typeof data.error === 'string' && data.error.trim()) ||
      '';
  }
  if (!message && err?.message && typeof err.message === 'string') {
    message = err.message.trim();
  }
  if (!message) {
    message = 'Request failed';
  }
  if (message.length > MAX_MESSAGE_LEN) {
    message = message.slice(0, MAX_MESSAGE_LEN - 1).trim() + '…';
  }

  const code = data?.error ?? err?.errorCode ?? null;

  return {
    status,
    code: typeof code === 'string' ? code : null,
    message,
  };
}
