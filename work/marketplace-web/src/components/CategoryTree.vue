<template>
  <div class="category-tree">
    <ul v-if="categories.length > 0">
      <li v-for="category in categories" :key="category.id" class="category-item">
        <div class="row">
          <button
            v-if="hasChildren(category)"
            type="button"
            class="toggle"
            :aria-label="isOpen(category.id) ? 'Kapat' : 'Aç'"
            @click="toggle(category.id)"
          >
            {{ isOpen(category.id) ? '▾' : '▸' }}
          </button>
          <span v-else class="toggle-spacer" aria-hidden="true">•</span>

          <router-link
            :to="`/search/${category.id}`"
            class="category-link"
            :class="{ 'has-children': hasChildren(category) }"
          >
            {{ labelFor(category) }}
            <span v-if="category.slug && category.title && category.slug !== category.title" class="slug-hint">
              ({{ category.slug }})
            </span>
          </router-link>
        </div>
        <CategoryTree
          v-if="hasChildren(category) && isOpen(category.id)"
          :categories="category.children"
        />
      </li>
    </ul>
    <div v-else class="empty-state">No categories found</div>
  </div>
</template>

<script>
import { categoryLabel } from '../lib/categoryTree';

export default {
  name: 'CategoryTree',
  props: {
    categories: {
      type: Array,
      default: () => [],
    },
  },
  data() {
    return {
      open: {},
    };
  },
  methods: {
    labelFor(node) {
      return categoryLabel(node);
    },
    hasChildren(node) {
      return !!(node && Array.isArray(node.children) && node.children.length > 0);
    },
    isOpen(id) {
      const key = String(id);
      return Boolean(this.open[key]);
    },
    toggle(id) {
      const key = String(id);
      this.open = { ...this.open, [key]: !this.open[key] };
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

.row {
  display: flex;
  align-items: center;
  gap: 0.35rem;
}

.toggle {
  width: 1.5rem;
  height: 1.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 4px;
  background: #fff;
  cursor: pointer;
  line-height: 1;
  color: #333;
}

.toggle:hover {
  background: #f3f4f6;
}

.toggle-spacer {
  width: 1.5rem;
  text-align: center;
  color: #bbb;
}

.category-link {
  display: block;
  padding: 0.45rem 0.5rem;
  color: #0066cc;
  text-decoration: none;
  border-radius: 4px;
  transition: background 0.2s;
  flex: 1;
}

.category-link:hover {
  background: #f0f0f0;
}

.category-link.has-children {
  font-weight: 600;
}

.slug-hint {
  color: #666;
  font-weight: normal;
  margin-left: 0.35rem;
  font-size: 0.9em;
}

.empty-state {
  padding: 0.75rem;
  color: #666;
}
</style>


