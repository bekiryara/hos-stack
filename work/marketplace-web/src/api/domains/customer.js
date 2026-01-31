// Customer domain: authenticated user operations (personal scope)
// WP-NEXT: Extracted from client.js (NO BEHAVIOR CHANGE)
import { hosApiRequest, apiRequest, generateIdempotencyKey } from '../request.js';

// HOS API (WP-48: tenant ID resolution)
// WP-68: Auto-attach Authorization header (no manual token needed)
export function getMyMemberships() {
  return hosApiRequest('/v1/me/memberships');
}

// WP-68: Get current user info
export function getMe() {
  return hosApiRequest('/v1/me');
}

// Account Portal - Personal scope (WP-32, WP-8)
// NOTE: These are HOS API endpoints, use hosApiRequest (not apiRequest)
// Customer V1: Use /v1/me/* endpoints (userId parameter ignored but kept for compatibility)
export function getMyOrders(userId) {
  // Authorization header auto-attached by hosApiRequest
  // userId parameter kept for compatibility but ignored (HOS uses token to identify user)
  return hosApiRequest('/v1/me/orders');
}

export function getMyRentals(userId) {
  return hosApiRequest('/v1/me/rentals');
}

export function getMyReservations(userId) {
  return hosApiRequest('/v1/me/reservations');
}

export function getMyOrderById(id) {
  return hosApiRequest(`/v1/me/orders/${id}`);
}

export function getMyRentalById(id) {
  return hosApiRequest(`/v1/me/rentals/${id}`);
}

export function getMyReservationById(id) {
  return hosApiRequest(`/v1/me/reservations/${id}`);
}

// WP-68: Auto-attach Authorization header (no manual token needed)
// PERSONAL persona: Authorization header required (SPEC §5.2)
export function createReservation(data, userId) {
  const idempotencyKey = generateIdempotencyKey();
  const headers = {
    'Idempotency-Key': idempotencyKey,
  };
  if (userId) {
    headers['X-Requester-User-Id'] = userId;
  }
  return apiRequest('/api/v1/reservations', {
    method: 'POST',
    body: JSON.stringify(data),
    headers,
  });
}

export function createRental(data, userId) {
  const idempotencyKey = generateIdempotencyKey();
  const headers = {
    'Idempotency-Key': idempotencyKey,
  };
  if (userId) {
    headers['X-Requester-User-Id'] = userId;
  }
  return apiRequest('/api/v1/rentals', {
    method: 'POST',
    body: JSON.stringify(data),
    headers,
  });
}

// Customer V1: Create order (sale transaction)
export function createOrder(listingId, quantity = 1) {
  const idempotencyKey = generateIdempotencyKey();
  const headers = {
    'Idempotency-Key': idempotencyKey,
  };
  return apiRequest('/api/v1/orders', {
    method: 'POST',
    body: JSON.stringify({
      listing_id: listingId,
      quantity: quantity,
    }),
    headers,
  });
}
