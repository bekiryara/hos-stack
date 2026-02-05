<template>
  <div class="filter-field">
    <label class="field-label">
      {{ label }}
      <span v-if="filter && filter.required" class="required-badge">zorunlu</span>
    </label>

    <!-- Search-mode range(number): min/max -->
    <div v-if="isRangeSearch" class="range-row">
      <input
        v-model.number="minModel"
        type="number"
        :placeholder="`En az ${label}`"
        class="field-input"
      />
      <input
        v-model.number="maxModel"
        type="number"
        :placeholder="`En çok ${label}`"
        class="field-input"
      />
    </div>

    <!-- Select/enum -->
    <select
      v-else-if="isSelect"
      v-model="model"
      class="field-input"
    >
      <option value="">{{ selectPlaceholder }}</option>
      <option
        v-for="opt in selectOptions"
        :key="opt.value"
        :value="opt.value"
      >
        {{ opt.label }}
      </option>
    </select>

    <!-- String -->
    <input
      v-else-if="filter && filter.value_type === 'string'"
      v-model="model"
      type="text"
      :placeholder="label"
      class="field-input"
    />

    <!-- Boolean -->
    <input
      v-else-if="filter && filter.value_type === 'boolean'"
      v-model="model"
      type="checkbox"
      class="field-checkbox"
    />

    <!-- Number -->
    <input
      v-else-if="filter && filter.value_type === 'number'"
      v-model.number="model"
      type="number"
      :placeholder="label"
      class="field-input"
    />
  </div>
</template>

<script>
export default {
  name: 'FilterField',
  props: {
    filter: { type: Object, required: true },
    mode: { type: String, default: 'search' }, // search|create
    modelValue: { type: [String, Number, Boolean], default: '' },
    min: { type: [String, Number], default: '' },
    max: { type: [String, Number], default: '' },
  },
  emits: ['update:modelValue', 'update:min', 'update:max'],
  computed: {
    label() {
      return (this.filter && (this.filter.label || this.filter.attribute_key)) || '';
    },
    model: {
      get() {
        return this.modelValue;
      },
      set(v) {
        this.$emit('update:modelValue', v);
      },
    },
    minModel: {
      get() {
        return this.min;
      },
      set(v) {
        this.$emit('update:min', v);
      },
    },
    maxModel: {
      get() {
        return this.max;
      },
      set(v) {
        this.$emit('update:max', v);
      },
    },
    isRangeSearch() {
      return (
        this.mode === 'search' &&
        this.filter &&
        this.filter.filter_mode === 'range' &&
        this.filter.value_type === 'number'
      );
    },
    isSelect() {
      const f = this.filter;
      return !!(f && (f.ui_component === 'select' || f.value_type === 'enum' || f.value_type === 'select'));
    },
    selectOptions() {
      const f = this.filter || {};
      const raw =
        (f.rules && Array.isArray(f.rules.options) && f.rules.options) ||
        (Array.isArray(f.options) && f.options) ||
        (Array.isArray(f.enum) && f.enum) ||
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
    selectPlaceholder() {
      return `${this.label} seçiniz...`;
    },
  },
};
</script>

<style scoped>
.filter-field {
  margin-bottom: 1rem;
}

.field-label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.range-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
}

.field-input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
}

.field-checkbox {
  width: auto;
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
</style>

