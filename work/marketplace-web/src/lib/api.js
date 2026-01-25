// WP-67: API wrapper module (unified)
// Automatically attaches Authorization header for authenticated calls

import { getBearerToken, clearSession, setToken, saveSession } from './demoSession.js';

// HOS API base URL - use proxy if available, otherwise direct
const HOS_BASE_URL = import.meta.env.VITE_HOS_BASE_URL || '/api';

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
  
  // WP-67: Attach Authorization header if token exists
  if (requireAuth) {
    const bearerToken = getBearerToken();
    if (bearerToken) {
      headers['Authorization'] = bearerToken;
    } else {
      // WP-67: No token but auth required - clear session and redirect
      clearSession();
      const error = new Error('Authentication required');
      error.status = 401;
      error.errorCode = 'missing_token';
      throw error;
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
    
    // WP-67: Handle 401 - clear session
    if (response.status === 401) {
      clearSession();
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
 * WP-67: Login user (public customer, no tenantSlug)
 * @param {string} email
 * @param {string} password
 * @returns {Promise<{token: string, user?: object}>}
 */
export async function login(email, password) {
  const response = await apiRequest('/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      // WP-67: No tenantSlug for public customer login
      email,
      password,
    }),
  }, false); // Login doesn't require auth
  
  // WP-68: Token'ı önce kaydet, sonra /v1/me çağrısı yap
  if (response.token) {
    // Token'ı geçici olarak kaydet (user bilgisi olmadan)
    setToken(response.token);
    
    // WP-68: Token'ın kaydedildiğini doğrula
    const bearerToken = getBearerToken();
    if (!bearerToken) {
      throw new Error('Failed to save token');
    }
    
    // If response has user info, use it; otherwise fetch from /me
    let user = response.user || null;
    if (!user) {
      try {
        // WP-68: Token kaydedildi, şimdi /v1/me çağrısı yapabiliriz
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
    
    // Token ve user bilgisini birlikte kaydet
    saveSession(response.token, user);
    
    return {
      token: response.token,
      user,
    };
  }
  
  return {
    token: response.token,
    user: response.user || { email, id: null },
  };
}

/**
 * WP-67: Register user (public customer, no tenantSlug)
 * @param {string} email
 * @param {string} password
 * @returns {Promise<{token: string, user?: object}>}
 */
export async function register(email, password) {
  // WP-67: No tenantSlug for public customer registration
  const response = await apiRequest('/v1/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      email,
      password,
    }),
  }, false); // Register doesn't require auth
  
  // WP-68: Token'ı önce kaydet, sonra /v1/me çağrısı yap
  if (response.token) {
    // Token'ı geçici olarak kaydet (user bilgisi olmadan)
    setToken(response.token);
    
    // If response has user info, use it; otherwise fetch from /me
    let user = response.user || null;
    if (!user) {
      try {
        // WP-68: Token kaydedildi, şimdi /v1/me çağrısı yapabiliriz
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
    
    // Token ve user bilgisini birlikte kaydet
    saveSession(response.token, user);
    
    return {
      token: response.token,
      user,
    };
  }
  
  return {
    token: response.token,
    user: response.user || { email, id: null },
  };
}


