<template>
  <div class="filters-panel">
    <h3>Filtreler</h3>

    <div v-if="appliedFilters.length > 0" class="applied-filters">
      <div class="applied-header">
        <div class="applied-title">Seçilenler</div>
        <button type="button" class="clear-button" @click="handleClear">Sıfırla</button>
      </div>
      <ul class="applied-list">
        <li v-for="f in appliedFilters" :key="f.key">
          <strong>{{ f.label }}:</strong> {{ f.value }}
        </li>
      </ul>
    </div>
    <form v-if="(filters || []).length > 0" @submit.prevent="handleSubmit">
      <div v-for="filter in (filters || [])" :key="filter.attribute_key" class="filter-item">
        <FilterField
          :filter="filter"
          mode="search"
          v-model="localFormData[filter.attribute_key]"
          v-model:min="localFormData[filter.attribute_key + '_min']"
          v-model:max="localFormData[filter.attribute_key + '_max']"
        />
      </div>
      <button type="submit" class="search-button">Ara</button>
    </form>
    <div v-else-if="filtersLoaded" data-marker="filters-empty" class="empty-state">
      <p>Bu kategoride filtre yok</p>
      <button type="button" class="search-button" @click="handleSubmit">Ara</button>
    </div>
    <div v-else class="loading">Filtreler yükleniyor...</div>
  </div>
</template>

<script>
import FilterField from './common/FilterField.vue';

export default {
  name: 'FiltersPanel',
  components: { FilterField },
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
  computed: {
    labelMap() {
      const map = {};
      (this.filters || []).forEach((f) => {
        if (!f || !f.attribute_key) return;
        const key = String(f.attribute_key);
        map[key] = String(f.label || f.attribute_key);
      });
      return map;
    },
    appliedFilters() {
      const out = [];
      Object.keys(this.localFormData || {}).forEach((key) => {
        const value = this.localFormData[key];
        if (value !== null && value !== undefined && value !== '') {
          const rawKey = String(key);
          const m = rawKey.match(/^(.*)_(min|max)$/);
          const baseKey = m ? m[1] : rawKey;
          const suffix = m ? m[2] : '';
          const baseLabel = this.labelMap[baseKey] || baseKey;
          const label =
            suffix === 'min' ? `${baseLabel} (en az)` :
            suffix === 'max' ? `${baseLabel} (en çok)` :
            baseLabel;
          out.push({ key: rawKey, label, value });
        }
      });
      return out;
    },
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
    handleClear() {
      this.localFormData = {};
      this.$emit('update:modelValue', {});
      this.$emit('search', {});
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

.applied-filters {
  margin: 0.75rem 0 1rem;
  padding: 0.75rem;
  background: #fff;
  border: 1px solid #eee;
  border-radius: 6px;
}

.applied-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.applied-title {
  font-weight: 600;
}

.applied-list {
  margin: 0;
  padding-left: 1.25rem;
  color: #333;
}

.clear-button {
  background: transparent;
  border: 1px solid #bbb;
  color: #333;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.clear-button:hover {
  background: #f5f5f5;
}
</style>


