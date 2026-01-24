<template>
  <div class="account-portal">
    <h2>Account Portal</h2>
    
    <!-- Access Section -->
    <div class="access-section">
      <h3>Access</h3>
      
      <div class="form-row">
        <label>
          Base URL:
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <input v-model="baseUrl" type="text" placeholder="http://localhost:8080" @blur="onBaseUrlBlur" style="flex: 1;" />
            <button @click="resetBaseUrl" class="reset-btn" type="button">Reset</button>
          </div>
          <div v-if="baseUrlWarning" class="warning-box" style="margin-top: 0.5rem; padding: 0.5rem; background: #fff3cd; border: 1px solid #ffc107; border-radius: 4px; color: #856404;">
            {{ baseUrlWarning }}
          </div>
        </label>
      </div>
      
      <div class="form-row">
        <label>
          Authorization Token:
          <div class="token-input">
            <input 
              v-model="authToken" 
              :type="showToken ? 'text' : 'password'" 
              placeholder="Bearer ..." 
              @blur="saveToLocalStorage"
              style="width: 100%;"
            />
            <button @click="showToken = !showToken" class="toggle-btn">
              {{ showToken ? 'Hide' : 'Show' }}
            </button>
          </div>
        </label>
      </div>
      
      <div class="form-row">
        <label>
          Mode:
          <select v-model="mode" @change="saveToLocalStorage">
            <option value="personal">Personal</option>
            <option value="store">Store</option>
          </select>
        </label>
      </div>
      
      <div v-if="mode === 'personal'" class="form-row">
        <label>
          User ID:
          <input v-model="userId" type="text" placeholder="UUID" @blur="saveToLocalStorage" />
        </label>
      </div>
      
      <div v-if="mode === 'store'" class="form-row">
        <label>
          Tenant ID:
          <input v-model="tenantId" type="text" placeholder="UUID" @blur="saveToLocalStorage" />
        </label>
      </div>
      
      <div class="button-group">
        <button @click="refreshAll" :disabled="loading">
          {{ loading ? 'Loading...' : 'Refresh' }}
        </button>
      </div>
    </div>

    <!-- Results Section -->
    <div class="results-section">
      <!-- Loading State -->
      <div v-if="loading" class="loading-state">
        <p>Loading data...</p>
      </div>
      
      <!-- Error State -->
      <div v-if="error" class="error-box">
        <h3>Error</h3>
        <div class="error-details">
          <div><strong>Status:</strong> {{ error.status || 'N/A' }}</div>
          <div v-if="error.endpoint"><strong>Endpoint:</strong> {{ error.endpoint }}</div>
          <div v-if="error.errorCode"><strong>Error Code:</strong> {{ error.errorCode }}</div>
          <div><strong>Message:</strong> {{ error.message || 'Unknown error' }}</div>
          <div v-if="error.hint" class="error-hint" style="margin-top: 0.5rem; padding: 0.5rem; background: #f8f9fa; border-left: 3px solid #dc3545; font-style: italic;">
            <strong>Hint:</strong> {{ error.hint }}
          </div>
        </div>
      </div>
      
      <!-- Personal Mode Results -->
      <div v-if="mode === 'personal' && !loading && !error">
        <div class="result-section">
          <h3>My Orders</h3>
          <div v-if="personalOrders.length === 0" class="empty-state">
            No orders yet
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
              <tr v-for="order in personalOrders" :key="order.id">
                <td>{{ order.id }}</td>
                <td>{{ order.listing_id }}</td>
                <td>{{ order.status }}</td>
                <td>{{ order.quantity }}</td>
                <td>{{ formatDate(order.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        
        <div class="result-section">
          <h3>My Rentals</h3>
          <div v-if="personalRentals.length === 0" class="empty-state">
            No rentals yet
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
              <tr v-for="rental in personalRentals" :key="rental.id">
                <td>{{ rental.id }}</td>
                <td>{{ rental.listing_id }}</td>
                <td>{{ formatDate(rental.start_at) }}</td>
                <td>{{ formatDate(rental.end_at) }}</td>
                <td>{{ rental.status }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        
        <div class="result-section">
          <h3>My Reservations</h3>
          <div v-if="personalReservations.length === 0" class="empty-state">
            No reservations yet
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
              <tr v-for="reservation in personalReservations" :key="reservation.id">
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
      </div>
      
      <!-- Store Mode Results -->
      <div v-if="mode === 'store' && !loading && !error">
        <div class="result-section">
          <h3>Store Listings</h3>
          <div v-if="storeListings.length === 0" class="empty-state">
            No listings yet
          </div>
          <table v-else class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Title</th>
                <th>Category ID</th>
                <th>Status</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="listing in storeListings" :key="listing.id">
                <td>{{ listing.id }}</td>
                <td>{{ listing.title }}</td>
                <td>{{ listing.category_id }}</td>
                <td>{{ listing.status }}</td>
                <td>{{ formatDate(listing.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        
        <div class="result-section">
          <h3>Store Orders</h3>
          <div v-if="storeOrders.length === 0" class="empty-state">
            No orders yet
          </div>
          <table v-else class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Buyer User ID</th>
                <th>Status</th>
                <th>Quantity</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="order in storeOrders" :key="order.id">
                <td>{{ order.id }}</td>
                <td>{{ order.listing_id }}</td>
                <td>{{ order.buyer_user_id }}</td>
                <td>{{ order.status }}</td>
                <td>{{ order.quantity }}</td>
                <td>{{ formatDate(order.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        
        <div class="result-section">
          <h3>Store Rentals</h3>
          <div v-if="storeRentals.length === 0" class="empty-state">
            No rentals yet
          </div>
          <table v-else class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Renter User ID</th>
                <th>Start</th>
                <th>End</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="rental in storeRentals" :key="rental.id">
                <td>{{ rental.id }}</td>
                <td>{{ rental.listing_id }}</td>
                <td>{{ rental.renter_user_id }}</td>
                <td>{{ formatDate(rental.start_at) }}</td>
                <td>{{ formatDate(rental.end_at) }}</td>
                <td>{{ rental.status }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        
        <div class="result-section">
          <h3>Store Reservations</h3>
          <div v-if="storeReservations.length === 0" class="empty-state">
            No reservations yet
          </div>
          <table v-else class="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Listing ID</th>
                <th>Requester User ID</th>
                <th>Slot Start</th>
                <th>Slot End</th>
                <th>Party Size</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="reservation in storeReservations" :key="reservation.id">
                <td>{{ reservation.id }}</td>
                <td>{{ reservation.listing_id }}</td>
                <td>{{ reservation.requester_user_id }}</td>
                <td>{{ formatDate(reservation.slot_start) }}</td>
                <td>{{ formatDate(reservation.slot_end) }}</td>
                <td>{{ reservation.party_size }}</td>
                <td>{{ reservation.status }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { personalApi, storeApi, normalizeToken } from '../lib/pazarApi.js';
import { getToken } from '../lib/demoSession.js';

// Normalize Pazar host URL
function normalizePazarHost(baseUrl) {
  if (!baseUrl) return 'http://localhost:8080';
  
  let normalized = baseUrl.trim();
  
  // Remove trailing slash
  if (normalized.endsWith('/')) {
    normalized = normalized.slice(0, -1);
  }
  
  // Check if contains /api segment (likely HOS proxy, not Pazar host)
  if (normalized.includes('/api')) {
    return null; // Invalid - indicates proxy URL
  }
  
  return normalized;
}

export default {
  name: 'AccountPortalPage',
  data() {
    return {
      baseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080',
      authToken: '',
      mode: 'personal',
      userId: '',
      tenantId: '',
      showToken: false,
      baseUrlWarning: null,
      
      // Data
      personalOrders: [],
      personalRentals: [],
      personalReservations: [],
      storeListings: [],
      storeOrders: [],
      storeRentals: [],
      storeReservations: [],
      
      // State
      loading: false,
      error: null,
    };
  },
  mounted() {
    this.loadFromLocalStorage();
    this.checkBaseUrl();
    this.autoFillFromDemo();
  },
  methods: {
    checkBaseUrl() {
      const normalized = normalizePazarHost(this.baseUrl);
      if (normalized === null) {
        this.baseUrlWarning = 'This points to HOS API proxy. Pazar host should be http://localhost:8080';
        // Auto-switch to default
        this.baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';
        this.saveToLocalStorage();
      } else {
        this.baseUrl = normalized;
        this.baseUrlWarning = null;
      }
    },
    resetBaseUrl() {
      this.baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';
      this.baseUrlWarning = null;
      this.saveToLocalStorage();
    },
    autoFillFromDemo() {
      // Auto-fill token from demo session if empty, whitespace, or incomplete
      const currentToken = this.authToken ? this.authToken.trim() : '';
      // JWT token should have 3 parts separated by dots (header.payload.signature)
      const isTokenIncomplete = currentToken && currentToken.split('.').length !== 3;
      
      if (!currentToken || isTokenIncomplete) {
        const demoToken = getToken();
        if (demoToken && demoToken.trim()) {
          this.authToken = demoToken.trim();
          this.saveToLocalStorage(); // Save immediately
        }
      }
      
      // Auto-fill userId from localStorage if empty
      if (!this.userId && this.mode === 'personal') {
        const savedUserId = localStorage.getItem('accountPortal_userId');
        if (savedUserId) {
          this.userId = savedUserId;
        }
      }
      
      // Auto-fill tenantId from active tenant if empty
      if (!this.tenantId && this.mode === 'store') {
        const activeTenantId = localStorage.getItem('active_tenant_id');
        if (activeTenantId) {
          this.tenantId = activeTenantId;
        }
      }
    },
    saveToLocalStorage() {
      if (typeof localStorage !== 'undefined') {
        const normalized = normalizePazarHost(this.baseUrl);
        if (normalized) {
          localStorage.setItem('accountPortal_baseUrl', normalized);
        }
        localStorage.setItem('accountPortal_authToken', this.authToken);
        localStorage.setItem('accountPortal_mode', this.mode);
        localStorage.setItem('accountPortal_userId', this.userId);
        localStorage.setItem('accountPortal_tenantId', this.tenantId);
      }
    },
    loadFromLocalStorage() {
      if (typeof localStorage !== 'undefined') {
        this.baseUrl = localStorage.getItem('accountPortal_baseUrl') || this.baseUrl;
        const savedToken = localStorage.getItem('accountPortal_authToken');
        // Only use saved token if it's not empty/whitespace
        this.authToken = (savedToken && savedToken.trim()) ? savedToken : '';
        this.mode = localStorage.getItem('accountPortal_mode') || 'personal';
        this.userId = localStorage.getItem('accountPortal_userId') || '';
        this.tenantId = localStorage.getItem('accountPortal_tenantId') || '';
      }
    },
    onBaseUrlBlur() {
      this.checkBaseUrl();
      this.saveToLocalStorage();
    },
    formatDate(dateStr) {
      if (!dateStr) return 'N/A';
      try {
        return new Date(dateStr).toLocaleString();
      } catch {
        return dateStr;
      }
    },
    getErrorHint(status, endpoint) {
      if (status === 401) {
        return '401 → Token missing or invalid. Check Authorization Token field.';
      }
      if (status === 403) {
        return '403 → Forbidden. Check tenant_id/user_id matches your token.';
      }
      if (status === 404) {
        return `404 → Endpoint not found: ${endpoint}`;
      }
      if (status === 0) {
        return 'Network error. Check Base URL and ensure Pazar service is running.';
      }
      return null;
    },
    async refreshAll() {
      this.loading = true;
      this.error = null;
      
      // Validate baseUrl
      const normalized = normalizePazarHost(this.baseUrl);
      if (normalized === null) {
        this.error = {
          status: 0,
          message: 'Invalid Base URL: contains /api segment (likely HOS proxy, not Pazar host)',
          hint: 'Reset Base URL to http://localhost:8080',
        };
        this.loading = false;
        return;
      }
      
      // Normalize token (check if token exists and is valid)
      let normalizedToken = null;
      if (this.authToken && this.authToken.trim()) {
        normalizedToken = normalizeToken(this.authToken);
        // If token is incomplete (JWT should have 3 parts), try demo token
        if (!normalizedToken || normalizedToken.split('.').length !== 3) {
          const demoToken = getToken();
          if (demoToken && demoToken.trim()) {
            normalizedToken = normalizeToken(demoToken);
            this.authToken = demoToken; // Update UI
            this.saveToLocalStorage(); // Save for next time
          }
        }
      } else {
        // No token, try demo token
        const demoToken = getToken();
        if (demoToken && demoToken.trim()) {
          normalizedToken = normalizeToken(demoToken);
          this.authToken = demoToken; // Update UI
          this.saveToLocalStorage(); // Save for next time
        }
      }
      
      // Clear previous data
      this.personalOrders = [];
      this.personalRentals = [];
      this.personalReservations = [];
      this.storeListings = [];
      this.storeOrders = [];
      this.storeRentals = [];
      this.storeReservations = [];
      
      try {
        if (this.mode === 'personal') {
          // Personal scope: require token
          if (!this.userId) {
            throw new Error('User ID is required for personal scope');
          }
          if (!normalizedToken) {
            throw new Error('Authorization Token is required for personal scope');
          }
          
          const [ordersResp, rentalsResp, reservationsResp] = await Promise.all([
            personalApi.getOrders(normalized, this.userId, normalizedToken),
            personalApi.getRentals(normalized, this.userId, normalizedToken),
            personalApi.getReservations(normalized, this.userId, normalizedToken),
          ]);
          
          // Check for errors
          if (!ordersResp.ok) {
            this.error = {
              status: ordersResp.status,
              message: ordersResp.message,
              endpoint: `${normalized}/api/v1/orders?buyer_user_id=${this.userId}`,
              hint: this.getErrorHint(ordersResp.status, '/v1/orders'),
            };
            return;
          }
          if (!rentalsResp.ok) {
            this.error = {
              status: rentalsResp.status,
              message: rentalsResp.message,
              endpoint: `${normalized}/api/v1/rentals?renter_user_id=${this.userId}`,
              hint: this.getErrorHint(rentalsResp.status, '/v1/rentals'),
            };
            return;
          }
          if (!reservationsResp.ok) {
            this.error = {
              status: reservationsResp.status,
              message: reservationsResp.message,
              endpoint: `${normalized}/api/v1/reservations?requester_user_id=${this.userId}`,
              hint: this.getErrorHint(reservationsResp.status, '/v1/reservations'),
            };
            return;
          }
          
          // Extract data (pazarApi returns { ok: true, data: ... })
          const ordersData = Array.isArray(ordersResp.data) ? ordersResp.data : [];
          const rentalsData = Array.isArray(rentalsResp.data) ? rentalsResp.data : [];
          const reservationsData = Array.isArray(reservationsResp.data) ? reservationsResp.data : [];
          
          this.personalOrders = ordersData;
          this.personalRentals = rentalsData;
          this.personalReservations = reservationsData;
        } else {
          // Store scope: require tenantId
          if (!this.tenantId) {
            throw new Error('Tenant ID is required for store scope');
          }
          
          const [listingsResp, ordersResp, rentalsResp, reservationsResp] = await Promise.all([
            storeApi.getListings(normalized, this.tenantId, normalizedToken),
            storeApi.getOrders(normalized, this.tenantId, normalizedToken),
            storeApi.getRentals(normalized, this.tenantId, normalizedToken),
            storeApi.getReservations(normalized, this.tenantId, normalizedToken),
          ]);
          
          // Check for errors
          if (!listingsResp.ok) {
            this.error = {
              status: listingsResp.status,
              message: listingsResp.message,
              endpoint: `${normalized}/api/v1/listings?tenant_id=${this.tenantId}`,
              hint: this.getErrorHint(listingsResp.status, '/v1/listings'),
            };
            return;
          }
          if (!ordersResp.ok) {
            this.error = {
              status: ordersResp.status,
              message: ordersResp.message,
              endpoint: `${normalized}/api/v1/orders?seller_tenant_id=${this.tenantId}`,
              hint: this.getErrorHint(ordersResp.status, '/v1/orders'),
            };
            return;
          }
          if (!rentalsResp.ok) {
            this.error = {
              status: rentalsResp.status,
              message: rentalsResp.message,
              endpoint: `${normalized}/api/v1/rentals?provider_tenant_id=${this.tenantId}`,
              hint: this.getErrorHint(rentalsResp.status, '/v1/rentals'),
            };
            return;
          }
          if (!reservationsResp.ok) {
            this.error = {
              status: reservationsResp.status,
              message: reservationsResp.message,
              endpoint: `${normalized}/api/v1/reservations?provider_tenant_id=${this.tenantId}`,
              hint: this.getErrorHint(reservationsResp.status, '/v1/reservations'),
            };
            return;
          }
          
          // Extract data
          const listingsData = Array.isArray(listingsResp.data) ? listingsResp.data : [];
          const ordersData = Array.isArray(ordersResp.data) ? ordersResp.data : [];
          const rentalsData = Array.isArray(rentalsResp.data) ? rentalsResp.data : [];
          const reservationsData = Array.isArray(reservationsResp.data) ? reservationsResp.data : [];
          
          this.storeListings = listingsData;
          this.storeOrders = ordersData;
          this.storeRentals = rentalsData;
          this.storeReservations = reservationsData;
        }
      } catch (error) {
        this.error = {
          status: error.status || 0,
          message: error.message || 'Unknown error',
          hint: this.getErrorHint(error.status || 0, 'unknown'),
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

.access-section {
  margin: 1rem 0;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.access-section h3 {
  margin-top: 0;
  margin-bottom: 1rem;
  color: #333;
}

.form-row {
  margin: 0.75rem 0;
}

.form-row label {
  display: block;
  margin-bottom: 0.25rem;
  font-weight: 500;
}

.form-row input,
.form-row select {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 0.9rem;
}

.token-input {
  display: flex;
  gap: 0.5rem;
}

.token-input input {
  flex: 1;
}

.toggle-btn {
  padding: 0.5rem 1rem;
  background: #666;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.toggle-btn:hover {
  background: #555;
}

.reset-btn {
  padding: 0.5rem 1rem;
  background: #666;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
  white-space: nowrap;
}

.reset-btn:hover {
  background: #555;
}

.warning-box {
  font-size: 0.875rem;
}

.button-group {
  display: flex;
  gap: 0.5rem;
  margin-top: 1rem;
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

.results-section {
  margin-top: 2rem;
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
