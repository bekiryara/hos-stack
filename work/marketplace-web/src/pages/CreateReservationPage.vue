<template>
  <div class="create-reservation-page">
    <h2>Rezervasyon Olustur</h2>

    <div v-if="authError" class="error">
      <strong>Giris Gerekli</strong>
      <br />
      {{ authError }}
      <br />
      <router-link to="/login" class="action-link">Girise Git</router-link>
    </div>

    <div v-if="error && !authError" class="error">
      <strong>Error ({{ error.status || 'N/A' }}):</strong> {{ error.errorCode || 'unknown' }}
      <br />
      {{ error.message || 'Bilinmeyen hata' }}
      <div v-if="error.hint" class="error-hint" style="margin-top: 0.5rem; padding: 0.5rem; background: #f8f9fa; border-left: 3px solid #dc3545; font-style: italic;">
        <strong>Ipuclari:</strong> {{ error.hint }}
      </div>
      <div v-if="error.data && error.data.conflicting_reservation_id" class="conflict-info">
        Cakisan Rezervasyon ID: {{ error.data.conflicting_reservation_id }}
      </div>
    </div>

    <div v-if="success" class="success">
      <strong>Basarili!</strong> Rezervasyon olusturuldu. ID: {{ success.id }}
      <button @click="copyReservationId(success.id, $event)" class="copy-id-btn" title="Rezervasyon ID kopyala">ID Kopyala</button>
      <br />
      Durum: {{ success.status }}
      <PricingSummary
        class="success-pricing"
        :totals="success.totals"
        :price-amount="success.price_amount"
        :price-currency="success.price_currency"
        :billing-model="success.billing_model"
        :multiplier="success.totals?.multiplier || success.party_size || 1"
      />
      <div class="success-actions">
        <router-link :to="{ path: '/account', query: { tab: 'reservations' } }" class="action-link">Hesaba Git</router-link>
        <router-link v-if="success.listing_id" :to="`/listing/${success.listing_id}`" class="action-link">Ilani Gor</router-link>
        <router-link v-if="listingCategoryId" :to="`/search/${listingCategoryId}`" class="action-link">Aramaya Git</router-link>
      </div>
    </div>

    <form v-if="!success && !authError" @submit.prevent="handleSubmit" class="reservation-form">
      <div class="form-group">
        <label>
          Ilan ID <span class="required">*</span>
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
          Baslangic Tarihi <span class="required">*</span>
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
          Bitis Tarihi <span class="required">*</span>
          <input
            v-model="formData.slot_end"
            type="datetime-local"
            required
            class="form-input"
          />
        </label>
      </div>

      <div v-if="requiresPartySize" class="form-group">
        <label>
          Kisi Sayisi <span class="required">*</span>
          <input
            v-model.number="formData.party_size"
            type="number"
            required
            min="1"
            class="form-input"
          />
        </label>
      </div>

      <div v-if="requiresSessionCount" class="form-group">
        <label>
          Seans Sayisi <span class="required">*</span>
          <input
            v-model.number="formData.session_count"
            type="number"
            required
            min="1"
            class="form-input"
          />
        </label>
      </div>

      <button type="submit" :disabled="loading" class="submit-button">
        {{ loading ? 'Olusturuluyor...' : 'Rezervasyon Olustur' }}
      </button>
    </form>
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { getUserId } from '../lib/session.js';
import { modeGuardReasonForListing } from '../lib/servicePolicyGuard.js';
import PricingSummary from '../components/common/PricingSummary.vue';

