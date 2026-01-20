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
            v-model.number="formData[filter.attribute_key + '_min']"
            type="number"
            :placeholder="`Min ${filter.attribute_key}`"
            class="filter-input"
          />
          <input
            v-model.number="formData[filter.attribute_key + '_max']"
            type="number"
            :placeholder="`Max ${filter.attribute_key}`"
            class="filter-input"
          />
        </div>
        <input
          v-else-if="filter.value_type === 'string'"
          v-model="formData[filter.attribute_key]"
          type="text"
          :placeholder="filter.attribute_key"
          class="filter-input"
        />
        <input
          v-else-if="filter.value_type === 'boolean'"
          v-model="formData[filter.attribute_key]"
          type="checkbox"
          class="filter-checkbox"
        />
        <input
          v-else-if="filter.value_type === 'number'"
          v-model.number="formData[filter.attribute_key]"
          type="number"
          :placeholder="filter.attribute_key"
          class="filter-input"
        />
      </div>
      <button type="submit" class="search-button">Search</button>
    </form>
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
  },
  emits: ['search'],
  data() {
    return {
      formData: {},
    };
  },
  methods: {
    handleSubmit() {
      const attrs = {};
      Object.keys(this.formData).forEach((key) => {
        const value = this.formData[key];
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
</style>


