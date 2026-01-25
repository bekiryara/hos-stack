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
          <div v-if="userEmail"><strong>Email:</strong> {{ userEmail }}</div>
        </div>
        <div class="account-actions">
          <button @click="handleLogout" class="logout-button">Çıkış</button>
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
import { apiRequest as hosApiRequest } from '../lib/api.js';
import { isLoggedIn, getUser, clearSession, getUserId, getBearerToken } from '../lib/demoSession.js';

export default {
  name: 'AccountPortalPage',
  data() {
    return {
      // Data
      orders: [],
      rentals: [],
      reservations: [],
      
      // State
      loading: false,
      error: null,
      lastRefreshed: null,
    };
  },
  computed: {
    isAuthenticated() {
      return isLoggedIn();
    },
    userEmail() {
      const user = getUser();
      return user?.email || null;
    },
    userIdShort() {
      const user = getUser();
      const id = user?.id;
      return id ? id.substring(0, 8) + '...' : '(unknown)';
    },
  },
  async mounted() {
    if (this.isAuthenticated) {
      // WP-67: Fetch user info from /v1/me first
      try {
        const meResponse = await hosApiRequest('/v1/me', { method: 'GET' }, true);
        // Update user info in session
        const user = getUser();
        if (user) {
          user.email = meResponse.email || user.email;
          user.id = meResponse.user_id || meResponse.id || user.id;
          // Save updated user info
          const { saveSession } = await import('../lib/demoSession.js');
          const token = getBearerToken().replace('Bearer ', '');
          saveSession(token, user);
        }
      } catch (err) {
        // If /v1/me fails with 401, clear session and redirect
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
      }
      this.refreshAll();
    }
  },
  methods: {
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
