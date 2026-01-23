<template>
  <div class="listings-search-page">
    <h2>Search Listings</h2>
    <div v-if="loadingFilters" class="loading">Loading filters...</div>
    <div v-else-if="errorFilters" class="error">{{ errorFilters }}</div>
    <FiltersPanel
      v-else
      :filters="filters"
      @search="handleSearch"
    />
    <div v-if="loadingListings" class="loading">Searching listings...</div>
    <div v-else-if="errorListings" class="error">{{ errorListings }}</div>
    <ListingsGrid v-else-if="initialSearchDone" :listings="listings" />
    <div v-else class="loading">Ready to search...</div>
  </div>
</template>

<script>
import { api } from '../api/client';
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
      filters: [],
      listings: [],
      loadingFilters: true,
      loadingListings: false,
      errorFilters: null,
      errorListings: null,
      initialSearchDone: false, // WP-60: Guard to prevent infinite loops
    };
  },
  async mounted() {
    if (this.categoryId) {
      await this.loadFilters();
    }
  },
  watch: {
    categoryId: {
      handler: 'loadFilters',
      immediate: true,
    },
  },
  methods: {
    async loadFilters() {
      if (!this.categoryId) {
        this.loadingFilters = false;
        return;
      }
      try {
        this.loadingFilters = true;
        this.errorFilters = null;
        const schema = await api.getFilterSchema(this.categoryId);
        this.filters = schema.filters || [];
        this.loadingFilters = false;
        
        // WP-60: Auto-run initial search after filters load (once only)
        if (!this.initialSearchDone) {
          this.initialSearchDone = true;
          await this.handleSearch({});
        }
      } catch (err) {
        this.errorFilters = err.message;
        this.loadingFilters = false;
      }
    },
    async handleSearch(attrs) {
      try {
        this.loadingListings = true;
        this.errorListings = null;
        const params = {
          category_id: this.categoryId,
          status: 'published',
        };
        Object.keys(attrs).forEach((key) => {
          params[`attrs[${key}]`] = attrs[key];
        });
        this.listings = await api.searchListings(params);
        this.loadingListings = false;
      } catch (err) {
        this.errorListings = err.message;
        this.loadingListings = false;
      }
    },
  },
};
</script>

<style scoped>
.listings-search-page h2 {
  margin-bottom: 1.5rem;
  font-size: 2rem;
}
</style>


