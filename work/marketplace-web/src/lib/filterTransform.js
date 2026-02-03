/**
 * Filter/query transforms (single source of truth)
 *
 * Used by ListingsSearchPage and any other pages that need:
 * - filterState <-> URL query
 * - filterState -> API params
 */

function safeArray(v) {
  return Array.isArray(v) ? v : [];
}

export function stableStringify(obj) {
  // deterministic serialization (stable key order, shallow)
  const out = {};
  Object.keys(obj || {}).sort().forEach((k) => {
    out[k] = obj[k];
  });
  return JSON.stringify(out);
}

export function buildFiltersFromFilterState(filterState) {
  const filters = {};
  Object.keys(filterState || {}).forEach((key) => {
    const value = filterState[key];
    if (value !== null && value !== undefined && value !== '') {
      filters[key] = value;
    }
  });
  return filters;
}

export function buildQueryFromState({ q, sort, page, filterState }) {
  // canonical query shape
  // Route: /search/:categoryId?
  // Query: ?q=&filters=...&sort=&page=
  const query = {};
  if (q) query.q = String(q);
  if (sort) query.sort = String(sort);
  if (page && Number(page) > 1) query.page = String(page);

  const filters = buildFiltersFromFilterState(filterState);
  if (Object.keys(filters).length > 0) {
    query.filters = stableStringify(filters);
  }
  return query;
}

export function buildListingsApiParamsFromFilterState(schemaFilters, filterState) {
  // SPEC-aligned listing search params schema-driven (no hardcoded filter keys)
  const params = {};
  const state = filterState ?? {};
  safeArray(schemaFilters).forEach((def) => {
    const key = def?.attribute_key;
    if (!key) return;

    if (def.filter_mode === 'range' && def.value_type === 'number') {
      const min = state[`${key}_min`];
      const max = state[`${key}_max`];
      if (min !== null && min !== undefined && min !== '') params[`filters[${key}][min]`] = min;
      if (max !== null && max !== undefined && max !== '') params[`filters[${key}][max]`] = max;
      return;
    }

    const value = state[key];
    if (value === null || value === undefined || value === '') return;
    params[`filters[${key}]`] = value;
  });
  return params;
}

export function hydrateStateFromQuery({ query, schemaFilters }) {
  const q = typeof query?.q === 'string' ? query.q : '';
  const sort = typeof query?.sort === 'string' ? query.sort : '';
  const pageRaw = parseInt(String(query?.page || '1'), 10);
  const page = Number.isFinite(pageRaw) && pageRaw > 0 ? pageRaw : 1;

  // Build a quick lookup for value_type / filter_mode by attribute_key
  const byKey = {};
  safeArray(schemaFilters).forEach((f) => {
    if (f?.attribute_key) byKey[f.attribute_key] = f;
  });

  let rawFilters = null;
  if (typeof query?.filters === 'string' && query.filters.trim() !== '') {
    try {
      rawFilters = JSON.parse(query.filters);
    } catch {
      rawFilters = null;
    }
  }

  // Backward-compat: accept legacy f_* format if filters is missing
  if (!rawFilters) {
    rawFilters = {};
    Object.keys(query || {}).forEach((k) => {
      if (!k.startsWith('f_')) return;
      rawFilters[k.slice(2)] = query[k];
    });
  }

  const filterState = {};
  Object.keys(rawFilters || {}).forEach((rawKey) => {
    const rawVal = rawFilters[rawKey];

    // Range keys only if schema defines <attr> as range(number)
    const isMin = rawKey.endsWith('_min');
    const isMax = rawKey.endsWith('_max');
    const baseKey = (isMin || isMax) ? rawKey.replace(/_(min|max)$/, '') : rawKey;
    const def = byKey[baseKey];

    if ((isMin || isMax) && !(def && def.filter_mode === 'range' && def.value_type === 'number')) {
      // Unknown/min-max key not defined as range in schema: ignore (prevents hardcoded drift)
      return;
    }

    if (def && def.value_type === 'number') {
      const n = typeof rawVal === 'number' ? rawVal : Number(rawVal);
      if (!Number.isNaN(n)) filterState[rawKey] = n;
      return;
    }

    if (def && def.value_type === 'boolean') {
      if (typeof rawVal === 'boolean') {
        filterState[rawKey] = rawVal;
      } else {
        filterState[rawKey] = String(rawVal) === '1' || String(rawVal) === 'true';
      }
      return;
    }

    // default: string / select / enum values as strings
    filterState[rawKey] = rawVal === null || rawVal === undefined ? '' : String(rawVal);
  });

  return { q, sort, page, filterState };
}

