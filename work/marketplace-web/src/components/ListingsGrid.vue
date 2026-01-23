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
        <div v-if="listing.attributes" class="attributes-summary">
          <span
            v-for="(value, key) in listing.attributes"
            :key="key"
            class="attribute-tag"
          >
            {{ key }}: {{ value }}
          </span>
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

.no-results {
  text-align: center;
  padding: 3rem;
  color: #666;
  font-size: 1.1rem;
}
</style>


