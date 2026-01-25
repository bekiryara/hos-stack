<template>
  <div class="listings-grid">
    <div v-if="listings.length > 0" class="grid">
      <div
        v-for="listing in listings"
        :key="listing.id"
        class="listing-card"
        @click="goToDetail(listing.id)"
      >
        <h4>{{ listing.title || 'Untitled' }}</h4>
        <p class="listing-id">
          ID: {{ listing.id }}
          <button @click.stop="copyListingId(listing.id)" class="copy-id-btn" title="Copy listing ID">Copy</button>
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
          <button @click="goToDetail(listing.id)" class="action-btn view-btn">View</button>
          <button
            v-if="listing.transaction_modes && listing.transaction_modes.includes('reservation')"
            @click="goToReservation(listing.id)"
            class="action-btn reserve-btn"
          >
            Reserve
          </button>
          <button
            v-if="listing.transaction_modes && listing.transaction_modes.includes('rental')"
            @click="goToRental(listing.id)"
            class="action-btn rent-btn"
          >
            Rent
          </button>
        </div>
      </div>
    </div>
    <div v-else class="no-results">No listings found</div>
  </div>
</template>

<script>
export default {
  name: 'ListingsGrid',
  props: {
    listings: {
      type: Array,
      default: () => [],
    },
  },
  methods: {
    goToDetail(id) {
      this.$router.push(`/listing/${id}`);
    },
    goToReservation(listingId) {
      this.$router.push(`/marketplace/reservation/create?listing_id=${listingId}`);
    },
    goToRental(listingId) {
      this.$router.push(`/marketplace/rental/create?listing_id=${listingId}`);
    },
    copyListingId(id) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(id).then(() => {
          // Optional: Show brief feedback (minimal UI change)
          const btn = event.target;
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
  background: white;
  border: 1px solid #ddd;
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
  color: #0066cc;
}

.listing-id {
  font-size: 0.85rem;
  color: #666;
  margin-bottom: 0.25rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.copy-id-btn {
  font-size: 0.75rem;
  padding: 0.2rem 0.5rem;
  border: 1px solid #ccc;
  border-radius: 3px;
  background: #f5f5f5;
  color: #333;
  cursor: pointer;
  transition: background 0.2s;
}

.copy-id-btn:hover {
  background: #e5e5e5;
}

.listing-category {
  font-size: 0.85rem;
  color: #666;
  margin-bottom: 0.25rem;
}

.listing-status {
  font-size: 0.9rem;
  color: #888;
  margin-bottom: 0.5rem;
}

.attributes-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.attribute-tag {
  background: #e3f2fd;
  color: #1976d2;
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
  background: #e3f2fd;
  color: #1976d2;
}

.transaction-badge-rental {
  background: #f3e5f5;
  color: #7b1fa2;
}

.transaction-badge-sale {
  background: #e8f5e9;
  color: #388e3c;
}

.listing-actions {
  margin-top: 1rem;
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.action-btn {
  padding: 0.5rem 1rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: white;
  color: #333;
  cursor: pointer;
  font-size: 0.9rem;
  transition: all 0.2s;
}

.action-btn:hover {
  background: #f5f5f5;
  border-color: #999;
}

.view-btn {
  background: #0066cc;
  color: white;
  border-color: #0066cc;
}

.view-btn:hover {
  background: #0052a3;
  border-color: #0052a3;
}

.reserve-btn {
  background: #1976d2;
  color: white;
  border-color: #1976d2;
}

.reserve-btn:hover {
  background: #1565c0;
  border-color: #1565c0;
}

.rent-btn {
  background: #7b1fa2;
  color: white;
  border-color: #7b1fa2;
}

.rent-btn:hover {
  background: #6a1b9a;
  border-color: #6a1b9a;
}

.no-results {
  text-align: center;
  padding: 3rem;
  color: #666;
  font-size: 1.1rem;
}
</style>


