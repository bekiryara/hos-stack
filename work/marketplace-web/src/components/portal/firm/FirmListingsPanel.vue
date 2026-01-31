<template>
  <section class="portal-section">
    <h3>İlanlarım</h3>
    <div v-if="loading" class="section-loading">Loading …</div>
    <div v-else-if="error" class="section-error-box">
      <p>{{ error }}</p>
      <button type="button" class="btn-retry" @click="load">Retry</button>
    </div>
    <div v-else-if="!items.length" class="section-empty">No listings yet</div>
    <div v-else class="section-list">
      <table class="data-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Başlık</th>
            <th>Durum</th>
            <th>Kategori ID</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in items" :key="item.id">
            <td>{{ item.id }}</td>
            <td>{{ item.title || '—' }}</td>
            <td>{{ item.status || '—' }}</td>
            <td>{{ item.category_id || '—' }}</td>
            <td class="actions-cell">
              <router-link :to="`/listing/${item.id}`" class="btn-action">View</router-link>
              <router-link :to="`/listing/${item.id}/message`" class="btn-action">Message</router-link>
              <button type="button" class="btn-action btn-disabled" disabled title="not implemented">Edit</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <router-link v-if="activeTenantId" to="/listing/create" class="btn-primary">İlan Ver</router-link>
  </section>
</template>

<script>
import { api, normalizeListResponse } from '../../../api/client.js';

function extractItems(resp) {
  const { items } = normalizeListResponse(resp);
  return Array.isArray(items) ? items : [];
}

export default {
  name: 'FirmListingsPanel',
  props: {
    activeTenantId: { type: String, required: true },
  },
  data() {
    return {
      items: [],
      loading: false,
      error: null,
    };
  },
  mounted() {
    this.load();
  },
  methods: {
    async load() {
      if (!this.activeTenantId) return;
      this.loading = true;
      this.error = null;
      try {
        const resp = await api.getStoreListings(this.activeTenantId);
        this.items = extractItems(resp);
      } catch (err) {
        this.error = err.message || 'İlanlar yüklenemedi';
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
.portal-section {
  margin: 1.5rem 0;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.portal-section h3 {
  margin-top: 0;
  margin-bottom: 0.25rem;
  color: #333;
}

.section-loading,
.section-empty {
  padding: 1rem 0;
  color: #666;
}

.section-error-box {
  padding: 1rem;
  background: #ffebee;
  border: 1px solid #d32f2f;
  border-radius: 4px;
  color: #c62828;
}

.section-error-box p {
  margin: 0 0 0.75rem 0;
}

.btn-retry {
  padding: 0.4rem 0.8rem;
  background: #d32f2f;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.875rem;
}

.btn-retry:hover {
  background: #b71c1c;
}

.section-empty {
  font-style: italic;
  color: #999;
}

.actions-cell {
  white-space: nowrap;
}

.btn-action {
  display: inline-block;
  margin-right: 0.5rem;
  padding: 0.25rem 0.5rem;
  font-size: 0.8rem;
  text-decoration: none;
  border-radius: 4px;
  border: 1px solid #007bff;
  background: #007bff;
  color: white;
  cursor: pointer;
}

.btn-action:hover {
  background: #0056b3;
}

.btn-action.btn-disabled {
  background: #ccc;
  border-color: #999;
  color: #666;
  cursor: not-allowed;
}

.btn-primary {
  display: inline-block;
  margin-top: 0.75rem;
  padding: 0.5rem 1rem;
  background: #28a745;
  color: white;
  text-decoration: none;
  border-radius: 4px;
}

.btn-primary:hover {
  background: #218838;
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
</style>
