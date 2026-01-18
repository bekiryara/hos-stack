// API client for Marketplace backend
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

export async function apiRequest(endpoint, options = {}) {
  const url = `${API_BASE_URL}${endpoint}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
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

// Generate UUID v4 for idempotency keys
function generateIdempotencyKey() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

export const api = {
  getCategories: () => apiRequest('/api/v1/categories'),
  getFilterSchema: (categoryId) => apiRequest(`/api/v1/categories/${categoryId}/filter-schema`),
  searchListings: (params) => {
    const queryString = new URLSearchParams(params).toString();
    return apiRequest(`/api/v1/listings?${queryString}`);
  },
  getListing: (id) => apiRequest(`/api/v1/listings/${id}`),
  
  // Account Portal - Personal scope (Authorization required)
  getMyOrders: (authToken, userIdOpt) => {
    const headers = {
      'Authorization': authToken,
    };
    if (userIdOpt) {
      headers['X-Requester-User-Id'] = userIdOpt;
    }
    const endpoint = userIdOpt ? `/api/v1/orders?buyer_user_id=${userIdOpt}` : '/api/v1/orders';
    return apiRequest(endpoint, { headers });
  },
  getMyRentals: (authToken, userIdOpt) => {
    const headers = {
      'Authorization': authToken,
    };
    if (userIdOpt) {
      headers['X-Requester-User-Id'] = userIdOpt;
    }
    const endpoint = userIdOpt ? `/api/v1/rentals?renter_user_id=${userIdOpt}` : '/api/v1/rentals';
    return apiRequest(endpoint, { headers });
  },
  getMyReservations: (authToken, userIdOpt) => {
    const headers = {
      'Authorization': authToken,
    };
    if (userIdOpt) {
      headers['X-Requester-User-Id'] = userIdOpt;
    }
    const endpoint = userIdOpt ? `/api/v1/reservations?requester_user_id=${userIdOpt}` : '/api/v1/reservations';
    return apiRequest(endpoint, { headers });
  },
  
  // Account Portal - Store scope (X-Active-Tenant-Id required)
  getStoreListings: (authToken, tenantId, userIdOpt) => {
    const headers = {
      'Authorization': authToken,
      'X-Active-Tenant-Id': tenantId,
    };
    if (userIdOpt) {
      headers['X-Requester-User-Id'] = userIdOpt;
    }
    return apiRequest(`/api/v1/listings?tenant_id=${tenantId}`, { headers });
  },
  getStoreOrders: (authToken, tenantId, userIdOpt) => {
    const headers = {
      'Authorization': authToken,
      'X-Active-Tenant-Id': tenantId,
    };
    if (userIdOpt) {
      headers['X-Requester-User-Id'] = userIdOpt;
    }
    return apiRequest(`/api/v1/orders?seller_tenant_id=${tenantId}`, { headers });
  },
  getStoreRentals: (authToken, tenantId, userIdOpt) => {
    const headers = {
      'Authorization': authToken,
      'X-Active-Tenant-Id': tenantId,
    };
    if (userIdOpt) {
      headers['X-Requester-User-Id'] = userIdOpt;
    }
    return apiRequest(`/api/v1/rentals?provider_tenant_id=${tenantId}`, { headers });
  },
  getStoreReservations: (authToken, tenantId, userIdOpt) => {
    const headers = {
      'Authorization': authToken,
      'X-Active-Tenant-Id': tenantId,
    };
    if (userIdOpt) {
      headers['X-Requester-User-Id'] = userIdOpt;
    }
    return apiRequest(`/api/v1/reservations?provider_tenant_id=${tenantId}`, { headers });
  },
  
  // Write operations
  createListing: (data, tenantId) => {
    const idempotencyKey = generateIdempotencyKey();
    return apiRequest('/api/v1/listings', {
      method: 'POST',
      body: JSON.stringify(data),
      headers: {
        'X-Active-Tenant-Id': tenantId,
        'Idempotency-Key': idempotencyKey,
      },
    });
  },
  
  publishListing: (id, tenantId) => {
    return apiRequest(`/api/v1/listings/${id}/publish`, {
      method: 'POST',
      headers: {
        'X-Active-Tenant-Id': tenantId,
      },
    });
  },
  
  createReservation: (data, authToken, userId) => {
    const idempotencyKey = generateIdempotencyKey();
    const headers = {
      'Authorization': authToken,
      'Idempotency-Key': idempotencyKey,
    };
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
    const headers = {
      'Authorization': authToken,
      'Idempotency-Key': idempotencyKey,
    };
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

