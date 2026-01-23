<template>
  <div class="demo-dashboard-page">
    <h2>Demo Dashboard</h2>
    <div v-if="loading" class="loading">Loading demo listing...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else-if="listing" class="demo-listing">
      <h3>{{ listing.title || 'Demo Listing' }}</h3>
      <p><strong>Status:</strong> {{ listing.status }}</p>
      <p v-if="listing.description">{{ listing.description }}</p>
      <div class="actions">
        <button @click="openMessaging" class="action-button">Message Seller</button>
        <router-link :to="`/listing/${listing.id}`" class="action-button">View Details</router-link>
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';

export default {
  name: 'DemoDashboardPage',
  data() {
    return {
      listing: null,
      loading: true,
      error: null,
    };
  },
  async mounted() {
    await this.ensureDemoListing();
  },
  methods: {
    async ensureDemoListing() {
      try {
        // Try to get existing published listings
        const listings = await api.searchListings({ status: 'published', limit: 1 });
        const items = Array.isArray(listings) ? listings : (listings.items || []);
        
        if (items.length > 0) {
          this.listing = items[0];
          this.loading = false;
          return;
        }

        // If no published listing exists, try to get any listing
        const allListings = await api.searchListings({ limit: 1 });
        const allItems = Array.isArray(allListings) ? allListings : (allListings.items || []);
        
        if (allItems.length > 0) {
          this.listing = allItems[0];
          this.loading = false;
          return;
        }

        // No listing found - show message
        this.error = 'No demo listing found. Please create a listing first.';
        this.loading = false;
      } catch (err) {
        this.error = err.message;
        this.loading = false;
      }
    },
    openMessaging() {
      if (this.listing && this.listing.id) {
        this.$router.push(`/listing/${this.listing.id}/message`);
      }
    },
  },
};
</script>

<style scoped>
.demo-dashboard-page {
  max-width: 900px;
}

.demo-dashboard-page h2 {
  margin-bottom: 1.5rem;
  font-size: 2rem;
}

.demo-listing {
  padding: 1.5rem;
  background: #f9f9f9;
  border-radius: 8px;
  margin-top: 1rem;
}

.demo-listing h3 {
  margin-bottom: 1rem;
  font-size: 1.5rem;
}

.actions {
  margin-top: 1.5rem;
}

.action-button {
  padding: 0.75rem 1.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: #0066cc;
  color: white;
  cursor: pointer;
  font-size: 1rem;
  text-decoration: none;
  display: inline-block;
}

.action-button:hover {
  background: #0052a3;
}
</style>

