<template>
  <div class="categories-page">
    <div class="header-row">
      <h2>Kategoriler</h2>
      <router-link to="/" class="back-link">Keşfet</router-link>
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
    };
  },
  async mounted() {
    try {
      this.categories = await getCategoriesTree();
      this.loading = false;
    } catch (err) {
      this.error = err.message;
      this.loading = false;
    }
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


