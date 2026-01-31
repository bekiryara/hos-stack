<template>
  <div v-if="actions.length" class="transaction-action-bar">
    <button
      v-for="action in actions"
      :key="action.label"
      type="button"
      class="action-button"
      :disabled="!listingId || transitioning"
      @click="goTo(action)"
    >
      {{ action.label }}
    </button>
  </div>
</template>

<script>
import { TX_ACTIONS } from '../../lib/transactions/modes.js';

export default {
  name: 'TransactionActionBar',
  props: {
    listing: { type: Object, default: null },
  },
  data() {
    return {
      transitioning: false,
    };
  },
  computed: {
    listingId() {
      return String(this.listing?.id ?? '');
    },
    modes() {
      const m = this.listing?.transaction_modes;
      return Array.isArray(m) ? m : [];
    },
    actions() {
      return this.modes
        .map((m) => TX_ACTIONS[m])
        .filter(Boolean);
    },
  },
  methods: {
    goTo(action) {
      if (!this.listingId || !action) return;
      this.transitioning = true;
      const query = action.buildQuery(this.listing) || {};
      this.$router
        .push({ path: action.route, query })
        .finally(() => { this.transitioning = false; });
    },
  },
};
</script>

<style scoped>
.transaction-action-bar {
  margin-top: 1rem;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.75rem;
}

.action-button {
  padding: 0.75rem 1.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: #0066cc;
  color: white;
  cursor: pointer;
  font-size: 1rem;
}

.action-button:hover:not(:disabled) {
  background: #0052a3;
}

.action-button:disabled {
  background: #f5f5f5;
  color: #999;
  cursor: not-allowed;
}
</style>
