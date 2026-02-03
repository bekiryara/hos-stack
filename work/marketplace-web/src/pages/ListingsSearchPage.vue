<template>
  <div class="listings-search-page" data-marker="marketplace-search">
    <h2>Search Listings</h2>
    <div class="category-picker">
      <label class="category-label">Kategori</label>
      <CategoryPickerStepper
        :model-value="categoryId ? Number(categoryId) : null"
        :categories-tree="categoriesTree"
        mode="search"
        @category-change="onCategorySelectFromPicker"
      />
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
        <div class="empty-actions">
          <button type="button" class="secondary-button" @click="resetAllFilters">Reset filters</button>
          <router-link to="/" class="secondary-link">Browse categories</router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';
import { getCategoriesTree, getFilterSchemaForCategory } from '../lib/catalogSpine';
import {
  buildListingsApiParamsFromFilterState,
  buildQueryFromState,
  hydrateStateFromQuery,
  stableStringify,
} from '../lib/filterTransform';
import FiltersPanel from '../components/FiltersPanel.vue';
import ListingsGrid from '../components/ListingsGrid.vue';
import CategoryPickerStepper from '../components/catalog/CategoryPickerStepper.vue';

export default {
  name: 'ListingsSearchPage',
  components: {
    FiltersPanel,
    ListingsGrid,
    CategoryPickerStepper,
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
          const query = buildQueryFromState({ q: this.q, sort: this.sort, page: this.page, filterState: this.filterState });
          const nextKey = stableStringify(query);
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
        const key = stableStringify(newQuery || {});
        if (key === this.lastSyncedQueryKey) return;
        this.syncingFromQuery = true;
        try {
          const hydrated = hydrateStateFromQuery({ query: newQuery || {}, schemaFilters: this.filters });
          this.q = hydrated.q;
          this.sort = hydrated.sort;
          this.page = hydrated.page;
          this.filterState = hydrated.filterState;
          this.lastSyncedQueryKey = stableStringify(newQuery || {});
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
    async onCategorySelectFromPicker(nextId) {
      // Called by CategoryPickerStepper when user selects a category
      await this.onCategorySelect(nextId ? String(nextId) : '');
    },
    async onCategorySelect(nextId) {
      if (!nextId) {
        await this.$router.push({ path: '/search', query: {} });
        return;
      }
      await this.$router.push({ path: `/search/${nextId}`, query: {} });
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
        const hydrated = hydrateStateFromQuery({ query: this.$route.query || {}, schemaFilters: this.filters });
        this.q = hydrated.q;
        this.sort = hydrated.sort;
        this.page = hydrated.page;
        this.filterState = hydrated.filterState;
        this.lastSyncedQueryKey = stableStringify(this.$route.query || {});

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

        // WP-NEXT: filters empty-safe; determinism in API layer (toStableQueryString)
        const state = filterState ?? this.filterState ?? {};
        const schemaFilters = this.filters ?? [];
        const filterParams = buildListingsApiParamsFromFilterState(schemaFilters, state);
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
    resetAllFilters() {
      // Customer-browse friendly: reset state and re-run search (no firm/create CTAs here)
      this.q = '';
      this.sort = '';
      this.page = 1;
      this.filterState = {};
      this.handleSearch({});
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

.category-label {
  display: block;
  font-weight: 500;
  margin-bottom: 0.5rem;
}

.empty-actions {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  justify-content: center;
  margin-top: 0.75rem;
}

.secondary-button {
  padding: 0.5rem 0.9rem;
  border: 1px solid #ddd;
  background: #f5f5f5;
  border-radius: 4px;
  cursor: pointer;
}

.secondary-link {
  color: #0066cc;
  text-decoration: none;
}

.secondary-link:hover {
  text-decoration: underline;
}
</style>


