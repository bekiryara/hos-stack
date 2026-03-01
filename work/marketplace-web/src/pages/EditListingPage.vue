<template>
  <div class="edit-listing-page">
    <h2>Listing Edit v1</h2>

    <div v-if="loading" class="state-box">Loading listing...</div>
    <div v-else-if="error" class="state-box state-error">{{ error }}</div>
    <form v-else-if="ready" class="edit-form" @submit.prevent="submit">
      <div class="meta-box">
        <div><strong>ID:</strong> {{ id }}</div>
        <div><strong>Category:</strong> {{ categoryLabelText }}</div>
        <div><strong>Mode:</strong> {{ currentTransactionMode }}</div>
      </div>

      <div class="form-group">
        <label>
          Title
          <input v-model="form.title" type="text" maxlength="120" required class="form-input" />
        </label>
      </div>

      <div class="form-group">
        <label>
          Description
          <textarea v-model="form.description" rows="4" class="form-input" />
        </label>
      </div>

      <div class="form-group">
        <label>Fiyat</label>
        <div class="price-row">
          <input v-model.number="form.price_amount" type="number" min="0" step="1" class="form-input" />
          <select v-model="form.currency" class="form-input price-currency">
            <option value="TRY">TRY</option>
            <option value="USD">USD</option>
            <option value="EUR">EUR</option>
          </select>
        </div>
      </div>

      <div v-if="visibleFilters.length" class="form-group">
        <h3>Attributes</h3>
        <small v-if="hiddenFiltersCount > 0" class="hint">
          Geçerli mode dışında kalan {{ hiddenFiltersCount }} alan gizli tutuldu; görünmeyen schema alanları korunur.
        </small>
        <div
          v-for="filter in visibleFilters"
          :key="filter.attribute_key"
          class="attribute-field"
        >
          <FilterField
            :filter="filter"
            mode="edit"
            v-model="form.attributes[filter.attribute_key]"
          />
        </div>
      </div>

      <div class="actions">
        <button type="submit" class="btn-primary" :disabled="saving">
          {{ saving ? 'Saving...' : 'Kaydet' }}
        </button>
        <router-link :to="`/listing/${id}`" class="btn-secondary">Ilana Don</router-link>
      </div>

      <div v-if="saveError" class="state-box state-error">{{ saveError }}</div>
      <div v-if="saveSuccess" class="state-box state-success">Listing updated.</div>
    </form>
  </div>
</template>

<script>
import { api } from '../api/client';
import FilterField from '../components/common/FilterField.vue';
import { getCategoriesTree, getFilterSchemaForCategory } from '../lib/catalogSpine';
import { categoryLabel, findCategoryById } from '../lib/categoryTree';
import { normalizeApiError } from '../lib/errors/api_error.js';
import { notifyApiError, notifyApiSuccess } from '../lib/toast/notify_api.js';
import { getActiveTenantId } from '../lib/session.js';
import { isLegacyPriceAttributeKey } from '../lib/pricing.js';

const POLICY_KEYS = new Set(['offer_variant', 'interaction_mode', 'gender_context']);

