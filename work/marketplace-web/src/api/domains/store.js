// Store domain: firm/tenant operations (store scope)
// WP-NEXT: Extracted from client.js (NO BEHAVIOR CHANGE)
import { apiRequest, buildPersonaHeaders, PERSONA_MODES, generateIdempotencyKey } from '../request.js';
import {
  getActiveTenantId as getActiveTenantIdFromSession,
} from '../../lib/session.js';

// Account Portal - Store scope (WP-32, WP-8)
// STORE persona: X-Active-Tenant-Id header required (SPEC §5.2)
export function getStoreListings(tenantId, authToken) {
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
  return apiRequest(`/api/v1/listings?tenant_id=${tenantId}`, { headers });
}

export function getStoreOrders(tenantId, authToken) {
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
  return apiRequest(`/api/v1/orders?seller_tenant_id=${tenantId}`, { headers });
}

export function getStoreOrderById(id, tenantId, authToken) {
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
  return apiRequest(`/api/v1/orders/${id}?seller_tenant_id=${tenantId}`, { headers });
}

export function getStoreRentals(tenantId, authToken) {
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
  return apiRequest(`/api/v1/rentals?provider_tenant_id=${tenantId}`, { headers });
}

export function getStoreRentalById(id, tenantId, authToken) {
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
  return apiRequest(`/api/v1/rentals/${id}?provider_tenant_id=${tenantId}`, { headers });
}

export function getStoreReservations(tenantId, authToken) {
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId, authToken });
  return apiRequest(`/api/v1/reservations?provider_tenant_id=${tenantId}`, { headers });
}

// WP-NEXT: Transaction Decisions v1 — firm accept/reject (store scope)
export function acceptStoreOrder(orderId, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/orders/${orderId}/accept`, { method: 'POST', headers });
}

export function rejectStoreOrder(orderId, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/orders/${orderId}/reject`, { method: 'POST', headers });
}

export function acceptStoreRental(rentalId, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/rentals/${rentalId}/accept`, { method: 'POST', headers });
}

export function rejectStoreRental(rentalId, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/rentals/${rentalId}/reject`, { method: 'POST', headers });
}

export function acceptStoreReservation(reservationId, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/reservations/${reservationId}/accept`, { method: 'POST', headers });
}

export function rejectStoreReservation(reservationId, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/reservations/${reservationId}/reject`, { method: 'POST', headers });
}

// WP-NEXT: Transaction Lifecycle v1 — status transition (store scope)
export function transitionOrder(id, action, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/orders/${id}/transition`, {
    method: 'POST',
    body: JSON.stringify({ action }),
    headers,
  });
}

export function transitionRental(id, action, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/rentals/${id}/transition`, {
    method: 'POST',
    body: JSON.stringify({ action }),
    headers,
  });
}

export function transitionReservation(id, action, tenantId) {
  const tid = tenantId || getActiveTenantIdFromSession();
  const headers = buildPersonaHeaders(PERSONA_MODES.STORE, { tenantId: tid });
  return apiRequest(`/api/v1/reservations/${id}/transition`, {
    method: 'POST',
    body: JSON.stringify({ action }),
    headers,
  });
}

// Write operations (WP-8: Persona-based headers)
// STORE persona: X-Active-Tenant-Id required
export function createListing(data, tenantId) {
  const idempotencyKey = generateIdempotencyKey();
  const activeTenantId = tenantId || getActiveTenantIdFromSession();
  const headers = {
    'Idempotency-Key': idempotencyKey,
    'X-Active-Tenant-Id': activeTenantId,
  };
  return apiRequest('/api/v1/listings', {
    method: 'POST',
    body: JSON.stringify(data),
    headers,
  });
}

export function publishListing(id, tenantId) {
  const activeTenantId = tenantId || getActiveTenantIdFromSession();
  const headers = {
    'X-Active-Tenant-Id': activeTenantId,
  };
  return apiRequest(`/api/v1/listings/${id}/publish`, {
    method: 'POST',
    headers,
  });
}

export function updateListing(id, data, tenantId) {
  const activeTenantId = tenantId || getActiveTenantIdFromSession();
  const headers = {
    'X-Active-Tenant-Id': activeTenantId,
  };
  return apiRequest(`/api/v1/listings/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(data),
    headers,
  });
}
