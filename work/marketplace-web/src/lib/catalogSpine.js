// WP-NEXT: Catalog spine client (single source of truth)
// - Categories: fetch once, in-memory cache
// - Filter schema: per-categoryId cache
// No page-level copy/paste fetch logic.

import { api } from '../api/client';

let categoriesPromise = null;
let categoriesValue = null;
let categoriesViewKey = ''; // '' | 'menu' | other
let cityOptionsPromise = null;
let cityOptionsValue = null;
const districtOptionsPromises = new Map(); // city -> Promise<string[]>
const districtOptionsValues = new Map(); // city -> string[]
const neighborhoodOptionsPromises = new Map(); // city|district -> Promise<string[]>
const neighborhoodOptionsValues = new Map(); // city|district -> string[]

const filterSchemaPromises = new Map(); // categoryId -> Promise<schema>
const intentSchemaPromises = new Map(); // categoryId -> Promise<schema>

export async function getCategoriesTree(params = {}) {
  const view = params && params.view ? String(params.view) : 'menu';
  if (categoriesValue && categoriesViewKey === view) return categoriesValue;
  if (!categoriesPromise || categoriesViewKey !== view) {
    categoriesViewKey = view;
    categoriesPromise = api.getCategories({ view }).then((data) => {
      categoriesValue = data;
      return categoriesValue;
    });
  }
  return categoriesPromise;
}

export async function getFilterSchemaForCategory(categoryId) {
  const key = String(categoryId);
  if (!filterSchemaPromises.has(key)) {
    const p = api.getFilterSchema(key).catch((err) => {
      // allow retry after transient failures
      filterSchemaPromises.delete(key);
      throw err;
    });
    filterSchemaPromises.set(key, p);
  }
  return filterSchemaPromises.get(key);
}

export async function getIntentSchemaForCategory(categoryId) {
  const key = String(categoryId);
  if (!intentSchemaPromises.has(key)) {
    const p = api.getIntentSchema(key).catch((err) => {
      // allow retry after transient failures
      intentSchemaPromises.delete(key);
      throw err;
    });
    intentSchemaPromises.set(key, p);
  }
  return intentSchemaPromises.get(key);
}

export async function getCityOptions() {
  if (cityOptionsValue) return cityOptionsValue;
  if (!cityOptionsPromise) {
    cityOptionsPromise = api.getCityOptions().then((data) => {
      const raw = data && Array.isArray(data.options) ? data.options : [];
      cityOptionsValue = raw.map((v) => String(v)).filter((v) => v.length > 0);
      return cityOptionsValue;
    }).catch((err) => {
      cityOptionsPromise = null;
      throw err;
    });
  }
  return cityOptionsPromise;
}

export async function getDistrictOptions(city) {
  const key = String(city || '').trim();
  if (!key) return [];
  if (districtOptionsValues.has(key)) return districtOptionsValues.get(key);
  if (!districtOptionsPromises.has(key)) {
    const p = api.getDistrictOptions(key).then((data) => {
      const raw = data && Array.isArray(data.options) ? data.options : [];
      const items = raw.map((v) => String(v)).filter((v) => v.length > 0);
      districtOptionsValues.set(key, items);
      return items;
    }).catch((err) => {
      districtOptionsPromises.delete(key);
      throw err;
    });
    districtOptionsPromises.set(key, p);
  }
  return districtOptionsPromises.get(key);
}

export async function getNeighborhoodOptions(city, district) {
  const c = String(city || '').trim();
  const d = String(district || '').trim();
  if (!c || !d) return [];
  const key = `${c}|${d}`;
  if (neighborhoodOptionsValues.has(key)) return neighborhoodOptionsValues.get(key);
  if (!neighborhoodOptionsPromises.has(key)) {
    const p = api.getNeighborhoodOptions(c, d).then((data) => {
      const raw = data && Array.isArray(data.options) ? data.options : [];
      const items = raw.map((v) => String(v)).filter((v) => v.length > 0);
      neighborhoodOptionsValues.set(key, items);
      return items;
    }).catch((err) => {
      neighborhoodOptionsPromises.delete(key);
      throw err;
    });
    neighborhoodOptionsPromises.set(key, p);
  }
  return neighborhoodOptionsPromises.get(key);
}
