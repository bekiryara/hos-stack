<template>
  <div class="create-order-page">
    <h2>Siparis Olustur</h2>

    <div v-if="authError" class="error">
      <strong>Giris gerekli</strong>
      <br />{{ authError }}
      <br /><router-link to="/login" class="action-link">Giris Yap</router-link>
    </div>

    <div v-else-if="error" class="error">
      <strong>Hata ({{ error.status || '-' }}):</strong> {{ error.message || 'Bilinmeyen hata' }}
      <div v-if="error.hint" class="error-hint">{{ error.hint }}</div>
    </div>

    <div v-if="success" class="success-card">
      <div class="success-icon">&#10003;</div>
      <h3>Siparis Olusturuldu</h3>
      <p class="success-detail">Siparis No: <strong>{{ success.id }}</strong></p>
      <PricingSummary
        v-if="success.totals"
        class="success-pricing"
        :totals="success.totals"
        :multiplier="success.quantity || 1"
        :billing-model="success.totals?.billing_model || listingBillingModel"
      />
      <div class="success-actions">
        <router-link v-if="success.listing_id" :to="`/listing/${success.listing_id}`" class="action-link">Ilana don</router-link>
        <router-link :to="{ path: '/account', query: { tab: 'orders' } }" class="action-link">Siparislerim</router-link>
      </div>
    </div>

    <form v-if="!success && !authError" @submit.prevent="handleSubmit" class="order-form">
      <div v-if="listingPreview" class="listing-preview">
        <h4>{{ listingPreview.title }}</h4>
        <div v-if="listingPreview.price" class="preview-price">
          {{ formatPrice(listingPreview.price, listingPreview.price_currency) }}
        </div>
        <div v-if="!listingPreview.price" class="preview-no-price">Fiyat belirtilmemis</div>
      </div>
      <div v-else-if="listingLoading" class="listing-loading">Ilan yukleniyor...</div>

      <div class="form-group" v-if="!formData.listing_id">
        <label>
          Ilan ID <span class="required">*</span>
          <input
            v-model="listingIdInput"
            type="text"
            required
            placeholder="Listing UUID"
            class="form-input"
            @blur="fetchListing"
          />
        </label>
      </div>

      <div class="form-group">
        <label>
          {{ multiplierInputLabel }} <span class="required">*</span>
          <input
            v-model.number="formData.quantity"
            type="number"
            min="1"
            required
            class="form-input"
          />
        </label>
      </div>

      <PricingSummary
        v-if="listingPreview && listingPreview.price"
        class="order-summary"
        :price-amount="listingPreview.price"
        :price-currency="listingPreview.price_currency"
        :multiplier="formData.quantity"
        :billing-model="listingBillingModel"
      />

      <button type="submit" :disabled="loading" class="submit-button">
        {{ loading ? 'Olusturuluyor...' : 'Siparisi Onayla' }}
      </button>
    </form>
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { getUserId, clearSession } from '../lib/session.js';
import { modeGuardReasonForListing } from '../lib/servicePolicyGuard.js';
import PricingSummary from '../components/common/PricingSummary.vue';

