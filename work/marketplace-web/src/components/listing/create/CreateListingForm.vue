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
      <label class="category-label">
        Kategori <span class="required">*</span>
      </label>
      <CategoryPickerStepper
        v-model="local.category_id"
        :categories-tree="categoriesTree"
        mode="create"
        @category-change="emitCategoryChange"
        @gender-context="onGenderContext"
      />
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
      <label class="price-label">
        Fiyat
      </label>
      <div class="price-row">
        <input
          v-model.number="local.price_amount"
          type="number"
          min="0"
          step="1"
          placeholder="Fiyat"
          class="form-input"
        />
        <select v-model="local.currency" class="form-input price-currency">
          <option value="TRY">TRY</option>
          <option value="USD">USD</option>
          <option value="EUR">EUR</option>
        </select>
      </div>
      <small class="hint">
        Canonical fiyat alani. Eski attribute fiyatlari gecis icin ayrica kalabilir.
      </small>
    </div>

    <div class="form-group">
      <label>
        İlan Türü <span class="required">*</span>
        <select
          v-model="local.offer_variant"
          class="form-input"
          required
          :disabled="!intentSchema || !intentSchema.offer_variants || intentSchema.offer_variants.length === 0"
          @change="onOfferVariantChange"
        >
          <option value="" disabled>Seçiniz...</option>
          <option
            v-for="v in (intentSchema && intentSchema.offer_variants ? intentSchema.offer_variants : [])"
            :key="v.key"
            :value="v.key"
          >
            {{ v.label || v.key }}
          </option>
        </select>
        <small v-if="selectedOfferVariant" class="hint">
          <strong>Mode:</strong> {{ selectedOfferVariant.transaction_mode }}
          <span class="dot">•</span>
          <strong>Workflow:</strong> {{ selectedOfferVariant.interaction_mode }}
        </small>
      </label>
    </div>

    <div v-if="filterSchema && filterSchema.filters" class="form-group">
      <h3>Attributes (from filter-schema)</h3>
      <small v-if="hiddenFiltersCount > 0" class="hint">
        Bu ilan türünde geçerli olmayan {{ hiddenFiltersCount }} alan gizlendi. Değerleriniz silinmedi.
      </small>
      <div
        v-for="filter in visibleFilters"
        :key="filter.attribute_key"
        class="attribute-field"
      >
        <FilterField
          :filter="filter"
          mode="create"
          v-model="local.attributes[filter.attribute_key]"
        />
      </div>
    </div>

    <button type="submit" :disabled="loading || !tenantId" class="submit-button">
      {{ loading ? 'Creating...' : 'Create Listing (DRAFT)' }}
    </button>
  </form>
</template>

<script>
import CategoryPickerStepper from '../../catalog/CategoryPickerStepper.vue';
import FilterField from '../../common/FilterField.vue';

export default {
  name: 'CreateListingForm',
  components: {
    CategoryPickerStepper,
    FilterField,
  },
  props: {
    categoriesTree: { type: Array, default: () => [] },
    filterSchema: { type: Object, default: null },
    intentSchema: { type: Object, default: null },
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
        price_amount: null,
        currency: 'TRY',
        transaction_modes: [],
        offer_variant: '',
        attributes: {},
      },
    };
  },
  computed: {
    selectedOfferVariant() {
      const schema = this.intentSchema;
      const key = this.local.offer_variant || '';
      const list = schema && Array.isArray(schema.offer_variants) ? schema.offer_variants : [];
      return list.find((v) => v && v.key === key) || null;
    },
    currentTransactionMode() {
      const v = this.selectedOfferVariant;
      if (v && v.transaction_mode) return String(v.transaction_mode);
      const modes = Array.isArray(this.local.transaction_modes) ? this.local.transaction_modes : [];
      if (modes.length > 0 && modes[0]) return String(modes[0]);
      return 'sale';
    },
    visibleFilters() {
      const schema = this.filterSchema;
      const list = schema && Array.isArray(schema.filters) ? schema.filters : [];
      return list.filter((f) => this.isApplicableForMode(f, this.currentTransactionMode));
    },
    hiddenFiltersCount() {
      const schema = this.filterSchema;
      const list = schema && Array.isArray(schema.filters) ? schema.filters : [];
      return list.length - this.visibleFilters.length;
    },
  },
  watch: {
    intentSchema: {
      handler(newSchema) {
        const list = newSchema && Array.isArray(newSchema.offer_variants) ? newSchema.offer_variants : [];
        if (list.length === 0) return;
        if (this.local.offer_variant) return;
        const defKey = (newSchema && newSchema.default_offer_variant) ? String(newSchema.default_offer_variant) : '';
        const fallback = defKey && list.find((v) => v && v.key === defKey) ? defKey : String(list[0].key);
        this.local.offer_variant = fallback;
        this.applyOfferVariant();
      },
      immediate: true,
    },
  },
  methods: {
    // Faz-2: schema-driven applicability (hardcode yok).
    // Semantics: applies_to_transaction_modes is null/empty => applies to all modes.
    isApplicableForMode(filter, mode) {
      const m = mode ? String(mode) : '';
      if (!m) return true;
      const raw = filter && filter.applies_to_transaction_modes;
      if (!raw) return true;
      if (!Array.isArray(raw)) return true;
      if (raw.length === 0) return true;
      return raw.map(String).includes(m);
    },
    emitCategoryChange() {
      this.local.offer_variant = '';
      this.local.transaction_modes = [];
      if (this.local.attributes) {
        delete this.local.attributes.offer_variant;
        delete this.local.attributes.interaction_mode;
      }
      this.$emit('category-change', this.local.category_id);
    },
    onGenderContext(gender) {
      this.local.attributes = this.local.attributes || {};
      if (gender) {
        this.local.attributes.gender_context = gender;
      } else {
        delete this.local.attributes.gender_context;
      }
    },
    onOfferVariantChange() {
      this.applyOfferVariant();
    },
    applyOfferVariant() {
      const v = this.selectedOfferVariant;
      if (!v) return;
      const mode = v.transaction_mode || 'sale';
      this.local.transaction_modes = [mode];
      this.local.attributes = this.local.attributes || {};
      this.local.attributes.offer_variant = v.key;
      this.local.attributes.interaction_mode = (v.interaction_mode === 'flow') ? 'flow' : 'contact_only';
    },
    onSubmit() {
      const visibleKeys = new Set((this.visibleFilters || []).map((f) => String(f.attribute_key)));
      visibleKeys.add('offer_variant');
      visibleKeys.add('interaction_mode');
      visibleKeys.add('gender_context');

      const rawAttrs = this.local.attributes && typeof this.local.attributes === 'object' ? this.local.attributes : {};
      const filteredAttrs = {};
      Object.keys(rawAttrs).forEach((k) => {
        if (visibleKeys.has(String(k))) {
          filteredAttrs[k] = rawAttrs[k];
        }
      });

      const snapshot = {
        category_id: this.local.category_id,
        title: this.local.title,
        description: this.local.description,
        price_amount: this.local.price_amount,
        currency: this.local.currency || 'TRY',
        transaction_modes: [...(this.local.transaction_modes || [])],
        // Submit only visible attrs (do not delete hidden values from local state).
        attributes: filteredAttrs,
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

.hint {
  display: block;
  margin-top: 0.35rem;
  color: #666;
  font-size: 0.875rem;
}

.price-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 140px;
  gap: 0.75rem;
}

.price-currency {
  min-width: 0;
}

.dot {
  margin: 0 0.35rem;
  color: #999;
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

.category-label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}
</style>
