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
            <th>{{ scope === 'firm' ? 'Listing ID' : 'Listing ID' }}</th>
            <th v-if="kind === 'orders'">{{ scope === 'firm' ? 'Toplam' : 'Total' }}</th>
            <th v-if="kind === 'reservations'">{{ scope === 'firm' ? 'Fiyat' : 'Price' }}</th>
            <th v-if="kind === 'rentals'">{{ scope === 'firm' ? 'Fiyat' : 'Price' }}</th>
            <th>{{ scope === 'firm' ? 'Durum' : 'Status' }}</th>
            <th>{{ scope === 'firm' ? 'Oluşturulma' : 'Created' }}</th>
            <th v-if="scope === 'firm'">İşlem</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in items" :key="row.id">
            <td>
              <template v-if="scope === 'customer'">
                <router-link :to="detailLink(row)" class="id-link">{{ safe(row.id) }}</router-link>
              </template>
              <template v-else>{{ row.id }}</template>
            </td>
            <td>{{ safe(row.listing_id) }}</td>
            <td v-if="kind === 'orders'">{{ formatOrderTotal(row) }}</td>
            <td v-if="kind === 'reservations'">{{ formatReservationPrice(row) }}</td>
            <td v-if="kind === 'rentals'">{{ formatRentalPrice(row) }}</td>
            <td>{{ safe(row.status) }}</td>
            <td>{{ scope === 'firm' ? formatDate(row.created_at) : safe(row.created_at) }}</td>
            <td v-if="scope === 'firm'" class="actions-cell">
              <button
                type="button"
                class="btn-action"
                :disabled="!canApprove(row) || transitioning[row.id]"
                @click="accept(row.id)"
              >
                {{ transitioning[row.id] === 'accept' ? 'Working…' : 'Accept' }}
              </button>
              <button
                type="button"
                class="btn-action btn-reject"
                :disabled="!canReject(row) || transitioning[row.id]"
                @click="reject(row.id)"
              >
                {{ transitioning[row.id] === 'reject' ? 'Working…' : 'Reject' }}
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
import ActionResultBox from './ActionResultBox.vue';
import { buildOrderDetailLink, buildRentalDetailLink, buildReservationDetailLink } from '../account/account_record_links.js';

const EMPTY_TEXTS = { orders: 'No orders yet', rentals: 'No rentals yet', reservations: 'No reservations yet' };
const TITLES = {
  customer: { orders: 'Orders', rentals: 'Rentals', reservations: 'Reservations' },
  firm: { orders: 'Gelen Siparişler', rentals: 'Gelen Kiralama Talepleri', reservations: 'Gelen Rezervasyonlar' },
};
const HINTS = {
  orders: 'Onayla veya Reddet ile sipariş durumunu güncelleyebilirsiniz.',
  rentals: 'Onayla veya Reddet ile kiralama talebi durumunu güncelleyebilirsiniz.',
  reservations: 'Onayla veya Reddet ile rezervasyon durumunu güncelleyebilirsiniz.',
};
const LOAD_ERRORS = { orders: 'Siparişler yüklenemedi', rentals: 'Kiralamalar yüklenemedi', reservations: 'Rezervasyonlar yüklenemedi' };

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
      return EMPTY_TEXTS[this.kind] || 'No data';
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
    safe(val) {
      if (val == null || val === '') return '—';
      return val;
    },
    formatDate(dateStr) {
      if (!dateStr) return '—';
      try {
        return new Date(dateStr).toLocaleString();
      } catch {
        return dateStr;
      }
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
        notifySuccess('Accepted');
        await this.load();
      } catch (err) {
        this.errorMsg = err?.message || err?.data?.message || 'İşlem başarısız';
        notifyError('Action failed');
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
        notifySuccess('Rejected');
        await this.load();
      } catch (err) {
        this.errorMsg = err?.message || err?.data?.message || 'İşlem başarısız';
        notifyError('Action failed');
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
  color: #333;
}

.section-hint {
  margin: 0 0 0.75rem 0;
  font-size: 0.875rem;
  color: #666;
}

.actions-cell {
  white-space: nowrap;
}

.btn-action {
  display: inline-block;
  margin-right: 0.5rem;
  padding: 0.25rem 0.5rem;
  font-size: 0.8rem;
  border-radius: 4px;
  border: 1px solid #007bff;
  background: #007bff;
  color: white;
  cursor: pointer;
}

.btn-action:hover {
  background: #0056b3;
}

.btn-action:disabled {
  background: #ccc;
  border-color: #999;
  color: #666;
  cursor: not-allowed;
}

.btn-action.btn-reject {
  background: #dc3545;
  border-color: #dc3545;
}

.btn-action.btn-reject:hover:not(:disabled) {
  background: #c82333;
}

.id-link {
  color: #0066cc;
  text-decoration: none;
}

.id-link:hover {
  text-decoration: underline;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  background: white;
  border-radius: 4px;
  overflow: hidden;
}

.data-table thead {
  background: #f5f5f5;
}

.data-table th {
  padding: 0.75rem;
  text-align: left;
  font-weight: 600;
  border-bottom: 2px solid #ddd;
}

.data-table td {
  padding: 0.75rem;
  border-bottom: 1px solid #eee;
}
</style>
