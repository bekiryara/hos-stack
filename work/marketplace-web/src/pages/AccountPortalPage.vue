<template>
  <div class="account-portal">
    <h2>Account Portal</h2>
    
    <!-- Access Section -->
    <div class="access-section">
      <h3>Access</h3>
      
      <div class="form-row">
        <label>
          Base URL:
          <input v-model="baseUrl" type="text" placeholder="http://localhost:8080" @blur="saveToLocalStorage" />
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
          <div v-if="error.errorCode"><strong>Error Code:</strong> {{ error.errorCode }}</div>
          <div><strong>Message:</strong> {{ error.message || 'Unknown error' }}</div>
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
import { api, normalizeListResponse } from '../api/client.js';

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
  },
  methods: {
    saveToLocalStorage() {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem('accountPortal_baseUrl', this.baseUrl);
        localStorage.setItem('accountPortal_authToken', this.authToken);
        localStorage.setItem('accountPortal_mode', this.mode);
        localStorage.setItem('accountPortal_userId', this.userId);
        localStorage.setItem('accountPortal_tenantId', this.tenantId);
      }
    },
    loadFromLocalStorage() {
      if (typeof localStorage !== 'undefined') {
        this.baseUrl = localStorage.getItem('accountPortal_baseUrl') || this.baseUrl;
        this.authToken = localStorage.getItem('accountPortal_authToken') || '';
        this.mode = localStorage.getItem('accountPortal_mode') || 'personal';
        this.userId = localStorage.getItem('accountPortal_userId') || '';
        this.tenantId = localStorage.getItem('accountPortal_tenantId') || '';
      }
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
      this.loading = true;
      this.error = null;
      
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
          // Personal scope: parallel loads
          if (!this.userId) {
            throw new Error('User ID is required for personal scope');
          }
          
          const [ordersResp, rentalsResp, reservationsResp] = await Promise.all([
            api.getMyOrders(this.userId, this.authToken || null).catch(e => e),
            api.getMyRentals(this.userId, this.authToken || null).catch(e => e),
            api.getMyReservations(this.userId, this.authToken || null).catch(e => e),
          ]);
          
          // Check for errors
          if (ordersResp instanceof Error) {
            this.error = {
              status: ordersResp.status,
              errorCode: ordersResp.errorCode,
              message: ordersResp.message,
            };
            return;
          }
          if (rentalsResp instanceof Error) {
            this.error = {
              status: rentalsResp.status,
              errorCode: rentalsResp.errorCode,
              message: rentalsResp.message,
            };
            return;
          }
          if (reservationsResp instanceof Error) {
            this.error = {
              status: reservationsResp.status,
              errorCode: reservationsResp.errorCode,
              message: reservationsResp.message,
            };
            return;
          }
          
          // Normalize responses
          const ordersNorm = normalizeListResponse(ordersResp);
          const rentalsNorm = normalizeListResponse(rentalsResp);
          const reservationsNorm = normalizeListResponse(reservationsResp);
          
          this.personalOrders = ordersNorm.items || [];
          this.personalRentals = rentalsNorm.items || [];
          this.personalReservations = reservationsNorm.items || [];
        } else {
          // Store scope: parallel loads
          if (!this.tenantId) {
            throw new Error('Tenant ID is required for store scope');
          }
          
          const [listingsResp, ordersResp, rentalsResp, reservationsResp] = await Promise.all([
            api.getStoreListings(this.tenantId, this.authToken || null).catch(e => e),
            api.getStoreOrders(this.tenantId, this.authToken || null).catch(e => e),
            api.getStoreRentals(this.tenantId, this.authToken || null).catch(e => e),
            api.getStoreReservations(this.tenantId, this.authToken || null).catch(e => e),
          ]);
          
          // Check for errors
          if (listingsResp instanceof Error) {
            this.error = {
              status: listingsResp.status,
              errorCode: listingsResp.errorCode,
              message: listingsResp.message,
            };
            return;
          }
          if (ordersResp instanceof Error) {
            this.error = {
              status: ordersResp.status,
              errorCode: ordersResp.errorCode,
              message: ordersResp.message,
            };
            return;
          }
          if (rentalsResp instanceof Error) {
            this.error = {
              status: rentalsResp.status,
              errorCode: rentalsResp.errorCode,
              message: rentalsResp.message,
            };
            return;
          }
          if (reservationsResp instanceof Error) {
            this.error = {
              status: reservationsResp.status,
              errorCode: reservationsResp.errorCode,
              message: reservationsResp.message,
            };
            return;
          }
          
          // Normalize responses
          const listingsNorm = normalizeListResponse(listingsResp);
          const ordersNorm = normalizeListResponse(ordersResp);
          const rentalsNorm = normalizeListResponse(rentalsResp);
          const reservationsNorm = normalizeListResponse(reservationsResp);
          
          this.storeListings = listingsNorm.items || [];
          this.storeOrders = ordersNorm.items || [];
          this.storeRentals = rentalsNorm.items || [];
          this.storeReservations = reservationsNorm.items || [];
        }
      } catch (error) {
        this.error = {
          status: error.status || 0,
          errorCode: error.errorCode,
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
