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

      <div v-if="activeTenantId" class="tenant-address-card">
        <h3>Firma Adresi</h3>
        <div v-if="tenantAddressLoading" class="loading-firm-state">
          <p>Firma adresi yukleniyor...</p>
        </div>
        <div v-else class="address-form-grid">
          <label>Il
            <input v-model.trim="tenantAddress.city" type="text" class="form-input" />
          </label>
          <label>Ilce
            <input v-model.trim="tenantAddress.district" type="text" class="form-input" />
          </label>
          <label>Mahalle
            <input v-model.trim="tenantAddress.neighborhood" type="text" class="form-input" />
          </label>
          <label>Sokak / Cadde
            <input v-model.trim="tenantAddress.street" type="text" class="form-input" />
          </label>
          <label>Dis Kapi No
            <input v-model.trim="tenantAddress.building_no" type="text" class="form-input" />
          </label>
          <label>Ic Kapi No
            <input v-model.trim="tenantAddress.door_no" type="text" class="form-input" />
          </label>
          <label class="full-width">Acik Adres
            <input v-model.trim="tenantAddress.address_line" type="text" class="form-input" />
          </label>
        </div>
        <div class="address-actions">
          <button @click="saveTenantAddress" :disabled="tenantAddressSaving" class="set-active-btn">
            {{ tenantAddressSaving ? 'Kaydediliyor...' : 'Firma Adresini Kaydet' }}
          </button>
          <small v-if="tenantAddressError" class="tenant-id-warning">{{ tenantAddressError }}</small>
          <small v-if="tenantAddressSaved" class="status-active">Kaydedildi.</small>
        </div>
      </div>
      
      <!-- Refresh Button (WP-NEXT: panel isolation — refresh all) -->
      <div class="button-group">
        <button @click="refreshAll" :disabled="refreshing">
          {{ refreshing ? 'Yükleniyor...' : 'Yenile' }}
        </button>
      </div>

      <!-- Customer Records: tabs + lazy-load panels (account/) -->
      <section class="customer-records-section">
        <h3 class="customer-records-title">Kayıtlar</h3>
        <div class="tabs-row">
          <button
            type="button"
            :class="['tab-btn', { active: activeTab === 'orders' }]"
            @click="setTab('orders')"
          >
            Orders
          </button>
          <button
            type="button"
            :class="['tab-btn', { active: activeTab === 'rentals' }]"
            @click="setTab('rentals')"
          >
            Rentals
          </button>
          <button
            type="button"
            :class="['tab-btn', { active: activeTab === 'reservations' }]"
            @click="setTab('reservations')"
          >
            Reservations
          </button>
        </div>
        <div v-show="activeTab === 'orders'">
          <MyOrdersPanel ref="ordersPanelRef" :active="activeTab === 'orders'" />
        </div>
        <div v-show="activeTab === 'rentals'">
          <MyRentalsPanel ref="rentalsPanelRef" :active="activeTab === 'rentals'" />
        </div>
        <div v-show="activeTab === 'reservations'">
          <MyReservationsPanel ref="reservationsPanelRef" :active="activeTab === 'reservations'" />
        </div>
      </section>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { isLoggedIn, getActiveTenantId, setActiveTenantId, clearSession } from '../lib/session.js';
import { notifyApiSuccess } from '../lib/toast/notify_api.js';
import MyReservationsPanel from '../components/account/MyReservationsPanel.vue';
import MyRentalsPanel from '../components/account/MyRentalsPanel.vue';
import MyOrdersPanel from '../components/account/MyOrdersPanel.vue';

