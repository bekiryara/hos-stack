<template>
  <div class="create-order-page">
    <h2>Sipariş Oluştur</h2>

    <div v-if="authError" class="error">
      <strong>Giriş gerekli</strong>
      <br />{{ authError }}
      <br /><router-link to="/login" class="action-link">Giriş Yap</router-link>
    </div>

    <div v-else-if="error" class="error">
      <strong>Hata ({{ error.status || '—' }}):</strong> {{ error.message || 'Bilinmeyen hata' }}
      <div v-if="error.hint" class="error-hint">{{ error.hint }}</div>
    </div>

    <div v-if="success" class="success-card">
      <div class="success-icon">&#10003;</div>
      <h3>Sipariş Oluşturuldu</h3>
      <p class="success-detail">Sipariş No: <strong>{{ success.id }}</strong></p>
      <div v-if="success.totals" class="order-totals">
        <div class="total-row">
          <span>Birim Fiyat</span>
          <span>{{ formatPrice(success.totals.unit_price, success.totals.currency) }}</span>
        </div>
        <div class="total-row">
          <span>Adet</span>
          <span>{{ success.quantity }}</span>
        </div>
        <div class="total-row total-row-final">
          <span>Toplam</span>
          <span>{{ formatPrice(success.totals.subtotal, success.totals.currency) }}</span>
        </div>
      </div>
      <div class="success-actions">
        <router-link v-if="success.listing_id" :to="`/listing/${success.listing_id}`" class="action-link">ilana dön</router-link>
        <router-link :to="{ path: '/account', query: { tab: 'orders' } }" class="action-link">Siparişlerim</router-link>
      </div>
    </div>

    <form v-if="!success && !authError" @submit.prevent="handleSubmit" class="order-form">
      <div v-if="listingPreview" class="listing-preview">
        <h4>{{ listingPreview.title }}</h4>
        <div v-if="listingPreview.price" class="preview-price">
          {{ formatPrice(listingPreview.price, listingPreview.price_currency) }}
        </div>
        <div v-if="!listingPreview.price" class="preview-no-price">Fiyat belirtilmemiş</div>
      </div>
      <div v-else-if="listingLoading" class="listing-loading">İlan yükleniyor...</div>

      <div class="form-group" v-if="!formData.listing_id">
        <label>
          Listing ID <span class="required">*</span>
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
          Adet <span class="required">*</span>
          <input
            v-model.number="formData.quantity"
            type="number"
            min="1"
            required
            class="form-input"
          />
        </label>
      </div>

      <div v-if="listingPreview && listingPreview.price" class="order-summary">
        <div class="total-row">
          <span>Birim Fiyat</span>
          <span>{{ formatPrice(listingPreview.price, listingPreview.price_currency) }}</span>
        </div>
        <div class="total-row total-row-final">
          <span>Toplam</span>
          <span>{{ formatPrice(listingPreview.price * formData.quantity, listingPreview.price_currency) }}</span>
        </div>
      </div>

      <button type="submit" :disabled="loading" class="submit-button">
        {{ loading ? 'Oluşturuluyor...' : 'Siparişi Onayla' }}
      </button>
    </form>
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { getUserId, clearSession } from '../lib/session.js';

export default {
  name: 'CreateOrderPage',
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
    };
  },
  async mounted() {
    const userId = getUserId();
    if (!userId) {
      this.authError = 'Lütfen giriş yapınız.';
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
      } catch {
        this.listingPreview = null;
      } finally {
        this.listingLoading = false;
      }
    },
    async handleSubmit() {
      const userId = getUserId();
      if (!userId) {
        this.authError = 'Lütfen giriş yapınız.';
        clearSession();
        this.$router.push('/login?reason=expired');
        return;
      }
      if (!this.formData.listing_id || !this.formData.quantity || this.formData.quantity < 1) {
        this.error = { message: 'Tüm alanları doldurunuz', status: 400 };
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
        if (err.status === 404) hint = 'İlan bulunamadı.';
        else if (err.status === 422) hint = 'Geçersiz veri. Lütfen kontrol edin.';
        else if (err.status === 403) hint = 'Bu işlem için yetkiniz yok.';
        this.error = {
          status: err.status || 0,
          message: err.message || 'Sipariş oluşturulamadı',
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
.error-hint { margin-top: 0.5rem; color: #7a1f1f; font-size: 0.9rem; }

.success-card {
  text-align: center;
  padding: 2rem;
  background: #f0fdf4;
  border: 1px solid #86efac;
  border-radius: 10px;
  margin-bottom: 1rem;
}
.success-icon { font-size: 2.5rem; color: #22c55e; margin-bottom: 0.5rem; }
.success-card h3 { margin-bottom: 0.75rem; }
.success-detail { font-size: 0.85rem; color: #555; margin-bottom: 1rem; word-break: break-all; }
.success-actions { display: flex; justify-content: center; gap: 1rem; margin-top: 1rem; }

.action-link { color: #1976d2; text-decoration: none; font-weight: 500; }
.action-link:hover { text-decoration: underline; }

.listing-preview {
  padding: 1rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  margin-bottom: 0.5rem;
}
.listing-preview h4 { margin: 0 0 0.5rem; }
.preview-price { font-size: 1.3rem; font-weight: 700; color: #ef4444; }
.preview-no-price { color: #94a3b8; font-size: 0.9rem; }
.listing-loading { color: #64748b; font-size: 0.9rem; margin-bottom: 0.5rem; }

.order-form { display: flex; flex-direction: column; gap: 1.25rem; }
.form-group { display: flex; flex-direction: column; }
.form-group label { margin-bottom: 0.4rem; font-weight: 500; font-size: 0.95rem; }
.required { color: #dc3545; }
.form-input { padding: 0.7rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 1rem; }

.order-summary, .order-totals {
  padding: 1rem;
  background: #fafafa;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}
.total-row { display: flex; justify-content: space-between; padding: 0.35rem 0; font-size: 0.95rem; }
.total-row-final { font-weight: 700; font-size: 1.1rem; border-top: 1px solid #e5e7eb; padding-top: 0.5rem; margin-top: 0.25rem; }

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
.submit-button:hover:not(:disabled) { background: #16a34a; }
.submit-button:disabled { background: #94a3b8; cursor: not-allowed; }
</style>

