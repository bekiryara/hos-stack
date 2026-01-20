// Pazar API Client (WP-18)
// Centralized API client for Account Portal and other Pazar endpoints

const base = import.meta.env.VITE_PAZAR_API_BASE || 'http://localhost:8080';
const API_BASE = `${base}/api`;

/**
 * Standardized request function
 * @param {string} path - API path (e.g., '/v1/orders')
 * @param {object} options - Request options
 * @param {string} options.method - HTTP method (default: 'GET')
 * @param {object} options.headers - Additional headers
 * @param {object|string} options.body - Request body (will be JSON.stringify'd if object)
 * @param {object} options.params - Query parameters (will be appended to URL)
 * @param {string} options.tenantId - Tenant ID (adds X-Active-Tenant-Id header)
 * @param {string} options.token - Auth token (adds Authorization: Bearer <token> header)
 * @returns {Promise<object>} Parsed JSON response or error object
 */
export async function request(path, { method = 'GET', headers = {}, body, params, tenantId, token } = {}) {
  // Build URL with query parameters
  let url = `${API_BASE}${path}`;
  if (params && Object.keys(params).length > 0) {
    const queryString = new URLSearchParams(params).toString();
    url += `?${queryString}`;
  }
  
  // Build headers
  const requestHeaders = {
    'Accept': 'application/json',
    ...headers,
  };
  
  // Add Content-Type if body exists
  if (body) {
    requestHeaders['Content-Type'] = 'application/json';
  }
  
  // Add tenant header if provided
  if (tenantId) {
    requestHeaders['X-Active-Tenant-Id'] = tenantId;
  }
  
  // Add authorization header if token provided
  if (token) {
    // Ensure token starts with "Bearer " if not already
    const authToken = token.startsWith('Bearer ') ? token : `Bearer ${token}`;
    requestHeaders['Authorization'] = authToken;
  }
  
  // Prepare body
  let requestBody = body;
  if (body && typeof body === 'object') {
    requestBody = JSON.stringify(body);
  }
  
  try {
    const response = await fetch(url, {
      method,
      headers: requestHeaders,
      body: requestBody,
    });
    
    // Try to parse response as JSON
    let responseData;
    const contentType = response.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      responseData = await response.json();
    } else {
      responseData = await response.text();
    }
    
    // If not OK, return error object
    if (!response.ok) {
      return {
        ok: false,
        status: response.status,
        message: responseData?.message || responseData?.error || response.statusText || 'Request failed',
        body: responseData,
      };
    }
    
    // Success
    return {
      ok: true,
      status: response.status,
      data: responseData,
    };
  } catch (error) {
    // Network or parsing error
    return {
      ok: false,
      status: 0,
      message: error.message || 'Network error',
      body: null,
    };
  }
}

/**
 * Account Portal - Store scope endpoints
 */
export const storeApi = {
  getListings: (tenantId, token) => 
    request('/v1/listings', { tenantId, token, params: { tenant_id: tenantId } }),
  
  getOrders: (tenantId, token) => 
    request('/v1/orders', { tenantId, token, params: { seller_tenant_id: tenantId } }),
  
  getRentals: (tenantId, token) => 
    request('/v1/rentals', { tenantId, token, params: { provider_tenant_id: tenantId } }),
  
  getReservations: (tenantId, token) => 
    request('/v1/reservations', { tenantId, token, params: { provider_tenant_id: tenantId } }),
};

/**
 * Account Portal - Personal scope endpoints
 * Note: token is REQUIRED for personal scope
 */
export const personalApi = {
  getOrders: (userId, token) => 
    request('/v1/orders', { token, params: { buyer_user_id: userId } }),
  
  getRentals: (userId, token) => 
    request('/v1/rentals', { token, params: { renter_user_id: userId } }),
  
  getReservations: (userId, token) => 
    request('/v1/reservations', { token, params: { requester_user_id: userId } }),
};

