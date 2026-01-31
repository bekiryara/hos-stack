// HTTP request infrastructure for Marketplace API
// WP-NEXT: Extracted from client.js (NO BEHAVIOR CHANGE)
import {
  getBearerToken,
  clearSession,
} from '../lib/session.js';

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/marketplace';
export const MESSAGING_BASE_URL = '/api/messaging';
export const MESSAGING_API_KEY = import.meta.env.VITE_MESSAGING_API_KEY || 'dev-messaging-key';

function notifySessionExpired() {
  // Router listens to this to apply a single, consistent 401 redirect policy.
  if (typeof window === 'undefined') return;
  try {
    window.dispatchEvent(new CustomEvent('hos:session-expired'));
  } catch {
    // ignore
  }
}

/**
 * Persona modes for WP-8 Persona & Scope Lock (SPEC §5.1-§5.3)
 * - GUEST: No headers required
 * - PERSONAL: Authorization header required
 * - STORE: X-Active-Tenant-Id header required
 */
export const PERSONA_MODES = {
  GUEST: 'guest',
  PERSONAL: 'personal',
  STORE: 'store',
};

/**
 * Build headers based on persona mode (WP-8)
 * @param {string} personaMode - 'guest', 'personal', or 'store'
 * @param {Object} config - { authToken, tenantId }
 * @returns {Object} Headers object
 */
export function buildPersonaHeaders(personaMode, config = {}) {
  const headers = {
    'Content-Type': 'application/json',
  };

  if (personaMode === PERSONA_MODES.PERSONAL) {
    // PERSONAL: Authorization header required (SPEC §5.2)
    if (config.authToken) {
      headers['Authorization'] = config.authToken.startsWith('Bearer ') 
        ? config.authToken 
        : `Bearer ${config.authToken}`;
    }
  } else if (personaMode === PERSONA_MODES.STORE) {
    // STORE: X-Active-Tenant-Id header required (SPEC §5.2)
    if (config.tenantId) {
      headers['X-Active-Tenant-Id'] = config.tenantId;
    }
    // Optional: Authorization header for store scope (GENESIS phase)
    if (config.authToken) {
      headers['Authorization'] = config.authToken.startsWith('Bearer ') 
        ? config.authToken 
        : `Bearer ${config.authToken}`;
    }
  }
  // GUEST: No headers required

  return headers;
}

export async function apiRequest(endpoint, options = {}, skipAuth = false) {
  const url = `${API_BASE_URL}${endpoint}`;
  
  // Merge headers: options.headers takes precedence
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };
  
  // WP-68: Auto-attach Authorization header if token exists
  // Allow opt-out via skipAuth parameter for truly public calls
  if (!skipAuth) {
    const bearerToken = getBearerToken();
    if (bearerToken) {
      headers['Authorization'] = bearerToken;
    }
  }
  
  const response = await fetch(url, {
    ...options,
    headers,
  });

  // WP-68: Handle 401 - clear session (redirect handled by router guard or component)
  if (response.status === 401) {
    clearSession();
    notifySessionExpired();
  }

  if (!response.ok) {
    let errorData;
    try {
      errorData = await response.json();
    } catch {
      errorData = { error: 'unknown', message: response.statusText };
    }
    const error = new Error(errorData.message || `API request failed: ${response.status}`);
    error.status = response.status;
    error.errorCode = errorData.error;
    error.data = errorData;
    throw error;
  }

  return response.json();
}

// Unwrap data envelope helper
// If resp is {data: ...} return resp.data
// If resp is {data: ..., meta: ...} return {items: resp.data, meta: resp.meta}
// Otherwise return resp as-is
export function unwrapData(resp) {
  if (resp && typeof resp === 'object' && 'data' in resp) {
    if ('meta' in resp) {
      return { items: resp.data, meta: resp.meta };
    }
    return resp.data;
  }
  return resp;
}

// Normalize list response helper (WP-32)
// If resp is an array => return { items: resp, meta: null }
// If resp is object with resp.data => return { items: resp.data, meta: resp.meta || null }
// Else => return { items: resp, meta: null } (fallback)
export function normalizeListResponse(resp) {
  if (Array.isArray(resp)) {
    return { items: resp, meta: null };
  }
  if (resp && typeof resp === 'object' && 'data' in resp) {
    return { items: resp.data, meta: resp.meta || null };
  }
  return { items: resp, meta: null };
}

// Generate UUID v4 for idempotency keys
export function generateIdempotencyKey() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// HOS API helper (WP-48: same-origin proxy via nginx)
// WP-68: Auto-attach Authorization header when token exists
// Calls HOS API through /api/* proxy (nginx routes to hos-api:3000)
export async function hosApiRequest(endpoint, options = {}, skipAuth = false) {
  const url = `/api${endpoint}`; // nginx proxies /api/* to HOS API
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };
  
  // WP-68: Auto-attach Authorization header if token exists
  // Allow opt-out via skipAuth parameter for truly public calls
  if (!skipAuth) {
    const bearerToken = getBearerToken();
    if (bearerToken) {
      headers['Authorization'] = bearerToken;
    }
  }
  
  const response = await fetch(url, {
    ...options,
    headers,
  });

  // WP-68: Handle 401 - clear session (redirect handled by router guard or component)
  if (response.status === 401) {
    clearSession();
    notifySessionExpired();
  }

  if (!response.ok) {
    let errorData;
    try {
      errorData = await response.json();
    } catch {
      errorData = { error: 'unknown', message: response.statusText };
    }
    const error = new Error(errorData.message || `API request failed: ${response.status}`);
    error.status = response.status;
    error.errorCode = errorData.error;
    error.data = errorData;
    throw error;
  }

  return response.json();
}

/**
 * Messaging API helper (same-origin proxy via HOS Web nginx)
 * Calls Messaging API through /api/messaging/* proxy.
 */
export async function messagingApiRequest(endpoint, options = {}, skipAuth = false) {
  const url = `${MESSAGING_BASE_URL}${endpoint}`;
  const headers = {
    'Content-Type': 'application/json',
    'messaging-api-key': MESSAGING_API_KEY,
    ...options.headers,
  };

  if (!skipAuth) {
    const bearerToken = getBearerToken();
    if (bearerToken) {
      headers['Authorization'] = bearerToken;
    }
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });

  // Standard 401 behavior: clear local session (redirect handled by router/component)
  if (response.status === 401) {
    clearSession();
    notifySessionExpired();
  }

  if (!response.ok) {
    let errorData;
    try {
      errorData = await response.json();
    } catch {
      errorData = { error: 'unknown', message: response.statusText };
    }
    const error = new Error(errorData.message || `Messaging request failed: ${response.status}`);
    error.status = response.status;
    error.errorCode = errorData.error;
    error.data = errorData;
    throw error;
  }

  return response.json();
}
