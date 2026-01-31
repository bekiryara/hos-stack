/**
 * In-memory toast queue for global success/error/info notifications.
 * WP-NEXT: Toast WP-1 core — no external deps.
 */

const DEFAULT_TIMEOUT_MS = 3500;

let toasts = [];
const listeners = [];

function nextId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
}

function notifyListeners() {
  listeners.forEach((cb) => cb());
}

/**
 * @param {'success'|'error'|'info'} type
 * @param {string} message
 * @param {number} [timeout_ms]
 * @returns {string|undefined} toast id if pushed, undefined if message empty
 */
export function pushToast(type, message, timeout_ms = DEFAULT_TIMEOUT_MS) {
  const trimmed = typeof message === 'string' ? message.trim() : '';
  if (!trimmed) return undefined;
  const id = nextId();
  toasts = [
    ...toasts,
    { id, type, message: trimmed, created_at: Date.now(), timeout_ms },
  ];
  notifyListeners();
  return id;
}

export function removeToast(id) {
  toasts = toasts.filter((t) => t.id !== id);
  notifyListeners();
}

export function clearAll() {
  toasts = [];
  notifyListeners();
}

export function getToasts() {
  return [...toasts];
}

/**
 * @param {() => void} callback
 * @returns {() => void} unsubscribe
 */
export function subscribe(callback) {
  listeners.push(callback);
  return () => {
    const i = listeners.indexOf(callback);
    if (i !== -1) listeners.splice(i, 1);
  };
}
