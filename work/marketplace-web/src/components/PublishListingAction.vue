<template>
  <div class="publish-action">
    <div v-if="error" class="error">
      <strong>Error ({{ error.status }}):</strong> {{ error.errorCode || 'unknown' }}
      <br />
      {{ error.message }}
    </div>
    
    <div v-if="success" class="success">
      <strong>Success!</strong> Listing published.
      <br />
      Status: {{ success.status }}
    </div>
    
    <div v-if="!success && !loading">
      <label>
        Tenant ID (UUID) <span class="required">*</span>
        <input
          v-model="tenantId"
          type="text"
          placeholder="e.g., 951ba4eb-9062-40c4-9228-f8d2cfc2f426"
          class="form-input"
        />
      </label>
      <button @click="handlePublish" :disabled="!tenantId || loading" class="publish-button">
        {{ loading ? 'Publishing...' : 'Publish Listing' }}
      </button>
    </div>
    
    <div v-if="loading" class="loading">Publishing...</div>
  </div>
</template>

<script>
import { api } from '../api/client';

export default {
  name: 'PublishListingAction',
  props: {
    listingId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      tenantId: '',
      loading: false,
      error: null,
      success: null,
    };
  },
  methods: {
    async handlePublish() {
      if (!this.tenantId) {
        this.error = { message: 'Tenant ID is required', status: 400 };
        return;
      }
      
      this.loading = true;
      this.error = null;
      this.success = null;
      
      try {
        const result = await api.publishListing(this.listingId, this.tenantId);
        this.success = result;
        this.$emit('published', result);
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
.publish-action {
  margin-top: 1rem;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
}

.publish-action label {
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
  margin-bottom: 0.5rem;
}

.publish-button {
  background: #4caf50;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
}

.publish-button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.publish-button:hover:not(:disabled) {
  background: #45a049;
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

.loading {
  text-align: center;
  padding: 1rem;
  color: #666;
}
</style>


