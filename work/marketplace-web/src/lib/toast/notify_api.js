/**
 * Toast helpers for API success/error — use normalized API error messages.
 * WP-NEXT: Toast WP-2.
 */

import { normalizeApiError } from '../errors/api_error.js';
import { notifySuccess, notifyError } from './notify.js';

/**
 * Show error toast with context label + status + normalized message.
 * @param {unknown} err - Thrown API error
 * @param {string} contextLabel - Short label, e.g. "Create listing", "Firm register"
 */
export function notifyApiError(err, contextLabel) {
  const { status, message } = normalizeApiError(err);
  const statusPart = status != null ? String(status) : '';
  const text = [contextLabel, statusPart, message].filter(Boolean).join(' ').trim();
  if (text) notifyError(text);
}

/**
 * Show success toast for API action.
 * @param {string} message - e.g. "Listing created", "Firm registered"
 */
export function notifyApiSuccess(message) {
  notifySuccess(message);
}
