// WP-67: Single session module (unified customer auth)
// WP-72: Renamed localStorage keys from demo_* to auth_* (backward compatible)
// Manages authentication token in localStorage

const TOKEN_KEY = 'auth_token';
const OLD_TOKEN_KEY = 'demo_auth_token'; // Backward compatibility
const USER_KEY = 'auth_user';
const OLD_USER_KEY = 'demo_user'; // Backward compatibility
const TENANT_SLUG_KEY = 'tenant_slug';
const ACTIVE_TENANT_ID_KEY = 'active_tenant_id';

export function getToken() {
  // WP-72: Check new key first, fallback to old key for backward compatibility
  let token = localStorage.getItem(TOKEN_KEY);
  if (!token) {
    token = localStorage.getItem(OLD_TOKEN_KEY);
    if (token) {
      // Migrate to new key
      localStorage.setItem(TOKEN_KEY, token);
      localStorage.removeItem(OLD_TOKEN_KEY);
    }
  }
  return token;
}

/**
 * WP-67: Normalize token (remove "Bearer " prefix if present)
 * @param {string} input - Token with or without "Bearer " prefix
 * @returns {string} Raw token
 */
export function normalizeToken(input) {
  if (!input) return '';
  const trimmed = String(input).trim();
  // Case-insensitive check for "Bearer " prefix
  if (trimmed.toLowerCase().startsWith('bearer ')) {
    return trimmed.slice(7).trim();
  }
  return trimmed;
}

/**
 * WP-67: Save session (token + user)
 * @param {string} token - Raw JWT token (will be normalized)
 * @param {object} user - User info { email, id? }
 */
export function saveSession(token, user) {
  const rawToken = normalizeToken(token);
  if (rawToken) {
    localStorage.setItem(TOKEN_KEY, rawToken);
    // WP-72: Remove old key if exists
    localStorage.removeItem(OLD_TOKEN_KEY);
  } else {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(OLD_TOKEN_KEY);
  }
  
  if (user) {
    localStorage.setItem(USER_KEY, JSON.stringify(user));
    // WP-72: Remove old key if exists
    localStorage.removeItem(OLD_USER_KEY);
  } else {
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(OLD_USER_KEY);
  }
}

export function setToken(token) {
  const rawToken = normalizeToken(token);
  if (rawToken) {
    localStorage.setItem(TOKEN_KEY, rawToken);
    // WP-72: Remove old key if exists
    localStorage.removeItem(OLD_TOKEN_KEY);
  } else {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(OLD_TOKEN_KEY);
  }
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(OLD_TOKEN_KEY);
}

export function isTokenPresent() {
  return getToken() !== null;
}

/**
 * Decode JWT payload (base64url decode)
 * @param {string} token - JWT token
 * @returns {object|null} Decoded payload or null if invalid
 */
export function decodeJwtPayload(token) {
  if (!token) return null;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = parts[1];
    // Base64url decode (replace - with +, _ with /, add padding if needed)
    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
    const decoded = atob(padded);
    return JSON.parse(decoded);
  } catch (error) {
    console.error('Failed to decode JWT payload:', error);
    return null;
  }
}

/**
 * WP-67: Get Bearer token for Authorization header
 * @returns {string} "Bearer <raw_token>" or empty string
 */
export function getBearerToken() {
  const token = getToken();
  if (!token) return '';
  return `Bearer ${token}`;
}

/**
 * Get user ID from token payload (sub claim)
 * @returns {string|null} User ID or null
 */
export function getUserId() {
  const token = getToken();
  if (!token) return null;
  const payload = decodeJwtPayload(token);
  return payload?.sub || null;
}

/**
 * WP-67: Get user info from localStorage or token
 * @returns {object|null} { email, id? } or null
 */
export function getUser() {
  // WP-72: Check new key first, fallback to old key for backward compatibility
  let userStr = localStorage.getItem(USER_KEY);
  if (!userStr) {
    userStr = localStorage.getItem(OLD_USER_KEY);
    if (userStr) {
      // Migrate to new key
      localStorage.setItem(USER_KEY, userStr);
      localStorage.removeItem(OLD_USER_KEY);
    }
  }
  if (userStr) {
    try {
      return JSON.parse(userStr);
    } catch {
      // Fallback: try to get from token
    }
  }
  
  // Fallback: decode from token
  const token = getToken();
  if (token) {
    const payload = decodeJwtPayload(token);
    if (payload?.sub) {
      return {
        email: payload.email || payload.preferred_username || null,
        id: payload.sub
      };
    }
  }
  
  return null;
}

/**
 * WP-67: Check if user is logged in
 * @returns {boolean}
 */
export function isLoggedIn() {
  return getToken() !== null && getToken().length > 0;
}

/**
 * Set user ID (for backward compatibility, but prefer getting from token)
 * @param {string} userId - User ID
 */
export function setUserId(userId) {
  // Store in localStorage for backward compatibility
  // But prefer getting from token via getUserId()
  if (userId) {
    localStorage.setItem('demo_user_id', userId);
  } else {
    localStorage.removeItem('demo_user_id');
  }
}

/**
 * Get tenant ID from token payload (tenantId claim)
 * @returns {string|null} Tenant ID or null
 */
export function getTenantId() {
  const token = getToken();
  if (!token) return null;
  const payload = decodeJwtPayload(token);
  return payload?.tenantId || payload?.tenant_id || null;
}

/**
 * Get role from token payload (role claim)
 * @returns {string|null} Role or null
 */
export function getRole() {
  const token = getToken();
  if (!token) return null;
  const payload = decodeJwtPayload(token);
  return payload?.role || null;
}

/**
 * Set tenant slug
 * @param {string} slug - Tenant slug
 */
export function setTenantSlug(slug) {
  if (slug) {
    localStorage.setItem(TENANT_SLUG_KEY, slug);
  } else {
    localStorage.removeItem(TENANT_SLUG_KEY);
  }
}

/**
 * Get tenant slug
 * @returns {string|null} Tenant slug or null
 */
export function getTenantSlug() {
  return localStorage.getItem(TENANT_SLUG_KEY);
}

/**
 * Set active tenant ID (for backward compatibility)
 * @param {string} tenantId - Tenant ID
 */
export function setActiveTenantId(tenantId) {
  if (tenantId) {
    localStorage.setItem(ACTIVE_TENANT_ID_KEY, tenantId);
  } else {
    localStorage.removeItem(ACTIVE_TENANT_ID_KEY);
  }
}

/**
 * Get active tenant ID (for backward compatibility)
 * @returns {string|null} Tenant ID or null
 */
export function getActiveTenantId() {
  return localStorage.getItem(ACTIVE_TENANT_ID_KEY);
}

/**
 * WP-67: Clear all session data
 */
export function clearSession() {
  clearToken();
  localStorage.removeItem(USER_KEY);
  localStorage.removeItem(OLD_USER_KEY); // WP-72: Clear old key too
  localStorage.removeItem(TENANT_SLUG_KEY);
  localStorage.removeItem(ACTIVE_TENANT_ID_KEY);
  localStorage.removeItem('demo_user_id'); // Clear userId if stored separately
}

// Helper URLs
export const enterDemoUrl = '/'; // HOS Web home
export const demoUrl = '/marketplace/demo';
export const authPortalUrl = '/marketplace/auth';

