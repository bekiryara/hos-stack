<template>
  <SectionShell
    title="Siparişlerim"
    :status="panelStatus"
    :error-message="errorMessage"
    :empty="!loading && !error && (items || []).length === 0"
    empty-text="Henüz sipariş yok"
    @retry="load"
  >
    <table class="data-table">
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
        <tr v-for="order in (items || [])" :key="order.id">
          <td>{{ order.id }}</td>
          <td>{{ order.listing_id }}</td>
          <td>{{ order.status }}</td>
          <td>{{ order.quantity }}</td>
          <td>{{ formatDate(order.created_at) }}</td>
        </tr>
      </tbody>
    </table>
  </SectionShell>
</template>

<script>
import SectionShell from './SectionShell.vue';
import { api } from '../../api/client.js';
import { getUserId, clearSession } from '../../lib/session.js';

function extractItems(resp) {
  if (resp == null) return [];
  return Array.isArray(resp) ? resp : (resp.data ?? resp.items ?? []) ?? [];
}

export default {
  name: 'MyOrdersPanel',
  components: { SectionShell },
  data() {
    return {
      loading: false,
      error: null,
      items: [],
    };
  },
  computed: {
    panelStatus() {
      if (this.loading) return 'loading';
      if (this.error) return 'error';
      return 'ready';
    },
    errorMessage() {
      return this.error?.message || '';
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    async load() {
      const userId = getUserId();
      if (!userId) {
        clearSession();
        this.$router.push('/login?reason=expired');
        return;
      }
      this.loading = true;
      this.error = null;
      try {
        const resp = await api.getMyOrders(userId);
        this.items = extractItems(resp);
      } catch (err) {
        if (err.status === 401) {
          clearSession();
          this.$router.push('/login?reason=expired');
          return;
        }
        this.error = { message: err.message || 'Failed to load orders' };
        this.items = [];
      } finally {
        this.loading = false;
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
  },
};
</script>

<style scoped>
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
