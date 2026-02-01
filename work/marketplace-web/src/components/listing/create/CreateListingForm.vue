<template>
  <form @submit.prevent="onSubmit" class="listing-form">
    <div class="form-group">
      <label>
        Aktif Firma <span class="required">*</span>
        <div v-if="tenantId" class="tenant-id-display">
          <input
            :value="tenantId"
            type="text"
            required
            readonly
            class="form-input auto-filled"
          />
          <small class="auto-fill-note">Account sayfasından seçilen aktif firma kullanılır.</small>
        </div>
        <div v-else class="tenant-id-missing">
          <p class="tenant-id-warning">
            Bu işlem için aktif bir firmanız olmalı.
          </p>
          <div class="tenant-actions">
            <router-link to="/account" class="tenant-picker-link">Hesabıma Git</router-link>
            <router-link to="/firm/register" class="tenant-picker-link secondary">Firma Oluştur</router-link>
          </div>
          <small v-if="tenantIdLoadError" class="tenant-id-warning">
            <strong>Not:</strong> Aktif firma bulunamadı. Lütfen /account üzerinden firma oluşturun veya aktif firma seçin.
          </small>
        </div>
      </label>
    </div>

    <div class="form-group">
      <label>
        Category <span class="required">*</span>
        <select v-model.number="local.category_id" required class="form-input" @change="emitCategoryChange">
          <option value="">Select leaf category...</option>
          <option v-for="cat in leafCategories" :key="cat.id" :value="cat.id">
            {{ cat.slug || cat.title }} ({{ cat.id }})
          </option>
        </select>
        <small v-if="!leafCategories.length && categories.length" class="field-hint">Sadece yaprak kategoriler listelenir.</small>
      </label>
    </div>

    <div class="form-group">
      <label>
        Title <span class="required">*</span>
        <input
          v-model="local.title"
          type="text"
          required
          maxlength="120"
          placeholder="Listing title (max 120 chars)"
          class="form-input"
        />
      </label>
    </div>

    <div class="form-group">
      <label>
        Description
        <textarea
          v-model="local.description"
          placeholder="Optional description"
          class="form-input"
          rows="4"
        />
      </label>
    </div>

    <div class="form-group">
      <label>
        Transaction Modes <span class="required">*</span>
        <div class="checkbox-group">
          <label>
            <input v-model="local.transaction_modes" type="checkbox" value="sale" />
            Sale
          </label>
          <label>
            <input v-model="local.transaction_modes" type="checkbox" value="rental" />
            Rental
          </label>
          <label>
            <input v-model="local.transaction_modes" type="checkbox" value="reservation" />
            Reservation
          </label>
        </div>
      </label>
    </div>

    <div v-if="filterSchema && filterSchema.filters" class="form-group">
      <h3>Attributes (from filter-schema)</h3>
      <div
        v-for="filter in filterSchema.filters"
        :key="filter.attribute_key"
        class="attribute-field"
        :class="{ 'has-error': fieldError(filter.attribute_key) }"
      >
        <label>
          {{ filter.label || filter.attribute_key }}
          <span v-if="filter.required" class="required-badge">required</span>
          <span v-if="filter.type || filter.value_type" class="type-badge">{{ filter.type || filter.value_type }}</span>
        </label>
        <select
          v-if="isSelectField(filter)"
          v-model="local.attributes[filter.attribute_key]"
          class="form-input"
        >
          <option value=""></option>
          <option v-for="opt in getOptions(filter)" :key="String(opt)" :value="opt">{{ opt }}</option>
        </select>
        <input
          v-else-if="filter.value_type === 'string' || (filter.type === 'text' && filter.value_type !== 'number')"
          v-model="local.attributes[filter.attribute_key]"
          type="text"
          :placeholder="filter.attribute_key"
          class="form-input"
        />
        <input
          v-else-if="filter.value_type === 'boolean' || filter.type === 'boolean'"
          v-model="local.attributes[filter.attribute_key]"
          type="checkbox"
          class="form-checkbox"
        />
        <input
          v-else-if="filter.value_type === 'number' || filter.type === 'number' || filter.type === 'range'"
          v-model.number="local.attributes[filter.attribute_key]"
          type="number"
          :placeholder="filter.attribute_key"
          class="form-input"
        />
        <span v-if="fieldError(filter.attribute_key)" class="field-error">{{ fieldError(filter.attribute_key) }}</span>
      </div>
    </div>

    <button type="submit" :disabled="loading || !tenantId || !canSubmit" class="submit-button">
      {{ loading ? 'Creating...' : 'Create Listing (DRAFT)' }}
    </button>
  </form>
</template>

