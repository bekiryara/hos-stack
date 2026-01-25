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
      <button @click="copyListingId(success.id)" class="copy-id-btn" title="Copy listing ID">Copy ID</button>
      <br />
      Status: {{ success.status }}
      <br />
      <div class="success-actions">
        <router-link :to="`/listing/${success.id}`" class="action-link">View Listing</router-link>
        <button v-if="success.status === 'draft'" @click="handlePublish" :disabled="publishing" class="action-button publish-button">
          {{ publishing ? 'Publishing...' : 'Publish now' }}
        </button>
        <button v-if="success.status === 'published' && success.category_id" @click="goToCategorySearch(success.category_id)" class="action-button">Go to Search</button>
      </div>
      <div v-if="publishError" class="publish-error">
        <strong>Publish Error:</strong> {{ publishError.message }}
      </div>
    </div>
    
    <form v-if="!success" @submit.prevent="handleSubmit" class="listing-form">
      <div class="form-group">
        <label>
          Tenant ID (UUID) <span class="required">*</span>
          <div v-if="formData.tenantId" class="tenant-id-display">
            <input
              v-model="formData.tenantId"
              type="text"
              required
              readonly
              class="form-input auto-filled"
            />
            <small class="auto-fill-note">Auto-filled from active tenant</small>
          </div>
          <div v-else class="tenant-id-missing">
            <router-link to="/demo" class="tenant-picker-link">Select Active Tenant</router-link>
            <span class="or-text">or</span>
            <input
              v-model="formData.tenantId"
              type="text"
              required
              placeholder="Enter tenant ID manually"
              class="form-input"
            />
            <small v-if="tenantIdLoadError" class="tenant-id-warning">
              <strong>Note:</strong> Could not auto-load tenant ID. Please select from Demo page or enter manually.
            </small>
          </div>
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
import { isLoggedIn, getActiveTenantId } from '../lib/demoSession';

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
      publishing: false, // WP-64: Track publish operation
      publishError: null, // WP-64: Track publish errors
    };
  },
  async mounted() {
    try {
      this.categories = await api.getCategories();
      
      // WP-68: Auto-fill tenant ID using client.js helper (single source of truth)
      if (!this.formData.tenantId) {
        // Try active tenant from localStorage first
        const activeTenantId = getActiveTenantId();
        if (activeTenantId) {
          this.formData.tenantId = activeTenantId;
        } else {
          // WP-68: Check if user is logged in (token auto-attached by API)
          if (isLoggedIn()) {
            try {
              // WP-68: Token auto-attached by API wrapper
              const memberships = await api.getMyMemberships();
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
            // WP-68: User not logged in - show friendly message
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
        
        // WP-68: Check if user has active tenant (firm account required)
        const activeTenantId = this.formData.tenantId || getActiveTenantId();
        if (!activeTenantId) {
          this.error = { 
            message: 'Firma hesabı gerekli. Lütfen aktif bir firma seçin veya firma kaydı yapın.', 
            status: 400 
          };
          this.loading = false;
          return;
        }
        
        // WP-68: Token auto-attached by API wrapper
        // API client will auto-use activeTenantId
        const result = await api.createListing(payload, activeTenantId || null);
        this.success = result;
      } catch (err) {
        this.error = err;
      } finally {
        this.loading = false;
      }
    },
    copyListingId(id) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(id).then(() => {
          alert('Listing ID copied to clipboard!');
        }).catch(err => {
          console.error('Failed to copy:', err);
        });
      } else {
        // Fallback for older browsers
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
      
      try {
        // WP-68: Use existing publish endpoint with current tenant strategy
        const tenantId = this.formData.tenantId || getActiveTenantId();
        if (!tenantId) {
          this.publishError = { message: 'Tenant ID required. Please set active tenant.' };
          this.publishing = false;
          return;
        }
        
        const result = await api.publishListing(this.success.id, tenantId);
        
        // WP-64: Update local state to published
        this.success = {
          ...this.success,
          status: 'published',
        };
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

.success-actions {
  margin-top: 1rem;
  display: flex;
  gap: 1rem;
  align-items: center;
}

.success a,
.action-link {
  color: #0066cc;
  text-decoration: underline;
}

.action-button {
  padding: 0.5rem 1rem;
  border: 1px solid #28a745;
  border-radius: 4px;
  background: #28a745;
  color: white;
  cursor: pointer;
  font-size: 0.9rem;
}

.action-button:hover {
  background: #218838;
}

.copy-id-btn {
  font-size: 0.75rem;
  padding: 0.2rem 0.5rem;
  border: 1px solid #2e7d32;
  border-radius: 3px;
  background: #2e7d32;
  color: white;
  cursor: pointer;
  margin-left: 0.5rem;
}

.copy-id-btn:hover {
  background: #1b5e20;
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

.or-text {
  color: #666;
  font-size: 0.9rem;
  margin: 0.25rem 0;
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

.draft-note {
  color: #666;
  font-size: 0.9rem;
  font-style: italic;
  margin-left: 1rem;
}

.publish-button {
  background: #4caf50;
  border-color: #4caf50;
}

.publish-button:hover:not(:disabled) {
  background: #45a049;
  border-color: #45a049;
}

.publish-button:disabled {
  background: #ccc;
  border-color: #ccc;
  cursor: not-allowed;
}

.publish-error {
  margin-top: 0.5rem;
  padding: 0.5rem;
  background: #ffebee;
  color: #d32f2f;
  border-radius: 4px;
  font-size: 0.9rem;
}
</style>


