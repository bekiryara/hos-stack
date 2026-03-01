<template>
  <div class="transaction-detail">
    <div class="detail-header">
      <router-link :to="{ path: '/account', query: { tab: 'orders' } }" class="back-link">← Back to Account</router-link>
      <h2>Order {{ safe(item.id) }}</h2>
    </div>
    <div v-if="limitedMode" class="limited-banner">
      {{ loadError ? `Limited view — API fetch failed: ${loadError}` : 'Limited view (no detail endpoint)' }}
    </div>
    <SectionShell
      title="Details"
      :status="loading ? 'loading' : (loadError ? 'error' : 'ready')"
      :error-message="loadError || ''"
      :empty="!loading && !item.id"
      empty-text="No data"
      @retry="load"
    >
      <ul class="detail-list">
        <li><strong>id:</strong> {{ safe(item.id) }}</li>
        <li><strong>listing_id:</strong> {{ safe(item.listing_id) }}</li>
        <li><strong>quantity:</strong> {{ safe(item.quantity) }}</li>
        <li><strong>unit_price:</strong> {{ formatTotals(item.totals, 'unit_price') }}</li>
        <li><strong>subtotal:</strong> {{ formatTotals(item.totals, 'subtotal') }}</li>
        <li><strong>status:</strong> {{ safe(item.status) }}</li>
        <li><strong>created_at:</strong> {{ safe(item.created_at) }}</li>
        <li><strong>updated_at:</strong> {{ safe(item.updated_at) }}</li>
      </ul>
    </SectionShell>
  </div>
</template>

<script>
import SectionShell from '../components/portal/SectionShell.vue';
import { api } from '../api/client.js';

export default {
  name: 'OrderDetailPage',
  components: { SectionShell },
  props: { id: { type: String, required: true } },
  data() {
    return {
      loading: false,
      loadError: null,
      fetched: null,
      limited: { id: this.id, listing_id: null, quantity: null, totals: null, status: null, created_at: null, updated_at: null },
    };
  },
  computed: {
    item() {
      if (this.fetched) return { ...this.fetched, id: this.id };
      return this.limited;
    },
    limitedMode() {
      return !this.fetched;
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
    buildLimitedFromQuery() {
      const q = this.$route.query;
      this.limited = {
        id: this.id,
        listing_id: q.listing_id ?? null,
        quantity: q.quantity ?? null,
        totals: null,
        status: q.status ?? null,
        created_at: q.created_at ?? null,
        updated_at: q.updated_at ?? null,
      };
    },
    formatPrice(amount, currency) {
      const numeric = Number(amount);
      if (!Number.isFinite(numeric)) return '—';
      const resolvedCurrency = (typeof currency === 'string' && currency.trim()) || 'TRY';
      try {
        return new Intl.NumberFormat(undefined, {
          style: 'currency',
          currency: resolvedCurrency,
          maximumFractionDigits: 2,
        }).format(numeric);
      } catch {
        return `${numeric} ${resolvedCurrency}`;
      }
    },
    formatTotals(totals, field) {
      if (!totals || typeof totals !== 'object') return '—';
      return this.formatPrice(totals[field], totals.currency);
    },
    async load() {
      this.loadError = null;
      this.loading = true;
      try {
        const res = await api.getMyOrderById(this.id);
        this.fetched = res?.data ?? res?.item ?? res ?? {};
      } catch (err) {
        this.loadError = (err.message || err.status || 'Request failed').toString();
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
.transaction-detail { max-width: 600px; margin: 0 auto; padding: 1.5rem; }
.detail-header { margin-bottom: 1rem; }
.back-link { font-size: 0.9rem; color: #0066cc; text-decoration: none; }
.back-link:hover { text-decoration: underline; }
.limited-banner { padding: 0.5rem 1rem; background: #fff3cd; border: 1px solid #ffc107; border-radius: 4px; margin-bottom: 1rem; font-size: 0.9rem; }
.detail-list { list-style: none; padding: 0; margin: 0; }
.detail-list li { margin-bottom: 0.35rem; }
</style>
