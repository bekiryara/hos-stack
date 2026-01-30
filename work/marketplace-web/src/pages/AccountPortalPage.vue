<template>
  <div class="account-portal">
    <h2>Hesabım</h2>
    
    <!-- Logged-out view -->
    <div v-if="!isAuthenticated" class="logged-out-view">
      <div class="login-cta">
        <p>Hesabınızı görüntülemek için giriş yapın.</p>
        <router-link to="/login" class="login-button">Giriş Yap</router-link>
      </div>
    </div>
    
    <!-- Logged-in view -->
    <div v-else>
      <!-- User Summary Card -->
      <div class="user-summary-card">
        <h3>Kullanıcı Bilgileri</h3>
        <div class="user-info">
          <div v-if="userInfo.email"><strong>Email:</strong> {{ userInfo.email }}</div>
          <div v-if="userInfo.display_name"><strong>Ad:</strong> {{ userInfo.display_name }}</div>
          <div v-if="userInfo.memberships_count !== undefined"><strong>Firma Sayısı:</strong> {{ userInfo.memberships_count }}</div>
        </div>
      </div>
      
      <!-- WP-68: Firm Status Card (ALWAYS RENDER) -->
      <div class="firm-status-card">
        <h3>Firma Durumu</h3>
        <div v-if="membershipsLoading" class="loading-firm-state">
          <p>Firma bilgileri yükleniyor...</p>
        </div>
        <div v-else-if="memberships.length === 0" class="no-firm-state">
          <p>Henüz bir firmanız yok. Firma oluşturarak ilan verebilirsiniz.</p>
          <router-link to="/firm/register" class="firm-register-btn-primary">Firma Oluştur</router-link>
        </div>
        <div v-else class="has-firm-state">
          <div class="firm-info">
            <p><strong>Aktif Firma:</strong> {{ activeTenantName || 'Seçilmemiş' }}</p>
            <p v-if="activeTenantId"><strong>Firma ID:</strong> {{ activeTenantId.substring(0, 8) }}...</p>
            <p v-if="activeTenantId"><strong>Durum:</strong> <span class="status-active">AKTİF</span></p>
          </div>
          <div class="firm-actions">
            <router-link v-if="activeTenantId" to="/firm" class="firm-panel-link">Firma Paneli</router-link>
            <span v-else class="firm-panel-disabled">Firma paneli için aktif firma seçin.</span>
          </div>
        </div>
      </div>
      
      <!-- WP-68: Active Tenant Selection -->
      <div v-if="memberships.length > 0" class="tenant-selection-card">
        <h3>Firmalarım</h3>
        <div class="memberships-list">
          <div v-for="membership in memberships" :key="membership.tenant_id" class="membership-item" :class="{ active: membership.tenant_id === activeTenantId }">
            <div class="membership-info">
              <strong>{{ membership.tenant_name || membership.tenant_slug }}</strong>
              <span class="membership-role">{{ membership.role }}</span>
            </div>
            <button 
              v-if="membership.tenant_id !== activeTenantId"
              @click="setActiveTenant(membership.tenant_id)"
              class="set-active-btn"
            >
              Aktif Firma Yap
            </button>
            <span v-else class="active-badge">Aktif</span>
          </div>
        </div>
      </div>
      
      <!-- Refresh Button (WP-NEXT: panel isolation — refresh all) -->
      <div class="button-group">
        <button @click="refreshAll" :disabled="anyPanelLoading">
          {{ anyPanelLoading ? 'Yükleniyor...' : 'Yenile' }}
        </button>
      </div>

      <!-- Data Panels (WP-NEXT: per-panel loading + error + retry + empty) -->
      <!-- Rezervasyonlarım -->
      <div class="result-section">
        <h3>Rezervasyonlarım</h3>
        <div v-if="reservationsLoading" class="section-loading">Yükleniyor …</div>
        <div v-else-if="panelErrors.reservations" class="error-box">
          <div class="error-details">
            <div><strong>Message:</strong> {{ panelErrors.reservations.message || 'Unknown error' }}</div>
            <button type="button" class="btn-retry" @click="loadReservations">Yeniden dene</button>
          </div>
        </div>
        <div v-else-if="(reservations || []).length === 0" class="empty-state">
          Henüz rezervasyon yok
        </div>
        <table v-else class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Slot Start</th>
                <th>Slot End</th>
                <th>Party Size</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="reservation in (reservations || [])" :key="reservation.id">
                <td>{{ reservation.id }}</td>
                <td>{{ reservation.listing_id }}</td>
                <td>{{ formatDate(reservation.slot_start) }}</td>
                <td>{{ formatDate(reservation.slot_end) }}</td>
                <td>{{ reservation.party_size }}</td>
                <td>{{ reservation.status }}</td>
              </tr>
            </tbody>
          </table>
      </div>

      <!-- Kiralamalarım -->
      <div class="result-section">
        <h3>Kiralamalarım</h3>
        <div v-if="rentalsLoading" class="section-loading">Yükleniyor …</div>
        <div v-else-if="panelErrors.rentals" class="error-box">
          <div class="error-details">
            <div><strong>Message:</strong> {{ panelErrors.rentals.message || 'Unknown error' }}</div>
            <button type="button" class="btn-retry" @click="loadRentals">Yeniden dene</button>
          </div>
        </div>
        <div v-else-if="(rentals || []).length === 0" class="empty-state">
          Henüz kiralama yok
        </div>
        <table v-else class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Start</th>
                <th>End</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="rental in (rentals || [])" :key="rental.id">
                <td>{{ rental.id }}</td>
                <td>{{ rental.listing_id }}</td>
                <td>{{ formatDate(rental.start_at) }}</td>
                <td>{{ formatDate(rental.end_at) }}</td>
                <td>{{ rental.status }}</td>
              </tr>
            </tbody>
          </table>
      </div>

      <!-- Siparişlerim -->
      <div class="result-section">
        <h3>Siparişlerim</h3>
        <div v-if="ordersLoading" class="section-loading">Yükleniyor …</div>
        <div v-else-if="panelErrors.orders" class="error-box">
          <div class="error-details">
            <div><strong>Message:</strong> {{ panelErrors.orders.message || 'Unknown error' }}</div>
            <button type="button" class="btn-retry" @click="loadOrders">Yeniden dene</button>
          </div>
        </div>
        <div v-else-if="(orders || []).length === 0" class="empty-state">
          Henüz sipariş yok
        </div>
        <table v-else class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Status</th>
                <th>Quantity</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="order in (orders || [])" :key="order.id">
                <td>{{ order.id }}</td>
                <td>{{ order.listing_id }}</td>
                <td>{{ order.status }}</td>
                <td>{{ order.quantity }}</td>
                <td>{{ formatDate(order.created_at) }}</td>
              </tr>
            </tbody>
          </table>
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { isLoggedIn, getUser, clearSession, getUserId, getActiveTenantId, setActiveTenantId } from '../lib/session.js';

