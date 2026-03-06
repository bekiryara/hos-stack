<template>
  <div class="edit-listing-page">
    <h2>Ilan Duzenle</h2>

    <div v-if="loading" class="state-box">Ilan yukleniyor...</div>
    <div v-else-if="error" class="state-box state-error">{{ error }}</div>

    <div v-else-if="ready">
      <div class="meta-box">
        <div><strong>ID:</strong> {{ id }}</div>
        <div><strong>Category:</strong> {{ categoryLabelText }}</div>
        <div><strong>Mode:</strong> {{ currentTransactionMode }}</div>
      </div>

      <CreateListingForm
        :mode="'edit'"
        :categories-tree="categoriesTree"
        :filter-schema="filterSchema"
        :intent-schema="intentSchema"
        :city-options="cityOptions"
        :district-options="districtOptions"
        :neighborhood-options="neighborhoodOptions"
        :tenant-address="tenantAddress"
        :tenant-id="tenantId"
        :tenant-id-load-error="false"
        :loading="saving"
        :category-label-text="categoryLabelText"
        :initial-value="initialValue"
        :submit-visible-only="false"
        :submit-button-text="'Kaydet'"
        :submit-loading-text="'Kaydediliyor...'"
        :show-tenant-section="false"
        :secondary-action-to="`/listing/${id}`"
        :secondary-action-label="'Ilana Don'"
        @location-city-change="onLocationCityChange"
        @location-district-change="onLocationDistrictChange"
        @submit="onFormSubmit"
      />

      <div v-if="saveError" class="state-box state-error">{{ saveError }}</div>
      <div v-if="saveSuccess" class="state-box state-success">Ilan guncellendi.</div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';
import CreateListingForm from '../components/listing/create/CreateListingForm.vue';
import {
  getCategoriesTree,
  getFilterSchemaForCategory,
  getIntentSchemaForCategory,
  getCityOptions,
  getDistrictOptions,
  getNeighborhoodOptions,
} from '../lib/catalogSpine';
import { categoryLabel, findCategoryByCanonicalId } from '../lib/categoryTree';
import { normalizeApiError } from '../lib/errors/api_error.js';
import { notifyApiError, notifyApiSuccess } from '../lib/toast/notify_api.js';
import { getActiveTenantId } from '../lib/session.js';
import { isLegacyPriceAttributeKey } from '../lib/pricing.js';

const POLICY_KEYS = new Set([
  'offer_variant',
  'interaction_mode',
  'gender_context',
  'fulfillment_mode',
  'location_scope',
  'service_time_model',
  'offer_requirement',
  'pricing_strategy',
  'billing_model',
]);

export default {
  name: 'EditListingPage',
  components: { CreateListingForm },
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
      categoriesTree: [],
      filterSchema: null,
      intentSchema: null,
      categoryLabelText: '-',
      cityOptions: [],
      districtOptions: [],
      neighborhoodOptions: [],
      tenantId: '',
      tenantAddress: null,
      initialValue: null,
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
        if (filter?.attribute_key && !isLegacyPriceAttributeKey(filter.attribute_key)) {
          keys.add(String(filter.attribute_key));
        }
      });
      POLICY_KEYS.forEach((key) => keys.add(key));
      return keys;
    },
  },
  async mounted() {
    await this.load();
  },
  methods: {
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
    async loadTenantAddress() {
      if (!this.tenantId) {
        this.tenantAddress = null;
        return;
      }
      try {
        const resp = await api.hosGetTenantAddress(this.tenantId);
        this.tenantAddress = resp?.address || null;
      } catch {
        this.tenantAddress = null;
      }
    },
    async load() {
      this.loading = true;
      this.error = null;
      this.saveError = null;
      this.saveSuccess = false;
      try {
        const listing = await api.getListing(this.id);
        const [categoriesTree, filterSchema, intentSchema, cityOptions] = await Promise.all([
          getCategoriesTree(),
          getFilterSchemaForCategory(listing.category_id),
          getIntentSchemaForCategory(listing.category_id),
          getCityOptions().catch(() => []),
        ]);

        this.listing = listing;
        this.categoriesTree = Array.isArray(categoriesTree) ? categoriesTree : [];
        this.filterSchema = filterSchema;
        this.intentSchema = intentSchema;
        this.cityOptions = Array.isArray(cityOptions) ? cityOptions : [];

        const found = findCategoryByCanonicalId(this.categoriesTree, listing.category_id);
        this.categoryLabelText = found ? (categoryLabel(found) || String(found.id)) : String(listing.category_id);

        this.tenantId = getActiveTenantId() || String(listing.tenant_id || '');
        await this.loadTenantAddress();

        const city = String(listing?.location?.city || '').trim();
        const district = String(listing?.location?.district || '').trim();
        if (city) {
          try {
            this.districtOptions = await getDistrictOptions(city);
          } catch {
            this.districtOptions = [];
          }
        } else {
          this.districtOptions = [];
        }
        if (city && district) {
          try {
            this.neighborhoodOptions = await getNeighborhoodOptions(city, district);
          } catch {
            this.neighborhoodOptions = [];
          }
        } else {
          this.neighborhoodOptions = [];
        }

        this.initialValue = {
          category_id: listing.category_id,
          title: listing.title || '',
          description: listing.description || '',
          price_amount: Number.isFinite(Number(listing.price_amount)) ? Number(listing.price_amount) : null,
          currency: listing.currency || 'TRY',
          transaction_modes: Array.isArray(listing.transaction_modes) ? listing.transaction_modes : [],
          attributes: this.sanitizeAttributes(listing.attributes),
          location: listing.location || null,
        };

        this.ready = true;
      } catch (err) {
        this.error = err?.message || 'Listing yuklenemedi';
      } finally {
        this.loading = false;
      }
    },
    async onLocationCityChange(city) {
      this.neighborhoodOptions = [];
      const c = String(city || '').trim();
      if (!c) {
        this.districtOptions = [];
        return;
      }
      try {
        this.districtOptions = await getDistrictOptions(c);
      } catch {
        this.districtOptions = [];
      }
    },
    async onLocationDistrictChange(payload) {
      const city = String(payload?.city || '').trim();
      const district = String(payload?.district || '').trim();
      if (!city || !district) {
        this.neighborhoodOptions = [];
        return;
      }
      try {
        this.neighborhoodOptions = await getNeighborhoodOptions(city, district);
      } catch {
        this.neighborhoodOptions = [];
      }
    },
    async onFormSubmit(formSnapshot) {
      this.saving = true;
      this.saveError = null;
      this.saveSuccess = false;
      try {
        const payload = {
          title: formSnapshot.title,
          description: formSnapshot.description || null,
          price_amount: Number.isFinite(Number(formSnapshot.price_amount))
            ? Math.round(Number(formSnapshot.price_amount))
            : null,
          currency: (formSnapshot.currency || 'TRY').trim().toUpperCase(),
          attributes: this.sanitizeAttributes(formSnapshot.attributes),
          location: formSnapshot.location || null,
        };
        await api.updateListing(this.id, payload, this.tenantId || null);
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
  max-width: 900px;
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

</style>
