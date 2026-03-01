<template>
  <div class="transaction-detail">
    <div class="detail-header">
      <router-link :to="{ path: '/account', query: { tab: 'reservations' } }" class="back-link">← Back to Account</router-link>
      <h2>Reservation {{ safe(item.id) }}</h2>
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
        <li><strong>offer_id:</strong> {{ safe(item.offer_id) }}</li>
        <li><strong>pricing_source:</strong> {{ safe(item.pricing_source) }}</li>
        <li><strong>price_amount:</strong> {{ formatPrice(item.price_amount, item.price_currency) }}</li>
        <li><strong>billing_model:</strong> {{ safe(item.billing_model) }}</li>
        <li><strong>slot_start:</strong> {{ safe(item.slot_start) }}</li>
        <li><strong>slot_end:</strong> {{ safe(item.slot_end) }}</li>
        <li><strong>party_size:</strong> {{ safe(item.party_size) }}</li>
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
  name: 'ReservationDetailPage',
  components: { SectionShell },
  props: { id: { type: String, required: true } },
  data() {
    return {
      loading: false,
      loadError: null,
      fetched: null,
      limited: { id: this.id, listing_id: null, slot_start: null, slot_end: null, party_size: null, status: null, created_at: null, updated_at: null },
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
        offer_id: q.offer_id ?? null,
        pricing_source: q.pricing_source ?? null,
        price_amount: q.price_amount ?? null,
        price_currency: q.price_currency ?? null,
        billing_model: q.billing_model ?? null,
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
    formatPrice(amount, currency) {
      const numeric = Number(amount);
      if (!Number.isFinite(numeric)) return '—';
      const c = currency || 'TRY';
      try {
        return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: c, minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(numeric);
      } catch {
        return `${numeric} ${c}`;
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