export default {
  name: 'AccountPortalPage',
  data() {
    return {
      // Data
      orders: [],
      rentals: [],
      reservations: [],
      userInfo: {},
      memberships: [],
      activeTenantIdValue: getActiveTenantId(),
      
      // State (WP-NEXT: per-panel loading for isolation)
      ordersLoading: false,
      rentalsLoading: false,
      reservationsLoading: false,
      membershipsLoading: false, // WP-68: Separate loading state for memberships
      panelErrors: {
        orders: null,
        rentals: null,
        reservations: null,
      },
      lastRefreshed: null,
    };
  },
  computed: {
    isAuthenticated() {
      return isLoggedIn();
    },
    activeTenantId() {
      return this.activeTenantIdValue;
    },
    activeTenantName() {
      if (!this.activeTenantId || this.memberships.length === 0) return null;
      const active = this.memberships.find(m => m.tenant_id === this.activeTenantId);
      return active ? (active.tenant_name || active.tenant_slug) : null;
    },
  },
  async mounted() {
    if (this.isAuthenticated) {
      await this.loadUserInfo();
      await this.loadMemberships();
      this.refreshAll();
    }
  },
  methods: {
    async loadUserInfo() {
      try {
        // WP-68: Fetch user info from /v1/me
        this.userInfo = await api.getMe();
      } catch (err) {
        // If /v1/me fails with 401, clear session and redirect
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        console.error('Failed to load user info:', err);
      }
    },
    async loadMemberships() {
      this.membershipsLoading = true;
      try {
        const response = await api.getMyMemberships();
        this.memberships = response.items || response.data || (Array.isArray(response) ? response : []);

        // Keep active tenant id in sync (single source of truth: session storage)
        this.activeTenantIdValue = getActiveTenantId();
        if (this.memberships.length > 0 && !this.activeTenantIdValue) {
          // If user has memberships but no active tenant selected, default to first membership
          const first = this.memberships[0];
          if (first && first.tenant_id) {
            setActiveTenantId(first.tenant_id);
            this.activeTenantIdValue = first.tenant_id;
          }
        }
      } catch (err) {
        console.error('[AccountPortalPage] Failed to load memberships:', err);
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        this.memberships = []; // Set empty array on error
      } finally {
        this.membershipsLoading = false;
      }
    },
    setActiveTenant(tenantId) {
      setActiveTenantId(tenantId);
      this.activeTenantIdValue = tenantId || null;
      if (this.isAuthenticated) this.refreshAll();
    },
    // WP-NEXT: null-safe extract (no crash on null/undefined response)
    extractItems(resp) {
      if (resp == null) return [];
      return Array.isArray(resp) ? resp : (resp.data ?? resp.items ?? []) ?? [];
    },
    async loadOrders() {
      const userId = getUserId();
      if (!userId) {
        clearSession();
        this.$router.push('/login?reason=expired');
        return;
      }
      this.ordersLoading = true;
      this.panelErrors.orders = null;
      try {
        const resp = await api.getMyOrders(userId);
        this.orders = this.extractItems(resp);
      } catch (err) {
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        this.panelErrors = { ...this.panelErrors, orders: { panel: 'orders', status: err.status || 0, message: err.message || 'Failed to load orders', endpoint: '/v1/me/orders' } };
        this.orders = [];
      } finally {
        this.ordersLoading = false;
      }
    },
    async loadRentals() {
      const userId = getUserId();
      if (!userId) {
        clearSession();
        this.$router.push('/login?reason=expired');
        return;
      }
      this.rentalsLoading = true;
      this.panelErrors.rentals = null;
      try {
        const resp = await api.getMyRentals(userId);
        this.rentals = this.extractItems(resp);
      } catch (err) {
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        this.panelErrors = { ...this.panelErrors, rentals: { panel: 'rentals', status: err.status || 0, message: err.message || 'Failed to load rentals', endpoint: '/v1/me/rentals' } };
        this.rentals = [];
      } finally {
        this.rentalsLoading = false;
      }
    },
    async loadReservations() {
      const userId = getUserId();
      if (!userId) {
        clearSession();
        this.$router.push('/login?reason=expired');
        return;
      }
      this.reservationsLoading = true;
      this.panelErrors.reservations = null;
      try {
        const resp = await api.getMyReservations(userId);
        this.reservations = this.extractItems(resp);
      } catch (err) {
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        this.panelErrors = { ...this.panelErrors, reservations: { panel: 'reservations', status: err.status || 0, message: err.message || 'Failed to load reservations', endpoint: '/v1/me/reservations' } };
        this.reservations = [];
      } finally {
        this.reservationsLoading = false;
      }
    },
    refreshAll() {
      if (!this.isAuthenticated) return;
      this.loadOrders();
      this.loadRentals();
      this.loadReservations();
    },
    formatDate(dateStr) {
      if (!dateStr) return 'N/A';
      try {
        return new Date(dateStr).toLocaleString();
      } catch {
        return dateStr;
      }
    },
  },
};
</script>

