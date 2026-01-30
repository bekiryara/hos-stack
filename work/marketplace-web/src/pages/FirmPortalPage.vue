<template>
  <div class="firm-portal">
    <h2>Firma Paneli</h2>

    <!-- No active tenant: show warning + redirect (Step 7) -->
    <div v-if="!activeTenantId" class="no-tenant-warning">
      <p>Aktif firma seçilmedi. Firma panelini kullanmak için önce hesabınızdan bir firma seçin.</p>
      <router-link to="/account" class="btn-account">Hesaba Git</router-link>
    </div>

    <!-- With active tenant -->
    <template v-else>
      <div class="firm-info-bar">
        <p><strong>Aktif Firma ID:</strong> {{ activeTenantId }}</p>
        <p v-if="activeTenantName"><strong>Firma Adı:</strong> {{ activeTenantName }}</p>
      </div>

      <!-- Listings (Step 5) -->
      <section class="portal-section">
        <h3>İlanlarım</h3>
        <div v-if="listingsLoading" class="section-loading">Loading …</div>
        <div v-else-if="listingsError" class="section-error-box">
          <p>{{ listingsError }}</p>
          <button type="button" class="btn-retry" @click="loadListings">Retry</button>
        </div>
        <div v-else-if="!listings.length" class="section-empty">No listings yet</div>
        <div v-else class="section-list">
          <table class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Başlık</th>
                <th>Durum</th>
                <th>Kategori ID</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="item in listings" :key="item.id">
                <td>{{ item.id }}</td>
                <td>{{ item.title || '—' }}</td>
                <td>{{ item.status || '—' }}</td>
                <td>{{ item.category_id || '—' }}</td>
                <td class="actions-cell">
                  <router-link :to="`/listing/${item.id}`" class="btn-action">View</router-link>
                  <router-link :to="`/listing/${item.id}/message`" class="btn-action">Message</router-link>
                  <button type="button" class="btn-action btn-disabled" disabled title="not implemented">Edit</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <router-link v-if="activeTenantId" to="/listing/create" class="btn-primary">İlan Ver</router-link>
      </section>

      <!-- Orders (Step 6) -->
      <section class="portal-section">
        <h3>Gelen Siparişler</h3>
        <div v-if="ordersLoading" class="section-loading">Loading …</div>
        <div v-else-if="ordersError" class="section-error-box">
          <p>{{ ordersError }}</p>
          <button type="button" class="btn-retry" @click="loadOrders">Retry</button>
        </div>
        <div v-else-if="!orders.length" class="section-empty">No orders yet</div>
        <div v-else class="section-list">
          <table class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Durum</th>
                <th>Oluşturulma</th>
                <th>İşlem</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="item in orders" :key="item.id">
                <td>{{ item.id }}</td>
                <td>{{ item.listing_id || '—' }}</td>
                <td>{{ item.status || '—' }}</td>
                <td>{{ formatDate(item.created_at) }}</td>
                <td class="actions-cell">
                  <button type="button" class="btn-action" :disabled="!canApproveOrder(item) || orderTransitioning[item.id]" @click="transitionOrder(item.id, 'approve')">Onayla</button>
                  <button type="button" class="btn-action btn-reject" :disabled="!canRejectOrder(item) || orderTransitioning[item.id]" @click="transitionOrder(item.id, 'reject')">Reddet</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- Rentals (Step 6) -->
      <section class="portal-section">
        <h3>Gelen Kiralama Talepleri</h3>
        <div v-if="rentalsLoading" class="section-loading">Loading …</div>
        <div v-else-if="rentalsError" class="section-error-box">
          <p>{{ rentalsError }}</p>
          <button type="button" class="btn-retry" @click="loadRentals">Retry</button>
        </div>
        <div v-else-if="!rentals.length" class="section-empty">No rentals yet</div>
        <div v-else class="section-list">
          <table class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Durum</th>
                <th>Oluşturulma</th>
                <th>İşlem</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="item in rentals" :key="item.id">
                <td>{{ item.id }}</td>
                <td>{{ item.listing_id || '—' }}</td>
                <td>{{ item.status || '—' }}</td>
                <td>{{ formatDate(item.created_at) }}</td>
                <td class="actions-cell">
                  <button type="button" class="btn-action" :disabled="!canApproveRental(item) || rentalTransitioning[item.id]" @click="transitionRental(item.id, 'approve')">Onayla</button>
                  <button type="button" class="btn-action btn-reject" :disabled="!canRejectRental(item) || rentalTransitioning[item.id]" @click="transitionRental(item.id, 'reject')">Reddet</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- Reservations (Step 6) -->
      <section class="portal-section">
        <h3>Gelen Rezervasyonlar</h3>
        <div v-if="reservationsLoading" class="section-loading">Loading …</div>
        <div v-else-if="reservationsError" class="section-error-box">
          <p>{{ reservationsError }}</p>
          <button type="button" class="btn-retry" @click="loadReservations">Retry</button>
        </div>
        <div v-else-if="!reservations.length" class="section-empty">No reservations yet</div>
        <div v-else class="section-list">
          <table class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Durum</th>
                <th>Oluşturulma</th>
                <th>İşlem</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="item in reservations" :key="item.id">
                <td>{{ item.id }}</td>
                <td>{{ item.listing_id || '—' }}</td>
                <td>{{ item.status || '—' }}</td>
                <td>{{ formatDate(item.created_at) }}</td>
                <td class="actions-cell">
                  <button type="button" class="btn-action" :disabled="!canApproveReservation(item) || reservationTransitioning[item.id]" @click="transitionReservation(item.id, 'approve')">Onayla</button>
                  <button type="button" class="btn-action btn-reject" :disabled="!canRejectReservation(item) || reservationTransitioning[item.id]" @click="transitionReservation(item.id, 'reject')">Reddet</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </div>
