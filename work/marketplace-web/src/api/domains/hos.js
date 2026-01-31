// HOS domain: tenant management and auth operations
// WP-NEXT: Extracted from client.js (NO BEHAVIOR CHANGE)
import { hosApiRequest } from '../request.js';
import {
  getActiveTenantId as getActiveTenantIdFromSession,
  setActiveTenantId as setActiveTenantIdFromSession,
} from '../../lib/session.js';

// HOS Auth API (WP-66: browser auth flows)
// WP-68: Create tenant endpoint (auth required)
export function hosCreateTenant({ slug, display_name }) {
  return hosApiRequest('/v1/tenants/v2', {
    method: 'POST',
    body: JSON.stringify({ slug, display_name }),
  });
}

export function hosRegisterOwner({ tenantSlug, email, password }) {
  return hosApiRequest('/v1/auth/register', {
    method: 'POST',
    body: JSON.stringify({ tenantSlug, email, password }),
  });
}

export function hosLogin({ tenantSlug, email, password }) {
  return hosApiRequest('/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify({ tenantSlug, email, password }),
  });
}

// WP-??: Best-effort logout (revokes refresh cookie if present)
export function hosLogout() {
  return hosApiRequest('/v1/auth/logout', { method: 'POST' }, true);
}

// Active tenant wrappers (session.js delegates)
export function getActiveTenantId() {
  return getActiveTenantIdFromSession();
}

export function setActiveTenantId(tenantId) {
  return setActiveTenantIdFromSession(tenantId);
}
