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

      <FirmListingsPanel :active-tenant-id="activeTenantId" />
      <FirmOrdersPanel :active-tenant-id="activeTenantId" />
      <FirmRentalsPanel :active-tenant-id="activeTenantId" />
      <FirmReservationsPanel :active-tenant-id="activeTenantId" />
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
    };
  },
  async mounted() {
    this.activeTenantId = getActiveTenantId();
    if (!this.activeTenantId) return;
    await this.loadMembershipsForName();
  },
  methods: {
    async loadMembershipsForName() {
      try {
        const response = await api.getMyMemberships();
        const list = response.items || response.data || (Array.isArray(response) ? response : []);
        const active = list.find(m => m.tenant_id === this.activeTenantId);
        this.activeTenantName = active ? (active.tenant_name || active.tenant_slug) : null;
      } catch {
        this.activeTenantName = null;
      }
    },
  },
};
</script>

<style scoped>
.firm-portal {
  max-width: 1200px;
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
</style>
