// Pazar API Client (WP-18, WP-65)
// Centralized API client for Account Portal and other Pazar endpoints

const DEFAULT_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

/**
 * Normalize token (accept Bearer prefix or raw JWT)
 * @param {string} token - Raw token or "Bearer <token>"
 * @returns {string} Normalized token (raw JWT)
 */
export function normalizeToken(token) {
  if (!token) return null;
  const trimmed = token.trim();
  if (trimmed.startsWith('Bearer ')) {
    return trimmed.substring(7); // Remove Bearer prefix
  }
  return trimmed;
}

/**
 * Standardized request function
 * @param {string} path - API path (e.g., '/v1/orders')
 * @param {object} options - Request options
 * @param {string} options.baseHost - Pazar host (e.g., 'http://localhost:8080'), defaults to env or 'http://localhost:8080'
 * @param {string} options.method - HTTP method (default: 'GET')
 * @param {object} options.headers - Additional headers
 * @param {object|string} options.body - Request body (will be JSON.stringify'd if object)
 * @param {object} options.params - Query parameters (will be appended to URL)
 * @param {string} options.tenantId - Tenant ID (adds X-Active-Tenant-Id header)
 * @param {string} options.token - Auth token (adds Authorization: Bearer <token> header, normalized)
 * @returns {Promise<object>} Parsed JSON response or error object
 */
export async function request(path, { baseHost, method = 'GET', headers = {}, body, params, tenantId, token } = {}) {
  // Use provided baseHost or default
  const host = baseHost || DEFAULT_BASE;
  const API_BASE = `${host}/api`;
  
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
  
  // Add authorization header if token provided (normalize first)
  if (token) {
    const normalizedToken = normalizeToken(token);
    if (normalizedToken) {
      requestHeaders['Authorization'] = `Bearer ${normalizedToken}`;
    }
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
 * @param {string} baseHost - Pazar host (e.g., 'http://localhost:8080')
 * @param {string} tenantId - Tenant ID (required)
 * @param {string} token - Auth token (optional, normalized)
 */
export const storeApi = {
  getListings: (baseHost, tenantId, token) => 
    request('/v1/listings', { baseHost, tenantId, token, params: { tenant_id: tenantId } }),
  
  getOrders: (baseHost, tenantId, token) => 
    request('/v1/orders', { baseHost, tenantId, token, params: { seller_tenant_id: tenantId } }),
  
  getRentals: (baseHost, tenantId, token) => 
    request('/v1/rentals', { baseHost, tenantId, token, params: { provider_tenant_id: tenantId } }),
  
  getReservations: (baseHost, tenantId, token) => 
    request('/v1/reservations', { baseHost, tenantId, token, params: { provider_tenant_id: tenantId } }),
};

/**
 * Account Portal - Personal scope endpoints
 * Note: token is REQUIRED for personal scope
 * @param {string} baseHost - Pazar host (e.g., 'http://localhost:8080')
 * @param {string} userId - User ID (required)
 * @param {string} token - Auth token (required, normalized)
 */
export const personalApi = {
  getOrders: (baseHost, userId, token) => 
    request('/v1/orders', { baseHost, token, params: { buyer_user_id: userId } }),
  
  getRentals: (baseHost, userId, token) => 
    request('/v1/rentals', { baseHost, token, params: { renter_user_id: userId } }),
  
  getReservations: (baseHost, userId, token) => 
    request('/v1/reservations', { baseHost, token, params: { requester_user_id: userId } }),
};

