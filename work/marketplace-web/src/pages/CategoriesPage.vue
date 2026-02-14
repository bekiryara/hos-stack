<template>
  <div class="categories-page">
    <div class="header-row">
      <h2>Kategoriler</h2>
      <router-link to="/" class="back-link">Keşfet</router-link>
    </div>
    <div class="search-row">
      <input
        v-model="searchQuery"
        type="text"
        class="search-input"
        placeholder="Kategori ara (örn: asma yaprağı)..."
        @input="onSearchInput"
      />
      <button
        v-if="searchQuery"
        type="button"
        class="clear-btn"
        @click="clearSearch"
      >
        Temizle
      </button>
    </div>

    <div v-if="searchQuery" class="search-results-card">
      <div v-if="searchLoading" class="loading">Arama yapılıyor...</div>
      <div v-else-if="searchResults.length === 0" class="empty-state">Sonuç bulunamadı</div>
      <div v-else class="search-results">
        <router-link
          v-for="r in searchResults"
          :key="r.id"
          class="search-result-item"
          :to="`/search/${r.canonicalId}`"
          @click.native="clearSearch"
        >
          <div class="path">{{ r.path }}</div>
          <div class="meta">{{ r.slug }}</div>
        </router-link>
      </div>
    </div>
    <div v-if="loading" class="loading">Loading categories...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else class="tree-card">
      <CategoryTree :categories="categories" />
    </div>
  </div>
</template>

<script>
import { getCategoriesTree } from '../lib/catalogSpine';
import CategoryTree from '../components/CategoryTree.vue';
import { flattenCategoriesTree } from '../lib/categoryTree';

export default {
  name: 'CategoriesPage',
  components: {
    CategoryTree,
  },
  data() {
    return {
      categories: [],
      loading: true,
      error: null,
      searchQuery: '',
      searchLoading: false,
      searchResults: [],
      canonicalTree: null,
      canonicalFlat: null,
      searchTimer: null,
    };
  },
  async mounted() {
    try {
      // Canonical catalog tree (full coverage). Menu view is a curated/vitrine projection and can omit long-tail nodes.
      this.categories = await getCategoriesTree();
      this.loading = false;
    } catch (err) {
      this.error = err.message;
      this.loading = false;
    }
  },
  beforeUnmount() {
    if (this.searchTimer) clearTimeout(this.searchTimer);
  },
  methods: {
    clearSearch() {
      this.searchQuery = '';
      this.searchLoading = false;
      this.searchResults = [];
      if (this.searchTimer) clearTimeout(this.searchTimer);
      this.searchTimer = null;
    },
    async ensureCanonicalIndexLoaded() {
      if (this.canonicalFlat) return;
      this.canonicalTree = await getCategoriesTree(); // canonical DB tree (not menu-projected)
      this.canonicalFlat = flattenCategoriesTree(this.canonicalTree || []);
    },
    onSearchInput() {
      const q = String(this.searchQuery || '').trim();
      if (this.searchTimer) clearTimeout(this.searchTimer);
      this.searchTimer = setTimeout(async () => {
        const qq = String(this.searchQuery || '').trim().toLowerCase();
        if (!qq) {
          this.searchResults = [];
          this.searchLoading = false;
          return;
        }
        this.searchLoading = true;
        try {
          await this.ensureCanonicalIndexLoaded();
          const res = (this.canonicalFlat || [])
            .filter((c) => {
              const slug = String(c.slug || '').toLowerCase();
              const title = String(c.title || '').toLowerCase();
              const path = String(c.path || '').toLowerCase();
              return slug.includes(qq) || title.includes(qq) || path.includes(qq);
            })
            .slice(0, 30)
            .map((c) => ({
              id: c.id,
              canonicalId: (c.node && c.node.canonical_category_id) ? Number(c.node.canonical_category_id) : Number(c.id),
              slug: c.slug,
              path: c.path,
            }))
            .filter((x) => Number.isFinite(Number(x.canonicalId)) && Number(x.canonicalId) > 0);
          this.searchResults = res;
        } catch (e) {
          // keep menu usable even if canonical fetch fails
          this.searchResults = [];
        } finally {
          this.searchLoading = false;
        }
      }, q ? 250 : 0);
    },
  },
};
</script>

<style scoped>
.header-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.search-row {
  display: flex;
  gap: 0.6rem;
  align-items: center;
  margin-bottom: 0.75rem;
}

.search-input {
  flex: 1;
  padding: 0.7rem 0.85rem;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 1rem;
}

.clear-btn {
  padding: 0.7rem 0.9rem;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  background: #fff;
  cursor: pointer;
}

.clear-btn:hover {
  background: #f3f4f6;
}

.search-results-card {
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  background: #fff;
  padding: 0.5rem;
  margin-bottom: 0.9rem;
}

.search-results {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.search-result-item {
  display: block;
  padding: 0.6rem 0.65rem;
  border-radius: 8px;
  text-decoration: none;
  color: inherit;
  border: 1px solid transparent;
}

.search-result-item:hover {
  background: #f8fafc;
  border-color: #e5e7eb;
}

.path {
  font-weight: 700;
}

.meta {
  margin-top: 0.1rem;
  color: #666;
  font-size: 0.9rem;
}

.categories-page h2 {
  margin-bottom: 1.5rem;
  font-size: 2rem;
}

.back-link {
  color: #0066cc;
  text-decoration: none;
  font-size: 0.95rem;
}

.back-link:hover {
  text-decoration: underline;
}

.tree-card {
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  background: #fff;
  padding: 0.75rem 0.5rem;
  max-height: calc(100vh - 200px);
  overflow: auto;
}
</style>


