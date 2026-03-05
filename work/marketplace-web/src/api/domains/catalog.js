// Catalog domain: public guest browsing
// WP-NEXT: Extracted from client.js (NO BEHAVIOR CHANGE)
import { apiRequest, toStableQueryString } from '../request.js';

// GUEST persona: No headers required (SPEC §5.3)
// WP-68: Public calls use skipAuth to avoid attaching token
export function getCategories(params = {}) {
  const view = params && params.view ? String(params.view) : '';
  const qs = view ? `?view=${encodeURIComponent(view)}` : '';
  return apiRequest(`/api/v1/categories${qs}`, {}, true);
}

export function getFilterSchema(categoryId) {
  return apiRequest(`/api/v1/categories/${categoryId}/filter-schema`, {}, true);
}

export function getCategoryChildren(categoryId) {
  return apiRequest(`/api/v1/categories/${categoryId}/children`, {}, true);
}

export function getIntentSchema(categoryId) {
  return apiRequest(`/api/v1/categories/${categoryId}/intent-schema`, {}, true);
}

export function getCityOptions() {
  return apiRequest('/api/v1/options/cities', {}, true);
}

export function getDistrictOptions(city) {
  const c = encodeURIComponent(String(city || '').trim());
  return apiRequest(`/api/v1/options/districts?city=${c}`, {}, true);
}

export function getNeighborhoodOptions(city, district) {
  const c = encodeURIComponent(String(city || '').trim());
  const d = encodeURIComponent(String(district || '').trim());
  return apiRequest(`/api/v1/options/neighborhoods?city=${c}&district=${d}`, {}, true);
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
