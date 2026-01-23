<template>
  <div class="create-listing-page">
    <h2>Create Listing (DRAFT)</h2>
    
    <div v-if="error" class="error">
      <strong>Error ({{ error.status }}):</strong> {{ error.errorCode || 'unknown' }}
      <br />
      {{ error.message }}
    </div>
    
    <div v-if="success" class="success">
      <strong>Success!</strong> Listing created with ID: {{ success.id }}
      <br />
      Status: {{ success.status }}
      <br />
      <router-link :to="`/listing/${success.id}`">View Listing</router-link>
    </div>
    
    <form v-if="!success" @submit.prevent="handleSubmit" class="listing-form">
      <div class="form-group">
        <label>
          Tenant ID (UUID) <span class="required">*</span>
          <input
            v-model="formData.tenantId"
            type="text"
            required
            placeholder="e.g., 951ba4eb-9062-40c4-9228-f8d2cfc2f426"
            class="form-input"
            :readonly="!!formData.tenantId"
            :class="{ 'auto-filled': !!formData.tenantId }"
          />
          <small v-if="formData.tenantId" class="auto-fill-note">
            Auto-filled from active membership (WP-51)
          </small>
          <small v-else-if="tenantIdLoadError" class="tenant-id-warning">
            <strong>Note:</strong> Could not auto-load tenant ID. Please enter it manually.
            <br />
            To get your tenant ID, run: <code>.\ops\demo_seed_root_listings.ps1</code> and check the output.
          </small>
        </label>
      </div>
      
      <div class="form-group">
        <label>
          Category <span class="required">*</span>
          <select v-model.number="formData.category_id" required class="form-input">
            <option value="">Select category...</option>
            <option v-for="cat in categories" :key="cat.id" :value="cat.id">
              {{ cat.name }} ({{ cat.slug }})
            </option>
          </select>
        </label>
      </div>
      
      <div class="form-group">
        <label>
          Title <span class="required">*</span>
          <input
            v-model="formData.title"
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
            v-model="formData.description"
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
              <input
                v-model="formData.transaction_modes"
                type="checkbox"
                value="sale"
              />
              Sale
            </label>
            <label>
              <input
                v-model="formData.transaction_modes"
                type="checkbox"
                value="rental"
              />
              Rental
            </label>
            <label>
              <input
                v-model="formData.transaction_modes"
                type="checkbox"
                value="reservation"
              />
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
          <div v-if="filter.filter_mode === 'range' && filter.value_type === 'number'">
            <input
              v-model.number="formData.attributes[filter.attribute_key + '_min']"
              type="number"
              :placeholder="`Min ${filter.attribute_key}`"
              class="form-input"
            />
            <input
              v-model.number="formData.attributes[filter.attribute_key + '_max']"
              type="number"
              :placeholder="`Max ${filter.attribute_key}`"
              class="form-input"
            />
          </div>
          <input
            v-else-if="filter.value_type === 'string'"
            v-model="formData.attributes[filter.attribute_key]"
            type="text"
            :placeholder="filter.attribute_key"
            class="form-input"
          />
          <input
            v-else-if="filter.value_type === 'boolean'"
            v-model="formData.attributes[filter.attribute_key]"
            type="checkbox"
            class="form-checkbox"
          />
          <input
            v-else-if="filter.value_type === 'number'"
            v-model.number="formData.attributes[filter.attribute_key]"
            type="number"
            :placeholder="filter.attribute_key"
            class="form-input"
          />
        </div>
      </div>
      
      <button type="submit" :disabled="loading" class="submit-button">
        {{ loading ? 'Creating...' : 'Create Listing (DRAFT)' }}
      </button>
    </form>
  </div>
</template>

<script>
import { api } from '../api/client';

