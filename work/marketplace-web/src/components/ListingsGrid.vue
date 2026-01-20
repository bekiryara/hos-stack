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
        <p class="listing-id">ID: {{ listing.id }}</p>
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


