// API client for Marketplace backend
// WP-NEXT: Refactored into request wrapper + domain modules (NO BEHAVIOR CHANGE)
// This file now acts as a barrel export to maintain backwards compatibility.

// Re-export request infrastructure
export {
  PERSONA_MODES,
  apiRequest,
  hosApiRequest,
  messagingApiRequest,
  unwrapData,
  normalizeListResponse,
} from './request.js';

// Re-export messaging domain functions
export {
  messagingUpsertThread,
  messagingGetThreadByContext,
  messagingSendMessage,
} from './domains/messaging.js';

// Import domain modules for api object composition
import * as catalog from './domains/catalog.js';
import * as customer from './domains/customer.js';
import * as store from './domains/store.js';
import * as hos from './domains/hos.js';

// Import for login/register
import { hosApiRequest } from './request.js';
import { setToken, saveSession } from '../lib/session.js';

/**
 * HOS customer auth: login (public customer, tenantSlug omitted)
 * Keeps session logic centralized in this module (single auth spine).
 */
export async function login(email, password) {
  const response = await hosApiRequest(
    '/v1/auth/login',
    {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    },
    true // skipAuth: login is public
  );

  if (response?.token) {
    // Save token first, then hydrate user from /v1/me when possible
    setToken(response.token);

    let user = response.user || null;
    if (!user) {
      try {
        const me = await hosApiRequest('/v1/me', {}, false);
        user = {
          email: me?.email || email,
          id: me?.user_id || me?.id || null,
        };
      } catch {
        user = { email, id: null };
      }
    }

    saveSession(response.token, user);
    return { token: response.token, user };
  }

  return { token: response?.token, user: response?.user || { email, id: null } };
}

/**
 * HOS customer auth: register (public customer, tenantSlug omitted)
 * Keeps session logic centralized in this module (single auth spine).
 */
export async function register(email, password) {
  const response = await hosApiRequest(
    '/v1/auth/register',
    {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    },
    true // skipAuth: register is public
  );

  if (response?.token) {
    // Save token first, then hydrate user from /v1/me when possible
    setToken(response.token);

    let user = response.user || null;
    if (!user) {
      try {
        const me = await hosApiRequest('/v1/me', {}, false);
        user = {
          email: me?.email || email,
          id: me?.user_id || me?.id || null,
        };
      } catch {
        user = { email, id: null };
      }
    }

    saveSession(response.token, user);
    return { token: response.token, user };
  }

  return { token: response?.token, user: response?.user || { email, id: null } };
}

// Compose api object from domain modules (maintains same interface)
export const api = {
  ...catalog,
  ...customer,
  ...store,
  ...hos,
};
