// Session module (single auth/session)
// Stores auth token + user in localStorage.
// Backward compatible migration from older legacy keys.
 
const TOKEN_KEY = 'auth_token';
const OLD_TOKEN_KEY = 'demo_auth_token'; // Backward compatibility (migrate once)
const USER_KEY = 'auth_user';
const OLD_USER_KEY = 'demo_user'; // Backward compatibility (migrate once)
const TENANT_SLUG_KEY = 'tenant_slug';
const ACTIVE_TENANT_ID_KEY = 'active_tenant_id';
 
export function getToken() {
  // Check new key first, fallback to old key for backward compatibility
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
 * Normalize token (remove "Bearer " prefix if present)
 * @param {string} input - Token with or without "Bearer " prefix
 * @returns {string} Raw token
 */
export function normalizeToken(input) {
  if (!input) return '';
  const trimmed = String(input).trim();
  if (trimmed.toLowerCase().startsWith('bearer ')) {
    return trimmed.slice(7).trim();
  }
  return trimmed;
}
 
/**
 * Save session (token + user)
 * @param {string} token - Raw JWT token (will be normalized)
 * @param {object} user - User info { email, id? }
 */
export function saveSession(token, user) {
  const rawToken = normalizeToken(token);
  if (rawToken) {
    localStorage.setItem(TOKEN_KEY, rawToken);
    localStorage.removeItem(OLD_TOKEN_KEY);
  } else {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(OLD_TOKEN_KEY);
  }
 
  if (user) {
    localStorage.setItem(USER_KEY, JSON.stringify(user));
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
 * Decode JWT payload (base64url decode). No signature verification (client-side convenience only).
 * @param {string} token - JWT token
 * @returns {object|null} Decoded payload or null if invalid
 */
export function decodeJwtPayload(token) {
  if (!token) return null;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = parts[1];
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
 * Get Bearer token for Authorization header
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
 * Get user info from localStorage or token
 * @returns {object|null} { email, id? } or null
 */
export function getUser() {
  let userStr = localStorage.getItem(USER_KEY);
  if (!userStr) {
    userStr = localStorage.getItem(OLD_USER_KEY);
    if (userStr) {
      localStorage.setItem(USER_KEY, userStr);
      localStorage.removeItem(OLD_USER_KEY);
    }
  }
  if (userStr) {
    try {
      return JSON.parse(userStr);
    } catch {
      // Fall through to token decode
    }
  }
 
  const token = getToken();
  if (token) {
    const payload = decodeJwtPayload(token);
    if (payload?.sub) {
      return {
        email: payload.email || payload.preferred_username || null,
        id: payload.sub,
      };
    }
  }
 
  return null;
}
 
export function isLoggedIn() {
  const token = getToken();
  return token !== null && token.length > 0;
}
 
export function setTenantSlug(slug) {
  if (slug) {
    localStorage.setItem(TENANT_SLUG_KEY, slug);
  } else {
    localStorage.removeItem(TENANT_SLUG_KEY);
  }
}
 
export function getTenantSlug() {
  return localStorage.getItem(TENANT_SLUG_KEY);
}
 
export function setActiveTenantId(tenantId) {
  if (tenantId) {
    localStorage.setItem(ACTIVE_TENANT_ID_KEY, tenantId);
  } else {
    localStorage.removeItem(ACTIVE_TENANT_ID_KEY);
  }
}
 
export function getActiveTenantId() {
  return localStorage.getItem(ACTIVE_TENANT_ID_KEY);
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
 
export function clearSession() {
  clearToken();
  localStorage.removeItem(USER_KEY);
  localStorage.removeItem(OLD_USER_KEY);
  localStorage.removeItem(TENANT_SLUG_KEY);
  localStorage.removeItem(ACTIVE_TENANT_ID_KEY);
}
