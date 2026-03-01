<template>
  <section class="records-panel-base">
    <h3 class="panel-title">{{ titleDisplay }}</h3>
    <p v-if="scope === 'firm'" class="section-hint">{{ hintDisplay }}</p>
    <ActionResultBox
      :loading="loading"
      :error="errorMsg"
      :empty="items.length === 0"
      :empty-text="emptyText"
      :on-retry="retry"
    />
    <div v-if="!loading && !errorMsg && items.length" class="section-list">
      <table class="data-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Ilan</th>
            <th v-if="kind === 'orders'">Toplam</th>
            <th v-if="kind === 'reservations'">Fiyat</th>
            <th v-if="kind === 'rentals'">Fiyat</th>
            <th>Durum</th>
            <th>Tarih</th>
            <th v-if="scope === 'firm'">Islem</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in items" :key="row.id">
            <td class="mono-cell" :title="safe(row.id)">
              <template v-if="scope === 'customer'">
                <router-link :to="detailLink(row)" class="id-link">{{ shortId(row.id) }}</router-link>
              </template>
              <template v-else>{{ shortId(row.id) }}</template>
            </td>
            <td :class="titleClass(row)" :title="safe(row.listing_id)">{{ listingDisplay(row) }}</td>
            <td v-if="kind === 'orders'">{{ formatOrderTotal(row) }}</td>
            <td v-if="kind === 'reservations'">{{ formatReservationPrice(row) }}</td>
            <td v-if="kind === 'rentals'">{{ formatRentalPrice(row) }}</td>
            <td><span class="status-pill">{{ statusLabel(row.status) }}</span></td>
            <td>{{ formatDate(row.created_at) }}</td>
            <td v-if="scope === 'firm'" class="actions-cell">
              <button
                type="button"
                class="btn-action"
                :disabled="!canApprove(row) || transitioning[row.id]"
                @click="accept(row.id)"
              >
                {{ transitioning[row.id] === 'accept' ? actionLabel('working') : actionLabel('accept') }}
              </button>
              <button
                type="button"
                class="btn-action btn-reject"
                :disabled="!canReject(row) || transitioning[row.id]"
                @click="reject(row.id)"
              >
                {{ transitioning[row.id] === 'reject' ? actionLabel('working') : actionLabel('reject') }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<script>
import { api, normalizeListResponse } from '../../api/client.js';
import { notifySuccess, notifyError } from '../../lib/toast/notify.js';
import { getActionLabel, getStatusLabel } from '../../lib/displayLabels.js';
import { formatDisplayDate, formatDisplayPrice, formatShortId } from '../../lib/displayFormatters.js';
import ActionResultBox from './ActionResultBox.vue';
import { buildOrderDetailLink, buildRentalDetailLink, buildReservationDetailLink } from '../account/account_record_links.js';

const EMPTY_TEXTS = { orders: 'Henuz siparis yok', rentals: 'Henuz kiralama yok', reservations: 'Henuz rezervasyon yok' };
const TITLES = {
  customer: { orders: 'Siparislerim', rentals: 'Kiralamalarim', reservations: 'Rezervasyonlarim' },
  firm: { orders: 'Gelen Siparisler', rentals: 'Gelen Kiralama Talepleri', reservations: 'Gelen Rezervasyonlar' },
};
const HINTS = {
  orders: 'Onayla veya Reddet ile siparis durumunu guncelleyebilirsiniz.',
  rentals: 'Onayla veya Reddet ile kiralama talebi durumunu guncelleyebilirsiniz.',
  reservations: 'Onayla veya Reddet ile rezervasyon durumunu guncelleyebilirsiniz.',
};
const LOAD_ERRORS = { orders: 'Siparisler yuklenemedi', rentals: 'Kiralamalar yuklenemedi', reservations: 'Rezervasyonlar yuklenemedi' };

function normalizeCustomerItems(res) {
  if (res == null) return [];
  return Array.isArray(res) ? res : (res.items || res.data || []) || [];
}

function extractFirmItems(resp) {
  const { items } = normalizeListResponse(resp);
  return Array.isArray(items) ? items : [];
}

export default {
  name: 'RecordsPanelBase',
  components: { ActionResultBox },
  props: {
    scope: { type: String, required: true, validator: (v) => ['firm', 'customer'].includes(v) },
    kind: { type: String, required: true, validator: (v) => ['orders', 'rentals', 'reservations'].includes(v) },
    title: { type: String, default: '' },
    activeTenantId: { type: String, default: '' },
    active: { type: Boolean, default: true },
  },
  data() {
    return {
      loading: false,
      errorMsg: null,
      items: [],
      listingTitlesById: {},
      transitioning: {},
      loadedOnce: false,
    };
  },
  computed: {
    titleDisplay() {
      return this.title || TITLES[this.scope]?.[this.kind] || this.kind;
    },
    hintDisplay() {
      return HINTS[this.kind] || '';
    },
    emptyText() {
      return EMPTY_TEXTS[this.kind] || 'Henuz veri yok';
    },
  },
  watch: {
    active: {
      handler(val) {
        if (this.scope === 'customer' && val && !this.loadedOnce) {
          this.load().then(() => { this.loadedOnce = true; }).catch(() => {});
        }
      },
      immediate: true,
    },
  },
  mounted() {
    if (this.scope === 'firm' && this.activeTenantId) this.load();
  },
  methods: {
    async load() {
      if (this.scope === 'firm' && !this.activeTenantId) return;
      if (this.scope === 'customer' && !this.active) return;
      this.loading = true;
      this.errorMsg = null;
      try {
        if (this.scope === 'customer') {
          const fn = { orders: api.getMyOrders, rentals: api.getMyRentals, reservations: api.getMyReservations }[this.kind];
          const res = await fn();
          this.items = normalizeCustomerItems(res);
        } else {
          const fn = { orders: api.getStoreOrders, rentals: api.getStoreRentals, reservations: api.getStoreReservations }[this.kind];
          const resp = await fn(this.activeTenantId);
          this.items = extractFirmItems(resp);
          await this.loadFirmListingTitles();
        }
      } catch (err) {
        this.errorMsg = err?.message || (typeof err === 'string' ? err : null) || LOAD_ERRORS[this.kind];
        if (this.scope === 'customer') this.items = [];
      } finally {
        this.loading = false;
      }
      return Promise.resolve();
    },
    retry() {
      return this.load();
    },
    async loadFirmListingTitles() {
      if (this.scope !== 'firm' || !this.activeTenantId) return;
      try {
        const resp = await api.getStoreListings(this.activeTenantId);
        const rows = extractFirmItems(resp);
        this.listingTitlesById = rows.reduce((acc, item) => {
          if (item?.id && item?.title) acc[item.id] = item.title;
          return acc;
        }, {});
      } catch {
        this.listingTitlesById = {};
      }
    },
    safe(val) {
      if (val == null || val === '') return '—';
      return val;
    },
    formatDate(dateStr) {
      return formatDisplayDate(dateStr);
    },
    formatPrice(amount, currency) {
      return formatDisplayPrice(amount, currency);
    },
    shortId(value) {
      return formatShortId(value);
    },
    statusLabel(status) {
      return getStatusLabel(status);
    },
    actionLabel(key) {
      return getActionLabel(key);
    },
    titleClass(row) {
      return this.listingTitlesById[row?.listing_id] ? '' : 'mono-cell';
    },
    listingDisplay(row) {
      return this.listingTitlesById[row?.listing_id] || this.shortId(row?.listing_id);
    },
    formatOrderTotal(row) {
      const totals = row?.totals;
      if (!totals || typeof totals !== 'object') return '—';
      return this.formatPrice(totals.subtotal, totals.currency);
    },
    formatReservationPrice(row) {
      if (!row || row.price_amount == null) return '—';
      return this.formatPrice(row.price_amount, row.price_currency);
    },
    formatRentalPrice(row) {
      if (!row || row.price_amount == null) return '—';
      return this.formatPrice(row.price_amount, row.price_currency);
    },
    detailLink(row) {
      const fns = { orders: buildOrderDetailLink, rentals: buildRentalDetailLink, reservations: buildReservationDetailLink };
      return fns[this.kind](row);
    },
    canApprove(row) {
      if (this.kind === 'orders') return row && row.status === 'placed';
      return row && row.status === 'requested';
    },
    canReject(row) {
      return this.canApprove(row);
    },
    async accept(id) {
      if (this.scope !== 'firm' || !this.activeTenantId) return;
      this.transitioning = { ...this.transitioning, [id]: 'accept' };
      this.errorMsg = null;
      try {
        const fns = { orders: api.acceptStoreOrder, rentals: api.acceptStoreRental, reservations: api.acceptStoreReservation };
        await fns[this.kind](id, this.activeTenantId);
        notifySuccess('Onaylandi');
        await this.load();
      } catch (err) {
        this.errorMsg = err?.message || err?.data?.message || 'Islem basarisiz';
        notifyError('Islem basarisiz');
      } finally {
        this.transitioning = { ...this.transitioning, [id]: false };
      }
    },
    async reject(id) {
      if (this.scope !== 'firm' || !this.activeTenantId) return;
      this.transitioning = { ...this.transitioning, [id]: 'reject' };
      this.errorMsg = null;
      try {
        const fns = { orders: api.rejectStoreOrder, rentals: api.rejectStoreRental, reservations: api.rejectStoreReservation };
        await fns[this.kind](id, this.activeTenantId);
        notifySuccess('Reddedildi');
        await this.load();
      } catch (err) {
        this.errorMsg = err?.message || err?.data?.message || 'Islem basarisiz';
        notifyError('Islem basarisiz');
      } finally {
        this.transitioning = { ...this.transitioning, [id]: false };
      }
    },
  },
};
</script>

<style scoped>
.records-panel-base {
  margin: 1.5rem 0;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.panel-title {
  margin-top: 0;
  margin-bottom: 0.25rem;
}

.section-hint {
  margin-top: 0;
  color: #666;
}

.section-list {
  overflow-x: auto;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  background: #fff;
}

.data-table th,
.data-table td {
  padding: 0.75rem;
  border-bottom: 1px solid #eee;
  text-align: left;
}

.data-table thead {
  background: #f5f5f5;
}

.actions-cell {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  white-space: nowrap;
}

.btn-action {
  padding: 0.35rem 0.7rem;
  border: 1px solid #2563eb;
  background: #2563eb;
  color: #fff;
  border-radius: 4px;
  cursor: pointer;
}

.btn-action:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-reject {
  border-color: #dc2626;
  background: #dc2626;
}

.id-link {
  color: #2563eb;
  text-decoration: none;
}

.mono-cell {
  font-family: Consolas, 'Courier New', monospace;
  white-space: nowrap;
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
