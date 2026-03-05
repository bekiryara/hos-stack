<template>
  <div class="create-listing-page">
    <h2>Create Listing (DRAFT)</h2>

    <ActionResultBox
      :loading="loading"
      :error="submitErrorMsg"
      :on-retry="clearSubmitError"
    />

    <CreateListingSuccessBox
      v-if="success"
      :success="success"
      :publishing="publishing"
      :publish-error="publishError"
      @copy-id="copyListingId"
      @publish="handlePublish"
      @go-search="goToCategorySearch"
    />

    <CreateListingForm
      v-else
      :categories-tree="categoriesTree"
      :filter-schema="filterSchema"
      :intent-schema="intentSchema"
      :city-options="cityOptions"
      :district-options="districtOptions"
      :neighborhood-options="neighborhoodOptions"
      :tenant-address="tenantAddress"
      :tenant-id="tenantId"
      :tenant-id-load-error="tenantIdLoadError"
      :loading="loading"
      @category-change="onCategoryChange"
      @location-city-change="onLocationCityChange"
      @location-district-change="onLocationDistrictChange"
      @submit="onFormSubmit"
    />
  </div>
</template>

<script>
import { api } from '../api/client';
import { getCategoriesTree, getFilterSchemaForCategory, getIntentSchemaForCategory, getCityOptions, getDistrictOptions, getNeighborhoodOptions } from '../lib/catalogSpine';
import { isLoggedIn, getActiveTenantId, setActiveTenantId } from '../lib/session.js';
import { normalizeApiError } from '../lib/errors/api_error.js';
import { notifyApiSuccess, notifyApiError } from '../lib/toast/notify_api.js';
import ActionResultBox from '../components/common/ActionResultBox.vue';
import CreateListingForm from '../components/listing/create/CreateListingForm.vue';
import CreateListingSuccessBox from '../components/listing/create/CreateListingSuccessBox.vue';

