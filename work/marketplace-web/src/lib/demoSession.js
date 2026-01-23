// Demo session helper (WP-58)
// Manages demo authentication token in localStorage

const TOKEN_KEY = 'demo_auth_token';

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

// Helper URLs
export const enterDemoUrl = '/'; // HOS Web home
export const demoUrl = '/marketplace/demo';

