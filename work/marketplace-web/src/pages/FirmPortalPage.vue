<template>
  <div class="firm-portal">
    <div class="header-row">
      <h2>Firma Paneli</h2>
      <router-link to="/listing/create" class="primary-cta">Ilan ver</router-link>
    </div>

    <div v-if="!activeTenantId" class="no-tenant-warning">
      <p>Aktif firma secilmedi. Firma paneli icin once Hesabim ekranindan firma secin.</p>
      <router-link to="/account" class="btn-account">Hesaba Git</router-link>
    </div>

    <template v-else>
      <div class="firm-info-bar">
        <p><strong>Aktif Firma ID:</strong> {{ activeTenantId }}</p>
        <p v-if="activeTenantName"><strong>Firma Adi:</strong> {{ activeTenantName }}</p>
      </div>

      <div class="portal-layout">
        <aside class="sidebar">
          <button type="button" class="nav-btn" :class="{ active: currentTab === 'overview' }" @click="goTab('overview')">Genel Bakis</button>
          <button type="button" class="nav-btn" :class="{ active: currentTab === 'listings' }" @click="goTab('listings')">Ilanlarim</button>
          <button type="button" class="nav-btn" :class="{ active: currentTab === 'orders' }" @click="goTab('orders')">Gelen Siparisler</button>
          <button type="button" class="nav-btn" :class="{ active: currentTab === 'rentals' }" @click="goTab('rentals')">Kiralama Talepleri</button>
          <button type="button" class="nav-btn" :class="{ active: currentTab === 'reservations' }" @click="goTab('reservations')">Rezervasyonlar</button>
          <button type="button" class="nav-btn" :class="{ active: currentTab === 'messages' }" @click="goTab('messages')">Mesajlar</button>
          <button type="button" class="nav-btn" @click="goSettings">Firma Ayarlari</button>
        </aside>

        <section class="content">
          <div v-if="currentTab === 'overview'" class="overview">
            <h3>Genel Bakis</h3>
            <div class="overview-grid">
              <div class="card">
                <div class="label">Aktif Firma</div>
                <div class="value">{{ activeTenantName || 'Secili' }}</div>
              </div>
              <div class="card">
                <div class="label">Toplam Ilan</div>
                <div class="value">{{ overview.listingsTotal }}</div>
              </div>
              <div class="card">
                <div class="label">Bekleyen Siparis</div>
                <div class="value">{{ overview.ordersPending }}</div>
              </div>
              <div class="card">
                <div class="label">Bekleyen Kiralama</div>
                <div class="value">{{ overview.rentalsPending }}</div>
              </div>
              <div class="card">
                <div class="label">Bekleyen Rezervasyon</div>
                <div class="value">{{ overview.reservationsPending }}</div>
              </div>
              <div class="card">
                <div class="label">Toplam Islem</div>
                <div class="value">{{ overview.totalTransactions }}</div>
              </div>
            </div>
            <p v-if="overviewLoading" class="overview-note">Ozet verileri yukleniyor...</p>
            <p v-else-if="overviewError" class="overview-note warn">{{ overviewError }}</p>
          </div>

          <FirmListingsPanel v-else-if="currentTab === 'listings'" :active-tenant-id="activeTenantId" />
          <FirmOrdersPanel v-else-if="currentTab === 'orders'" :active-tenant-id="activeTenantId" />
          <FirmRentalsPanel v-else-if="currentTab === 'rentals'" :active-tenant-id="activeTenantId" />
          <FirmReservationsPanel v-else-if="currentTab === 'reservations'" :active-tenant-id="activeTenantId" />

          <div v-else-if="currentTab === 'messages'" class="card">
            <h3>Mesajlar</h3>
            <p>Mesajlasma su an ilan bazli calisiyor.</p>
            <p>Ilanlarim sekmesindeki "Mesajlar" aksiyonundan ilgili mesaj ekranina gidebilirsiniz.</p>
            <button type="button" class="btn-account" @click="goTab('listings')">Ilanlarima Don</button>
          </div>

        </section>
      </div>
    </template>
  </div>
</template>

<script>
import { getActiveTenantId } from '../lib/session.js';
import { api } from '../api/client.js';
import FirmListingsPanel from '../components/portal/firm/FirmListingsPanel.vue';
import FirmOrdersPanel from '../components/portal/firm/FirmOrdersPanel.vue';
import FirmRentalsPanel from '../components/portal/firm/FirmRentalsPanel.vue';
import FirmReservationsPanel from '../components/portal/firm/FirmReservationsPanel.vue';

const TABS = ['overview', 'listings', 'orders', 'rentals', 'reservations', 'messages'];

