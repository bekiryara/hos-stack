// Session store module (WP-66: Customer Auth UI)
// Single source of truth for user session

const TOKEN_KEY = 'customer_auth_token';
const USER_KEY = 'customer_user';

/**
 * Load session from localStorage
 * @returns {object|null} { token, user } or null
 */
export function loadSession() {
  const token = localStorage.getItem(TOKEN_KEY);
  const userStr = localStorage.getItem(USER_KEY);
  
  if (!token) return null;
  
  let user = null;
  if (userStr) {
    try {
      user = JSON.parse(userStr);
    } catch (e) {
      console.warn('Failed to parse user from session:', e);
    }
  }
  
  return { token, user };
}

/**
 * Save session to localStorage
 * @param {object} session - { token, user }
 */
export function saveSession({ token, user }) {
  if (token) {
    localStorage.setItem(TOKEN_KEY, token);
  } else {
    localStorage.removeItem(TOKEN_KEY);
  }
  
  if (user) {
    localStorage.setItem(USER_KEY, JSON.stringify(user));
  } else {
    localStorage.removeItem(USER_KEY);
  }
}

/**
 * Clear session from localStorage
 */
export function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

/**
 * Check if user is logged in
 * @returns {boolean}
 */
export function isLoggedIn() {
  const token = localStorage.getItem(TOKEN_KEY);
  return token !== null && token.length > 0;
}

/**
 * Get current token
 * @returns {string|null}
 */
export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

/**
 * Get current user
 * @returns {object|null}
 */
export function getUser() {
  const userStr = localStorage.getItem(USER_KEY);
  if (!userStr) return null;
  try {
    return JSON.parse(userStr);
  } catch {
    return null;
  }
}

