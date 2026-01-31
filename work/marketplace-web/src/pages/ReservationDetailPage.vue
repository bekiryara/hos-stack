<template>
  <div class="transaction-detail">
    <div class="detail-header">
      <router-link :to="{ path: '/account', query: { tab: 'reservations' } }" class="back-link">← Back to Account</router-link>
      <h2>Reservation {{ safe(item.id) }}</h2>
    </div>
    <LimitedViewBanner
      :show="limitedMode"
      :reason="limitedReason"
      :error-text="limitedErrorText"
    />
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
import LimitedViewBanner from '../components/common/LimitedViewBanner.vue';
import { api } from '../api/client.js';
import { buildLimitedFromQuery, classifyLimitedReason, LIMITED_REASON } from '../lib/detail/limited_view.js';
import { normalizeApiError } from '../lib/errors/api_error.js';

const RESERVATION_KEYS = ['listing_id', 'slot_start', 'slot_end', 'party_size', 'status', 'created_at', 'updated_at'];

export default {
  name: 'ReservationDetailPage',
  components: { SectionShell, LimitedViewBanner },
  props: { id: { type: String, required: true } },
  data() {
    return {
      loading: false,
      loadError: null,
      fetched: null,
      limited: {},
      limitedReason: null,
      limitedErrorText: null,
    };
  },
  computed: {
    item() {
      if (this.fetched) return { ...this.fetched, id: this.id };
      return { id: this.id, ...this.limited };
    },
    limitedMode() {
      return !this.fetched;
    },
  },
  mounted() {
    const id = this.id;
    this.limited = { ...buildLimitedFromQuery(this.$route.query, RESERVATION_KEYS) };
    if (!id) {
      this.limitedReason = LIMITED_REASON.NO_ID;
      return;
    }
    this.load();
  },
  methods: {
    safe(val) {
      if (val == null || val === '') return '—';
      return val;
    },
    async load() {
      this.loadError = null;
      this.limitedReason = null;
      this.limitedErrorText = null;
      this.loading = true;
      try {
        const res = await api.getMyReservationById(this.id);
        this.fetched = res?.data ?? res?.item ?? res ?? {};
      } catch (err) {
        this.limitedReason = classifyLimitedReason(err);
        const n = normalizeApiError(err);
        this.limitedErrorText = n.message;
        this.loadError = n.message;
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
.detail-list { list-style: none; padding: 0; margin: 0; }
.detail-list li { margin-bottom: 0.35rem; }
</style>
