// Demo session helper (WP-58, WP-66)
// Manages demo authentication token in localStorage

const TOKEN_KEY = 'demo_auth_token';
const TENANT_SLUG_KEY = 'tenant_slug';
const ACTIVE_TENANT_ID_KEY = 'active_tenant_id';

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
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
 * Clear all session data
 */
export function clearSession() {
  clearToken();
  localStorage.removeItem(TENANT_SLUG_KEY);
  localStorage.removeItem(ACTIVE_TENANT_ID_KEY);
}

// Helper URLs
export const enterDemoUrl = '/'; // HOS Web home
export const demoUrl = '/marketplace/demo';
export const authPortalUrl = '/marketplace/auth';

