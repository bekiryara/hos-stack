<template>
  <div class="account-portal">
    <h2>Account Portal</h2>
    
    <!-- Access Section -->
    <div class="access-section">
      <div class="form-row">
        <label>
          Mode:
          <select v-model="mode">
            <option value="store">Store (Tenant)</option>
            <option value="personal">Personal (User)</option>
          </select>
        </label>
      </div>
      
      <!-- Store Panel -->
      <div v-if="mode === 'store'" class="panel">
        <h3>Store (Tenant) Panel</h3>
        <div class="form-row">
          <label>
            Tenant ID:
            <input v-model="tenantId" type="text" placeholder="UUID for X-Active-Tenant-Id" />
          </label>
        </div>
        <div class="form-row">
          <label>
            Authorization Token (optional):
            <div class="token-input">
              <input 
                v-model="authToken" 
                :type="showToken ? 'text' : 'password'" 
                placeholder="Bearer ..." 
              />
              <button @click="showToken = !showToken" class="toggle-btn">
                {{ showToken ? 'Hide' : 'Show' }}
              </button>
            </div>
          </label>
        </div>
        <div class="button-group">
          <button @click="loadStoreListings" :disabled="!tenantId || storeListingsLoading">
            Listings
          </button>
          <button @click="loadStoreOrders" :disabled="!tenantId || storeOrdersLoading">
            Orders
          </button>
          <button @click="loadStoreRentals" :disabled="!tenantId || storeRentalsLoading">
            Rentals
          </button>
          <button @click="loadStoreReservations" :disabled="!tenantId || storeReservationsLoading">
            Reservations
          </button>
        </div>
      </div>
      
      <!-- Personal Panel -->
      <div v-if="mode === 'personal'" class="panel">
        <h3>Personal (User) Panel</h3>
        <div class="form-row">
          <label>
            User ID:
            <input v-model="userId" type="text" placeholder="UUID for X-Requester-User-Id" />
          </label>
        </div>
        <div class="form-row">
          <label>
            Authorization Token (required):
            <div class="token-input">
              <input 
                v-model="authToken" 
                :type="showToken ? 'text' : 'password'" 
                placeholder="Bearer ..." 
                required
              />
              <button @click="showToken = !showToken" class="toggle-btn">
                {{ showToken ? 'Hide' : 'Show' }}
              </button>
            </div>
          </label>
        </div>
        <div v-if="!authToken" class="token-warning">
          ⚠️ Token is required for personal scope requests
        </div>
        <div class="button-group">
          <button 
            @click="loadPersonalOrders" 
            :disabled="!authToken || personalOrdersLoading"
            :title="!authToken ? 'Token required' : ''"
          >
            My Orders
          </button>
          <button 
            @click="loadPersonalRentals" 
            :disabled="!authToken || personalRentalsLoading"
            :title="!authToken ? 'Token required' : ''"
          >
            My Rentals
          </button>
          <button 
            @click="loadPersonalReservations" 
            :disabled="!authToken || personalReservationsLoading"
            :title="!authToken ? 'Token required' : ''"
          >
            My Reservations
          </button>
        </div>
      </div>
    </div>

    <!-- Results Section -->
    <div class="results-section">
      <!-- Store Results -->
      <div v-if="mode === 'store'">
        <div v-if="storeListingsResult" class="result-box">
          <h3>Listings Result</h3>
          <div class="result-summary">
            <strong>Count:</strong> {{ Array.isArray(storeListingsResult.data) ? storeListingsResult.data.length : 'N/A' }}
            <span v-if="Array.isArray(storeListingsResult.data) && storeListingsResult.data.length > 0">
              | <strong>First:</strong> {{ JSON.stringify(storeListingsResult.data[0]).substring(0, 100) }}...
            </span>
          </div>
          <pre class="json-output">{{ formatJSON(storeListingsResult) }}</pre>
        </div>
        
        <div v-if="storeOrdersResult" class="result-box">
          <h3>Orders Result</h3>
          <div class="result-summary">
            <strong>Count:</strong> {{ Array.isArray(storeOrdersResult.data) ? storeOrdersResult.data.length : 'N/A' }}
            <span v-if="Array.isArray(storeOrdersResult.data) && storeOrdersResult.data.length > 0">
              | <strong>First:</strong> {{ JSON.stringify(storeOrdersResult.data[0]).substring(0, 100) }}...
            </span>
          </div>
          <pre class="json-output">{{ formatJSON(storeOrdersResult) }}</pre>
        </div>
        
        <div v-if="storeRentalsResult" class="result-box">
          <h3>Rentals Result</h3>
          <div class="result-summary">
            <strong>Count:</strong> {{ Array.isArray(storeRentalsResult.data) ? storeRentalsResult.data.length : 'N/A' }}
            <span v-if="Array.isArray(storeRentalsResult.data) && storeRentalsResult.data.length > 0">
              | <strong>First:</strong> {{ JSON.stringify(storeRentalsResult.data[0]).substring(0, 100) }}...
            </span>
          </div>
          <pre class="json-output">{{ formatJSON(storeRentalsResult) }}</pre>
        </div>
        
        <div v-if="storeReservationsResult" class="result-box">
          <h3>Reservations Result</h3>
          <div class="result-summary">
            <strong>Count:</strong> {{ Array.isArray(storeReservationsResult.data) ? storeReservationsResult.data.length : 'N/A' }}
            <span v-if="Array.isArray(storeReservationsResult.data) && storeReservationsResult.data.length > 0">
              | <strong>First:</strong> {{ JSON.stringify(storeReservationsResult.data[0]).substring(0, 100) }}...
            </span>
          </div>
          <pre class="json-output">{{ formatJSON(storeReservationsResult) }}</pre>
        </div>
      </div>
      
      <!-- Personal Results -->
      <div v-if="mode === 'personal'">
        <div v-if="personalOrdersResult" class="result-box">
          <h3>My Orders Result</h3>
          <div class="result-summary">
            <strong>Count:</strong> {{ Array.isArray(personalOrdersResult.data) ? personalOrdersResult.data.length : 'N/A' }}
            <span v-if="Array.isArray(personalOrdersResult.data) && personalOrdersResult.data.length > 0">
              | <strong>First:</strong> {{ JSON.stringify(personalOrdersResult.data[0]).substring(0, 100) }}...
            </span>
          </div>
          <pre class="json-output">{{ formatJSON(personalOrdersResult) }}</pre>
        </div>
        
        <div v-if="personalRentalsResult" class="result-box">
          <h3>My Rentals Result</h3>
          <div class="result-summary">
            <strong>Count:</strong> {{ Array.isArray(personalRentalsResult.data) ? personalRentalsResult.data.length : 'N/A' }}
            <span v-if="Array.isArray(personalRentalsResult.data) && personalRentalsResult.data.length > 0">
              | <strong>First:</strong> {{ JSON.stringify(personalRentalsResult.data[0]).substring(0, 100) }}...
            </span>
          </div>
          <pre class="json-output">{{ formatJSON(personalRentalsResult) }}</pre>
        </div>
        
        <div v-if="personalReservationsResult" class="result-box">
          <h3>My Reservations Result</h3>
          <div class="result-summary">
            <strong>Count:</strong> {{ Array.isArray(personalReservationsResult.data) ? personalReservationsResult.data.length : 'N/A' }}
            <span v-if="Array.isArray(personalReservationsResult.data) && personalReservationsResult.data.length > 0">
              | <strong>First:</strong> {{ JSON.stringify(personalReservationsResult.data[0]).substring(0, 100) }}...
            </span>
          </div>
          <pre class="json-output">{{ formatJSON(personalReservationsResult) }}</pre>
        </div>
      </div>
      
      <!-- Error Display -->
      <div v-if="lastError" class="error-box">
        <h3>Error</h3>
        <div class="error-details">
          <div><strong>Status:</strong> {{ lastError.status || 'N/A' }}</div>
          <div><strong>Message:</strong> {{ lastError.message || 'Unknown error' }}</div>
          <pre v-if="lastError.body" class="json-output">{{ formatJSON(lastError.body) }}</pre>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { storeApi, personalApi } from '../lib/pazarApi.js';

