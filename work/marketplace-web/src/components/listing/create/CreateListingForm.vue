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
          <option value="">Select category...</option>
          <option v-for="cat in categories" :key="cat.id" :value="cat.id">
            {{ cat.slug }} ({{ cat.id }})
          </option>
        </select>
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
      >
        <label>
          {{ filter.attribute_key }}
          <span v-if="filter.required" class="required-badge">required</span>
          <span v-if="filter.value_type" class="type-badge">{{ filter.value_type }}</span>
        </label>
        <input
          v-if="filter.value_type === 'string'"
          v-model="local.attributes[filter.attribute_key]"
          type="text"
          :placeholder="filter.attribute_key"
          class="form-input"
        />
        <input
          v-else-if="filter.value_type === 'boolean'"
          v-model="local.attributes[filter.attribute_key]"
          type="checkbox"
          class="form-checkbox"
        />
        <input
          v-else-if="filter.value_type === 'number'"
          v-model.number="local.attributes[filter.attribute_key]"
          type="number"
          :placeholder="filter.attribute_key"
          class="form-input"
        />
      </div>
    </div>

    <button type="submit" :disabled="loading || !tenantId" class="submit-button">
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
  methods: {
    emitCategoryChange() {
      this.$emit('category-change', this.local.category_id);
    },
    onSubmit() {
      const snapshot = {
        category_id: this.local.category_id,
        title: this.local.title,
        description: this.local.description,
        transaction_modes: [...(this.local.transaction_modes || [])],
        attributes: { ...(this.local.attributes || {}) },
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
