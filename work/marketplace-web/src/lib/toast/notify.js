/**
 * Global notify helpers — delegate to toast store.
 * WP-NEXT: Toast WP-1 core.
 */

import { pushToast } from './toast_store.js';

const DEFAULT_TIMEOUT_MS = 3500;

/**
 * @param {string} message
 * @param {{ timeout_ms?: number }} [opts]
 */
export function notifySuccess(message, opts = {}) {
  const timeout_ms = opts.timeout_ms ?? DEFAULT_TIMEOUT_MS;
  return pushToast('success', message, timeout_ms);
}

/**
 * @param {string} message
 * @param {{ timeout_ms?: number }} [opts]
 */
export function notifyError(message, opts = {}) {
  const timeout_ms = opts.timeout_ms ?? DEFAULT_TIMEOUT_MS;
  return pushToast('error', message, timeout_ms);
}

/**
 * @param {string} message
 * @param {{ timeout_ms?: number }} [opts]
 */
export function notifyInfo(message, opts = {}) {
  const timeout_ms = opts.timeout_ms ?? DEFAULT_TIMEOUT_MS;
  return pushToast('info', message, timeout_ms);
}
