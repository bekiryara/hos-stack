// WP-NEXT: Catalog spine client (single source of truth)
// - Categories: fetch once, in-memory cache
// - Filter schema: per-categoryId cache
// No page-level copy/paste fetch logic.

import { api } from '../api/client';

let categoriesPromise = null;
let categoriesValue = null;
let categoriesViewKey = ''; // '' | 'menu' | other

const filterSchemaPromises = new Map(); // categoryId -> Promise<schema>
const intentSchemaPromises = new Map(); // categoryId -> Promise<schema>

export async function getCategoriesTree(params = {}) {
  const view = params && params.view ? String(params.view) : '';
  if (categoriesValue && categoriesViewKey === view) return categoriesValue;
  if (!categoriesPromise || categoriesViewKey !== view) {
    categoriesViewKey = view;
    categoriesPromise = api.getCategories({ view }).then((data) => {
      categoriesValue = data;
      return data;
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