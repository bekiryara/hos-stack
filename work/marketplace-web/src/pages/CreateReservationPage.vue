<template>
  <div class="create-reservation-page">
    <h2>Create Reservation</h2>
    
    <div v-if="error" class="error">
      <strong>Error ({{ error.status }}):</strong> {{ error.errorCode || 'unknown' }}
      <br />
      {{ error.message }}
      <div v-if="error.data && error.data.conflicting_reservation_id" class="conflict-info">
        Conflicting Reservation ID: {{ error.data.conflicting_reservation_id }}
      </div>
    </div>
    
    <div v-if="success" class="success">
      <strong>Success!</strong> Reservation created with ID: {{ success.id }}
      <br />
      Status: {{ success.status }}
      <br />
      <router-link :to="`/listing/${success.listing_id}`">View Listing</router-link>
    </div>
    
    <form v-if="!success" @submit.prevent="handleSubmit" class="reservation-form">
      <div class="form-group">
        <label>
          Authorization Token (Bearer) <span class="required">*</span>
          <input
            v-model="formData.authToken"
            type="text"
            required
            placeholder="Bearer your-token-here"
            class="form-input"
          />
        </label>
      </div>
      
      <div class="form-group">
        <label>
          User ID (optional)
          <input
            v-model="formData.userId"
            type="text"
            placeholder="User ID for X-Requester-User-Id header"
            class="form-input"
          />
        </label>
      </div>
      
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

export default {
  name: 'CreateReservationPage',
  data() {
    return {
      formData: {
        authToken: '',
        userId: '',
        listing_id: '',
        slot_start: '',
        slot_end: '',
        party_size: 1,
      },
      loading: false,
      error: null,
      success: null,
    };
  },
  methods: {
    async handleSubmit() {
      if (!this.formData.authToken || !this.formData.listing_id || !this.formData.slot_start || !this.formData.slot_end || !this.formData.party_size) {
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
      
      try {
        const payload = {
          listing_id: this.formData.listing_id,
          slot_start: slotStart,
          slot_end: slotEnd,
          party_size: this.formData.party_size,
        };
        
        const result = await api.createReservation(
          payload,
          this.formData.authToken,
          this.formData.userId || null
        );
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
</style>


