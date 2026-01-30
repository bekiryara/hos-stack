// API client for Marketplace backend
// WP-61: Use same-origin proxy path instead of direct 8080 to avoid CORS
// WP-68: Auto-attach Authorization header when token exists
import {
  getBearerToken,
  clearSession,
  setToken,
  saveSession,
  getActiveTenantId as getActiveTenantIdFromSession,
  setActiveTenantId as setActiveTenantIdFromSession,
} from '../lib/session.js';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/marketplace';
const MESSAGING_BASE_URL = '/api/messaging';
const MESSAGING_API_KEY = import.meta.env.VITE_MESSAGING_API_KEY || 'dev-messaging-key';

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
function buildPersonaHeaders(personaMode, config = {}) {
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
function generateIdempotencyKey() {
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

/**
 * HOS customer auth: login (public customer, tenantSlug omitted)
 * Keeps session logic centralized in this module (single auth spine).
 */
export async function login(email, password) {
  const response = await hosApiRequest(
    '/v1/auth/login',
    {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    },
    true // skipAuth: login is public
  );

  if (response?.token) {
    // Save token first, then hydrate user from /v1/me when possible
    setToken(response.token);

    let user = response.user || null;
    if (!user) {
      try {
        const me = await hosApiRequest('/v1/me', {}, false);
        user = {
          email: me?.email || email,
          id: me?.user_id || me?.id || null,
        };
      } catch {
        user = { email, id: null };
      }
    }

    saveSession(response.token, user);
    return { token: response.token, user };
  }

  return { token: response?.token, user: response?.user || { email, id: null } };
}

/**
 * HOS customer auth: register (public customer, tenantSlug omitted)
 * Keeps session logic centralized in this module (single auth spine).
 */
export async function register(email, password) {
  const response = await hosApiRequest(
    '/v1/auth/register',
    {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    },
    true // skipAuth: register is public
  );

  if (response?.token) {
    // Save token first, then hydrate user from /v1/me when possible
    setToken(response.token);

    let user = response.user || null;
    if (!user) {
      try {
        const me = await hosApiRequest('/v1/me', {}, false);
        user = {
          email: me?.email || email,
          id: me?.user_id || me?.id || null,
        };
      } catch {
        user = { email, id: null };
      }
    }

    saveSession(response.token, user);
    return { token: response.token, user };
  }

  return { token: response?.token, user: response?.user || { email, id: null } };
}

export const api = {
  // GUEST persona: No headers required (SPEC §5.3)
  // WP-68: Public calls use skipAuth to avoid attaching token
  getCategories: () => apiRequest('/api/v1/categories', {}, true), // skipAuth = true
  getFilterSchema: (categoryId) => apiRequest(`/api/v1/categories/${categoryId}/filter-schema`, {}, true), // skipAuth = true
  searchListings: (params) => {
    const queryString = new URLSearchParams(params).toString();
    // Stable read spine (array response).
    return apiRequest(`/api/v1/listings?${queryString}`, {}, true); // skipAuth = true
  },
  getListing: (id) => apiRequest(`/api/v1/listings/${id}`, {}, true), // skipAuth = true
  
  // HOS API (WP-48: tenant ID resolution)
  // WP-68: Auto-attach Authorization header (no manual token needed)
  getMyMemberships: () => {
    // Authorization header auto-attached by hosApiRequest
    return hosApiRequest('/v1/me/memberships');
  },
  
  // HOS Auth API (WP-66: browser auth flows)
  // WP-68: Create tenant endpoint (auth required)
  // Backend has /v1/tenants/v2, but WP-68 requires /v1/tenants
  // Use /v1/tenants/v2 for now (backend implementation)
  hosCreateTenant: ({ slug, display_name }) => {
    return hosApiRequest('/v1/tenants/v2', {
      method: 'POST',
      body: JSON.stringify({ slug, display_name }),
    });
  },
  
  // WP-68: Get current user info
  getMe: () => {
    return hosApiRequest('/v1/me');
  },
  
  hosRegisterOwner: ({ tenantSlug, email, password }) => {
    return hosApiRequest('/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify({ tenantSlug, email, password }),
    });
  },
  
  hosLogin: ({ tenantSlug, email, password }) => {
    return hosApiRequest('/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ tenantSlug, email, password }),
    });
  },

  // WP-??: Best-effort logout (revokes refresh cookie if present)
  // Always safe to call; UI still clears local session after.
  hosLogout: () => {
    return hosApiRequest('/v1/auth/logout', { method: 'POST' }, true);
  },
  
  // Active tenant is stored in `src/lib/session.js` (single source of truth).
  // Keep these wrappers for backwards compatibility.
  getActiveTenantId: () => getActiveTenantIdFromSession(),
  setActiveTenantId: (tenantId) => setActiveTenantIdFromSession(tenantId),
  
  // Account Portal - Personal scope (WP-32, WP-8)
  // WP-68: Auto-attach Authorization header (no manual token needed)
  // NOTE: These are HOS API endpoints, use hosApiRequest (not apiRequest)
  // Customer V1: Use /v1/me/* endpoints (userId parameter ignored but kept for compatibility)
  getMyOrders: (userId) => {
    // Authorization header auto-attached by hosApiRequest
    // userId parameter kept for compatibility but ignored (HOS uses token to identify user)
    return hosApiRequest('/v1/me/orders');
  },
  getMyRentals: (userId) => {
    // Authorization header auto-attached by hosApiRequest
    // userId parameter kept for compatibility but ignored (HOS uses token to identify user)
    return hosApiRequest('/v1/me/rentals');
  },
  getMyReservations: (userId) => {
    // Authorization header auto-attached by hosApiRequest
    // userId parameter kept for compatibility but ignored (HOS uses token to identify user)
    return hosApiRequest('/v1/me/reservations');
  },
  
  // Account Portal - Store scope (WP-32, WP-8)
  // STORE persona: X-Active-Tenant-Id header required (SPEC §5.2)
  getStoreListings: (tenantId, authToken) => {
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
    return apiRequest(`/api/v1/listings?tenant_id=${tenantId}`, { headers });
  },
  getStoreOrders: (tenantId, authToken) => {
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
    return apiRequest(`/api/v1/orders?seller_tenant_id=${tenantId}`, { headers });
  },
  getStoreRentals: (tenantId, authToken) => {
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
    return apiRequest(`/api/v1/rentals?provider_tenant_id=${tenantId}`, { headers });
  },
  getStoreReservations: (tenantId, authToken) => {
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
    return apiRequest(`/api/v1/reservations?provider_tenant_id=${tenantId}`, { headers });
  },

  // WP-NEXT: Transaction Decisions v1 — firm accept/reject (store scope)
  acceptStoreOrder: (orderId, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/orders/${orderId}/accept`, { method: 'POST', headers });
  },
  rejectStoreOrder: (orderId, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/orders/${orderId}/reject`, { method: 'POST', headers });
  },
  acceptStoreRental: (rentalId, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/rentals/${rentalId}/accept`, { method: 'POST', headers });
  },
  rejectStoreRental: (rentalId, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/rentals/${rentalId}/reject`, { method: 'POST', headers });
  },
  acceptStoreReservation: (reservationId, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/reservations/${reservationId}/accept`, { method: 'POST', headers });
  },
  rejectStoreReservation: (reservationId, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/reservations/${reservationId}/reject`, { method: 'POST', headers });
  },

  // WP-NEXT: Transaction Lifecycle v1 — status transition (store scope)
  transitionOrder: (id, action, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/orders/${id}/transition`, {
      method: 'POST',
      body: JSON.stringify({ action }),
      headers,
    });
  },
  transitionRental: (id, action, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/rentals/${id}/transition`, {
      method: 'POST',
      body: JSON.stringify({ action }),
      headers,
    });
  },
  transitionReservation: (id, action, tenantId) => {
    const tid = tenantId || getActiveTenantIdFromSession();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
    return apiRequest(`/api/v1/reservations/${id}/transition`, {
      method: 'POST',
      body: JSON.stringify({ action }),
      headers,
    });
  },

  // Write operations (WP-8: Persona-based headers)
  // STORE persona: X-Active-Tenant-Id required
  // WP-68: Auto-use activeTenantId from localStorage if tenantId not provided
  // WP-68: Token auto-attached by apiRequest
  createListing: (data, tenantId) => {
    const idempotencyKey = generateIdempotencyKey();
    // Auto-use activeTenantId if tenantId not provided
    const activeTenantId = tenantId || getActiveTenantIdFromSession();
    const headers = {
      'Idempotency-Key': idempotencyKey,
      'X-Active-Tenant-Id': activeTenantId,
    };
    // Authorization header auto-attached by apiRequest
    return apiRequest('/api/v1/listings', {
      method: 'POST',
      body: JSON.stringify(data),
      headers,
    });
  },
  
  publishListing: (id, tenantId) => {
    // Auto-use activeTenantId if tenantId not provided
    const activeTenantId = tenantId || getActiveTenantIdFromSession();
    const headers = {
      'X-Active-Tenant-Id': activeTenantId,
    };
    // Authorization header auto-attached by apiRequest
    return apiRequest(`/api/v1/listings/${id}/publish`, {
      method: 'POST',
      headers,
    });
  },
  
  // WP-68: Auto-attach Authorization header (no manual token needed)
  // PERSONAL persona: Authorization header required (SPEC §5.2)
  createReservation: (data, userId) => {
    const idempotencyKey = generateIdempotencyKey();
    const headers = {
      'Idempotency-Key': idempotencyKey,
    };
    if (userId) {
      headers['X-Requester-User-Id'] = userId;
    }
    // Authorization header auto-attached by apiRequest (via getBearerToken)
    return apiRequest('/api/v1/reservations', {
      method: 'POST',
      body: JSON.stringify(data),
      headers,
    });
  },
  
  createRental: (data, userId) => {
    const idempotencyKey = generateIdempotencyKey();
    const headers = {
      'Idempotency-Key': idempotencyKey,
    };
    if (userId) {
      headers['X-Requester-User-Id'] = userId;
    }
    // Authorization header auto-attached by apiRequest (via getBearerToken)
    return apiRequest('/api/v1/rentals', {
      method: 'POST',
      body: JSON.stringify(data),
      headers,
    });
  },
  
  // Customer V1: Create order (sale transaction)
  createOrder: (listingId, quantity = 1) => {
    const idempotencyKey = generateIdempotencyKey();
    const headers = {
      'Idempotency-Key': idempotencyKey,
    };
    // Authorization header auto-attached by apiRequest (via getBearerToken)
    return apiRequest('/api/v1/orders', {
      method: 'POST',
      body: JSON.stringify({
        listing_id: listingId,
        quantity: quantity,
      }),
      headers,
    });
  },
};

