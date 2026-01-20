<template>
  <div class="categories-page">
    <h2>Categories</h2>
    <div v-if="loading" class="loading">Loading categories...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <CategoryTree v-else :categories="categories" />
  </div>
</template>

<script>
import { api } from '../api/client';
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
      this.categories = await api.getCategories();
      this.loading = false;
    } catch (err) {
      this.error = err.message;
      this.loading = false;
    }
  },
};
</script>

<style scoped>
.categories-page h2 {
  margin-bottom: 1.5rem;
  font-size: 2rem;
}
</style>