export default {
  name: 'CreateListingPage',
  components: {
    ActionResultBox,
    CreateListingForm,
    CreateListingSuccessBox,
  },
  computed: {
    submitErrorMsg() {
      if (!this.error) return null;
      return typeof this.error === 'string' ? this.error : (this.error.message || null);
    },
  },
  data() {
    return {
      categoriesTree: [],
      filterSchema: null,
      intentSchema: null,
      tenantId: '',
      tenantIdLoadError: false,
      cityOptions: [],
      districtOptions: [],
      neighborhoodOptions: [],
      tenantAddress: null,
      loading: false,
      error: null,
      success: null,
      publishing: false,
      publishError: null,
    };
  },
  async mounted() {
    try {
      const [categoriesTree, cityOptions] = await Promise.all([
        getCategoriesTree(),
        getCityOptions().catch(() => []),
      ]);
      this.categoriesTree = categoriesTree;
      this.cityOptions = Array.isArray(cityOptions) ? cityOptions : [];

      if (!this.tenantId) {
        const activeTenantId = getActiveTenantId();
        if (activeTenantId) {
          this.tenantId = activeTenantId;
          await this.loadTenantAddress();
        } else {
          if (isLoggedIn()) {
            try {
              const memberships = await api.getMyMemberships();
              const items = memberships.items || memberships.data || (Array.isArray(memberships) ? memberships : []);
              if (items.length > 0) {
                const adminMembership = items.find(m => m.role === 'admin' || m.role === 'owner');
                const selectedMembership = adminMembership || items[0];
                const tid = selectedMembership.tenant_id || selectedMembership.tenant?.id;
                if (tid) {
                  setActiveTenantId(tid);
                  this.tenantId = tid;
                  await this.loadTenantAddress();
                } else {
                  this.tenantIdLoadError = true;
                }
              } else {
                this.tenantIdLoadError = true;
              }
            } catch (err) {
              console.warn('Could not fetch memberships for tenant ID:', err);
              this.tenantIdLoadError = true;
            }
          } else {
            this.tenantIdLoadError = true;
          }
        }
      } else {
        await this.loadTenantAddress();
      }
    } catch (err) {
      this.error = err;
    }
  },
  methods: {
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
    async onCategoryChange(categoryId) {
      if (!categoryId) {
        this.filterSchema = null;
        this.intentSchema = null;
        this.districtOptions = [];
        this.neighborhoodOptions = [];
        return;
      }
      try {
        const [filterSchema, intentSchema] = await Promise.all([
          getFilterSchemaForCategory(categoryId),
          getIntentSchemaForCategory(categoryId),
        ]);
        this.filterSchema = filterSchema;
        this.intentSchema = intentSchema;
      } catch (err) {
        console.error('Failed to load filter schema:', err);
        this.filterSchema = null;
        this.intentSchema = null;
        this.districtOptions = [];
        this.neighborhoodOptions = [];
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
    clearSubmitError() {
      this.error = null;
    },
    onFormSubmit(formSnapshot) {
      if (!this.tenantId || !formSnapshot.category_id || !formSnapshot.title || (formSnapshot.transaction_modes || []).length === 0) {
        this.error = { message: 'Please fill all required fields', status: 400 };
        return;
      }

      this.loading = true;
      this.error = null;

      const attributes = {};
      Object.keys(formSnapshot.attributes || {}).forEach((key) => {
        const value = formSnapshot.attributes[key];
        if (value !== null && value !== undefined && value !== '') {
          attributes[key] = value;
        }
      });

      const payload = {
        category_id: formSnapshot.category_id,
        title: formSnapshot.title,
        description: formSnapshot.description || null,
        price_amount: Number.isFinite(Number(formSnapshot.price_amount))
          ? Math.round(Number(formSnapshot.price_amount))
          : null,
        currency: (typeof formSnapshot.currency === 'string' && formSnapshot.currency.trim()) ? formSnapshot.currency.trim().toUpperCase() : 'TRY',
        transaction_modes: formSnapshot.transaction_modes || [],
        attributes: Object.keys(attributes).length > 0 ? attributes : null,
        location: formSnapshot.location || null,
      };

      const activeTenantId = this.tenantId || getActiveTenantId();
      if (!activeTenantId) {
        this.error = {
          message: 'Firma hesabı gerekli. Lütfen aktif bir firma seçin veya firma kaydı yapın.',
          status: 400,
        };
        this.loading = false;
        return;
      }

      api
        .createListing(payload, activeTenantId || null)
        .then((result) => {
          this.success = result;
          notifyApiSuccess('Listing created');
        })
        .catch((err) => {
          const normalized = normalizeApiError(err);
          this.error = { status: normalized.status, errorCode: normalized.code, message: normalized.message };
          notifyApiError(err, 'Create listing');
        })
        .finally(() => {
          this.loading = false;
        });
    },
    copyListingId(id) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(id).then(() => {
          alert('Listing ID copied to clipboard!');
        }).catch(err => {
          console.error('Failed to copy:', err);
        });
      } else {
        const textArea = document.createElement('textarea');
        textArea.value = id;
        document.body.appendChild(textArea);
        textArea.select();
        try {
          document.execCommand('copy');
          alert('Listing ID copied to clipboard!');
        } catch (err) {
          console.error('Fallback copy failed:', err);
        }
        document.body.removeChild(textArea);
      }
    },
    goToCategorySearch(categoryId) {
      this.$router.push(`/search/${categoryId}`);
    },
    async handlePublish() {
      if (!this.success || !this.success.id) {
        this.publishError = { message: 'No listing to publish' };
        return;
      }

      this.publishing = true;
      this.publishError = null;

      const tenantId = this.tenantId || getActiveTenantId();
      if (!tenantId) {
        this.publishError = { message: 'Tenant ID required. Please set active tenant.' };
        this.publishing = false;
        return;
      }

      try {
        await api.publishListing(this.success.id, tenantId);
        this.success = { ...this.success, status: 'published' };
      } catch (err) {
        this.publishError = err;
      } finally {
        this.publishing = false;
      }
    },
  },
};
</script>

<style scoped>
.create-listing-page {
  max-width: 800px;
}
</style>