export default {
  name: 'CreateListingPage',
  data() {
    return {
      categories: [],
      filterSchema: null,
      formData: {
        tenantId: '',
        category_id: '',
        title: '',
        description: '',
        transaction_modes: [],
        attributes: {},
      },
      loading: false,
      error: null,
      success: null,
      tenantIdLoadError: false, // WP-51: Track if tenant ID auto-load failed
    };
  },
  async mounted() {
    try {
      this.categories = await api.getCategories();
      
      // WP-62: Auto-fill tenant ID using client.js helper (single source of truth)
      if (!this.formData.tenantId) {
        // Try active tenant from localStorage first
        const activeTenantId = api.getActiveTenantId();
        if (activeTenantId) {
          this.formData.tenantId = activeTenantId;
        } else {
          // Fetch from HOS API if demo token exists
          const demoToken = localStorage.getItem('demo_auth_token');
          if (demoToken) {
            try {
              const memberships = await api.getMyMemberships(demoToken);
              const items = memberships.items || memberships.data || (Array.isArray(memberships) ? memberships : []);
              if (items.length > 0) {
                // Prefer admin role, else first membership
                const adminMembership = items.find(m => m.role === 'admin' || m.role === 'owner');
                const selectedMembership = adminMembership || items[0];
                const tenantId = selectedMembership.tenant_id || selectedMembership.tenant?.id;
                if (tenantId) {
                  // WP-62: Use client.js helper to set active tenant
                  api.setActiveTenantId(tenantId);
                  this.formData.tenantId = tenantId;
                } else {
                  // No tenant_id found in memberships
                  this.tenantIdLoadError = true;
                }
              } else {
                // No memberships found
                this.tenantIdLoadError = true;
              }
            } catch (err) {
              // WP-51: Show actionable error message in UI
              console.warn('Could not fetch memberships for tenant ID:', err);
              this.tenantIdLoadError = true;
            }
          } else {
            // No demo token - user not logged in
            this.tenantIdLoadError = true;
          }
        }
      }
    } catch (err) {
      this.error = err;
    }
  },
  watch: {
    'formData.category_id': {
      handler: 'loadFilterSchema',
      immediate: false,
    },
  },
  methods: {
    async loadFilterSchema() {
      if (!this.formData.category_id) {
        this.filterSchema = null;
        return;
      }
      try {
        this.filterSchema = await api.getFilterSchema(this.formData.category_id);
      } catch (err) {
        console.error('Failed to load filter schema:', err);
        this.filterSchema = null;
      }
    },
    async handleSubmit() {
      if (!this.formData.tenantId || !this.formData.category_id || !this.formData.title || this.formData.transaction_modes.length === 0) {
        this.error = { message: 'Please fill all required fields', status: 400 };
        return;
      }
      
      this.loading = true;
      this.error = null;
      
      try {
        // Build attributes object (handle range min/max)
        const attributes = {};
        Object.keys(this.formData.attributes).forEach((key) => {
          const value = this.formData.attributes[key];
          if (value !== null && value !== undefined && value !== '') {
            if (key.endsWith('_min')) {
              const baseKey = key.replace('_min', '');
              attributes[`${baseKey}_min`] = value;
            } else if (key.endsWith('_max')) {
              const baseKey = key.replace('_max', '');
              attributes[`${baseKey}_max`] = value;
            } else {
              attributes[key] = value;
            }
          }
        });
        
        const payload = {
          category_id: this.formData.category_id,
          title: this.formData.title,
          description: this.formData.description || null,
          transaction_modes: this.formData.transaction_modes,
          attributes: Object.keys(attributes).length > 0 ? attributes : null,
        };
        
        const result = await api.createListing(payload, this.formData.tenantId);
        this.success = result;
      } catch (err) {
        this.error = err;
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
.create-listing-page {
  max-width: 800px;
}

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

.error {
  background: #ffebee;
  color: #d32f2f;
  padding: 1rem;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.success {
  background: #e8f5e9;
  color: #2e7d32;
  padding: 1rem;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.success a {
  color: #0066cc;
  text-decoration: underline;
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

.tenant-id-warning code {
  background: #f5f5f5;
  padding: 0.125rem 0.25rem;
  border-radius: 2px;
  font-family: 'Courier New', monospace;
  font-size: 0.8rem;
}
</style>


