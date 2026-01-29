<template>
  <div class="listings-search-page" data-marker="marketplace-search">
    <h2>Search Listings</h2>
    <div class="category-picker">
      <label>
        Category
        <select
          class="category-select"
          :value="categoryId || ''"
          @change="onCategorySelect($event.target.value)"
        >
          <option value="">Select category...</option>
          <option v-for="opt in categoryOptions" :key="opt.id" :value="String(opt.id)">
            {{ opt.label }}
          </option>
        </select>
      </label>
    </div>
    <div v-if="loadingFilters" class="loading">Loading filters...</div>
    <div v-else-if="errorFilters" class="error">{{ errorFilters }}</div>
    <FiltersPanel
      v-else
      :filters="filters"
      :filters-loaded="filtersLoaded"
      v-model="filterState"
      @search="handleSearch"
    />
    <div v-if="loadingListings" class="loading">Searching listings...</div>
    <div v-else-if="errorListings" class="error">{{ errorListings }}</div>
    <div v-else-if="searchExecuted" data-marker="search-executed">
      <ListingsGrid v-if="listings && listings.length > 0" :listings="listings" />
      <div v-else class="empty-state">
        <p>No listings found</p>
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';
import { getCategoriesTree, getFilterSchemaForCategory } from '../lib/catalogSpine';
import FiltersPanel from '../components/FiltersPanel.vue';
import ListingsGrid from '../components/ListingsGrid.vue';

