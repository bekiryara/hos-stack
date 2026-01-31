<template>
  <section class="portal-section">
    <h3>Gelen Rezervasyonlar</h3>
    <p class="section-hint">Onayla veya Reddet ile rezervasyon durumunu güncelleyebilirsiniz.</p>
    <div v-if="loading" class="section-loading">Loading …</div>
    <div v-else-if="error" class="section-error-box">
      <p>{{ error }}</p>
      <button type="button" class="btn-retry" @click="load">Retry</button>
    </div>
    <div v-else-if="!items.length" class="section-empty">No reservations yet</div>
    <div v-else class="section-list">
      <table class="data-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Listing ID</th>
            <th>Durum</th>
            <th>Oluşturulma</th>
            <th>İşlem</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in items" :key="item.id">
            <td>{{ item.id }}</td>
            <td>{{ item.listing_id || '—' }}</td>
            <td>{{ item.status || '—' }}</td>
            <td>{{ formatDate(item.created_at) }}</td>
            <td class="actions-cell">
              <button type="button" class="btn-action" :disabled="!canApprove(item) || transitioning[item.id]" @click="acceptReservation(item.id)">Accept</button>
              <button type="button" class="btn-action btn-reject" :disabled="!canReject(item) || transitioning[item.id]" @click="rejectReservation(item.id)">Reject</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<script>
import { api, normalizeListResponse } from '../../../api/client.js';

function extractItems(resp) {
  const { items } = normalizeListResponse(resp);
  return Array.isArray(items) ? items : [];
}

export default {
  name: 'FirmReservationsPanel',
  props: {
    activeTenantId: { type: String, required: true },
  },
  data() {
    return {
      items: [],
      loading: false,
      error: null,
      transitioning: {},
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
        const resp = await api.getStoreReservations(this.activeTenantId);
        this.items = extractItems(resp);
      } catch (err) {
        this.error = err.message || 'Rezervasyonlar yüklenemedi';
      } finally {
        this.loading = false;
      }
    },
    formatDate(dateStr) {
      if (!dateStr) return '—';
      try {
        return new Date(dateStr).toLocaleString();
      } catch {
        return dateStr;
      }
    },
    canApprove(item) {
      return item && item.status === 'requested';
    },
    canReject(item) {
      return item && item.status === 'requested';
    },
    async acceptReservation(id) {
      if (!this.activeTenantId) return;
      this.transitioning = { ...this.transitioning, [id]: true };
      this.error = null;
      try {
        await api.acceptStoreReservation(id, this.activeTenantId);
        await this.load();
      } catch (err) {
        this.error = err.message || err.data?.message || 'İşlem başarısız';
      } finally {
        this.transitioning = { ...this.transitioning, [id]: false };
      }
    },
    async rejectReservation(id) {
      if (!this.activeTenantId) return;
      this.transitioning = { ...this.transitioning, [id]: true };
      this.error = null;
      try {
        await api.rejectStoreReservation(id, this.activeTenantId);
        await this.load();
      } catch (err) {
        this.error = err.message || err.data?.message || 'İşlem başarısız';
      } finally {
        this.transitioning = { ...this.transitioning, [id]: false };
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

.section-hint {
  margin: 0 0 0.75rem 0;
  font-size: 0.875rem;
  color: #666;
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

.btn-action:disabled {
  background: #ccc;
  border-color: #999;
  color: #666;
  cursor: not-allowed;
}

.btn-action.btn-reject {
  background: #dc3545;
  border-color: #dc3545;
}

.btn-action.btn-reject:hover:not(:disabled) {
  background: #c82333;
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