export default {
  name: 'FirmPortalPage',
  components: {
    FirmListingsPanel,
    FirmOrdersPanel,
    FirmRentalsPanel,
    FirmReservationsPanel,
  },
  data() {
    return {
      activeTenantId: null,
      activeTenantName: null,
      overviewLoading: false,
      overviewError: null,
      overview: {
        listingsTotal: 0,
        ordersPending: 0,
        rentalsPending: 0,
        reservationsPending: 0,
        totalTransactions: 0,
      },
    };
  },
  computed: {
    currentTab() {
      const q = String(this.$route.query.tab || 'overview').trim();
      return TABS.includes(q) ? q : 'overview';
    },
  },
  async mounted() {
    this.activeTenantId = getActiveTenantId();
    if (!this.activeTenantId) return;
    await Promise.all([this.loadMembershipsForName(), this.loadOverview()]);
  },
  methods: {
    goTab(tab) {
      const target = TABS.includes(tab) ? tab : 'overview';
      this.$router.replace({ query: { ...this.$route.query, tab: target } }).catch(() => {});
    },
    goSettings() {
      this.$router.push('/firm/settings').catch(() => {});
    },
    async loadMembershipsForName() {
      try {
        const response = await api.getMyMemberships();
        const list = response.items || response.data || (Array.isArray(response) ? response : []);
        const active = list.find((m) => m.tenant_id === this.activeTenantId);
        this.activeTenantName = active ? (active.tenant_name || active.tenant_slug) : null;
      } catch {
        this.activeTenantName = null;
      }
    },
    asItems(resp) {
      if (Array.isArray(resp)) return resp;
      if (resp && Array.isArray(resp.items)) return resp.items;
      if (resp && Array.isArray(resp.data)) return resp.data;
      return [];
    },
    countPending(items, statuses) {
      const set = new Set(statuses.map((s) => String(s).toLowerCase()));
      return items.filter((x) => set.has(String(x?.status || '').toLowerCase())).length;
    },
    async loadOverview() {
      if (!this.activeTenantId) return;
      this.overviewLoading = true;
      this.overviewError = null;
      try {
        const [listingsResp, ordersResp, rentalsResp, reservationsResp] = await Promise.all([
          api.getStoreListings(this.activeTenantId),
          api.getStoreOrders(this.activeTenantId),
          api.getStoreRentals(this.activeTenantId),
          api.getStoreReservations(this.activeTenantId),
        ]);
        const listings = this.asItems(listingsResp);
        const orders = this.asItems(ordersResp);
        const rentals = this.asItems(rentalsResp);
        const reservations = this.asItems(reservationsResp);

        const ordersPending = this.countPending(orders, ['placed', 'received', 'pending', 'siparis alindi', 'siparis_alindi']);
        const rentalsPending = this.countPending(rentals, ['requested', 'pending', 'talep geldi', 'talep_geldi']);
        const reservationsPending = this.countPending(reservations, ['requested', 'pending', 'talep geldi', 'talep_geldi']);

        this.overview = {
          listingsTotal: listings.length,
          ordersPending,
          rentalsPending,
          reservationsPending,
          totalTransactions: orders.length + rentals.length + reservations.length,
        };
      } catch {
        this.overviewError = 'Ozet metrikleri yuklenemedi.';
      } finally {
        this.overviewLoading = false;
      }
    },
  },
};
</script>

<style scoped>
.firm-portal {
  width: 100%;
  max-width: 100%;
  margin: 0;
  padding: 0.5rem 0 1.5rem 0;
}

.firm-portal h2 {
  margin-top: 0;
  margin-bottom: 0.25rem;
  color: #333;
}

.header-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.85rem;
}

.primary-cta {
  display: inline-block;
  padding: 0.6rem 0.9rem;
  background: #0f766e;
  color: #fff;
  text-decoration: none;
  border-radius: 8px;
  font-weight: 600;
}

.primary-cta:hover {
  background: #0b5f59;
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
  padding: 0.6rem 1rem;
  background: #007bff;
  color: white;
  text-decoration: none;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.btn-account:hover {
  background: #0056b3;
}

.firm-info-bar {
  margin-bottom: 1rem;
  padding: 1rem 1.1rem;
  background: linear-gradient(135deg, #f8fbff 0%, #eef6ff 100%);
  border-radius: 10px;
  border: 1px solid #d7e5f8;
}

.firm-info-bar p {
  margin: 0.25rem 0;
  color: #333;
}

.portal-layout {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 1.1rem;
  align-items: start;
}

.sidebar {
  position: sticky;
  top: 80px;
  border: 1px solid #dbe1ea;
  border-radius: 12px;
  padding: 0.6rem;
  background: #f9fbff;
  height: fit-content;
  box-shadow: 0 3px 12px rgba(17, 24, 39, 0.05);
}

.nav-btn {
  width: 100%;
  text-align: left;
  padding: 0.7rem 0.8rem;
  border: 1px solid transparent;
  border-radius: 8px;
  background: transparent;
  cursor: pointer;
  margin-bottom: 0.4rem;
  color: #1f2937;
  font-weight: 500;
}

.nav-btn:hover {
  background: #f8f9fa;
}

.nav-btn.active {
  background: #ddeeff;
  border-color: #98c2ff;
  color: #0b53bf;
  font-weight: 600;
}

.content {
  min-width: 0;
  border: 1px solid #dfe5ee;
  border-radius: 12px;
  background: #ffffff;
  padding: 1rem;
  box-shadow: 0 3px 12px rgba(17, 24, 39, 0.04);
}

.card {
  border: 1px solid #e3e7ef;
  border-radius: 10px;
  padding: 1rem 1.1rem;
  background: #fff;
}

.overview h3 {
  margin-top: 0;
}

.overview-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(220px, 1fr));
  gap: 0.85rem;
}

.overview-note {
  margin-top: 0.8rem;
  color: #4b5563;
}

.overview-note.warn {
  color: #b45309;
}

.label {
  color: #666;
  font-size: 0.85rem;
}

.value {
  margin-top: 0.3rem;
  color: #222;
  font-weight: 600;
}

@media (max-width: 900px) {
  .portal-layout {
    grid-template-columns: 1fr;
  }

  .sidebar {
    position: static;
  }
}
</style>
