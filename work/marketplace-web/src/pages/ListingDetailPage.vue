<template>
  <div class="listing-detail-page">
    <div v-if="loading" class="loading">Loading listing...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else-if="listing" class="listing-detail">
      <h2>{{ listing.title || 'Untitled Listing' }}</h2>
      <div class="detail-section">
        <h3>Basic Info</h3>
        <p><strong>ID:</strong> {{ listing.id }}</p>
        <p><strong>Status:</strong> {{ listing.status }}</p>
        <p v-if="listing.category_id"><strong>Category ID:</strong> {{ listing.category_id }}</p>
        <div v-if="listing.transaction_modes && listing.transaction_modes.length > 0" class="transaction-modes">
          <strong>Transaction Modes:</strong>
          <div class="transaction-badges">
            <span
              v-for="mode in listing.transaction_modes"
              :key="mode"
              class="transaction-badge"
              :class="`transaction-badge-${mode}`"
            >
              {{ mode.charAt(0).toUpperCase() + mode.slice(1) }}
            </span>
          </div>
        </div>
      </div>
      <div v-if="listing.attributes" class="detail-section">
        <h3>Attributes</h3>
        <pre class="attributes-json">{{ JSON.stringify(listing.attributes, null, 2) }}</pre>
      </div>
      <div v-if="listing" class="detail-section">
        <h3>Full Data</h3>
        <pre class="full-json">{{ JSON.stringify(listing, null, 2) }}</pre>
      </div>
      <div class="actions">
        <button @click="openMessaging" class="action-button">Message Seller</button>
        <router-link to="/reservation/create" class="action-button">Create Reservation</router-link>
        <router-link to="/rental/create" class="action-button">Create Rental</router-link>
        <button disabled class="action-button">Satın Al (Coming Next)</button>
      </div>
      
      <div v-if="listing && listing.status === 'draft'" class="publish-section">
        <h3>Publish Listing</h3>
        <PublishListingAction :listing-id="listing.id" @published="handlePublished" />
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';
import PublishListingAction from '../components/PublishListingAction.vue';

export default {
  name: 'ListingDetailPage',
  components: {
    PublishListingAction,
  },
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      listing: null,
      loading: true,
      error: null,
    };
  },
  async mounted() {
    await this.loadListing();
  },
  methods: {
    async loadListing() {
      try {
        this.listing = await api.getListing(this.id);
        this.loading = false;
      } catch (err) {
        // WP-62: Better error handling for 404 and other errors
        if (err.status === 404) {
          this.error = `Listing not found (ID: ${this.id})`;
        } else if (err.status) {
          this.error = `Error ${err.status}: ${err.message || 'Unknown error'}`;
        } else {
          this.error = err.message || 'Failed to load listing';
        }
        this.loading = false;
      }
    },
    handlePublished(updatedListing) {
      this.listing = updatedListing;
    },
    openMessaging() {
      this.$router.push(`/listing/${this.id}/message`);
    },
  },
};
</script>

<style scoped>
.listing-detail-page {
  max-width: 900px;
}

.listing-detail h2 {
  margin-bottom: 1.5rem;
  font-size: 2rem;
}

.detail-section {
  margin-bottom: 2rem;
  padding: 1.5rem;
  background: #f9f9f9;
  border-radius: 8px;
}

.detail-section h3 {
  margin-bottom: 1rem;
  font-size: 1.3rem;
}

.detail-section p {
  margin-bottom: 0.5rem;
}

.attributes-json,
.full-json {
  background: #f5f5f5;
  padding: 1rem;
  border-radius: 4px;
  overflow-x: auto;
  font-size: 0.9rem;
  line-height: 1.5;
}

.actions {
  margin-top: 2rem;
  display: flex;
  gap: 1rem;
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
  margin-right: 0.5rem;
}

.action-button:hover {
  background: #0052a3;
}

.action-button:disabled {
  background: #f5f5f5;
  color: #999;
  cursor: not-allowed;
}

.publish-section {
  margin-top: 2rem;
  padding: 1.5rem;
  background: #f9f9f9;
  border-radius: 8px;
}

.publish-section h3 {
  margin-bottom: 1rem;
}

.transaction-modes {
  margin-top: 1rem;
}

.transaction-modes strong {
  display: block;
  margin-bottom: 0.5rem;
}

.transaction-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.transaction-badge {
  display: inline-block;
  padding: 0.4rem 0.8rem;
  border-radius: 4px;
  font-size: 0.9rem;
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
</style>

