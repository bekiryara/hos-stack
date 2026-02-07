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
            <div class="thumb-subtle">Demo</div>
          </div>
        </div>
        <h4>{{ listing.title || 'Untitled' }}</h4>
        <p class="listing-id">
          ID: {{ listing.id }}
          <button @click.stop="copyListingId(listing.id, $event)" class="copy-id-btn" title="Copy listing ID">Copy</button>
        </p>
        <p v-if="listing.category_id" class="listing-category">Category ID: {{ listing.category_id }}</p>
        <p class="listing-status">Status: {{ listing.status }}</p>
        <div v-if="listing.transaction_modes && listing.transaction_modes.length > 0" class="transaction-modes-summary">
          <span
            v-for="mode in listing.transaction_modes"
            :key="mode"
            class="transaction-badge"
            :class="`transaction-badge-${mode}`"
          >
            {{ mode.charAt(0).toUpperCase() + mode.slice(1) }}
          </span>
        </div>
        <div v-if="listing.attributes" class="attributes-summary">
          <span
            v-for="(value, key) in listing.attributes"
            :key="key"
            class="attribute-tag"
          >
            {{ key }}: {{ value }}
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
    copyListingId(id, evt) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(id).then(() => {
          // Optional: Show brief feedback (minimal UI change)
          const btn = evt?.target;
          if (!btn) return;
          const originalText = btn.textContent;
          btn.textContent = 'Copied!';
          setTimeout(() => {
            btn.textContent = originalText;
          }, 1000);
        }).catch(err => {
          console.error('Failed to copy:', err);
        });
      } else {
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = id;
        document.body.appendChild(textArea);
        textArea.select();
        try {
          document.execCommand('copy');
        } catch (err) {
          console.error('Fallback copy failed:', err);
        }
        document.body.removeChild(textArea);
      }
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

.listing-id {
  font-size: 0.85rem;
  color: var(--text-muted, #6b7280);
  margin-bottom: 0.25rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.copy-id-btn {
  font-size: 0.75rem;
  padding: 0.2rem 0.5rem;
  border: 1px solid var(--border, #e5e7eb);
  border-radius: 3px;
  background: var(--surface-2, #f8fafc);
  color: var(--text, #374151);
  cursor: pointer;
  transition: background 0.2s;
}

.copy-id-btn:hover {
  background: #eef2f7;
}

.listing-category {
  font-size: 0.85rem;
  color: var(--text-muted, #6b7280);
  margin-bottom: 0.25rem;
}

.listing-status {
  font-size: 0.9rem;
  color: var(--text-muted, #6b7280);
  margin-bottom: 0.5rem;
}

.attributes-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.attribute-tag {
  background: var(--pill-bg, #f1f5f9);
  color: var(--pill-text, #334155);
  padding: 0.25rem 0.5rem;
  border-radius: 3px;
  font-size: 0.85rem;
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

.thumb-subtle {
  color: var(--text-muted, #6b7280);
  font-size: 0.8rem;
}

.no-results {
  text-align: center;
  padding: 3rem;
  color: #666;
  font-size: 1.1rem;
}
</style>