export default {
  name: 'CreateOrderPage',
  components: { PricingSummary },
  data() {
    return {
      formData: {
        listing_id: '',
        quantity: 1,
      },
      listingIdInput: '',
      listingPreview: null,
      listingLoading: false,
      loading: false,
      error: null,
      authError: null,
      success: null,
      listingBillingModel: '',
    };
  },
  computed: {
    multiplierInputLabel() {
      const map = {
        one_time: 'Adet',
        per_day: 'Gun',
        per_night: 'Gece',
        per_month: 'Ay',
        per_person: 'Kisi',
        per_hour: 'Saat',
        per_session: 'Seans',
        per_visit: 'Ziyaret',
      };
      return map[String(this.listingBillingModel || '').trim()] || 'Adet';
    },
  },
  async mounted() {
    const userId = getUserId();
    if (!userId) {
      this.authError = 'Lutfen giris yapiniz.';
      clearSession();
      this.$router.push('/login?reason=expired');
      return;
    }
    const listingId = this.$route.query.listing_id;
    if (listingId) {
      this.formData.listing_id = listingId;
      this.listingIdInput = listingId;
      await this.fetchListing();
    }
  },
  methods: {
    async fetchListing() {
      const id = this.listingIdInput || this.formData.listing_id;
      if (!id) return;
      this.formData.listing_id = id;
      this.listingLoading = true;
      try {
        this.listingPreview = await api.getListing(id);
        const attrs = this.listingPreview?.attributes && typeof this.listingPreview.attributes === 'object'
          ? this.listingPreview.attributes
          : {};
        this.listingBillingModel = String(attrs.billing_model || this.listingPreview?.billing_model || '').trim();
      } catch {
        this.listingPreview = null;
        this.listingBillingModel = '';
      } finally {
        this.listingLoading = false;
      }
    },
    async handleSubmit() {
      const userId = getUserId();
      if (!userId) {
        this.authError = 'Lutfen giris yapiniz.';
        clearSession();
        this.$router.push('/login?reason=expired');
        return;
      }
      if (!this.formData.listing_id || !this.formData.quantity || this.formData.quantity < 1) {
        this.error = { message: 'Tum alanlari doldurunuz', status: 400 };
        return;
      }
      let listing = this.listingPreview;
      if (!listing) {
        try {
          listing = await api.getListing(this.formData.listing_id);
          this.listingPreview = listing;
        } catch {
          listing = null;
        }
      }
      const policyReason = modeGuardReasonForListing(listing, 'sale');
      if (policyReason) {
        this.error = { message: policyReason, status: 422, errorCode: 'POLICY_MISMATCH' };
        return;
      }

      this.loading = true;
      this.error = null;
      try {
        const result = await api.createOrder(this.formData.listing_id, this.formData.quantity);
        this.success = result;
      } catch (err) {
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        let hint = null;
        if (err.status === 404) hint = 'Ilan bulunamadi.';
        else if (err.status === 422) hint = 'Gecersiz veri. Lutfen kontrol edin.';
        else if (err.status === 403) hint = 'Bu islem icin yetkiniz yok.';
        this.error = {
          status: err.status || 0,
          message: err.message || 'Siparis olusturulamadi',
          hint,
        };
      } finally {
        this.loading = false;
      }
    },
    formatPrice(amount, currency) {
      if (!amount && amount !== 0) return '';
      const c = currency || 'TRY';
      try {
        return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: c, minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(amount);
      } catch {
        return `${amount} ${c}`;
      }
    },
  },
};
</script>

<style scoped>
.create-order-page {
  max-width: 560px;
  margin: 0 auto;
  padding: 2rem;
}

.error {
  padding: 1rem;
  background: #ffebee;
  border: 1px solid #d32f2f;
  border-radius: 6px;
  color: #c62828;
  margin-bottom: 1rem;
}

.error-hint {
  margin-top: 0.5rem;
  color: #7a1f1f;
  font-size: 0.9rem;
}

.success-card {
  text-align: center;
  padding: 2rem;
  background: #f0fdf4;
  border: 1px solid #86efac;
  border-radius: 10px;
  margin-bottom: 1rem;
}

.success-icon {
  font-size: 2.5rem;
  color: #22c55e;
  margin-bottom: 0.5rem;
}

.success-card h3 {
  margin-bottom: 0.75rem;
}

.success-detail {
  font-size: 0.85rem;
  color: #555;
  margin-bottom: 1rem;
  word-break: break-all;
}

.success-pricing {
  text-align: left;
}

.success-actions {
  display: flex;
  justify-content: center;
  gap: 1rem;
  margin-top: 1rem;
}

.action-link {
  color: #1976d2;
  text-decoration: none;
  font-weight: 500;
}

.action-link:hover {
  text-decoration: underline;
}

.listing-preview {
  padding: 1rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  margin-bottom: 0.5rem;
}

.listing-preview h4 {
  margin: 0 0 0.5rem;
}

.preview-price {
  font-size: 1.3rem;
  font-weight: 700;
  color: #ef4444;
}

.preview-no-price {
  color: #94a3b8;
  font-size: 0.9rem;
}

.listing-loading {
  color: #64748b;
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
}

.order-form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.form-group {
  display: flex;
  flex-direction: column;
}

.form-group label {
  margin-bottom: 0.4rem;
  font-weight: 500;
  font-size: 0.95rem;
}

.required {
  color: #dc3545;
}

.form-input {
  padding: 0.7rem;
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  font-size: 1rem;
}

.submit-button {
  padding: 0.85rem 1.5rem;
  background: #22c55e;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  cursor: pointer;
  font-weight: 600;
}

.submit-button:hover:not(:disabled) {
  background: #16a34a;
}

.submit-button:disabled {
  background: #94a3b8;
  cursor: not-allowed;
}
</style>
