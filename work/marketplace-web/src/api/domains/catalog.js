// Catalog domain: public guest browsing
// WP-NEXT: Extracted from client.js (NO BEHAVIOR CHANGE)
import { apiRequest, toStableQueryString } from '../request.js';

// GUEST persona: No headers required (SPEC §5.3)
// WP-68: Public calls use skipAuth to avoid attaching token
export function getCategories() {
  return apiRequest('/api/v1/categories', {}, true);
}

export function getFilterSchema(categoryId) {
  return apiRequest(`/api/v1/categories/${categoryId}/filter-schema`, {}, true);
}

export function getIntentSchema(categoryId) {
  return apiRequest(`/api/v1/categories/${categoryId}/intent-schema`, {}, true);
}

export function searchListings(params) {
  const queryString = toStableQueryString(params);
  return apiRequest(`/api/v1/listings?${queryString}`, {}, true);
}

export function getListing(id) {
  return apiRequest(`/api/v1/listings/${id}`, {}, true);
}

// Offers (packages) are public read for listing detail pages
export function getListingOffers(listingId) {
  return apiRequest(`/api/v1/listings/${listingId}/offers`, {}, true);
}