</template>

<script>
import { getActiveTenantId } from '../lib/session.js';
import { api } from '../api/client.js';
import { normalizeListResponse } from '../api/client.js';

function extractItems(resp) {
  const { items } = normalizeListResponse(resp);
  return Array.isArray(items) ? items : [];
}

export default {
  name: 'FirmPortalPage',
  data() {
    return {
      activeTenantId: null,
      activeTenantName: null,
      memberships: [],
      listings: [],
      orders: [],
      rentals: [],
      reservations: [],
      listingsLoading: false,
      ordersLoading: false,
      rentalsLoading: false,
      reservationsLoading: false,
      listingsError: null,
      ordersError: null,
      rentalsError: null,
      reservationsError: null,
      orderTransitioning: {},
      rentalTransitioning: {},
      reservationTransitioning: {},
    };
  },
  async mounted() {
    this.activeTenantId = getActiveTenantId();
    if (!this.activeTenantId) return;
    await this.loadMembershipsForName();
    this.loadListings();
    this.loadOrders();
    this.loadRentals();
    this.loadReservations();
  },
  methods: {
    async loadMembershipsForName() {
      try {
        const response = await api.getMyMemberships();
        const list = response.items || response.data || (Array.isArray(response) ? response : []);
        this.memberships = list;
        const active = list.find(m => m.tenant_id === this.activeTenantId);
        this.activeTenantName = active ? (active.tenant_name || active.tenant_slug) : null;
      } catch {
        this.activeTenantName = null;
      }
    },
    async loadListings() {
      if (!this.activeTenantId) return;
      this.listingsLoading = true;
      this.listingsError = null;
      try {
        const resp = await api.getStoreListings(this.activeTenantId);
        this.listings = extractItems(resp);
      } catch (err) {
        this.listingsError = err.message || 'İlanlar yüklenemedi';
      } finally {
        this.listingsLoading = false;
      }
    },
    async loadOrders() {
      if (!this.activeTenantId) return;
      this.ordersLoading = true;
      this.ordersError = null;
      try {
        const resp = await api.getStoreOrders(this.activeTenantId);
        this.orders = extractItems(resp);
      } catch (err) {
        this.ordersError = err.message || 'Siparişler yüklenemedi';
      } finally {
        this.ordersLoading = false;
      }
    },
    async loadRentals() {
      if (!this.activeTenantId) return;
      this.rentalsLoading = true;
      this.rentalsError = null;
      try {
        const resp = await api.getStoreRentals(this.activeTenantId);
        this.rentals = extractItems(resp);
      } catch (err) {
        this.rentalsError = err.message || 'Kiralamalar yüklenemedi';
      } finally {
        this.rentalsLoading = false;
      }
    },
    async loadReservations() {
      if (!this.activeTenantId) return;
      this.reservationsLoading = true;
      this.reservationsError = null;
      try {
        const resp = await api.getStoreReservations(this.activeTenantId);
        this.reservations = extractItems(resp);
      } catch (err) {
        this.reservationsError = err.message || 'Rezervasyonlar yüklenemedi';
      } finally {
        this.reservationsLoading = false;
      }
    },
    formatDate(dateStr) {
      if (!dateStr) return '—';
      try {
        return new Date(dateStr).toLocaleString();
      } catch {
        return dateStr;
      }
    },
    canApproveOrder(item) {
      return item && (item.status === 'placed');
    },
    canRejectOrder(item) {
      return item && (item.status === 'placed');
    },
    canApproveRental(item) {
      return item && (item.status === 'requested');
    },
    canRejectRental(item) {
      return item && (item.status === 'requested');
    },
    canApproveReservation(item) {
      return item && (item.status === 'requested');
    },
    canRejectReservation(item) {
      return item && (item.status === 'requested');
    },
    async transitionOrder(id, action) {
      if (!this.activeTenantId) return;
      this.orderTransitioning = { ...this.orderTransitioning, [id]: true };
      this.ordersError = null;
      try {
        await api.transitionOrder(id, action, this.activeTenantId);
        await this.loadOrders();
      } catch (err) {
        this.ordersError = err.message || err.data?.message || 'İşlem başarısız';
      } finally {
        this.orderTransitioning = { ...this.orderTransitioning, [id]: false };
      }
    },
    async transitionRental(id, action) {
      if (!this.activeTenantId) return;
      this.rentalTransitioning = { ...this.rentalTransitioning, [id]: true };
      this.rentalsError = null;
      try {
        await api.transitionRental(id, action, this.activeTenantId);
        await this.loadRentals();
      } catch (err) {
        this.rentalsError = err.message || err.data?.message || 'İşlem başarısız';
      } finally {
        this.rentalTransitioning = { ...this.rentalTransitioning, [id]: false };
      }
    },
    async transitionReservation(id, action) {
      if (!this.activeTenantId) return;
      this.reservationTransitioning = { ...this.reservationTransitioning, [id]: true };
      this.reservationsError = null;
      try {
        await api.transitionReservation(id, action, this.activeTenantId);
        await this.loadReservations();
      } catch (err) {
        this.reservationsError = err.message || err.data?.message || 'İşlem başarısız';
      } finally {
        this.reservationTransitioning = { ...this.reservationTransitioning, [id]: false };
      }
    },
  },
};
</script>

