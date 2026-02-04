<template>
  <div class="category-picker-stepper">
    <!-- Search Box -->
    <div class="picker-search">
      <input
        v-model="searchQuery"
        type="text"
        placeholder="Kategori ara..."
        class="search-input"
        @input="onSearchInput"
      />
      <button
        v-if="selectedCategoryId || searchQuery"
        type="button"
        class="clear-btn"
        @click="handleClear"
      >
        Temizle
      </button>
    </div>

    <!-- Search Results (when typing) -->
    <div v-if="searchQuery && searchResults.length > 0" class="search-results">
      <div
        v-for="result in searchResults"
        :key="result.id"
        class="search-result-item"
        :class="{ 'is-leaf': result.isLeaf, 'disabled': mode === 'create' && !result.isLeaf }"
        @click="selectFromSearch(result)"
      >
        <span class="result-path">{{ result.path }}</span>
        <span v-if="result.isLeaf" class="leaf-badge">Seçilebilir</span>
        <span v-else-if="mode === 'create'" class="non-leaf-hint">Alt kategori seç</span>
      </div>
    </div>
    <div v-else-if="searchQuery && searchResults.length === 0" class="no-results">
      Sonuç bulunamadı
    </div>

    <!-- Breadcrumb Navigation -->
    <div v-if="!searchQuery" class="breadcrumb">
      <span
        class="breadcrumb-item clickable"
        @click="goToLevel(-1)"
      >
        Ana
      </span>
      <template v-for="(crumb, idx) in breadcrumbs" :key="crumb.id">
        <span class="breadcrumb-separator">&gt;</span>
        <span
          class="breadcrumb-item"
          :class="{ clickable: idx < breadcrumbs.length - 1 }"
          @click="goToLevel(idx)"
        >
          {{ labelFor(crumb) }}
        </span>
      </template>
    </div>

    <!-- Category Steps (when not searching) -->
    <div v-if="!searchQuery" class="steps-container">
      <div v-if="currentLevelCategories.length === 0" class="empty-level">
        Alt kategori yok
      </div>
      <div v-else class="category-grid">
        <button
          v-for="cat in currentLevelCategories"
          :key="cat.id"
          type="button"
          class="category-btn"
          :class="{
            selected: isSelected(cat.id),
            'is-leaf': isLeaf(cat),
            'has-children': !isLeaf(cat)
          }"
          @click="selectCategory(cat)"
        >
          <span class="cat-name">{{ labelFor(cat) }}</span>
          <span v-if="!isLeaf(cat)" class="arrow">&rarr;</span>
          <span v-else-if="mode === 'create'" class="check-icon">&#10003;</span>
        </button>
      </div>
    </div>

    <!-- Selected Category Display -->
    <div v-if="selectedCategoryId && selectedCategoryPath" class="selected-display">
      <strong>Seçili:</strong> {{ selectedCategoryPath }}
      <span
        v-if="mode === 'search' && selectedCategoryMeta && !selectedCategoryMeta.isLeaf"
        class="selected-hint"
      >
        (alt kategoriler dahil)
      </span>
    </div>
  </div>
</template>

<script>
import {
  categoryLabel,
  flattenCategoriesTree,
  findCategoryAncestorPathIds,
  getBreadcrumbsForPath,
  getChildrenAtPath,
  isLeafCategory,
} from '../../lib/categoryTree';