<style scoped>
.account-portal {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.logged-out-view {
  margin: 2rem 0;
}

.login-cta {
  text-align: center;
  padding: 3rem;
  background: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.login-cta p {
  margin-bottom: 1.5rem;
  font-size: 1.1rem;
  color: #666;
}

.login-button {
  display: inline-block;
  padding: 0.75rem 2rem;
  background: #007bff;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-size: 1rem;
}

.login-button:hover {
  background: #0056b3;
}

.user-summary-card {
  margin: 1rem 0;
  padding: 1.5rem;
  background: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.user-summary-card h3 {
  margin-top: 0;
  margin-bottom: 1rem;
  color: #333;
}

.user-info {
  margin-bottom: 1rem;
}

.user-info div {
  margin: 0.5rem 0;
  color: #666;
}

.last-refreshed {
  font-size: 0.875rem;
  color: #999;
  font-style: italic;
}

.button-group {
  display: flex;
  gap: 0.5rem;
  margin: 1rem 0;
}

.button-group button {
  padding: 0.75rem 1.5rem;
  background: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
}

.button-group button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.button-group button:hover:not(:disabled) {
  background: #0052a3;
}

.loading-state {
  padding: 2rem;
  text-align: center;
  color: #666;
}

.firm-panel-disabled {
  color: #666;
  font-size: 0.9rem;
}

.tenant-selection-card {
  margin: 1rem 0;
  padding: 1.5rem;
  background: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.tenant-selection-card h3 {
  margin-top: 0;
  margin-bottom: 1rem;
  color: #333;
}

.memberships-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.membership-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: white;
  border-radius: 4px;
  border: 1px solid #dee2e6;
}

.membership-item.active {
  border-color: #007bff;
  background: #e7f3ff;
}

.membership-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.membership-role {
  font-size: 0.875rem;
  color: #666;
  text-transform: capitalize;
}

.set-active-btn {
  padding: 0.5rem 1rem;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.875rem;
}

.set-active-btn:hover {
  background: #0056b3;
}

.active-badge {
  padding: 0.25rem 0.75rem;
  background: #28a745;
  color: white;
  border-radius: 12px;
  font-size: 0.875rem;
}

/* WP-67: Firm Status Card */
.firm-status-card {
  margin: 1rem 0;
  padding: 1.5rem;
  background: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.firm-status-card h3 {
  margin-top: 0;
  margin-bottom: 1rem;
  color: #333;
}

.no-firm-state {
  text-align: center;
  padding: 1rem 0;
}

.no-firm-state p {
  margin-bottom: 1.5rem;
  color: #666;
}

.firm-register-btn-primary {
  display: inline-block;
  padding: 0.75rem 2rem;
  background: #28a745;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-size: 1rem;
  font-weight: 600;
}

.firm-register-btn-primary:hover {
  background: #218838;
}

.has-firm-state {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 1rem;
}

.firm-info {
  flex: 1;
  min-width: 200px;
}

.firm-info p {
  margin: 0.5rem 0;
  color: #333;
}

.firm-actions {
  display: flex;
  gap: 1rem;
}

/* WP-68: firm link styles cleaned up */

.loading-firm-state {
  text-align: center;
  padding: 1rem 0;
  color: #666;
}

.status-active {
  color: #28a745;
  font-weight: 600;
}

.error-box {
  margin: 1rem 0;
  padding: 1rem;
  background: #ffebee;
  border-radius: 4px;
  border: 1px solid #d32f2f;
}

.error-box h3 {
  margin-top: 0;
  margin-bottom: 0.5rem;
  color: #d32f2f;
}

.error-details {
  color: #c62828;
}

.error-details div {
  margin: 0.5rem 0;
}

.result-section {
  margin: 2rem 0;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.result-section h3 {
  margin-top: 0;
  margin-bottom: 1rem;
  color: #333;
}

.section-loading {
  padding: 1rem;
  color: #666;
}

.btn-retry {
  margin-top: 0.5rem;
  padding: 0.5rem 1rem;
  background: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.btn-retry:hover {
  background: #0052a3;
}

.empty-state {
  padding: 2rem;
  text-align: center;
  color: #999;
  font-style: italic;
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

.data-table tbody tr:hover {
  background: #f9f9f9;
}
</style>
