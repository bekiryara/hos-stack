/**
 * Limited view (query fallback) — reason classification, query parsing, message map.
 * WP-NEXT: Detail fallback centralization. No hard-code in pages.
 */

export const LIMITED_REASON = {
  FETCH_FAILED: 'fetch_failed',
  UNAUTHORIZED: 'unauthorized',
  FORBIDDEN: 'forbidden',
  NOT_FOUND: 'not_found',
  NO_ID: 'no_id',
  UNKNOWN: 'unknown',
};

/**
 * @param {unknown} err
 * @returns {string}
 */
export function classifyLimitedReason(err) {
  const status = err?.status ?? err?.response?.status ?? null;
  if (status === 401) return LIMITED_REASON.UNAUTHORIZED;
  if (status === 403) return LIMITED_REASON.FORBIDDEN;
  if (status === 404) return LIMITED_REASON.NOT_FOUND;
  if (status != null) return LIMITED_REASON.FETCH_FAILED;
  return LIMITED_REASON.UNKNOWN;
}

/**
 * @param {Record<string, unknown>} query - route.query
 * @param {string[]} allowKeys
 * @returns {Record<string, string|null>}
 */
export function buildLimitedFromQuery(query, allowKeys) {
  if (!query || typeof query !== 'object') return {};
  const out = {};
  for (const key of allowKeys) {
    const v = query[key];
    if (v == null || v === '') {
      out[key] = null;
    } else {
      out[key] = String(v).trim() || null;
    }
  }
  return out;
}

/**
 * @param {string} reason
 * @returns {string}
 */
export function limitedMessage(reason) {
  const map = {
    [LIMITED_REASON.FETCH_FAILED]: 'Limited view — API fetch failed.',
    [LIMITED_REASON.UNAUTHORIZED]: 'Limited view — authentication required.',
    [LIMITED_REASON.FORBIDDEN]: 'Limited view — access forbidden.',
    [LIMITED_REASON.NOT_FOUND]: 'Limited view — record not found.',
    [LIMITED_REASON.NO_ID]: 'Limited view — no record id.',
    [LIMITED_REASON.UNKNOWN]: 'Limited view — unable to load details.',
  };
  return map[reason] ?? map[LIMITED_REASON.UNKNOWN];
}
