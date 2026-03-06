<template>
  <div class="transaction-detail">
    <div class="detail-header">
      <router-link :to="{ path: '/account', query: { tab: 'orders' } }" class="back-link">Hesaba don</router-link>
      <h2>Siparis Detayi</h2>
    </div>

    <div v-if="loadError" class="limited-banner">
      {{ `Sinirli gorunum - API erisimi basarisiz: ${loadError}` }}
    </div>

    <SectionShell
      title="Siparis Ozeti"
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
        <div class="summary-item summary-item-pricing">
          <PricingSummary
            :totals="item.totals"
            :multiplier="item.totals?.multiplier || item.quantity || 1"
            :billing-model="item.totals?.billing_model || ''"
          />
        </div>
        <div class="summary-item">
          <span class="summary-label">Siparis Tarihi</span>
          <span class="summary-value">{{ formatDate(item.created_at) }}</span>
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
        <li><strong>Fiyat Kaynagi:</strong> {{ formatTotalsValue(item.totals, 'pricing_source') }}</li>
        <li><strong>Ucretlendirme Modeli:</strong> {{ formatTotalsValue(item.totals, 'billing_model') }}</li>
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
import { getActiveTenantId } from '../lib/session.js';

export default {
  name: 'OrderDetailPage',
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
        quantity: null,
        totals: null,
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
        quantity: q.quantity ?? null,
        totals: null,
        status: q.status ?? null,
        created_at: q.created_at ?? null,
        updated_at: q.updated_at ?? null,
      };
    },
    formatDate(dateStr) {
      return formatDisplayDate(dateStr);
    },
    formatTotalsValue(totals, field) {
      if (!totals || typeof totals !== 'object') return '—';
      return this.safe(totals[field]);
    },
    async load() {
      this.loadError = null;
      this.loading = true;
      try {
        const personalRes = await api.getMyOrderById(this.id);
        this.fetched = personalRes?.data ?? personalRes?.item ?? personalRes ?? {};
      } catch (err) {
        const firstError = (err.message || err.status || 'Request failed').toString();
        const activeTenantId = getActiveTenantId();
        if (activeTenantId) {
          try {
            const storeRes = await api.getStoreOrderById(this.id, activeTenantId);
            this.fetched = storeRes?.data ?? storeRes?.item ?? storeRes ?? {};
            this.loadError = null;
            return;
          } catch {
            // Keep original personal-scope error in limited mode.
          }
        }
        this.loadError = firstError;
      } finally {
        this.loading = false;
      }
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