export default {
  name: 'ListingsSearchPage',
  components: {
    FiltersPanel,
    ListingsGrid,
  },
  props: {
    categoryId: {
      type: String,
      default: null,
    },
  },
  data() {
    return {
      categoriesTree: [],
      filters: [],
      filterState: {}, // WP-NEXT: single source of truth for UI filter values
      q: '', // WP-NEXT: canonical query param (future-safe)
      sort: '', // WP-NEXT: canonical query param (future-safe)
      page: 1, // WP-NEXT: canonical query param (backend supports page/per_page)
      listings: [],
      loadingFilters: true,
      filtersLoaded: false, // WP-60: Track if filters have finished loading (even if empty)
      loadingListings: false,
      errorFilters: null,
      errorListings: null,
      initialSearchDone: false, // WP-60: Guard to prevent infinite loops
      searchExecuted: false, // WP-60: Track if search has been executed at least once
      querySyncTimer: null, // WP-NEXT: debounce URL query sync
      syncingFromQuery: false, // prevents state->query loop
      syncingToQuery: false, // prevents query->state loop
      lastSyncedQueryKey: '', // deterministic back/forward hydration
    };
  },
  computed: {
    categoryOptions() {
      // Flatten category tree for a simple selector (schema-driven; no hardcoded vertical logic)
      const out = [];
      const walk = (nodes, depth) => {
        (nodes || []).forEach((n) => {
          const prefix = depth > 0 ? `${'—'.repeat(depth)} ` : '';
          out.push({ id: n.id, label: `${prefix}${n.slug} (${n.id})` });
          if (n.children && n.children.length > 0) walk(n.children, depth + 1);
        });
      };
      walk(this.categoriesTree, 0);
      return out;
    },
  },
  async mounted() {
    try {
      this.categoriesTree = await getCategoriesTree();
    } catch {
      // Category selector is optional for /search/:categoryId; ignore failures here.
      this.categoriesTree = [];
    }
    if (this.categoryId) {
      await this.loadFilters();
    }
  },
  watch: {
    categoryId: {
      handler(newVal, oldVal) {
        // WP-48: Reset initialSearchDone when categoryId changes
        if (newVal !== oldVal) {
          this.initialSearchDone = false;
          this.searchExecuted = false;
          this.filterState = {};
        }
        this.loadFilters();
      },
      immediate: true,
    },
    filterState: {
      handler() {
        // WP-NEXT: keep filter state in URL query (refresh/back works)
        if (this.syncingFromQuery) return;
        if (!this.filtersLoaded) return;
        if (!this.categoryId) return;
        // Any filter change resets paging
        this.page = 1;
        if (this.querySyncTimer) clearTimeout(this.querySyncTimer);
        this.querySyncTimer = setTimeout(async () => {
          const query = this.buildQueryFromFilterState();
          const nextKey = this.stableStringify(query);
          this.lastSyncedQueryKey = nextKey;
          this.syncingToQuery = true;
          try {
            await this.$router.replace({ query });
          } catch {
            // ignore navigation duplication errors
          } finally {
            this.syncingToQuery = false;
          }
        }, 250);
      },
      deep: true,
    },
    '$route.query': {
      handler(newQuery) {
        if (this.syncingToQuery) return;
        if (!this.filtersLoaded) return;
        if (!this.categoryId) return;
        const key = this.stableStringify(newQuery || {});
        if (key === this.lastSyncedQueryKey) return;
        this.syncingFromQuery = true;
        try {
          this.hydrateFilterStateFromQuery(this.filters);
          // Back/forward should immediately re-run the search for the new URL state
          this.executeSearch(this.filterState);
        } finally {
          this.syncingFromQuery = false;
        }
      },
      deep: true,
    },
  },
  methods: {
    async onCategorySelect(nextId) {
      if (!nextId) {
        await this.$router.push({ path: '/search', query: {} });
        return;
      }
      await this.$router.push({ path: `/search/${nextId}`, query: {} });
    },
    stableStringify(obj) {
      // WP-NEXT: deterministic serialization (stable key order, shallow)
      const out = {};
      Object.keys(obj || {}).sort().forEach((k) => {
        out[k] = obj[k];
      });
      return JSON.stringify(out);
    },
    buildFiltersFromFilterState() {
      const filters = {};
      Object.keys(this.filterState || {}).forEach((key) => {
        const value = this.filterState[key];
        if (value !== null && value !== undefined && value !== '') {
          filters[key] = value;
        }
      });
      return filters;
    },
    buildQueryFromFilterState() {
      // WP-NEXT: canonical query shape
      // Route: /search/:categoryId?
      // Query: ?q=&filters=...&sort=&page=
      const query = {};
      if (this.q) query.q = String(this.q);
      if (this.sort) query.sort = String(this.sort);
      if (this.page && Number(this.page) > 1) query.page = String(this.page);

      const filters = this.buildFiltersFromFilterState();
      if (Object.keys(filters).length > 0) {
        query.filters = this.stableStringify(filters);
      }

      return query;
    },
    buildListingsApiParamsFromFilterState(schemaFilters, filterState) {
      // WP-75: build SPEC-aligned listing search params schema-driven (no hardcoded filter keys)
      // - filters[KEY]=VALUE
      // - filters[KEY][min|max]=... for range(number) filters
      const params = {};
      const state = filterState || {};
      (schemaFilters || []).forEach((def) => {
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
    },
    hydrateFilterStateFromQuery(schemaFilters) {
      const query = this.$route.query || {};
      // canonical non-filter query params
      this.q = typeof query.q === 'string' ? query.q : '';
      this.sort = typeof query.sort === 'string' ? query.sort : '';
      const page = parseInt(String(query.page || '1'), 10);
      this.page = Number.isFinite(page) && page > 0 ? page : 1;

      // Build a quick lookup for value_type / filter_mode by attribute_key
      const byKey = {};
      (schemaFilters || []).forEach((f) => {
        if (f && f.attribute_key) byKey[f.attribute_key] = f;
      });

      let rawFilters = null;
      if (typeof query.filters === 'string' && query.filters.trim() !== '') {
        try {
          rawFilters = JSON.parse(query.filters);
        } catch {
          rawFilters = null;
        }
      }

      // Backward-compat: accept legacy f_* format if filters is missing
      if (!rawFilters) {
        rawFilters = {};
        Object.keys(query).forEach((k) => {
          if (!k.startsWith('f_')) return;
          rawFilters[k.slice(2)] = query[k];
        });
      }

      const next = {};
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
          if (!Number.isNaN(n)) next[rawKey] = n;
          return;
        }
        if (def && def.value_type === 'boolean') {
          if (typeof rawVal === 'boolean') {
            next[rawKey] = rawVal;
          } else {
            next[rawKey] = String(rawVal) === '1' || String(rawVal) === 'true';
          }
          return;
        }
        // default: string / select / enum values as strings
        next[rawKey] = rawVal === null || rawVal === undefined ? '' : String(rawVal);
      });

      this.filterState = next;
      this.lastSyncedQueryKey = this.stableStringify(query);
    },
    async loadFilters() {
      if (!this.categoryId) {
        this.loadingFilters = false;
        this.filtersLoaded = true;
        return;
      }
      try {
        this.loadingFilters = true;
        this.filtersLoaded = false;
        this.errorFilters = null;
        const schema = await getFilterSchemaForCategory(this.categoryId);
        // WP-60: Normalize filters to [] if undefined/null
        this.filters = (schema && schema.filters) ? schema.filters : [];
        this.loadingFilters = false;
        this.filtersLoaded = true; // WP-60: Mark as loaded even if filters array is empty
        
        // WP-NEXT: Hydrate filter state from URL query (after schema loads)
        this.hydrateFilterStateFromQuery(this.filters);

        // WP-60: Auto-run initial search after filters load (once only)
        if (!this.initialSearchDone) {
          this.initialSearchDone = true;
          await this.executeSearch(this.filterState);
        }
      } catch (err) {
        this.errorFilters = err.message;
        this.loadingFilters = false;
        this.filtersLoaded = true; // WP-60: Mark as loaded even on error
        // WP-60: Normalize filters to [] on error
        this.filters = [];
      }
    },
    async executeSearch(filterState) {
      try {
        this.loadingListings = true;
        this.errorListings = null;
        const params = {
          category_id: this.categoryId,
          status: 'published',
          page: this.page,
          per_page: 20,
        };
        if (this.q) params.q = String(this.q);

        const filterParams = this.buildListingsApiParamsFromFilterState(this.filters, filterState || this.filterState);
        Object.keys(filterParams).forEach((k) => {
          params[k] = filterParams[k];
        });
        this.listings = await api.searchListings(params);
        this.loadingListings = false;
        this.searchExecuted = true; // WP-60: Mark search as executed
      } catch (err) {
        this.errorListings = err.message;
        this.loadingListings = false;
        this.searchExecuted = true; // WP-60: Mark search as executed even on error
      }
    },
    async handleSearch(attrs) {
      // URL query is kept in sync by filterState watcher; search just executes with current state.
      await this.executeSearch(this.filterState);
    },
  },
};
</script>

<style scoped>
.listings-search-page h2 {
  margin-bottom: 1.5rem;
  font-size: 2rem;
}

.category-picker {
  margin-bottom: 1rem;
}

.category-select {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
  margin-top: 0.25rem;
}
</style>


