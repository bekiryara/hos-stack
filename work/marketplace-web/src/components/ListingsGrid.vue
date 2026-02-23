<template>
  <div class="listings-grid">
    <div v-if="listings.length > 0" class="grid">
      <div
        v-for="listing in listings"
        :key="listing.id"
        class="listing-card"
        @click="goToDetail(listing.id)"
      >
        <div class="thumb" aria-hidden="true">
          <div class="thumb-placeholder">
            <div class="thumb-badge">Fotoğraf</div>
          </div>
        </div>
        <h4>{{ listing.title || 'Untitled' }}</h4>
        <div v-if="listing.price" class="listing-price">
          {{ formatPrice(listing.price, listing.price_currency) }}
        </div>
        <div v-if="highlightsFor(listing).length" class="highlights">
          <span v-for="h in highlightsFor(listing)" :key="h.key" class="highlight-tag">
            {{ h.value }}
          </span>
        </div>
        <div v-if="listing.transaction_modes && listing.transaction_modes.length > 0" class="transaction-modes-summary">
          <span
            v-for="mode in listing.transaction_modes"
            :key="mode"
            class="transaction-badge"
            :class="`transaction-badge-${mode}`"
          >
            {{ modeLabel(mode) }}
          </span>
        </div>
        <div class="listing-actions" @click.stop>
          <button
            v-for="a in actionsFor(listing)"
            :key="a.key"
            type="button"
            class="action-btn"
            :class="a.uiClass"
            @click="runAction(a)"
          >
            {{ a.label }}
          </button>
        </div>
      </div>
    </div>
    <div v-else class="no-results">No listings found</div>
  </div>
</template>

<script>
import { resolveListingActions } from '../lib/listingActions';

export default {
  name: 'ListingsGrid',
  props: {
    listings: {
      type: Array,
      default: () => [],
    },
  },
  methods: {
    actionsFor(listing) {
      return resolveListingActions(listing, { context: 'grid' });
    },
    runAction(action) {
      if (!action || !action.to) return;
      this.$router.push(action.to);
    },
    goToDetail(id) {
      this.$router.push(`/listing/${id}`);
    },
    formatPrice(amount, currency) {
      if (!amount && amount !== 0) return '';
      const c = currency || 'TRY';
      try {
        return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: c, minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(amount);
      } catch {
        return `${amount} ${c}`;
      }
    },
    highlightsFor(listing) {
      const keys = listing.card_highlights || [];
      const attrs = listing.attributes || {};
      return keys
        .filter(k => attrs[k] != null && attrs[k] !== '')
        .map(k => ({ key: k, value: String(attrs[k]) }))
        .slice(0, 4);
    },
    modeLabel(mode) {
      const labels = { sale: 'Satılık', rental: 'Kiralık', reservation: 'Rezervasyon' };
      return labels[mode] || mode;
    },
  },
};
</script>

<style scoped>
.listings-grid {
  margin-top: 2rem;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
}

.listing-card {
  background: var(--surface, #fff);
  border: 1px solid var(--border, #e5e7eb);
  border-radius: 8px;
  padding: 1.5rem;
  cursor: pointer;
  transition: box-shadow 0.2s;
}

.listing-card:hover {
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.listing-card h4 {
  margin-bottom: 0.5rem;
  color: var(--text-strong, #1f2937);
  font-weight: 600;
}

.listing-price {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--accent, #ef4444);
  margin-bottom: 0.5rem;
}

.highlights {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-bottom: 0.5rem;
}

.highlight-tag {
  background: var(--pill-bg, #f1f5f9);
  color: var(--pill-text, #334155);
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
  font-size: 0.8rem;
}

.transaction-modes-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.transaction-badge {
  display: inline-block;
  padding: 0.3rem 0.6rem;
  border-radius: 3px;
  font-size: 0.8rem;
  font-weight: 500;
  text-transform: capitalize;
}

.transaction-badge-reservation {
  background: var(--pill-bg, #f1f5f9);
  color: var(--pill-text, #334155);
}

.transaction-badge-rental {
  background: var(--pill-bg, #f1f5f9);
  color: var(--pill-text, #334155);
}

.transaction-badge-sale {
  background: var(--pill-bg, #f1f5f9);
  color: var(--pill-text, #334155);
}

.listing-actions {
  margin-top: 1rem;
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.action-btn {
  padding: 0.5rem 1rem;
  border: 1px solid var(--border, #e5e7eb);
  border-radius: 4px;
  background: var(--surface, #fff);
  color: var(--text, #374151);
  cursor: pointer;
  font-size: 0.9rem;
  transition: all 0.2s;
}

.action-btn:hover {
  background: #f8fafc;
  border-color: #cbd5e1;
}

.view-btn {
  background: var(--btn-neutral, #111827);
  color: white;
  border-color: var(--btn-neutral, #111827);
}

.view-btn:hover {
  background: var(--btn-neutral-hover, #0b1220);
  border-color: var(--btn-neutral-hover, #0b1220);
}

.reserve-btn {
  background: var(--surface, #fff);
  color: var(--text, #374151);
  border-color: var(--border, #e5e7eb);
}

.reserve-btn:hover {
  background: #f8fafc;
  border-color: #cbd5e1;
}

.rent-btn {
  background: var(--surface, #fff);
  color: var(--text, #374151);
  border-color: var(--border, #e5e7eb);
}

.rent-btn:hover {
  background: #f8fafc;
  border-color: #cbd5e1;
}

.buy-btn {
  background: var(--surface, #fff);
  color: var(--text, #374151);
  border-color: var(--border, #e5e7eb);
}

.buy-btn:hover {
  background: #f8fafc;
  border-color: #cbd5e1;
}

.thumb {
  border-radius: 10px;
  background: linear-gradient(135deg, #f1f5f9, #e2e8f0);
  aspect-ratio: 16 / 9;
  margin: -0.25rem 0 0.75rem;
  overflow: hidden;
  border: 1px solid var(--border, #e5e7eb);
}

.thumb-placeholder {
  height: 100%;
  display: grid;
  place-content: center;
  text-align: center;
  gap: 0.25rem;
}

.thumb-badge {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.65);
  border: 1px solid rgba(226, 232, 240, 0.9);
  color: var(--text-label, #4b5563);
  font-size: 0.8rem;
  font-weight: 600;
}

.no-results {
  text-align: center;
  padding: 3rem;
  color: #666;
  font-size: 1.1rem;
}
</style>