export default {
  name: 'CreateReservationPage',
  components: { PricingSummary },
  data() {
    return {
      formData: {
        listing_id: '',
        slot_start: '',
        slot_end: '',
        party_size: 1,
        session_count: 1,
      },
      loading: false,
      error: null,
      authError: null,
      success: null,
      listingCategoryId: null,
      listingBillingModel: '',
    };
  },
  computed: {
    requiresPartySize() {
      return this.listingBillingModel === 'per_person';
    },
    requiresSessionCount() {
      return this.listingBillingModel === 'per_session';
    },
  },
  watch: {
    'formData.listing_id'(value, oldValue) {
      const next = String(value || '').trim();
      const prev = String(oldValue || '').trim();
      if (next === prev) return;
      // Best-effort preload for dynamic billing-model fields.
      if (/^[0-9a-fA-F-]{36}$/.test(next)) {
        this.loadListingCategory(next);
      }
    },
  },
  mounted() {
    const userId = getUserId();
    if (!userId) {
      this.authError = 'Oturum bulunamadi. Lutfen once giris yapin.';
      return;
    }

    const listingId = this.$route.query.listing_id;
    if (listingId) {
      this.formData.listing_id = listingId;
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
        const attrs = listing?.attributes && typeof listing.attributes === 'object' ? listing.attributes : {};
        this.listingBillingModel = String(attrs.billing_model || listing?.billing_model || '').trim();
      } catch (err) {
        console.warn('Ilan kategorisi yuklenemedi:', err);
      }
    },
    async validateListingPolicy(listingId) {
      try {
        const listing = await api.getListing(listingId);
        if (listing && listing.category_id) {
          this.listingCategoryId = listing.category_id;
        }
        return modeGuardReasonForListing(listing, 'reservation');
      } catch {
        return null;
      }
    },
    async handleSubmit() {
      const userId = getUserId();

      if (!userId) {
        this.authError = 'Oturum bulunamadi. Lutfen once giris yapin.';
        return;
      }

      if (!this.formData.listing_id || !this.formData.slot_start || !this.formData.slot_end) {
        this.error = { message: 'Lutfen zorunlu alanlari doldurun', status: 400 };
        return;
      }
      if (this.requiresPartySize && !this.formData.party_size) {
        this.error = { message: 'Kisi sayisi zorunludur', status: 400 };
        return;
      }
      if (this.requiresSessionCount && !this.formData.session_count) {
        this.error = { message: 'Seans sayisi zorunludur', status: 400 };
        return;
      }

      const policyReason = await this.validateListingPolicy(this.formData.listing_id);
      if (policyReason) {
        this.error = { message: policyReason, status: 422, errorCode: 'POLICY_MISMATCH' };
        return;
      }

      const slotStart = new Date(this.formData.slot_start).toISOString();
      const slotEnd = new Date(this.formData.slot_end).toISOString();

      if (slotEnd <= slotStart) {
        this.error = { message: 'Bitis tarihi baslangictan sonra olmalidir', status: 400 };
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
          party_size: this.requiresPartySize ? this.formData.party_size : 1,
          session_count: this.requiresSessionCount ? Math.max(1, Number(this.formData.session_count || 1)) : undefined,
        };

        const result = await api.createReservation(payload, userId || null);
        this.success = result;

        if (result.listing_id && !this.listingCategoryId) {
          await this.loadListingCategory(result.listing_id);
        }
      } catch (err) {
        const hint = err.status === 401 ? '401 -> Token missing or invalid. Check Authorization Token.' :
          err.status === 404 ? '404 -> Listing not found. Check Listing ID.' :
            err.status === 409 ? '409 -> Slot conflict. Pick a different time range.' :
              err.status === 422 ? '422 -> Validation error. Check all required fields.' : null;
        this.error = {
          status: err?.status,
          errorCode: err?.errorCode,
          message: err?.message,
          data: err?.data,
          hint: hint || (err?.message || 'Bilinmeyen hata'),
        };
      } finally {
        this.loading = false;
      }
    },
    copyReservationId(id, event) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(id).then(() => {
          const btn = event.target;
          const originalText = btn.textContent;
          btn.textContent = 'Kopyalandi!';
          setTimeout(() => {
            btn.textContent = originalText;
          }, 1000);
        }).catch((err) => {
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

.success-pricing {
  margin-top: 0.85rem;
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
