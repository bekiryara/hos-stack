// API wrapper module (WP-66: Customer Auth UI)
// Automatically attaches Authorization header for authenticated calls

import { getToken } from './session.js';

// HOS API base URL - use proxy if available, otherwise direct
const HOS_BASE_URL = import.meta.env.VITE_HOS_BASE_URL || '/api';
const DEFAULT_TENANT_SLUG = import.meta.env.VITE_DEFAULT_TENANT_SLUG || 'tenant-a';

/**
 * Mask token for logging (show only last 6 chars)
 * @param {string} token
 * @returns {string}
 */
function maskToken(token) {
  if (!token || token.length < 6) return '****';
  return '****' + token.slice(-6);
}

/**
 * Make API request with automatic Authorization header
 * @param {string} endpoint - API endpoint (e.g., '/v1/auth/login')
 * @param {object} options - Fetch options
 * @param {boolean} requireAuth - Whether to require auth token (default: true)
 * @returns {Promise<Response>}
 */
export async function apiRequest(endpoint, options = {}, requireAuth = true) {
  // Use /api proxy for HOS API (same as client.js hosApiRequest)
  const url = endpoint.startsWith('http') ? endpoint : `${HOS_BASE_URL}${endpoint}`;
  
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };
  
  // Attach Authorization header if token exists
  if (requireAuth) {
    const token = getToken();
    if (token) {
      headers['Authorization'] = token.startsWith('Bearer ') ? token : `Bearer ${token}`;
    }
  }
  
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

/**
 * Login user
 * @param {string} email
 * @param {string} password
 * @returns {Promise<{token: string, user?: object}>}
 */
export async function login(email, password) {
  const response = await apiRequest('/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      tenantSlug: DEFAULT_TENANT_SLUG,
      email,
      password,
    }),
  }, false); // Login doesn't require auth
  
  // If response has user info, use it; otherwise fetch from /me
  let user = response.user || null;
  if (response.token && !user) {
    try {
      // Try to fetch user profile from /me endpoint
      const meResponse = await apiRequest('/v1/me', {}, true);
      user = {
        email: meResponse.email || email,
        id: meResponse.user_id || meResponse.id,
      };
    } catch (e) {
      // Fallback: use email from login
      user = { email, id: null };
    }
  }
  
  return {
    token: response.token,
    user,
  };
}

/**
 * Register user
 * @param {string} email
 * @param {string} password
 * @returns {Promise<{token: string, user?: object}>}
 */
export async function register(email, password) {
  // Backend requires tenantSlug, but we hide it from user
  const response = await apiRequest('/v1/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      tenantSlug: DEFAULT_TENANT_SLUG,
      email,
      password,
    }),
  }, false); // Register doesn't require auth
  
  // If response has user info, use it; otherwise construct from email
  let user = response.user || null;
  if (response.token && !user) {
    try {
      // Try to fetch user profile from /me endpoint
      const meResponse = await apiRequest('/v1/me', {}, true);
      user = {
        email: meResponse.email || email,
        id: meResponse.user_id || meResponse.id,
      };
    } catch (e) {
      // Fallback: use email from register
      user = { email, id: null };
    }
  }
  
  return {
    token: response.token,
    user,
  };
}

/**
 * Get default tenant slug (for internal use only)
 * @returns {string}
 */
export function getDefaultTenantSlug() {
  return DEFAULT_TENANT_SLUG;
}