<script>
export default {
  name: 'CreateListingForm',
  props: {
    categories: { type: Array, default: () => [] },
    filterSchema: { type: Object, default: null },
    tenantId: { type: String, default: '' },
    tenantIdLoadError: { type: Boolean, default: false },
    loading: { type: Boolean, default: false },
    backendError: { type: Object, default: null },
  },
  emits: ['category-change', 'submit'],
  data() {
    return {
      local: {
        category_id: '',
        title: '',
        description: '',
        transaction_modes: [],
        attributes: {},
      },
    };
  },
  computed: {
    flatCategories() {
      const out = [];
      const walk = (nodes) => {
        if (!Array.isArray(nodes)) return;
        for (const n of nodes) {
          if (!n) continue;
          out.push(n);
          const children = Array.isArray(n.children) ? n.children : [];
          if (children.length) walk(children);
        }
      };
      walk(this.categories);
      return out;
    },
    leafCategories() {
      const flat = this.flatCategories || [];
      return flat.filter((c) => {
        const children = Array.isArray(c.children) ? c.children : [];
        return children.length === 0;
      });
    },
    canSubmit() {
      const hasTenant = !!this.tenantId;
      const hasCategory = !!this.local.category_id;
      const hasTitle = !!(this.local.title && String(this.local.title).trim().length > 0);
      return hasTenant && hasCategory && hasTitle;
    },
    backendCode() {
      const b = this.backendError;
      if (!b || typeof b !== 'object') return null;
      return b.code || b.error_code || b.error || null;
    },
    backendDetails() {
      const b = this.backendError;
      if (!b || typeof b !== 'object') return null;
      return b.details && typeof b.details === 'object' ? b.details : null;
    },
    fieldErrors() {
      const code = this.backendCode;
      const details = this.backendDetails;
      const out = {};
      if (!code || !details) return out;

      if (code === 'missing_required_attribute' && Array.isArray(details.missing)) {
        for (const k of details.missing) out[String(k)] = 'Required field is missing.';
      }
      if (code === 'invalid_attribute_value' && details.invalid_values && typeof details.invalid_values === 'object') {
        for (const [k] of Object.entries(details.invalid_values)) out[String(k)] = 'Invalid value for this field.';
      }
      if (code === 'unknown_attribute_keys' && Array.isArray(details.unknown_keys)) {
        for (const k of details.unknown_keys) out[String(k)] = 'Unknown attribute key for this category.';
      }
      return out;
    },
  },
  watch: {
    'local.category_id'(val) {
      this.local.attributes = {};
      this.$emit('category-change', val);
    },
    filterSchema: {
      deep: true,
      handler() {
        this.local.attributes = {};
      },
    },
  },
  methods: {
    emitCategoryChange() {
      this.$emit('category-change', this.local.category_id);
    },
    isSelectField(filter) {
      if (!filter || typeof filter !== 'object') return false;
      const rules = filter.rules && typeof filter.rules === 'object' ? filter.rules : null;
      if (rules && Array.isArray(rules.options) && rules.options.length) return true;
      if (filter.value_type === 'enum') return true;
      if (filter.ui_component === 'select') return true;
      return false;
    },
    getOptions(filter) {
      const rules = filter && filter.rules && typeof filter.rules === 'object' ? filter.rules : null;
      const opts = rules && Array.isArray(rules.options) ? rules.options : [];
      return opts.map((o) => (o == null ? '' : String(o))).filter((s) => s !== '');
    },
    fieldError(key) {
      return this.fieldErrors[String(key)] || null;
    },
    onSubmit() {
      const normalizedAttributes = {};
      for (const [k, v] of Object.entries(this.local.attributes || {})) {
        if (v === null || v === undefined) continue;
        if (typeof v === 'string' && v.trim() === '') continue;
        normalizedAttributes[k] = v;
      }

      const snapshot = {
        category_id: this.local.category_id,
        title: (this.local.title || '').trim(),
        description: this.local.description || '',
        transaction_modes: Array.isArray(this.local.transaction_modes) ? [...this.local.transaction_modes] : [],
        attributes: normalizedAttributes,
      };

      this.$emit('submit', snapshot);
    },
  },
};
</script>

<style scoped>
.listing-form {
  margin-top: 2rem;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.required {
  color: #d32f2f;
}

.form-input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
}

.form-checkbox {
  width: auto;
  margin-right: 0.5rem;
}

.checkbox-group {
  display: flex;
  gap: 1rem;
  margin-top: 0.5rem;
}

.checkbox-group label {
  display: flex;
  align-items: center;
  font-weight: normal;
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

.type-badge {
  display: inline-block;
  background: #e3f2fd;
  color: #1976d2;
  font-size: 0.75rem;
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
  margin-left: 0.5rem;
}

.attribute-field {
  margin-bottom: 1rem;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
}

.attribute-field.has-error {
  border-left: 3px solid #d32f2f;
}

.field-error {
  display: block;
  color: #d32f2f;
  font-size: 0.85rem;
  margin-top: 0.25rem;
}

.field-hint {
  display: block;
  color: #666;
  font-size: 0.85rem;
  margin-top: 0.25rem;
}

.submit-button {
  background: #0066cc;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
  margin-top: 1rem;
}

.submit-button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.submit-button:hover:not(:disabled) {
  background: #0052a3;
}

.tenant-id-display {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.tenant-id-missing {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.tenant-picker-link {
  color: #0066cc;
  text-decoration: underline;
  font-weight: 500;
}

.auto-filled {
  background-color: #f5f5f5 !important;
  cursor: not-allowed;
}

.auto-fill-note {
  color: #666;
  display: block;
  margin-top: 0.25rem;
  font-size: 0.875rem;
}

.tenant-id-warning {
  color: #f57c00;
  display: block;
  margin-top: 0.5rem;
  font-size: 0.875rem;
  background: #fff3e0;
  padding: 0.5rem;
  border-radius: 4px;
  border-left: 3px solid #ff9800;
}
</style>
