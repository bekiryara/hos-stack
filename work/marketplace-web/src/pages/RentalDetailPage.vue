<template>
  <div class="transaction-detail">
    <div class="detail-header">
      <router-link :to="{ path: '/account', query: { tab: 'rentals' } }" class="back-link">← Back to Account</router-link>
      <h2>Rental {{ safe(item.id) }}</h2>
    </div>
    <div v-if="limitedMode" class="limited-banner">Limited view (no detail endpoint)</div>
    <SectionShell
      title="Details"
      :status="loading ? 'loading' : (error ? 'error' : 'ready')"
      :error-message="error ? (error.message || '') : ''"
      :empty="!loading && !error && !item.id"
      empty-text="No data"
      @retry="load"
    >
      <ul class="detail-list">
        <li><strong>id:</strong> {{ safe(item.id) }}</li>
        <li><strong>listing_id:</strong> {{ safe(item.listing_id) }}</li>
        <li><strong>status:</strong> {{ safe(item.status) }}</li>
        <li><strong>created_at:</strong> {{ safe(item.created_at) }}</li>
        <li><strong>updated_at:</strong> {{ safe(item.updated_at) }}</li>
      </ul>
    </SectionShell>
  </div>
</template>

<script>
import SectionShell from '../components/portal/SectionShell.vue';

export default {
  name: 'RentalDetailPage',
  components: { SectionShell },
  props: { id: { type: String, required: true } },
  data() {
    return {
      item: {},
      loading: false,
      error: null,
      limitedMode: false,
    };
  },
  mounted() {
    this.load();
  },
  methods: {
    safe(val) {
      if (val == null || val === '') return '—';
      return val;
    },
    load() {
      this.loading = true;
      this.error = null;
      const q = this.$route.query;
      this.item = {
        id: this.id,
        listing_id: q.listing_id ?? null,
        status: q.status ?? null,
        created_at: q.created_at ?? null,
        updated_at: q.updated_at ?? null,
      };
      this.limitedMode = true;
      this.loading = false;
    },
  },
};
</script>

<style scoped>
.transaction-detail { max-width: 600px; margin: 0 auto; padding: 1.5rem; }
.detail-header { margin-bottom: 1rem; }
.back-link { font-size: 0.9rem; color: #0066cc; text-decoration: none; }
.back-link:hover { text-decoration: underline; }
.limited-banner { padding: 0.5rem 1rem; background: #fff3cd; border: 1px solid #ffc107; border-radius: 4px; margin-bottom: 1rem; font-size: 0.9rem; }
.detail-list { list-style: none; padding: 0; margin: 0; }
.detail-list li { margin-bottom: 0.35rem; }
</style>
