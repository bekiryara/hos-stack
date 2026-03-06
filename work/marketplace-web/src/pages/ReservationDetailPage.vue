<template>
  <div class="transaction-detail">
    <div class="detail-header">
      <router-link :to="{ path: '/account', query: { tab: 'reservations' } }" class="back-link">Hesaba don</router-link>
      <h2>Rezervasyon Detayi</h2>
    </div>

    <div v-if="loadError" class="limited-banner">
      {{ `Sinirli gorunum - API erisimi basarisiz: ${loadError}` }}
    </div>

    <SectionShell
      title="Rezervasyon Ozeti"
      :status="loading ? 'loading' : (loadError ? 'error' : 'ready')"
      :error-message="loadError || ''"
      :empty="!loading && !item.id"
      empty-text="Veri yok"
      @retry="load"
    >
      <div class="summary-grid">
        <div class="summary-item">
          <span class="summary-label">Ilan</span>
          <span class="summary-value">{{ listingDisplay }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">Durum</span>
          <span class="summary-value"><span class="status-pill">{{ statusLabel(item.status) }}</span></span>
        </div>
        <div class="summary-item">
          <span class="summary-label">Baslangic</span>
          <span class="summary-value">{{ formatDate(item.slot_start) }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">Bitis</span>
          <span class="summary-value">{{ formatDate(item.slot_end) }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">Kisi Sayisi</span>
          <span class="summary-value">{{ safe(item.party_size) }}</span>
        </div>
        <div class="summary-item summary-item-pricing">
          <PricingSummary
            :totals="item.totals"
            :price-amount="item.price_amount"
            :price-currency="item.price_currency"
            :billing-model="item.billing_model"
            :multiplier="item.totals?.multiplier || item.party_size || 1"
          />
        </div>
      </div>
    </SectionShell>

    <SectionShell
      title="Teknik Bilgiler"
      :status="loading ? 'loading' : 'ready'"
      :error-message="''"
      :empty="false"
      empty-text=""
    >
      <ul class="detail-list">
        <li><strong>Islem Referansi:</strong> {{ safe(item.id) }}</li>
        <li><strong>Ilan Referansi:</strong> {{ safe(item.listing_id) }}</li>
        <li><strong>Offer Referansi:</strong> {{ safe(item.offer_id) }}</li>
        <li><strong>Fiyat Kaynagi:</strong> {{ safe(item.pricing_source) }}</li>
        <li><strong>Ucretlendirme Modeli:</strong> {{ safe(item.billing_model) }}</li>
        <li><strong>Olusturulma Tarihi:</strong> {{ formatDate(item.created_at) }}</li>
        <li><strong>Son Guncellenme Tarihi:</strong> {{ formatDate(item.updated_at) }}</li>
      </ul>
    </SectionShell>
  </div>
</template>

<script>
import SectionShell from '../components/portal/SectionShell.vue';
import PricingSummary from '../components/common/PricingSummary.vue';
import { api } from '../api/client.js';
import { getStatusLabel } from '../lib/displayLabels.js';
import { formatDisplayDate } from '../lib/displayFormatters.js';

export default {
  name: 'ReservationDetailPage',
  components: { SectionShell, PricingSummary },
  props: { id: { type: String, required: true } },
  data() {
    return {
      loading: false,
      loadError: null,
      fetched: null,
      limited: {
        id: this.id,
        listing_id: null,
        listing_title: null,
        offer_id: null,
        pricing_source: null,
        price_amount: null,
        price_currency: null,
        billing_model: null,
        totals: null,
        slot_start: null,
        slot_end: null,
        party_size: null,
        status: null,
        created_at: null,
        updated_at: null,
      },
    };
  },
  computed: {
    item() {
      if (this.fetched) return { ...this.fetched, id: this.id };
      return this.limited;
    },
    listingDisplay() {
      return this.item?.listing_title || this.safe(this.item?.listing_id);
    },
  },
  mounted() {
    this.buildLimitedFromQuery();
    this.load();
  },
  methods: {
    safe(val) {
      if (val == null || val === '') return '—';
      return val;
    },
    statusLabel(status) {
      return getStatusLabel(status);
    },
    buildLimitedFromQuery() {
      const q = this.$route.query;
      this.limited = {
        id: this.id,
        listing_id: q.listing_id ?? null,
        listing_title: q.listing_title ?? null,
        offer_id: q.offer_id ?? null,
        pricing_source: q.pricing_source ?? null,
        price_amount: q.price_amount ?? null,
        price_currency: q.price_currency ?? null,
        billing_model: q.billing_model ?? null,
        totals: null,
        slot_start: q.slot_start ?? null,
        slot_end: q.slot_end ?? null,
        party_size: q.party_size ?? null,
        status: q.status ?? null,
        created_at: q.created_at ?? null,
        updated_at: q.updated_at ?? null,
      };
    },
    async load() {
      this.loadError = null;
      this.loading = true;
      try {
        const res = await api.getMyReservationById(this.id);
        this.fetched = res?.data ?? res?.item ?? res ?? {};
      } catch (err) {
        this.loadError = (err.message || err.status || 'Request failed').toString();
      } finally {
        this.loading = false;
      }
    },
    formatDate(dateStr) {
      return formatDisplayDate(dateStr);
    },
  },
};
</script>

<style scoped>
.transaction-detail {
  max-width: 760px;
  margin: 0 auto;
  padding: 1.5rem;
}

.detail-header {
  margin-bottom: 1rem;
}

.back-link {
  font-size: 0.9rem;
  color: #0066cc;
  text-decoration: none;
}

.back-link:hover {
  text-decoration: underline;
}

.limited-banner {
  padding: 0.5rem 1rem;
  background: #fff3cd;
  border: 1px solid #ffc107;
  border-radius: 4px;
  margin-bottom: 1rem;
  font-size: 0.9rem;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 0.85rem;
}

.summary-item {
  padding: 0.85rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #fff;
}

.summary-item-pricing {
  grid-column: span 2;
}

.summary-label {
  display: block;
  margin-bottom: 0.35rem;
  color: #64748b;
  font-size: 0.85rem;
  font-weight: 600;
}

.summary-value {
  color: #0f172a;
  font-size: 1rem;
  font-weight: 600;
}

.detail-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.detail-list li {
  margin-bottom: 0.45rem;
}

.status-pill {
  display: inline-block;
  padding: 0.2rem 0.55rem;
  border-radius: 999px;
  background: #eef2ff;
  color: #3730a3;
  font-size: 0.85rem;
  font-weight: 600;
}
</style>