export default {
  name: 'AccountPortalPage',
  data() {
    return {
      mode: 'personal',
      authToken: '',
      userId: '',
      tenantId: '',
      showToken: false,
      
      // Store results
      storeListingsResult: null,
      storeOrdersResult: null,
      storeRentalsResult: null,
      storeReservationsResult: null,
      
      // Personal results
      personalOrdersResult: null,
      personalRentalsResult: null,
      personalReservationsResult: null,
      
      // Loading states
      storeListingsLoading: false,
      storeOrdersLoading: false,
      storeRentalsLoading: false,
      storeReservationsLoading: false,
      personalOrdersLoading: false,
      personalRentalsLoading: false,
      personalReservationsLoading: false,
      
      // Error state
      lastError: null,
    };
  },
  watch: {
    authToken() {
      this.saveToLocalStorage();
    },
    userId() {
      this.saveToLocalStorage();
    },
    tenantId() {
      this.saveToLocalStorage();
    },
    mode() {
      this.saveToLocalStorage();
    },
  },
  mounted() {
    this.loadFromLocalStorage();
  },
  methods: {
    saveToLocalStorage() {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem('accountPortal_authToken', this.authToken);
        localStorage.setItem('accountPortal_userId', this.userId);
        localStorage.setItem('accountPortal_tenantId', this.tenantId);
        localStorage.setItem('accountPortal_mode', this.mode);
      }
    },
    loadFromLocalStorage() {
      if (typeof localStorage !== 'undefined') {
        this.authToken = localStorage.getItem('accountPortal_authToken') || '';
        this.userId = localStorage.getItem('accountPortal_userId') || '';
        this.tenantId = localStorage.getItem('accountPortal_tenantId') || '';
        this.mode = localStorage.getItem('accountPortal_mode') || 'personal';
      }
    },
    formatJSON(obj) {
      try {
        return JSON.stringify(obj, null, 2);
      } catch (e) {
        return String(obj);
      }
    },
    
    // Store API calls
    async loadStoreListings() {
      if (!this.tenantId) {
        this.lastError = { message: 'Tenant ID is required' };
        return;
      }
      this.storeListingsLoading = true;
      this.lastError = null;
      this.storeListingsResult = null;
      try {
        const result = await storeApi.getListings(this.tenantId, this.authToken || null);
        if (result.ok) {
          this.storeListingsResult = result;
        } else {
          this.lastError = result;
        }
      } catch (error) {
        this.lastError = { message: error.message, status: 0 };
      } finally {
        this.storeListingsLoading = false;
      }
    },
    
    async loadStoreOrders() {
      if (!this.tenantId) {
        this.lastError = { message: 'Tenant ID is required' };
        return;
      }
      this.storeOrdersLoading = true;
      this.lastError = null;
      this.storeOrdersResult = null;
      try {
        const result = await storeApi.getOrders(this.tenantId, this.authToken || null);
        if (result.ok) {
          this.storeOrdersResult = result;
        } else {
          this.lastError = result;
        }
      } catch (error) {
        this.lastError = { message: error.message, status: 0 };
      } finally {
        this.storeOrdersLoading = false;
      }
    },
    
    async loadStoreRentals() {
      if (!this.tenantId) {
        this.lastError = { message: 'Tenant ID is required' };
        return;
      }
      this.storeRentalsLoading = true;
      this.lastError = null;
      this.storeRentalsResult = null;
      try {
        const result = await storeApi.getRentals(this.tenantId, this.authToken || null);
        if (result.ok) {
          this.storeRentalsResult = result;
        } else {
          this.lastError = result;
        }
      } catch (error) {
        this.lastError = { message: error.message, status: 0 };
      } finally {
        this.storeRentalsLoading = false;
      }
    },
    
    async loadStoreReservations() {
      if (!this.tenantId) {
        this.lastError = { message: 'Tenant ID is required' };
        return;
      }
      this.storeReservationsLoading = true;
      this.lastError = null;
      this.storeReservationsResult = null;
      try {
        const result = await storeApi.getReservations(this.tenantId, this.authToken || null);
        if (result.ok) {
          this.storeReservationsResult = result;
        } else {
          this.lastError = result;
        }
      } catch (error) {
        this.lastError = { message: error.message, status: 0 };
      } finally {
        this.storeReservationsLoading = false;
      }
    },
    
    // Personal API calls
    async loadPersonalOrders() {
      if (!this.authToken) {
        this.lastError = { message: 'Authorization Token is required for personal scope' };
        return;
      }
      this.personalOrdersLoading = true;
      this.lastError = null;
      this.personalOrdersResult = null;
      try {
        const result = await personalApi.getOrders(this.userId || null, this.authToken);
        if (result.ok) {
          this.personalOrdersResult = result;
        } else {
          this.lastError = result;
        }
      } catch (error) {
        this.lastError = { message: error.message, status: 0 };
      } finally {
        this.personalOrdersLoading = false;
      }
    },
    
    async loadPersonalRentals() {
      if (!this.authToken) {
        this.lastError = { message: 'Authorization Token is required for personal scope' };
        return;
      }
      this.personalRentalsLoading = true;
      this.lastError = null;
      this.personalRentalsResult = null;
      try {
        const result = await personalApi.getRentals(this.userId || null, this.authToken);
        if (result.ok) {
          this.personalRentalsResult = result;
        } else {
          this.lastError = result;
        }
      } catch (error) {
        this.lastError = { message: error.message, status: 0 };
      } finally {
        this.personalRentalsLoading = false;
      }
    },
    
    async loadPersonalReservations() {
      if (!this.authToken) {
        this.lastError = { message: 'Authorization Token is required for personal scope' };
        return;
      }
      this.personalReservationsLoading = true;
      this.lastError = null;
      this.personalReservationsResult = null;
      try {
        const result = await personalApi.getReservations(this.userId || null, this.authToken);
        if (result.ok) {
          this.personalReservationsResult = result;
        } else {
          this.lastError = result;
        }
      } catch (error) {
        this.lastError = { message: error.message, status: 0 };
      } finally {
        this.personalReservationsLoading = false;
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

.panel {
  margin-top: 1rem;
  padding: 1rem;
  background: white;
  border-radius: 4px;
  border: 1px solid #ccc;
}

.panel h3 {
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

.token-warning {
  padding: 0.75rem;
  background: #fff3cd;
  border: 1px solid #ffc107;
  border-radius: 4px;
  color: #856404;
  margin: 0.75rem 0;
}

.button-group {
  display: flex;
  gap: 0.5rem;
  margin-top: 1rem;
  flex-wrap: wrap;
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

.result-box {
  margin: 1rem 0;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.result-box h3 {
  margin-top: 0;
  margin-bottom: 0.5rem;
  color: #333;
}

.result-summary {
  margin-bottom: 0.5rem;
  font-size: 0.9rem;
  color: #666;
}

.json-output {
  background: #2d2d2d;
  color: #f8f8f2;
  padding: 1rem;
  border-radius: 4px;
  overflow-x: auto;
  font-family: 'Courier New', monospace;
  font-size: 0.85rem;
  line-height: 1.5;
  max-height: 500px;
  overflow-y: auto;
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
</style>