export default {
  name: 'EditListingPage',
  components: { FilterField },
  props: {
    id: { type: String, required: true },
  },
  data() {
    return {
      loading: true,
      saving: false,
      ready: false,
      error: null,
      saveError: null,
      saveSuccess: false,
      listing: null,
      filterSchema: null,
      categoryLabelText: null,
      form: {
        title: '',
        description: '',
        price_amount: null,
        currency: 'TRY',
        attributes: {},
      },
    };
  },
  computed: {
    currentTransactionMode() {
      const modes = Array.isArray(this.listing?.transaction_modes) ? this.listing.transaction_modes : [];
      return modes[0] || 'sale';
    },
    allowedAttributeKeys() {
      const keys = new Set();
      const filters = Array.isArray(this.filterSchema?.filters) ? this.filterSchema.filters : [];
      filters.forEach((filter) => {
        if (filter?.attribute_key && !isLegacyPriceAttributeKey(filter.attribute_key)) keys.add(String(filter.attribute_key));
      });
      POLICY_KEYS.forEach((key) => keys.add(key));
      return keys;
    },
    visibleFilters() {
      const filters = Array.isArray(this.filterSchema?.filters) ? this.filterSchema.filters : [];
      return filters.filter((filter) => this.isApplicableForMode(filter, this.currentTransactionMode) && !isLegacyPriceAttributeKey(filter?.attribute_key));
    },
    hiddenFiltersCount() {
      const filters = Array.isArray(this.filterSchema?.filters) ? this.filterSchema.filters : [];
      return Math.max(0, filters.length - this.visibleFilters.length);
    },
  },
  async mounted() {
    await this.load();
  },
  methods: {
    isApplicableForMode(filter, mode) {
      const raw = filter?.applies_to_transaction_modes;
      if (!raw || !Array.isArray(raw) || raw.length === 0) return true;
      return raw.map(String).includes(String(mode || ''));
    },
    sanitizeAttributes(source) {
      const attrs = source && typeof source === 'object' ? source : {};
      const sanitized = {};
      Object.keys(attrs).forEach((key) => {
        if (this.allowedAttributeKeys.has(String(key))) {
          sanitized[key] = attrs[key];
        }
      });
      return sanitized;
    },
    async load() {
      this.loading = true;
      this.error = null;
      try {
        const listing = await api.getListing(this.id);
        const [filterSchema, categoriesTree] = await Promise.all([
          getFilterSchemaForCategory(listing.category_id),
          getCategoriesTree(),
        ]);

        this.listing = listing;
        this.filterSchema = filterSchema;
        this.form.title = listing.title || '';
        this.form.description = listing.description || '';
        this.form.price_amount = Number.isFinite(Number(listing.price)) ? Math.round(Number(listing.price)) : null;
        this.form.currency = listing.price_currency || 'TRY';
        this.form.attributes = this.sanitizeAttributes(listing.attributes);

        const found = findCategoryById(Array.isArray(categoriesTree) ? categoriesTree : [], listing.category_id);
        this.categoryLabelText = found ? (categoryLabel(found) || String(found.id)) : String(listing.category_id);
        this.ready = true;
      } catch (err) {
        this.error = err?.message || 'Listing yuklenemedi';
      } finally {
        this.loading = false;
      }
    },
    async submit() {
      this.saving = true;
      this.saveError = null;
      this.saveSuccess = false;
      try {
        const tenantId = getActiveTenantId();
        const payload = {
          title: this.form.title,
          description: this.form.description || null,
          price_amount: Number.isFinite(Number(this.form.price_amount)) ? Math.round(Number(this.form.price_amount)) : null,
          currency: (this.form.currency || 'TRY').trim().toUpperCase(),
          attributes: this.sanitizeAttributes(this.form.attributes),
        };
        await api.updateListing(this.id, payload, tenantId);
        this.saveSuccess = true;
        notifyApiSuccess('Listing updated');
        await this.load();
      } catch (err) {
        const normalized = normalizeApiError(err);
        this.saveError = normalized.message || 'Listing guncellenemedi';
        notifyApiError(err, 'Update listing');
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<style scoped>
.edit-listing-page {
  max-width: 860px;
}

.meta-box,
.state-box {
  margin-bottom: 1rem;
  padding: 0.9rem 1rem;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #f8fafc;
}

.state-error {
  border-color: #fca5a5;
  background: #fef2f2;
  color: #991b1b;
}

.state-success {
  border-color: #86efac;
  background: #f0fdf4;
  color: #166534;
}

.form-group {
  margin-bottom: 1.25rem;
}

.form-input {
  width: 100%;
  padding: 0.55rem 0.7rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 1rem;
}

.price-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 140px;
  gap: 0.75rem;
}

.hint {
  display: block;
  margin-top: 0.35rem;
  color: #666;
  font-size: 0.875rem;
}

.attribute-field {
  margin-bottom: 1rem;
  padding: 1rem;
  background: #f9fafb;
  border-radius: 6px;
  border: 1px solid #e5e7eb;
}

.actions {
  display: flex;
  gap: 0.75rem;
  align-items: center;
}

.btn-primary,
.btn-secondary {
  display: inline-block;
  padding: 0.6rem 1rem;
  border-radius: 6px;
  text-decoration: none;
  border: none;
  cursor: pointer;
  font-size: 0.95rem;
}

.btn-primary {
  background: #2563eb;
  color: #fff;
}

.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-secondary {
  background: #e5e7eb;
  color: #111827;
}
</style>
