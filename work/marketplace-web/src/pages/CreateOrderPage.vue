<template>
  <div class="create-order-page">
    <h2>Create Order</h2>
    
    <div v-if="authError" class="error">
      <strong>Authentication Required</strong>
      <br />
      {{ authError }}
      <br />
      <router-link to="/login" class="action-link">Go to Login</router-link>
    </div>
    
    <div v-if="error && !authError" class="error">
      <strong>Error ({{ error.status || 'N/A' }}):</strong> {{ error.errorCode || 'unknown' }}
      <br />
      {{ error.message || 'Unknown error' }}
    </div>
    
    <div v-if="success" class="success">
      <strong>Success!</strong> Order created with ID: {{ success.id }}
      <button @click="copyOrderId(success.id)" class="copy-id-btn" title="Copy order ID">Copy ID</button>
      <br />
      Status: {{ success.status }}
      <br />
      Quantity: {{ success.quantity }}
      <br />
      <div class="success-actions">
        <router-link v-if="success.listing_id" :to="`/listing/${success.listing_id}`" class="action-link">View Listing</router-link>
        <router-link to="/account" class="action-link">View My Orders</router-link>
      </div>
    </div>
    
    <form v-if="!success && !authError" @submit.prevent="handleSubmit" class="order-form">
      <div class="form-group">
        <label>
          Listing ID (UUID) <span class="required">*</span>
          <input
            v-model="formData.listing_id"
            type="text"
            required
            placeholder="e.g., listing-uuid-here"
            class="form-input"
          />
        </label>
      </div>
      
      <div class="form-group">
        <label>
          Quantity <span class="required">*</span>
          <input
            v-model.number="formData.quantity"
            type="number"
            min="1"
            required
            class="form-input"
          />
        </label>
      </div>
      
      <button type="submit" :disabled="loading" class="submit-button">
        {{ loading ? 'Creating...' : 'Create Order' }}
      </button>
    </form>
  </div>
</template>

<script>
import { api } from '../api/client';
import { getUserId, clearSession } from '../lib/demoSession.js';

export default {
  name: 'CreateOrderPage',
  data() {
    return {
      formData: {
        listing_id: '',
        quantity: 1,
      },
      loading: false,
      error: null,
      authError: null,
      success: null,
    };
  },
  mounted() {
    // Check authentication
    const userId = getUserId();
    if (!userId) {
      this.authError = 'No authentication token found. Please login first.';
      clearSession();
      this.$router.push('/login?reason=expired');
      return;
    }
    
    // Get listing_id from query params
    const listingId = this.$route.query.listing_id;
    if (listingId) {
      this.formData.listing_id = listingId;
    }
  },
  methods: {
    async handleSubmit() {
      const userId = getUserId();
      
      if (!userId) {
        this.authError = 'No authentication token found. Please login first.';
        clearSession();
        this.$router.push('/login?reason=expired');
        return;
      }
      
      if (!this.formData.listing_id || !this.formData.quantity || this.formData.quantity < 1) {
        this.error = { message: 'Please fill all required fields', status: 400 };
        return;
      }
      
      this.loading = true;
      this.error = null;
      this.authError = null;
      
      try {
        const result = await api.createOrder(this.formData.listing_id, this.formData.quantity);
        this.success = result;
      } catch (err) {
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        this.error = {
          status: err.status || 0,
          message: err.message || 'Failed to create order',
          errorCode: err.errorCode || 'unknown',
        };
      } finally {
        this.loading = false;
      }
    },
    copyOrderId(id) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(id).then(() => {
          const btn = event.target;
          const originalText = btn.textContent;
          btn.textContent = 'Copied!';
          setTimeout(() => {
            btn.textContent = originalText;
          }, 1000);
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
        } catch (err) {
          console.error('Fallback copy failed:', err);
        }
        document.body.removeChild(textArea);
      }
    },
  },
};
</script>

<style scoped>
.create-order-page {
  max-width: 600px;
  margin: 0 auto;
  padding: 2rem;
}

.error {
  padding: 1rem;
  background: #ffebee;
  border: 1px solid #d32f2f;
  border-radius: 4px;
  color: #c62828;
  margin-bottom: 1rem;
}

.success {
  padding: 1rem;
  background: #e8f5e9;
  border: 1px solid #388e3c;
  border-radius: 4px;
  color: #2e7d32;
  margin-bottom: 1rem;
}

.success-actions {
  margin-top: 1rem;
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.action-link {
  color: #1976d2;
  text-decoration: none;
  font-weight: 500;
}

.action-link:hover {
  text-decoration: underline;
}

.copy-id-btn {
  margin-left: 0.5rem;
  padding: 0.25rem 0.5rem;
  font-size: 0.875rem;
  border: 1px solid #388e3c;
  border-radius: 3px;
  background: white;
  color: #388e3c;
  cursor: pointer;
}

.copy-id-btn:hover {
  background: #f1f8f4;
}

.order-form {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.form-group {
  display: flex;
  flex-direction: column;
}

.form-group label {
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.required {
  color: #dc3545;
}

.form-input {
  padding: 0.75rem;
  border: 1px solid #ced4da;
  border-radius: 4px;
  font-size: 1rem;
}

.submit-button {
  padding: 0.75rem 1.5rem;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
  font-weight: 500;
}

.submit-button:hover:not(:disabled) {
  background: #0056b3;
}

.submit-button:disabled {
  background: #6c757d;
  cursor: not-allowed;
}
</style>

