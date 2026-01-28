// WP-NEXT: Catalog spine client (single source of truth)
// - Categories: fetch once, in-memory cache
// - Filter schema: per-categoryId cache
// No page-level copy/paste fetch logic.

import { api } from '../api/client';

let categoriesPromise = null;
let categoriesValue = null;

const filterSchemaPromises = new Map(); // categoryId -> Promise<schema>

export async function getCategoriesTree() {
  if (categoriesValue) return categoriesValue;
  if (!categoriesPromise) {
    categoriesPromise = api.getCategories().then((data) => {
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

