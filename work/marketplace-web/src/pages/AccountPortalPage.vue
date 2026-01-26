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
        <div class="account-actions">
          <button @click="handleLogout" class="logout-button">Çıkış</button>
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
            <router-link to="/listing/create" class="firm-panel-link">Firma Paneli</router-link>
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
      
      <!-- Refresh Button -->
      <div class="button-group">
        <button @click="refreshAll" :disabled="loading">
          {{ loading ? 'Yükleniyor...' : 'Yenile' }}
        </button>
      </div>
      
      <!-- Error State -->
      <div v-if="error" class="error-box">
        <h3>Hata</h3>
        <div class="error-details">
          <div><strong>Status:</strong> {{ error.status || 'N/A' }}</div>
          <div v-if="error.endpoint"><strong>Endpoint:</strong> {{ error.endpoint }}</div>
          <div><strong>Message:</strong> {{ error.message || 'Unknown error' }}</div>
        </div>
      </div>
      
      <!-- Loading State -->
      <div v-if="loading" class="loading-state">
        <p>Yükleniyor...</p>
      </div>
      
      <!-- Data Panels -->
      <div v-if="!loading && !error">
        <!-- Rezervasyonlarım -->
        <div class="result-section">
          <h3>Rezervasyonlarım</h3>
          <div v-if="reservations.length === 0" class="empty-state">
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
              <tr v-for="reservation in reservations" :key="reservation.id">
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
          <div v-if="rentals.length === 0" class="empty-state">
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
              <tr v-for="rental in rentals" :key="rental.id">
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
          <div v-if="orders.length === 0" class="empty-state">
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
              <tr v-for="order in orders" :key="order.id">
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
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { isLoggedIn, getUser, clearSession, getUserId, getActiveTenantId, setActiveTenantId } from '../lib/demoSession.js';
// WP-68: Removed isDemoMode import - single auth entry, no demo mode UI

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
      
      // State
      loading: false,
      membershipsLoading: false, // WP-68: Separate loading state for memberships
      error: null,
      lastRefreshed: null,
    };
  },
  computed: {
    isAuthenticated() {
      return isLoggedIn();
    },
    activeTenantId() {
      return getActiveTenantId();
    },
    activeTenantName() {
      if (!this.activeTenantId || this.memberships.length === 0) return null;
      const active = this.memberships.find(m => m.tenant_id === this.activeTenantId);
      return active ? (active.tenant_name || active.tenant_slug) : null;
    },
  },
  async mounted() {
    console.log('[AccountPortalPage] mounted() called, isAuthenticated:', this.isAuthenticated);
    if (this.isAuthenticated) {
      console.log('[AccountPortalPage] User is authenticated, loading data...');
      await this.loadUserInfo();
      await this.loadMemberships();
      this.refreshAll();
    } else {
      console.log('[AccountPortalPage] User is NOT authenticated, skipping data load');
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
      console.log('[AccountPortalPage] loadMemberships() called');
      this.membershipsLoading = true;
      try {
        // WP-68: Fetch memberships
        console.log('[AccountPortalPage] Calling api.getMyMemberships()...');
        const response = await api.getMyMemberships();
        console.log('[AccountPortalPage] getMyMemberships response:', response);
        this.memberships = response.items || response.data || (Array.isArray(response) ? response : []);
        console.log('[AccountPortalPage] memberships set to:', this.memberships);
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
        console.log('[AccountPortalPage] loadMemberships() completed, membershipsLoading:', this.membershipsLoading);
      }
    },
    setActiveTenant(tenantId) {
      // WP-68: Set active tenant
      setActiveTenantId(tenantId);
      this.$forceUpdate(); // Force re-render to show active state
    },
    formatDate(dateStr) {
      if (!dateStr) return 'N/A';
      try {
        return new Date(dateStr).toLocaleString();
      } catch {
        return dateStr;
      }
    },
    async refreshAll() {
      if (!this.isAuthenticated) {
        return;
      }
      
      this.loading = true;
      this.error = null;
      
      // WP-68: Get userId from token (single source of truth)
      const userId = getUserId();
      if (!userId) {
        // WP-68: No userId - clear session and redirect to login
        clearSession();
        this.$router.push('/login?reason=expired');
        return;
      }
      
      // WP-68: Token auto-attached by API wrapper, no need to pass manually
      
      // Clear previous data
      this.orders = [];
      this.rentals = [];
      this.reservations = [];
      
      try {
        // WP-68: Fetch all in parallel using client.js functions (auto-auth)
        const [ordersResp, rentalsResp, reservationsResp] = await Promise.all([
          api.getMyOrders(userId).catch(err => ({ ok: false, error: err })),
          api.getMyRentals(userId).catch(err => ({ ok: false, error: err })),
          api.getMyReservations(userId).catch(err => ({ ok: false, error: err })),
        ]);
        
        // Helper: Extract items from various response formats
        const extractItems = (r) => Array.isArray(r) ? r : (r?.data ?? r?.items ?? []);
        
        // Helper: Check if response is an error wrapper (only { ok: false } is treated as error)
        const isErrWrapper = (r) => r && typeof r === 'object' && r.ok === false;
        
        // WP-67: Handle 401 - clear session and redirect
        const errors = [];
        
        if (isErrWrapper(ordersResp)) {
          const err = ordersResp.error || ordersResp;
          if (err.status === 401) {
            clearSession();
            this.$router.push('/login?reason=expired');
            return;
          }
          errors.push({ panel: 'orders', status: err.status || 0, message: err.message || 'Failed to load orders', endpoint: '/v1/me/orders' });
        } else {
          // Extract data (API returns {data: [...]} or array or {items: [...]})
          this.orders = extractItems(ordersResp);
        }
        
        if (isErrWrapper(rentalsResp)) {
          const err = rentalsResp.error || rentalsResp;
          if (err.status === 401) {
            clearSession();
            this.$router.push('/login?reason=expired');
            return;
          }
          errors.push({ panel: 'rentals', status: err.status || 0, message: err.message || 'Failed to load rentals', endpoint: '/v1/me/rentals' });
        } else {
          this.rentals = extractItems(rentalsResp);
        }
        
        if (isErrWrapper(reservationsResp)) {
          const err = reservationsResp.error || reservationsResp;
          if (err.status === 401) {
            clearSession();
            this.$router.push('/login?reason=expired');
            return;
          }
          errors.push({ panel: 'reservations', status: err.status || 0, message: err.message || 'Failed to load reservations', endpoint: '/v1/me/reservations' });
        } else {
          this.reservations = extractItems(reservationsResp);
        }
        
        // Show first error if any, but don't block other panels
        if (errors.length > 0) {
          const firstError = errors[0];
          this.error = {
            status: firstError.status,
            message: firstError.message,
            endpoint: firstError.endpoint,
            allErrors: errors,
          };
        }
        
        this.lastRefreshed = new Date();
      } catch (error) {
        // WP-67: Handle 401 in catch block too
        if (error.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        this.error = {
          status: error.status || 0,
          message: error.message || 'Unknown error',
        };
      } finally {
        this.loading = false;
      }
    },
    handleLogout() {
      clearSession();
      this.$router.push('/login');
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

.account-actions {
  display: flex;
  gap: 1rem;
  margin-top: 1rem;
}

.firm-register-btn {
  padding: 0.5rem 1rem;
  background: #28a745;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-size: 0.9rem;
  display: inline-block;
}

.firm-register-btn:hover {
  background: #218838;
}

.logout-button {
  padding: 0.5rem 1rem;
  background: #dc3545;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.logout-button:hover {
  background: #c82333;
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

/* WP-68: Removed firm-demo-link styles - no longer used (single auth entry) */

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
