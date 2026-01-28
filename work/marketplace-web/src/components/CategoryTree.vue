<template>
  <div class="category-tree">
    <ul v-if="categories.length > 0">
      <li v-for="category in categories" :key="category.id" class="category-item">
        <router-link
          :to="`/search/${category.id}`"
          class="category-link"
          :class="{ 'has-children': category.children && category.children.length > 0 }"
        >
          {{ category.slug }} ({{ category.id }})
        </router-link>
        <CategoryTree
          v-if="category.children && category.children.length > 0"
          :categories="category.children"
        />
      </li>
    </ul>
    <div v-else class="loading">Loading categories...</div>
  </div>
</template>

<script>
export default {
  name: 'CategoryTree',
  props: {
    categories: {
      type: Array,
      default: () => [],
    },
  },
};
</script>

<style scoped>
.category-tree {
  margin-left: 1rem;
}

.category-item {
  margin: 0.5rem 0;
  list-style: none;
}

.category-link {
  display: block;
  padding: 0.5rem;
  color: #0066cc;
  text-decoration: none;
  border-radius: 4px;
  transition: background 0.2s;
}

.category-link:hover {
  background: #f0f0f0;
}

.category-link.has-children {
  font-weight: 600;
}
</style>


