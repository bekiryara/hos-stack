// API client for Marketplace backend
// WP-61: Use same-origin proxy path instead of direct 8080 to avoid CORS
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/marketplace';

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

export async function apiRequest(endpoint, options = {}) {
  const url = `${API_BASE_URL}${endpoint}`;
  
  // Merge headers: options.headers takes precedence over persona headers
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };
  
  const response = await fetch(url, {
    ...options,
    headers,
  });

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
// Calls HOS API through /api/* proxy (nginx routes to hos-api:3000)
async function hosApiRequest(endpoint, options = {}) {
  const url = `/api${endpoint}`; // nginx proxies /api/* to HOS API
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };
  
  const response = await fetch(url, {
    ...options,
    headers,
  });

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

export const api = {
  // GUEST persona: No headers required (SPEC §5.3)
  getCategories: () => apiRequest('/api/v1/categories'),
  getFilterSchema: (categoryId) => apiRequest(`/api/v1/categories/${categoryId}/filter-schema`),
  searchListings: (params) => {
    const queryString = new URLSearchParams(params).toString();
    return apiRequest(`/api/v1/listings?${queryString}`);
  },
  getListing: (id) => apiRequest(`/api/v1/listings/${id}`),
  
  // HOS API (WP-48: tenant ID resolution)
  // PERSONAL persona: Authorization header required
  getMyMemberships: (authToken) => {
    const headers = buildPersonaHeaders(PERSONA_MODES.PERSONAL, { authToken });
    return hosApiRequest('/v1/me/memberships', { headers });
  },
  
  // HOS Auth API (WP-66: browser auth flows)
  // NOTE: /tenants endpoint is public (no auth required)
  hosCreateTenant: ({ slug, name }) => {
    return hosApiRequest('/v1/tenants', {
      method: 'POST',
      body: JSON.stringify({ slug, name }),
    });
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
  
  // WP-62: Active Tenant helpers (single source of truth)
  getActiveTenantId: () => {
    return localStorage.getItem('active_tenant_id');
  },
  setActiveTenantId: (tenantId) => {
    if (tenantId) {
      localStorage.setItem('active_tenant_id', tenantId);
    } else {
      localStorage.removeItem('active_tenant_id');
    }
  },
  
  // Account Portal - Personal scope (WP-32, WP-8)
  // PERSONAL persona: Authorization header required (SPEC §5.2)
  getMyOrders: (userId, authToken) => {
    const headers = buildPersonaHeaders(PERSONA_MODES.PERSONAL, { authToken });
    return apiRequest(`/api/v1/orders?buyer_user_id=${userId}`, { headers });
  },
  getMyRentals: (userId, authToken) => {
    const headers = buildPersonaHeaders(PERSONA_MODES.PERSONAL, { authToken });
    return apiRequest(`/api/v1/rentals?renter_user_id=${userId}`, { headers });
  },
  getMyReservations: (userId, authToken) => {
    const headers = buildPersonaHeaders(PERSONA_MODES.PERSONAL, { authToken });
    return apiRequest(`/api/v1/reservations?requester_user_id=${userId}`, { headers });
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
  
  // Write operations (WP-8: Persona-based headers)
  // STORE persona: X-Active-Tenant-Id required
  // WP: Auto-use activeTenantId from localStorage if tenantId not provided
  createListing: (data, tenantId, authToken) => {
    const idempotencyKey = generateIdempotencyKey();
    // Auto-use activeTenantId if tenantId not provided
    const activeTenantId = tenantId || api.getActiveTenantId();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: activeTenantId, authToken });
    headers['Idempotency-Key'] = idempotencyKey;
    return apiRequest('/api/v1/listings', {
      method: 'POST',
      body: JSON.stringify(data),
      headers,
    });
  },
  
  publishListing: (id, tenantId) => {
    // Auto-use activeTenantId if tenantId not provided
    const activeTenantId = tenantId || api.getActiveTenantId();
    const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: activeTenantId });
    return apiRequest(`/api/v1/listings/${id}/publish`, {
      method: 'POST',
      headers,
    });
  },
  
  // PERSONAL persona: Authorization header required (SPEC §5.2)
  createReservation: (data, authToken, userId) => {
    const idempotencyKey = generateIdempotencyKey();
    const headers = buildPersonaHeaders(PERSONA_MODES.PERSONAL, { authToken });
    headers['Idempotency-Key'] = idempotencyKey;
    if (userId) {
      headers['X-Requester-User-Id'] = userId;
    }
    return apiRequest('/api/v1/reservations', {
      method: 'POST',
      body: JSON.stringify(data),
      headers,
    });
  },
  
  createRental: (data, authToken, userId) => {
    const idempotencyKey = generateIdempotencyKey();
    const headers = buildPersonaHeaders(PERSONA_MODES.PERSONAL, { authToken });
    headers['Idempotency-Key'] = idempotencyKey;
    if (userId) {
      headers['X-Requester-User-Id'] = userId;
    }
    return apiRequest('/api/v1/rentals', {
      method: 'POST',
      body: JSON.stringify(data),
      headers,
    });
  },
};

