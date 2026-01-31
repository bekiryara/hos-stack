// Catalog domain: public guest browsing
// WP-NEXT: Extracted from client.js (NO BEHAVIOR CHANGE)
import { apiRequest } from '../request.js';

// GUEST persona: No headers required (SPEC §5.3)
// WP-68: Public calls use skipAuth to avoid attaching token
export function getCategories() {
  return apiRequest('/api/v1/categories', {}, true);
}

export function getFilterSchema(categoryId) {
  return apiRequest(`/api/v1/categories/${categoryId}/filter-schema`, {}, true);
}

export function searchListings(params) {
  const queryString = new URLSearchParams(params).toString();
  return apiRequest(`/api/v1/listings?${queryString}`, {}, true);
}

export function getListing(id) {
  return apiRequest(`/api/v1/listings/${id}`, {}, true);
}
