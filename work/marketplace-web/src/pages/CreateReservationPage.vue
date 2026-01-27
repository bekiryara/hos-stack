<template>
  <div class="create-reservation-page">
    <h2>Create Reservation</h2>
    
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
      <div v-if="error.hint" class="error-hint" style="margin-top: 0.5rem; padding: 0.5rem; background: #f8f9fa; border-left: 3px solid #dc3545; font-style: italic;">
        <strong>Hint:</strong> {{ error.hint }}
      </div>
      <div v-if="error.data && error.data.conflicting_reservation_id" class="conflict-info">
        Conflicting Reservation ID: {{ error.data.conflicting_reservation_id }}
      </div>
    </div>
    
    <div v-if="success" class="success">
      <strong>Success!</strong> Reservation created with ID: {{ success.id }}
      <button @click="copyReservationId(success.id)" class="copy-id-btn" title="Copy reservation ID">Copy ID</button>
      <br />
      Status: {{ success.status }}
      <br />
      <div class="success-actions">
        <router-link to="/account" class="action-link">Go to Account</router-link>
        <router-link v-if="success.listing_id" :to="`/listing/${success.listing_id}`" class="action-link">View Listing</router-link>
        <router-link v-if="listingCategoryId" :to="`/search/${listingCategoryId}`" class="action-link">Go to Search</router-link>
      </div>
    </div>
    
    <form v-if="!success && !authError" @submit.prevent="handleSubmit" class="reservation-form">
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
          Slot Start (date-time) <span class="required">*</span>
          <input
            v-model="formData.slot_start"
            type="datetime-local"
            required
            class="form-input"
          />
        </label>
      </div>
      
      <div class="form-group">
        <label>
          Slot End (date-time, must be after start) <span class="required">*</span>
          <input
            v-model="formData.slot_end"
            type="datetime-local"
            required
            class="form-input"
          />
        </label>
      </div>
      
      <div class="form-group">
        <label>
          Party Size <span class="required">*</span>
          <input
            v-model.number="formData.party_size"
            type="number"
            required
            min="1"
            class="form-input"
          />
        </label>
      </div>
      
      <button type="submit" :disabled="loading" class="submit-button">
        {{ loading ? 'Creating...' : 'Create Reservation' }}
      </button>
    </form>
  </div>
</template>

<script>
import { api } from '../api/client';
import { getUserId } from '../lib/demoSession';

// Simple JWT decode (no verification needed for demo)
function decodeJWT(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = JSON.parse(atob(parts[1]));
    return payload;
  } catch {
    return null;
  }
}

export default {
  name: 'CreateReservationPage',
  data() {
    return {
      formData: {
        listing_id: '',
        slot_start: '',
        slot_end: '',
        party_size: 1,
      },
      loading: false,
      error: null,
      authError: null,
      success: null,
      listingCategoryId: null,
    };
  },
  mounted() {
    // WP-68: Check authentication (userId from token)
    const userId = getUserId();
    if (!userId) {
      this.authError = 'No authentication token found. Please login first.';
      return;
    }
    
    // Get listing_id from query params
    const listingId = this.$route.query.listing_id;
    if (listingId) {
      this.formData.listing_id = listingId;
      // Try to load listing to get category_id for success screen
      this.loadListingCategory(listingId);
    }
  },
  methods: {
    async loadListingCategory(listingId) {
      try {
        const listing = await api.getListing(listingId);
        if (listing && listing.category_id) {
          this.listingCategoryId = listing.category_id;
        }
      } catch (err) {
        // Non-fatal: just won't show category in success screen
        console.warn('Could not load listing category:', err);
      }
    },
    async handleSubmit() {
      // WP-68: Get userId from demoSession (token auto-attached by API)
      const userId = getUserId();
      
      if (!userId) {
        this.authError = 'No authentication token found. Please login first.';
        return;
      }
      
      if (!this.formData.listing_id || !this.formData.slot_start || !this.formData.slot_end || !this.formData.party_size) {
        this.error = { message: 'Please fill all required fields', status: 400 };
        return;
      }
      
      // Convert datetime-local to ISO format
      const slotStart = new Date(this.formData.slot_start).toISOString();
      const slotEnd = new Date(this.formData.slot_end).toISOString();
      
      if (slotEnd <= slotStart) {
        this.error = { message: 'Slot end must be after slot start', status: 400 };
        return;
      }
      
      this.loading = true;
      this.error = null;
      this.authError = null;
      
      try {
        const payload = {
          listing_id: this.formData.listing_id,
          slot_start: slotStart,
          slot_end: slotEnd,
          party_size: this.formData.party_size,
        };
        
        // WP-68: Token auto-attached by API wrapper
        const result = await api.createReservation(
          payload,
          userId || null
        );
        this.success = result;
        
        // Load category if not already loaded
        if (result.listing_id && !this.listingCategoryId) {
          await this.loadListingCategory(result.listing_id);
        }
      } catch (err) {
        // Improve error display with hint
        const hint = err.status === 401 ? '401 → Token missing or invalid. Check Authorization Token.' : 
                     err.status === 404 ? '404 → Listing not found. Check Listing ID.' :
                     err.status === 422 ? '422 → Validation error. Check all required fields.' : null;
        this.error = {
          ...err,
          hint: hint || (err.message || 'Unknown error'),
        };
      } finally {
        this.loading = false;
      }
    },
    copyReservationId(id) {
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
      }
    },
  },
};
</script>

<style scoped>
.create-reservation-page {
  max-width: 600px;
}

.reservation-form {
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

.conflict-info {
  margin-top: 0.5rem;
  font-size: 0.9rem;
  font-style: italic;
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

.auto-fill-note {
  font-size: 0.85rem;
  color: #666;
  font-style: italic;
}

.readonly {
  background: #f5f5f5;
  cursor: not-allowed;
}

.copy-id-btn {
  font-size: 0.85rem;
  padding: 0.3rem 0.6rem;
  margin-left: 0.5rem;
  border: 1px solid #ccc;
  border-radius: 3px;
  background: #f5f5f5;
  color: #333;
  cursor: pointer;
  transition: background 0.2s;
}

.copy-id-btn:hover {
  background: #e5e5e5;
}

.success-actions {
  margin-top: 1rem;
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.action-link {
  color: #0066cc;
  text-decoration: underline;
  font-weight: 500;
}
</style>


