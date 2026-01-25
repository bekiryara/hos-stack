<template>
  <div class="account-portal">
    <h2>Hesabım</h2>
    
    <!-- Logged-out view -->
    <div v-if="!isAuthenticated" class="logged-out-view">
      <div class="login-cta">
        <p>Hesabınızı görüntülemek için giriş yapın.</p>
        <router-link to="/auth" class="login-button">Giriş Yap</router-link>
      </div>
    </div>
    
    <!-- Logged-in view -->
    <div v-else>
      <!-- User Summary Card -->
      <div class="user-summary-card">
        <h3>Kullanıcı Bilgileri</h3>
        <div class="user-info">
          <div v-if="userEmail"><strong>Email:</strong> {{ userEmail }}</div>
          <div><strong>User ID:</strong> {{ userIdShort }}</div>
          <div v-if="activeTenantId"><strong>Active Tenant ID:</strong> {{ activeTenantId }}</div>
        </div>
        <div class="last-refreshed" v-if="lastRefreshed">
          Son yenileme: {{ formatDate(lastRefreshed) }}
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
import { api } from '../api/client';
import { getToken, getUserId, getTenantId, getActiveTenantId, decodeJwtPayload } from '../lib/demoSession.js';

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
      return getToken() !== null;
    },
    userId() {
      return getUserId();
    },
    userIdShort() {
      const uid = this.userId;
      return uid ? uid.substring(0, 8) + '...' : '(unknown)';
    },
    userEmail() {
      const token = getToken();
      if (!token) return null;
      const payload = decodeJwtPayload(token);
      return payload?.email || null;
    },
    activeTenantId() {
      return getActiveTenantId();
    },
  },
  mounted() {
    if (this.isAuthenticated) {
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
      
      const token = getToken();
      const userId = getUserId();
      
      if (!token || !userId) {
        this.error = {
          status: 401,
          message: 'Authentication required. Please login again.',
        };
        this.loading = false;
        return;
      }
      
      // Clear previous data
      this.orders = [];
      this.rentals = [];
      this.reservations = [];
      
      try {
        // Fetch all in parallel
        const [ordersResp, rentalsResp, reservationsResp] = await Promise.all([
          api.getMyOrders(userId, token).catch(err => ({ ok: false, error: err })),
          api.getMyRentals(userId, token).catch(err => ({ ok: false, error: err })),
          api.getMyReservations(userId, token).catch(err => ({ ok: false, error: err })),
        ]);
        
        // Check for errors - collect per-panel errors instead of failing all
        const errors = [];
        
        if (ordersResp.error || !ordersResp.ok) {
          const err = ordersResp.error || ordersResp;
          errors.push({ panel: 'orders', status: err.status || 0, message: err.message || 'Failed to load orders', endpoint: '/api/v1/orders' });
        } else {
          // Extract data (API returns arrays directly or wrapped in {data: ...})
          this.orders = Array.isArray(ordersResp) ? ordersResp : (ordersResp.data || []);
        }
        
        if (rentalsResp.error || !rentalsResp.ok) {
          const err = rentalsResp.error || rentalsResp;
          errors.push({ panel: 'rentals', status: err.status || 0, message: err.message || 'Failed to load rentals', endpoint: '/api/v1/rentals' });
        } else {
          this.rentals = Array.isArray(rentalsResp) ? rentalsResp : (rentalsResp.data || []);
        }
        
        if (reservationsResp.error || !reservationsResp.ok) {
          const err = reservationsResp.error || reservationsResp;
          errors.push({ panel: 'reservations', status: err.status || 0, message: err.message || 'Failed to load reservations', endpoint: '/api/v1/reservations' });
        } else {
          this.reservations = Array.isArray(reservationsResp) ? reservationsResp : (reservationsResp.data || []);
        }
        
        // Show first error if any, but don't block other panels
        if (errors.length > 0) {
          const firstError = errors[0];
          this.error = {
            status: firstError.status,
            message: firstError.message,
            endpoint: firstError.endpoint,
            allErrors: errors, // Store all errors for potential future use
          };
        }
        
        this.lastRefreshed = new Date();
      } catch (error) {
        this.error = {
          status: error.status || 0,
          message: error.message || 'Unknown error',
        };
      } finally {
        this.loading = false;
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