export default {
  name: 'AccountPortalPage',
  components: {
    MyReservationsPanel,
    MyRentalsPanel,
    MyOrdersPanel,
  },
  data() {
    return {
      userInfo: {},
      memberships: [],
      activeTenantIdValue: getActiveTenantId(),
      membershipsLoading: false,
      refreshing: false,
      tenantAddress: {
        city: '',
        district: '',
        neighborhood: '',
        street: '',
        building_no: '',
        door_no: '',
        address_line: '',
      },
      tenantAddressLoading: false,
      tenantAddressSaving: false,
      tenantAddressError: null,
      tenantAddressSaved: false,
    };
  },
  computed: {
    isAuthenticated() {
      return isLoggedIn();
    },
    activeTenantId() {
      return this.activeTenantIdValue;
    },
    allowedTabs() {
      return ['orders', 'rentals', 'reservations'];
    },
    activeTab() {
      const tab = this.$route.query.tab || 'orders';
      return this.allowedTabs.includes(tab) ? tab : 'orders';
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
      if (this.activeTenantId) {
        await this.loadTenantAddress();
      }
    }
  },
  methods: {
    async loadUserInfo() {
      try {
        this.userInfo = await api.getMe();
      } catch (err) {
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

        this.activeTenantIdValue = getActiveTenantId();
        if (this.memberships.length > 0 && !this.activeTenantIdValue) {
          const first = this.memberships[0];
          if (first && first.tenant_id) {
            setActiveTenantId(first.tenant_id);
            this.activeTenantIdValue = first.tenant_id;
          }
        }
        if (this.activeTenantIdValue) {
          await this.loadTenantAddress();
        }
      } catch (err) {
        console.error('[AccountPortalPage] Failed to load memberships:', err);
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        this.memberships = [];
      } finally {
        this.membershipsLoading = false;
      }
    },
    async loadTenantAddress() {
      if (!this.activeTenantIdValue) return;
      this.tenantAddressLoading = true;
      this.tenantAddressError = null;
      this.tenantAddressSaved = false;
      try {
        const resp = await api.hosGetTenantAddress(this.activeTenantIdValue);
        const a = resp?.address || {};
        this.tenantAddress = {
          city: a.city || '',
          district: a.district || '',
          neighborhood: a.neighborhood || '',
          street: a.street || '',
          building_no: a.building_no || '',
          door_no: a.door_no || '',
          address_line: a.address_line || '',
        };
      } catch (err) {
        this.tenantAddressError = err?.message || 'Firma adresi yuklenemedi.';
      } finally {
        this.tenantAddressLoading = false;
      }
    },
    async saveTenantAddress() {
      if (!this.activeTenantIdValue) return;
      this.tenantAddressSaving = true;
      this.tenantAddressError = null;
      this.tenantAddressSaved = false;
      try {
        const payload = {};
        ['city', 'district', 'neighborhood', 'street', 'building_no', 'door_no', 'address_line'].forEach((k) => {
          const v = typeof this.tenantAddress[k] === 'string' ? this.tenantAddress[k].trim() : '';
          if (v) payload[k] = v;
        });
        await api.hosUpsertTenantAddress(this.activeTenantIdValue, payload);
        this.tenantAddressSaved = true;
      } catch (err) {
        this.tenantAddressError = err?.message || 'Firma adresi kaydedilemedi.';
      } finally {
        this.tenantAddressSaving = false;
      }
    },
    setActiveTenant(tenantId) {
      setActiveTenantId(tenantId);
      this.activeTenantIdValue = tenantId || null;
      notifyApiSuccess('Tenant selected');
      if (this.isAuthenticated) {
        this.loadTenantAddress();
        this.refreshAll();
      }
    },
    setTab(tab) {
      if (!this.allowedTabs.includes(tab)) return;
      this.$router.replace({ query: { ...this.$route.query, tab } }).catch(() => {});
    },
    refreshAll() {
      if (!this.isAuthenticated) return;
      this.refreshing = true;
      const ref = this.activeTab === 'orders' ? this.$refs.ordersPanelRef : this.activeTab === 'rentals' ? this.$refs.rentalsPanelRef : this.$refs.reservationsPanelRef;
      (ref?.load?.() ?? Promise.resolve()).finally(() => {
        this.refreshing = false;
      });
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

.loading-firm-state {
  text-align: center;
  padding: 1rem 0;
  color: #666;
}

.status-active {
  color: #28a745;
  font-weight: 600;
}

.tenant-address-card {
  margin: 1rem 0;
  padding: 1.5rem;
  background: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.address-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

.address-form-grid label {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  font-weight: 500;
  color: #333;
}

.address-form-grid .form-input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.address-form-grid .full-width {
  grid-column: 1 / -1;
}

.address-actions {
  margin-top: 0.75rem;
  display: flex;
  gap: 0.75rem;
  align-items: center;
}

.customer-records-section {
  margin-top: 2rem;
}

.customer-records-title {
  margin-bottom: 1rem;
  color: #333;
}

.tabs-row {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.tab-btn {
  padding: 0.5rem 1rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: #f9f9f9;
  cursor: pointer;
  font-size: 0.95rem;
}

.tab-btn:hover {
  background: #eee;
}

.tab-btn.active {
  background: #0066cc;
  color: white;
  border-color: #0066cc;
}
</style>


