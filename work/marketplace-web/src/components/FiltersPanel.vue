<template>
  <div class="filters-panel">
    <h3>Filters</h3>
    <form v-if="filters.length > 0" @submit.prevent="handleSubmit">
      <div v-for="filter in filters" :key="filter.attribute_key" class="filter-item">
        <label>
          {{ filter.attribute_key }}
          <span v-if="filter.required" class="required-badge">required</span>
        </label>
        <div v-if="filter.filter_mode === 'range' && filter.value_type === 'number'">
          <input
            v-model.number="localFormData[filter.attribute_key + '_min']"
            type="number"
            :placeholder="`Min ${filter.attribute_key}`"
            class="filter-input"
          />
          <input
            v-model.number="localFormData[filter.attribute_key + '_max']"
            type="number"
            :placeholder="`Max ${filter.attribute_key}`"
            class="filter-input"
          />
        </div>
        <select
          v-else-if="isSelectFilter(filter)"
          v-model="localFormData[filter.attribute_key]"
          class="filter-input"
        >
          <option value="">Select {{ filter.attribute_key }}</option>
          <option
            v-for="opt in getSelectOptions(filter)"
            :key="opt.value"
            :value="opt.value"
          >
            {{ opt.label }}
          </option>
        </select>
        <input
          v-else-if="filter.value_type === 'string'"
          v-model="localFormData[filter.attribute_key]"
          type="text"
          :placeholder="filter.attribute_key"
          class="filter-input"
        />
        <input
          v-else-if="filter.value_type === 'boolean'"
          v-model="localFormData[filter.attribute_key]"
          type="checkbox"
          class="filter-checkbox"
        />
        <input
          v-else-if="filter.value_type === 'number'"
          v-model.number="localFormData[filter.attribute_key]"
          type="number"
          :placeholder="filter.attribute_key"
          class="filter-input"
        />
      </div>
      <button type="submit" class="search-button">Search</button>
    </form>
    <div v-else-if="filtersLoaded" data-marker="filters-empty" class="empty-state">
      <p>No filters for this category</p>
      <button type="button" class="search-button" @click="handleSubmit">Search</button>
    </div>
    <div v-else class="loading">Loading filters...</div>
  </div>
</template>

<script>
export default {
  name: 'FiltersPanel',
  props: {
    filters: {
      type: Array,
      default: () => [],
    },
    filtersLoaded: {
      type: Boolean,
      default: false,
    },
    modelValue: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['search', 'update:modelValue'],
  data() {
    return {
      localFormData: {},
      syncingFromParent: false,
    };
  },
  watch: {
    modelValue: {
      handler(val) {
        this.syncingFromParent = true;
        this.localFormData = { ...(val || {}) };
        this.$nextTick(() => {
          this.syncingFromParent = false;
        });
      },
      immediate: true,
    },
    localFormData: {
      handler(val) {
        if (this.syncingFromParent) return;
        this.$emit('update:modelValue', { ...(val || {}) });
      },
      deep: true,
    },
  },
  methods: {
    isSelectFilter(filter) {
      // WP-NEXT: enum/select support (schema-driven)
      return filter && (filter.ui_component === 'select' || filter.value_type === 'enum' || filter.value_type === 'select');
    },
    getSelectOptions(filter) {
      // Prefer schema rules.options (current backend shape), fallback to enum/options if present
      const raw =
        (filter && filter.rules && Array.isArray(filter.rules.options) && filter.rules.options) ||
        (filter && Array.isArray(filter.options) && filter.options) ||
        (filter && Array.isArray(filter.enum) && filter.enum) ||
        [];

      return raw
        .map((opt) => {
          if (opt && typeof opt === 'object') {
            const value = opt.value ?? opt.key ?? opt.id ?? '';
            const label = opt.label ?? opt.name ?? String(value);
            return { value: String(value), label: String(label) };
          }
          return { value: String(opt), label: String(opt) };
        })
        .filter((o) => o.value !== '');
    },
    handleSubmit() {
      const attrs = {};
      Object.keys(this.localFormData).forEach((key) => {
        const value = this.localFormData[key];
        if (value !== null && value !== undefined && value !== '') {
          if (key.endsWith('_min')) {
            const baseKey = key.replace('_min', '');
            attrs[`${baseKey}_min`] = value;
          } else if (key.endsWith('_max')) {
            const baseKey = key.replace('_max', '');
            attrs[`${baseKey}_max`] = value;
          } else {
            attrs[key] = value;
          }
        }
      });
      this.$emit('search', attrs);
    },
  },
};
</script>

<style scoped>
.filters-panel {
  background: #f9f9f9;
  padding: 1.5rem;
  border-radius: 8px;
  margin-bottom: 2rem;
}

.filters-panel h3 {
  margin-bottom: 1rem;
  font-size: 1.2rem;
}

.filter-item {
  margin-bottom: 1rem;
}

.filter-item label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.required-badge {
  display: inline-block;
  background: #ff9800;
  color: white;
  font-size: 0.75rem;
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
  margin-left: 0.5rem;
}

.filter-input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
}

.filter-checkbox {
  width: auto;
  margin-right: 0.5rem;
}

.search-button {
  background: #0066cc;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
  margin-top: 1rem;
}

.search-button:hover {
  background: #0052a3;
}

.empty-state {
  text-align: center;
  padding: 1rem;
  color: #666;
}

.empty-state p {
  margin-bottom: 1rem;
}
</style>