export default {
  name: 'CategoryPickerStepper',
  props: {
    categoriesTree: {
      type: Array,
      default: () => [],
    },
    modelValue: {
      type: [Number, String, null],
      default: null,
    },
    // 'create' = leaf-only required, 'search' = any level allowed
    mode: {
      type: String,
      default: 'search',
      validator: (v) => ['create', 'search'].includes(v),
    },
  },
  emits: ['update:modelValue', 'category-change'],
  data() {
    return {
      searchQuery: '',
      // Stack of selected category IDs for navigation
      navigationStack: [],
      // Internal selected value
      selectedCategoryId: null,
    };
  },
  computed: {
    // Flatten tree for search
    flatCategories() {
      return flattenCategoriesTree(this.categoriesTree);
    },
    // Search results filtered by query
    searchResults() {
      if (!this.searchQuery) return [];
      const q = this.searchQuery.toLowerCase().trim();
      return this.flatCategories.filter((cat) => {
        const slug = (cat.slug || '').toLowerCase();
        const title = (cat.title || '').toLowerCase();
        const path = (cat.path || '').toLowerCase();
        return slug.includes(q) || title.includes(q) || path.includes(q);
      }).slice(0, 15); // Limit results
    },
    // Breadcrumb trail based on navigation stack
    breadcrumbs() {
      return getBreadcrumbsForPath(this.categoriesTree, this.navigationStack);
    },
    // Current level categories to display
    currentLevelCategories() {
      return getChildrenAtPath(this.categoriesTree, this.navigationStack);
    },
    // Full path string for selected category
    selectedCategoryPath() {
      if (!this.selectedCategoryId) return '';
      const cat = this.flatCategories.find((c) => c.id === this.selectedCategoryId);
      return cat ? cat.path : '';
    },
    selectedCategoryMeta() {
      if (!this.selectedCategoryId) return null;
      return this.flatCategories.find((c) => c.id === this.selectedCategoryId) || null;
    },
  },
  watch: {
    modelValue: {
      handler(newVal) {
        const id = newVal ? Number(newVal) : null;
        if (id !== this.selectedCategoryId) {
          this.selectedCategoryId = id;
          this.syncNavigationToSelection(id);
        }
      },
      immediate: true,
    },
    categoriesTree: {
      handler() {
        // Re-sync when tree loads
        if (this.modelValue) {
          this.syncNavigationToSelection(Number(this.modelValue));
        }
      },
      immediate: true,
    },
  },
  methods: {
    labelFor(node) {
      return categoryLabel(node);
    },
    // Check if category is a leaf (no children)
    isLeaf(cat) {
      return isLeafCategory(cat);
    },
    // Check if category is currently selected
    isSelected(catId) {
      return this.selectedCategoryId === catId;
    },
    // Select a category from the stepper
    selectCategory(cat) {
      const leaf = this.isLeaf(cat);

      if (leaf) {
        // Leaf node: select and emit
        this.selectedCategoryId = cat.id;
        this.emitSelection(cat.id);
      } else {
        // Non-leaf: in search mode can select, in create mode drill down
        if (this.mode === 'search') {
          // Allow selection of non-leaf in search mode
          this.selectedCategoryId = cat.id;
          this.emitSelection(cat.id);
          // Also drill down to show children
          this.navigationStack.push(cat.id);
        } else {
          // Create mode: must drill down
          this.navigationStack.push(cat.id);
        }
      }
    },
    // Select from search results
    selectFromSearch(result) {
      if (this.mode === 'create' && !result.isLeaf) {
        // Can't select non-leaf in create mode, navigate to it instead
        this.syncNavigationToSelection(result.id);
        this.searchQuery = '';
        return;
      }
      this.selectedCategoryId = result.id;
      this.emitSelection(result.id);
      this.searchQuery = '';
      this.syncNavigationToSelection(result.id);
    },
    // Navigate to a breadcrumb level
    goToLevel(idx) {
      if (idx < 0) {
        // Go to root
        this.navigationStack = [];
      } else {
        // Go to specific level
        this.navigationStack = this.navigationStack.slice(0, idx + 1);
      }
    },
    // Clear selection
    handleClear() {
      this.searchQuery = '';
      this.navigationStack = [];
      this.selectedCategoryId = null;
      this.emitSelection(null);
    },
    // Emit selection to parent
    emitSelection(id) {
      this.$emit('update:modelValue', id);
      this.$emit('category-change', id);
    },
    // Sync navigation stack to match a selected category
    syncNavigationToSelection(targetId) {
      const path = findCategoryAncestorPathIds(this.categoriesTree, targetId);
      this.navigationStack = path;
    },
    onSearchInput() {
      // Debounce could be added here if needed
    },
  },
};
</script>

<style scoped>
.category-picker-stepper {
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  padding: 1rem;
  background: #fafafa;
}

.picker-search {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.search-input {
  flex: 1;
  padding: 0.5rem 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 0.95rem;
}

.search-input:focus {
  outline: none;
  border-color: #0066cc;
}

.clear-btn {
  padding: 0.5rem 1rem;
  background: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.875rem;
}

.clear-btn:hover {
  background: #eee;
}

/* Search Results */
.search-results {
  max-height: 200px;
  overflow-y: auto;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: white;
  margin-bottom: 0.75rem;
}

.search-result-item {
  padding: 0.6rem 0.75rem;
  cursor: pointer;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #eee;
}

.search-result-item:last-child {
  border-bottom: none;
}

.search-result-item:hover {
  background: #f0f7ff;
}

.search-result-item.disabled {
  opacity: 0.6;
  cursor: pointer;
}

.search-result-item.disabled:hover {
  background: #fff3e0;
}

.result-path {
  font-size: 0.9rem;
  color: #333;
}

.leaf-badge {
  font-size: 0.75rem;
  background: #e8f5e9;
  color: #2e7d32;
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
}

.non-leaf-hint {
  font-size: 0.75rem;
  color: #f57c00;
}

.no-results {
  padding: 0.75rem;
  color: #666;
  text-align: center;
  font-size: 0.9rem;
}

/* Breadcrumb */
.breadcrumb {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.25rem;
  margin-bottom: 0.75rem;
  font-size: 0.875rem;
  color: #666;
}

.breadcrumb-item {
  color: #666;
}

.breadcrumb-item.clickable {
  color: #0066cc;
  cursor: pointer;
}

.breadcrumb-item.clickable:hover {
  text-decoration: underline;
}

.breadcrumb-separator {
  color: #999;
  margin: 0 0.25rem;
}

/* Category Grid */
.steps-container {
  min-height: 80px;
}

.empty-level {
  padding: 1rem;
  text-align: center;
  color: #999;
}

.category-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 0.5rem;
}

.category-btn {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.6rem 0.75rem;
  background: white;
  border: 1px solid #ddd;
  border-radius: 6px;
  cursor: pointer;
  text-align: left;
  font-size: 0.9rem;
  transition: all 0.15s ease;
}

.category-btn:hover {
  border-color: #0066cc;
  background: #f0f7ff;
}

.category-btn.selected {
  border-color: #0066cc;
  background: #e3f2fd;
}

.category-btn.is-leaf {
  border-left: 3px solid #4caf50;
}

.category-btn.has-children {
  border-left: 3px solid #2196f3;
}

.cat-name {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.arrow {
  color: #2196f3;
  margin-left: 0.5rem;
}

.check-icon {
  color: #4caf50;
  margin-left: 0.5rem;
}

/* Selected Display */
.selected-display {
  margin-top: 0.75rem;
  padding: 0.6rem 0.75rem;
  background: #e8f5e9;
  border-radius: 4px;
  font-size: 0.9rem;
  color: #2e7d32;
}

.selected-hint {
  margin-left: 0.35rem;
  color: #2e7d32;
  opacity: 0.85;
}
</style>