<style scoped>
.firm-portal {
  max-width: 1000px;
  margin: 0 auto;
  padding: 2rem;
}

.firm-portal h2 {
  margin-top: 0;
  margin-bottom: 1.5rem;
  color: #333;
}

.no-tenant-warning {
  padding: 2rem;
  background: #fff3cd;
  border: 1px solid #ffc107;
  border-radius: 8px;
  margin-bottom: 1rem;
}

.no-tenant-warning p {
  margin: 0 0 1rem 0;
  color: #856404;
}

.btn-account {
  display: inline-block;
  padding: 0.75rem 1.5rem;
  background: #007bff;
  color: white;
  text-decoration: none;
  border-radius: 4px;
}

.btn-account:hover {
  background: #0056b3;
}

.firm-info-bar {
  margin-bottom: 1.5rem;
  padding: 1rem;
  background: #f8f9fa;
  border-radius: 4px;
  border: 1px solid #dee2e6;
}

.firm-info-bar p {
  margin: 0.25rem 0;
  color: #333;
}

.portal-section {
  margin: 1.5rem 0;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.portal-section h3 {
  margin-top: 0;
  margin-bottom: 1rem;
  color: #333;
}

.section-loading,
.section-error,
.section-empty {
  padding: 1rem 0;
  color: #666;
}

.section-error-box {
  padding: 1rem;
  background: #ffebee;
  border: 1px solid #d32f2f;
  border-radius: 4px;
  color: #c62828;
}

.section-error-box p {
  margin: 0 0 0.75rem 0;
}

.btn-retry {
  padding: 0.4rem 0.8rem;
  background: #d32f2f;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.875rem;
}

.btn-retry:hover {
  background: #b71c1c;
}

.actions-cell {
  white-space: nowrap;
}

.btn-action {
  display: inline-block;
  margin-right: 0.5rem;
  padding: 0.25rem 0.5rem;
  font-size: 0.8rem;
  text-decoration: none;
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

.btn-action.btn-disabled {
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

.section-empty {
  font-style: italic;
  color: #999;
}

.btn-primary {
  display: inline-block;
  margin-top: 0.75rem;
  padding: 0.5rem 1rem;
  background: #28a745;
  color: white;
  text-decoration: none;
  border-radius: 4px;
}

.btn-primary:hover {
  background: #218838;
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
