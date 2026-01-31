<template>
  <SectionShell
    title="Orders"
    :status="loading ? 'loading' : (error ? 'error' : 'ready')"
    :error-message="error ? (error.message || '') : ''"
    :empty="!loading && !error && items.length === 0"
    empty-text="No orders yet"
    @retry="load"
  >
    <table class="data-table">
      <thead>
        <tr>
          <th>ID</th>
          <th>Listing ID</th>
          <th>Status</th>
          <th>Created</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in items" :key="row.id">
          <td>
            <router-link :to="detailLink(row)" class="id-link">{{ safe(row.id) }}</router-link>
          </td>
          <td>{{ safe(row.listing_id) }}</td>
          <td>{{ safe(row.status) }}</td>
          <td>{{ safe(row.created_at) }}</td>
        </tr>
      </tbody>
    </table>
  </SectionShell>
</template>

<script>
import SectionShell from '../portal/SectionShell.vue';
import { api } from '../../api/client.js';
import { buildOrderDetailLink } from './account_record_links.js';

function normalizeItems(res) {
  if (res == null) return [];
  return Array.isArray(res) ? res : (res.items || res.data || []) || [];
}

export default {
  name: 'AccountMyOrdersPanel',
  components: { SectionShell },
  props: {
    active: { type: Boolean, default: false },
  },
  data() {
    return {
      items: [],
      loading: false,
      error: null,
      loadedOnce: false,
    };
  },
  watch: {
    active: {
      handler(val) {
        if (val && !this.loadedOnce) {
          this.load().then(() => { this.loadedOnce = true; }).catch(() => {});
        }
      },
      immediate: true,
    },
  },
  methods: {
    async load() {
      if (!this.active) return;
      this.loading = true;
      this.error = null;
      try {
        const res = await api.getMyOrders();
        this.items = normalizeItems(res);
      } catch (err) {
        this.error = err;
        this.items = [];
      } finally {
        this.loading = false;
      }
      return Promise.resolve();
    },
    safe(val) {
      if (val == null || val === '') return '—';
      return val;
    },
    detailLink(row) {
      return buildOrderDetailLink(row);
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
.data-table thead { background: #f5f5f5; }
.data-table th { padding: 0.75rem; text-align: left; font-weight: 600; border-bottom: 2px solid #ddd; }
.data-table td { padding: 0.75rem; border-bottom: 1px solid #eee; }
.data-table tbody tr:hover { background: #f9f9f9; }
.id-link { color: #0066cc; text-decoration: none; }
.id-link:hover { text-decoration: underline; }
</style>
